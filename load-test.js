import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter } from 'k6/metrics';

const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

const BASE_URL = __ENV.BASE_URL || 'http://localhost:6875';
const USER_EMAIL = __ENV.BOOKSTACK_USER || 'admin@admin.com';
const USER_PASSWORD = __ENV.BOOKSTACK_PASSWORD || 'teste12345';
const SUMMARY_PATH = __ENV.SUMMARY_PATH || 'results/k6-summary.json';

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // 1. Aquecimento (Warm-up): 10 usuários virtuais
    { duration: '1m',  target: 30 },  // 2. Carga média sustentada: 30 usuários virtuais
    { duration: '1m',  target: 80 },  // 3. Estresse / Pico: 80 usuários virtuais
    { duration: '30s', target: 0 },   // 4. Recuperação / Desaceleração: volta a 0
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],    // Taxa de falhas HTTP < 5%
    http_req_duration: ['p(95)<800'],  // 95% das requisições devem responder abaixo de 800ms
  },
};

// Termos comuns para simular busca real no banco de dados populado
const searchTerms = ['Large', 'book', 'test', 'page', 'chapter', 'content', 'dummy'];

export default function () {
  const random = Math.random();

  // Cenário 1 (60% das requisições): Navegação e Leitura Pública
  if (random < 0.60) {
    group('Navegacao e Leitura', function () {
      const res = http.get(`${BASE_URL}/books`);
      const booksOk = res.status === 200;
      if (booksOk) successfulRequests.add(1); else failedRequests.add(1);

      check(res, {
        'Livros carregados (HTTP 200)': (r) => r.status === 200,
      });

      sleep(Math.random() * 2 + 1);

      const shelfRes = http.get(`${BASE_URL}/shelves`);
      const shelfOk = shelfRes.status === 200;
      if (shelfOk) successfulRequests.add(1); else failedRequests.add(1);

      check(shelfRes, {
        'Prateleiras carregadas (HTTP 200)': (r) => r.status === 200,
      });
    });
  }
  // Cenário 2 (20% das requisições): Busca Textual (Estresse no Laravel + MariaDB)
  else if (random < 0.80) {
    group('Busca Textual', function () {
      const term = searchTerms[Math.floor(Math.random() * searchTerms.length)];
      const searchRes = http.get(`${BASE_URL}/search?term=${encodeURIComponent(term)}`);
      const searchOk = searchRes.status === 200;
      if (searchOk) successfulRequests.add(1); else failedRequests.add(1);

      check(searchRes, {
        'Busca respondeu (HTTP 200)': (r) => r.status === 200,
      });
      sleep(1);
    });
  }
  // Cenário 3 (20% das requisições): Fluxo Completo de Autenticação (Login, Admin/Settings e Logout)
  else {
    group('Fluxo de Login e Autenticacao', function () {
      const jar = http.cookieJar();
      jar.clear(BASE_URL);

      // 1. Acessa a página de login para obter o CSRF token do Laravel
      const loginPageRes = http.get(`${BASE_URL}/login`);
      const tokenMatch = loginPageRes.body
        ? loginPageRes.body.match(/name="_token"\s+value="([^"]+)"/) || loginPageRes.body.match(/value="([^"]+)"\s+name="_token"/)
        : null;
      const csrfToken = tokenMatch ? tokenMatch[1] : '';

      // 2. Realiza POST de Login com as credenciais
      const loginPayload = {
        email: USER_EMAIL,
        password: USER_PASSWORD,
        _token: csrfToken,
      };

      const loginRes = http.post(`${BASE_URL}/login`, loginPayload, {
        redirects: 2,
      });

      const loginOk = loginRes.status === 200 || loginRes.status === 302;

      // 3. Acessa área autenticada (painel de configurações / livros do usuário)
      const settingsRes = http.get(`${BASE_URL}/settings`);
      const settingsOk = settingsRes.status === 200;

      if (loginOk && settingsOk) {
        successfulRequests.add(1);
      } else {
        failedRequests.add(1);
      }

      check(loginRes, {
        'Login efetuado': () => loginOk,
      });
      check(settingsRes, {
        'Acesso a configuracoes autenticado': () => settingsOk,
      });

      // Limpa a sessão para os próximos loops
      jar.clear(BASE_URL);
      sleep(2);
    });
  }
}

function metricValue(data, metric, field, fallback = 0) {
  return data.metrics?.[metric]?.values?.[field] ?? fallback;
}

export function handleSummary(data) {
  const summary = {
    workload: 'bookstack',
    http_requests: metricValue(data, 'http_reqs', 'count'),
    successful_requests: metricValue(data, 'successful_requests', 'count'),
    failed_requests: metricValue(data, 'failed_requests', 'count'),
    dropped_iterations: metricValue(data, 'dropped_iterations', 'count'),
    failure_rate: metricValue(data, 'http_req_failed', 'rate'),
    checks_rate: metricValue(data, 'checks', 'rate'),
    request_duration_ms: {
      average: metricValue(data, 'http_req_duration', 'avg'),
      median: metricValue(data, 'http_req_duration', 'med'),
      p90: metricValue(data, 'http_req_duration', 'p(90)'),
      p95: metricValue(data, 'http_req_duration', 'p(95)'),
      max: metricValue(data, 'http_req_duration', 'max'),
    },
  };

  const text =
    `\n=== RESUMO K6 (BOOKSTACK) ===\n` +
    `Total de Requisições:   ${summary.http_requests}\n` +
    `Requisições com Sucesso: ${summary.successful_requests}\n` +
    `Taxa de Falha:          ${(summary.failure_rate * 100).toFixed(2)}%\n` +
    `Latência Média:         ${summary.request_duration_ms.average.toFixed(2)} ms\n` +
    `Latência p95:           ${summary.request_duration_ms.p95.toFixed(2)} ms\n` +
    `=============================\n`;

  return {
    [SUMMARY_PATH]: JSON.stringify(summary, null, 2),
    stdout: text,
  };
}
