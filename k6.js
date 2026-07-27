import http from "k6/http";
import { check } from "k6";
import { Counter } from "k6/metrics";

const successfulRequests = new Counter("successful_requests");
const failedRequests = new Counter("failed_requests");

const baseUrl = __ENV.BASE_URL || "http://127.0.0.1:8080";
const workload = __ENV.WORKLOAD || "mixed";
const implementation = __ENV.IMPLEMENTATION || "slow";
const scale = __ENV.SCALE || "1";
const rate = Number(__ENV.RATE || 2);
const durationSeconds = Number(__ENV.DURATION_SECONDS || 60);
const summaryPath = __ENV.SUMMARY_PATH || "results/k6-summary.json";

export const options = {
  discardResponseBodies: true,
  scenarios: {
    measured_workload: {
      executor: "constant-arrival-rate",
      rate,
      timeUnit: "1s",
      duration: `${durationSeconds}s`,
      preAllocatedVUs: Math.max(rate * 2, 10),
      maxVUs: Math.max(rate * 10, 50),
      gracefulStop: "5s",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    dropped_iterations: ["count==0"],
  },
};

export default function () {
  const url =
    `${baseUrl}/work` +
    `?workload=${encodeURIComponent(workload)}` +
    `&implementation=${encodeURIComponent(implementation)}` +
    `&scale=${encodeURIComponent(scale)}`;

  const response = http.get(url);
  const ok = response.status === 200;

  if (ok) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
  }

  check(response, {
    "status is 200": () => ok,
  });
}

function metricValue(data, metric, field, fallback = 0) {
  return data.metrics?.[metric]?.values?.[field] ?? fallback;
}

export function handleSummary(data) {
  const summary = {
    implementation,
    workload,
    scale: Number(scale),
    rate_requests_per_second: rate,
    configured_duration_seconds: durationSeconds,
    http_requests: metricValue(data, "http_reqs", "count"),
    successful_requests: metricValue(data, "successful_requests", "count"),
    failed_requests: metricValue(data, "failed_requests", "count"),
    dropped_iterations: metricValue(data, "dropped_iterations", "count"),
    failure_rate: metricValue(data, "http_req_failed", "rate"),
    checks_rate: metricValue(data, "checks", "rate"),
    request_duration_ms: {
      average: metricValue(data, "http_req_duration", "avg"),
      median: metricValue(data, "http_req_duration", "med"),
      p90: metricValue(data, "http_req_duration", "p(90)"),
      p95: metricValue(data, "http_req_duration", "p(95)"),
      max: metricValue(data, "http_req_duration", "max"),
    },
  };

  const text =
    `k6 completed: implementation=${implementation}, ` +
    `requests=${summary.http_requests}, successful=${summary.successful_requests}, ` +
    `dropped=${summary.dropped_iterations}, p95=${summary.request_duration_ms.p95} ms\n`;

  return {
    [summaryPath]: JSON.stringify(summary, null, 2),
    stdout: text,
  };
}
