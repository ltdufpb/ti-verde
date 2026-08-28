import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter } from 'k6/metrics';

const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:8080';
const SUMMARY_PATH = __ENV.SUMMARY_PATH || 'results/k6-summary.json';

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '40s', target: 30 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<800'],
  },
};

export default function () {
  const random = Math.random();

  // Cenário 1: Página Inicial / Portal UFPB (40%)
  if (random < 0.40) {
    group('Portal UFPB Home & Noticias', function () {
      const res = http.get(`${BASE_URL}/`);
      const ok = res.status === 200;
      if (ok) successfulRequests.add(1); else failedRequests.add(1);

      check(res, {
        'Home UFPB carregada (HTTP 200)': (r) => r.status === 200,
      });
      sleep(1);
    });
  }
  // Cenário 2: Busca Institucional e Editais (35%)
  else if (random < 0.75) {
    group('Portal UFPB Busca & Editais', function () {
      const searchRes = http.get(`${BASE_URL}/?s=edital+concurso+2026`);
      const searchOk = searchRes.status === 200;
      if (searchOk) successfulRequests.add(1); else failedRequests.add(1);

      check(searchRes, {
        'Busca de editais responde': (r) => r.status === 200,
      });

      sleep(0.5);

      const categoryRes = http.get(`${BASE_URL}/category/noticias/`);
      const catOk = categoryRes.status === 200;
      if (catOk) successfulRequests.add(1); else failedRequests.add(1);

      check(categoryRes, {
        'Categoria de notícias responde': (r) => r.status === 200,
      });
      sleep(1);
    });
  }
  // Cenário 3: Estrutura Organizacional / Centros e Departamentos (25%)
  else {
    group('Portal UFPB Centros & Cursos', function () {
      const orgRes = http.get(`${BASE_URL}/ensino/graduacao/`);
      const orgOk = orgRes.status === 200;
      if (orgOk) successfulRequests.add(1); else failedRequests.add(1);

      check(orgRes, {
        'Página de graduação responde': (r) => r.status === 200,
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
