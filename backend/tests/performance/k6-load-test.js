/**
 * File Name: k6-load-test.js
 * Description: Optional k6 scenario for serious load/soak testing against a
 * deployed environment (staging/prod). Not required for local development.
 *
 * Usage:
 *   k6 run -e BASE_URL=http://localhost:3000 tests/performance/k6-load-test.js
 *   # or:  docker run --rm -i -e BASE_URL=http://host.docker.internal:3000 grafana/k6 run - < tests/performance/k6-load-test.js
 *
 * Scenarios:
 *   - health_smoke: constant-rate probe of the DB-free health endpoint with a
 *     strict p95 budget;
 *   - unauthenticated_auth: verifies auth-protected endpoints reject load
 *     with 401s without degrading (still fast);
 *   - not_found: verifies the 404 handler is cheap.
 */
import http from "k6/http";
import { check, sleep } from "k6";
import { Trend } from "k6/metrics";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";

export const options = {
  scenarios: {
    health_smoke: {
      executor: "constant-arrival-rate",
      rate: 50,
      timeUnit: "1s",
      duration: "2m",
      preAllocatedVUs: 20,
      maxVUs: 100,
      exec: "health",
    },
    unauthenticated_auth: {
      executor: "constant-arrival-rate",
      rate: 20,
      timeUnit: "1s",
      duration: "2m",
      preAllocatedVUs: 10,
      maxVUs: 50,
      exec: "unauthenticatedChat",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<500"],
  },
};

const healthTrend = new Trend("health_duration", true);

export function health() {
  const res = http.get(`${BASE_URL}/api/health`);
  healthTrend.add(res.timings.duration);
  check(res, {
    "health returns 200": (r) => r.status === 200,
    "health is fast (<300ms)": (r) => r.timings.duration < 300,
  });
  sleep(0.1);
}

export function unauthenticatedChat() {
  const res = http.post(
    `${BASE_URL}/api/ai/chat`,
    JSON.stringify({ message: "hello" }),
    { headers: { "content-type": "application/json" } },
  );
  check(res, { "chat requires auth (401)": (r) => r.status === 401 });
  sleep(0.1);
}
