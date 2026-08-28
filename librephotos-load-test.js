import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter } from 'k6/metrics';

const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:3000';
const USERNAME = __ENV.LIBREPHOTOS_USER || 'admin';
const PASSWORD = __ENV.LIBREPHOTOS_PASS || 'AdminPass123!';
const SUMMARY_PATH = __ENV.SUMMARY_PATH || 'results/k6-summary.json';

export const options = {
  stages: [
    { duration: '10s', target: 5 },   // 1. Warm-up
    { duration: '30s', target: 15 },  // 2. Sustained Load
    { duration: '15s', target: 25 },  // 3. Peak Stress
    { duration: '5s',  target: 0 },   // 4. Cooldown
  ],
  thresholds: {
    http_req_failed: ['rate<0.10'],
    http_req_duration: ['p(95)<1500'],
  },
};

// Autentica uma vez no início do teste e distribui o token para todos os VUs
export function setup() {
  const loginPayload = JSON.stringify({
    username: USERNAME,
    password: PASSWORD,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const loginRes = http.post(`${BASE_URL}/api/auth/token/obtain/`, loginPayload, params);
  let authToken = '';

  if (loginRes.status === 200) {
    try {
      const body = JSON.parse(loginRes.body);
      if (body && body.access) {
        authToken = body.access;
      }
    } catch (e) {}
  }

  return { authToken };
}

export default function (data) {
  const random = Math.random();
  const token = data ? data.authToken : '';
  const authHeaders = token ? {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
  } : {
    headers: { 'Content-Type': 'application/json' },
  };

  // Cenário 1: Navegação Frontend Web (30%)
  if (random < 0.30) {
    group('Frontend Navigation', function () {
      const res = http.get(`${BASE_URL}/`);
      const ok = res.status === 200;
      if (ok) successfulRequests.add(1); else failedRequests.add(1);

      check(res, {
        'Frontend carregado (HTTP 200)': (r) => r.status === 200,
      });
      sleep(1);
    });
  }
  // Cenário 2: Consulta Álbuns / Timeline / Fotos (40%)
  else if (random < 0.70) {
    group('LibrePhotos Timeline & Photos', function () {
      const albumsRes = http.get(`${BASE_URL}/api/albums/date/list/`, authHeaders);
      const albumsOk = albumsRes.status === 200;
      if (albumsOk) successfulRequests.add(1); else failedRequests.add(1);

      check(albumsRes, {
        'Timeline álbuns (HTTP 200)': (r) => r.status === 200,
      });

      sleep(0.5);

      const photosRes = http.get(`${BASE_URL}/api/photos/`, authHeaders);
      const photosOk = photosRes.status === 200;
      if (photosOk) successfulRequests.add(1); else failedRequests.add(1);

      check(photosRes, {
        'Lista de fotos (HTTP 200)': (r) => r.status === 200,
      });
      sleep(0.5);
    });
  }
  // Cenário 3: Estatísticas, Usuário e Busca (30%)
  else {
    group('LibrePhotos Stats & Search', function () {
      const statsRes = http.get(`${BASE_URL}/api/stats/`, authHeaders);
      const statsOk = statsRes.status === 200;
      if (statsOk) successfulRequests.add(1); else failedRequests.add(1);

      check(statsRes, {
        'Stats respondem (HTTP 200)': (r) => r.status === 200,
      });

      sleep(0.5);

      const searchRes = http.get(`${BASE_URL}/api/photos/searchlist/?search=sample`, authHeaders);
      const searchOk = searchRes.status === 200;
      if (searchOk) successfulRequests.add(1); else failedRequests.add(1);

      check(searchRes, {
        'Busca responde (HTTP 200)': (r) => r.status === 200,
      });
      sleep(1);
    });
  }
}

export function handleSummary(data) {
  return {
    [SUMMARY_PATH]: JSON.stringify(data, null, 2),
  };
}
