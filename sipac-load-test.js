import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter } from 'k6/metrics';

const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:8080';
const USERNAME = __ENV.SIPAC_USER || __ENV.UFPB_USER || 'servidor_teste';
const PASSWORD = __ENV.SIPAC_PASS || __ENV.UFPB_PASS || 'ServidorPass123!';
const SUMMARY_PATH = __ENV.SUMMARY_PATH || 'results/k6-summary.json';

export const options = {
  stages: [
    { duration: '15s', target: 5 },
    { duration: '60s', target: 20 },
    { duration: '30s', target: 35 },
    { duration: '15s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.10'],
    http_req_duration: ['p(95)<2500'],
  },
};

export function setup() {
  const loginUrl = `${BASE_URL}/sipac/logar.do?dispatch=logOn`;
  const payload = {
    'user.login': USERNAME,
    'user.senha': PASSWORD,
  };

  const params = {
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    redirects: 2,
  };

  const loginRes = http.post(loginUrl, payload, params);
  let sessionCookie = '';

  if (loginRes.cookies && loginRes.cookies.JSESSIONID) {
    sessionCookie = loginRes.cookies.JSESSIONID[0].value;
  }

  return { sessionCookie };
}

export default function (data) {
  const random = Math.random();
  const sessionCookie = data ? data.sessionCookie : '';
  const headers = sessionCookie ? {
    headers: {
      'Cookie': `JSESSIONID=${sessionCookie}`,
      'User-Agent': 'k6-GreenLab-STI-UFPB-SIPAC',
    },
  } : {
    headers: { 'User-Agent': 'k6-GreenLab-STI-UFPB-SIPAC' },
  };

  // Cenário 1: Consulta e Busca de Processos (40%)
  if (random < 0.40) {
    group('SIPAC Busca de Processos', function () {
      const res = http.get(`${BASE_URL}/sipac/protocolo/mesa_virtual/lista.jsf`, headers);
      const ok = res.status === 200 || res.status === 302;
      if (ok) successfulRequests.add(1); else failedRequests.add(1);

      check(res, {
        'Mesa Virtual / Processos carregados': (r) => r.status === 200 || r.status === 302,
      });

      sleep(0.5);

      const searchRes = http.get(`${BASE_URL}/sipac/protocolo/busca_processos.jsf?ano=2026&tipo=1`, headers);
      const searchOk = searchRes.status === 200 || searchRes.status === 302;
      if (searchOk) successfulRequests.add(1); else failedRequests.add(1);

      check(searchRes, {
        'Busca de processos executada': (r) => r.status === 200 || r.status === 302,
      });
      sleep(1);
    });
  }
  // Cenário 2: Requisições e Compras / Almoxarifado (35%)
  else if (random < 0.75) {
    group('SIPAC Modulo Compras e Requisicoes', function () {
      const reqRes = http.get(`${BASE_URL}/sipac/requisicoes/minhas_requisicoes.jsf`, headers);
      const reqOk = reqRes.status === 200 || reqRes.status === 302;
      if (reqOk) successfulRequests.add(1); else failedRequests.add(1);

      check(reqRes, {
        'Lista de requisições carregada': (r) => r.status === 200 || r.status === 302,
      });
      sleep(1);
    });
  }
  // Cenário 3: Consulta Pública de Licitações e Contratos (25%)
  else {
    group('SIPAC Portal Publico de Transparencia e Contratos', function () {
      const pubRes = http.get(`${BASE_URL}/sipac/publico/contratos/lista.jsf`);
      const pubOk = pubRes.status === 200 || pubRes.status === 302;
      if (pubOk) successfulRequests.add(1); else failedRequests.add(1);

      check(pubRes, {
        'Contratos e transparência respondem': (r) => r.status === 200 || r.status === 302,
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
