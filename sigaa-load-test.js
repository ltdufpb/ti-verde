import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter } from 'k6/metrics';

const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:8080';
const USERNAME = __ENV.SIGAA_USER || __ENV.UFPB_USER || 'discente_teste';
const PASSWORD = __ENV.SIGAA_PASS || __ENV.UFPB_PASS || 'DiscentePass123!';
const SUMMARY_PATH = __ENV.SUMMARY_PATH || 'results/k6-summary.json';

export const options = {
  stages: [
    { duration: '15s', target: 10 },  // 1. Warm-up
    { duration: '60s', target: 30 },  // 2. Carga Sustentada (Horário de Pico)
    { duration: '30s', target: 50 },  // 3. Estresse (Período de Matrícula)
    { duration: '15s', target: 0 },   // 4. Cooldown
  ],
  thresholds: {
    http_req_failed: ['rate<0.10'],
    http_req_duration: ['p(95)<2500'], // Sistemas Java corporativos JSF/Hibernate
  },
};

// Autentica e extrai cookie JSESSIONID / Token SSO no início da execução
export function setup() {
  const loginUrl = `${BASE_URL}/sigaa/logar.do?dispatch=logOn`;
  const payload = {
    'user.login': USERNAME,
    'user.senha': PASSWORD,
  };

  const params = {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
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
      'User-Agent': 'k6-GreenLab-STI-UFPB-LoadTester',
    },
  } : {
    headers: { 'User-Agent': 'k6-GreenLab-STI-UFPB-LoadTester' },
  };

  // Cenário 1: Navegação no Portal do Discente / Painel Principal (30%)
  if (random < 0.30) {
    group('SIGAA Portal Discente', function () {
      const res = http.get(`${BASE_URL}/sigaa/portais/discente/discente.jsf`, headers);
      const ok = res.status === 200 || res.status === 302;
      if (ok) successfulRequests.add(1); else failedRequests.add(1);

      check(res, {
        'Portal Discente acessível': (r) => r.status === 200 || r.status === 302,
      });
      sleep(1);
    });
  }
  // Cenário 2: Consulta de Turmas Virtuais e Notas (30%)
  else if (random < 0.60) {
    group('SIGAA Turmas e Notas', function () {
      const turmasRes = http.get(`${BASE_URL}/sigaa/portais/discente/turmas.jsf`, headers);
      const turmasOk = turmasRes.status === 200 || turmasRes.status === 302;
      if (turmasOk) successfulRequests.add(1); else failedRequests.add(1);

      check(turmasRes, {
        'Turmas virtuais carregadas': (r) => r.status === 200 || r.status === 302,
      });

      sleep(0.5);

      const notasRes = http.get(`${BASE_URL}/sigaa/ensino/matricula/relatorios/boletim.jsf`, headers);
      const notasOk = notasRes.status === 200 || notasRes.status === 302;
      if (notasOk) successfulRequests.add(1); else failedRequests.add(1);

      check(notasRes, {
        'Boletim/Notas carregados': (r) => r.status === 200 || r.status === 302,
      });
      sleep(1);
    });
  }
  // Cenário 3: Emissão de Declaração de Vínculo e Histórico Escolar (Geração PDF / CPU-heavy) (25%)
  else if (random < 0.85) {
    group('SIGAA Emissão de Documentos e Histórico', function () {
      const declRes = http.get(`${BASE_URL}/sigaa/ensino/declaracao_vinculo.jsf`, headers);
      const declOk = declRes.status === 200 || declRes.status === 302;
      if (declOk) successfulRequests.add(1); else failedRequests.add(1);

      check(declRes, {
        'Declaração de vínculo gerada': (r) => r.status === 200 || r.status === 302,
      });

      sleep(1);

      const histRes = http.get(`${BASE_URL}/sigaa/ensino/historico.jsf`, headers);
      const histOk = histRes.status === 200 || histRes.status === 302;
      if (histOk) successfulRequests.add(1); else failedRequests.add(1);

      check(histRes, {
        'Histórico escolar processado': (r) => r.status === 200 || r.status === 302,
      });
      sleep(1.5);
    });
  }
  // Cenário 4: Consulta Pública de Cursos e Componentes Curriculares (15%)
  else {
    group('SIGAA Consultas Públicas', function () {
      const publicRes = http.get(`${BASE_URL}/sigaa/public/curso/curriculo.jsf`);
      const publicOk = publicRes.status === 200 || publicRes.status === 302;
      if (publicOk) successfulRequests.add(1); else failedRequests.add(1);

      check(publicRes, {
        'Consulta pública responde': (r) => r.status === 200 || r.status === 302,
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
