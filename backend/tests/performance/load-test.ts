/**
 * File Name: load-test.ts
 * Description: Dependency-free performance smoke/load test for the Auxilia
 * API. Boots the real Express app in-process on an ephemeral port and drives
 * concurrent HTTP traffic through it, reporting latency percentiles and
 * throughput. No external services (MongoDB) are required: the measured
 * routes are the DB-free hot paths (/api/health, 401/404 handlers).
 *
 * Usage:
 *   npm run test:performance
 *   PERF_DURATION_S=30 PERF_CONCURRENCY=50 PERF_MAX_P95_MS=500 npm run test:performance
 *
 * Exits non-zero when the p95 budget is exceeded or any request errors.
 */

process.env.NODE_ENV = "test"; // skips the baseline API rate limiter
process.env.JWT_SECRET = process.env.JWT_SECRET ?? "perf-test-secret-value-1234567890";
process.env.BCRYPT_ROUNDS = "10";
process.env.AUTH_RATE_LIMIT_MAX = "100000";
process.env.AI_RATE_LIMIT_PER_USER = "100000";

import type { Server } from "node:http";

const DURATION_S = Number(process.env.PERF_DURATION_S ?? "10");
const CONCURRENCY = Number(process.env.PERF_CONCURRENCY ?? "20");
const MAX_P95_MS = Number(process.env.PERF_MAX_P95_MS ?? "500");
const WARMUP_REQUESTS = 50;

interface Sample {
  route: string;
  status: number;
  durationMs: number;
}

const percentile = (sorted: number[], p: number): number => {
  if (sorted.length === 0) return 0;
  const index = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, index)];
};

const summary = (label: string, samples: Sample[]) => {
  const durations = samples.map((s) => s.durationMs).sort((a, b) => a - b);
  const errors = samples.filter((s) => s.status >= 500).length;
  const avg = durations.reduce((a, b) => a + b, 0) / (durations.length || 1);
  return {
    label,
    requests: samples.length,
    errors,
    avg: avg.toFixed(1),
    p50: percentile(durations, 50).toFixed(1),
    p90: percentile(durations, 90).toFixed(1),
    p95: percentile(durations, 95).toFixed(1),
    p99: percentile(durations, 99).toFixed(1),
    max: (durations.at(-1) ?? 0).toFixed(1),
  };
};

const run = async (): Promise<void> => {
  const { default: app } = await import("../../src/app.js");

  const server: Server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  const address = server.address();
  if (address === null || typeof address === "string") {
    throw new Error("Could not determine ephemeral port");
  }
  const baseUrl = `http://127.0.0.1:${address.port}`;

  const routes: Array<{ method: string; path: string; name: string }> = [
    { method: "GET", path: "/api/health", name: "GET /api/health" },
    { method: "POST", path: "/api/ai/chat", name: "POST /api/ai/chat (401)" },
    { method: "GET", path: "/api/__nope__", name: "GET /api/__nope__ (404)" },
  ];

  const hit = async (route: {
    method: string;
    path: string;
    name: string;
  }): Promise<Sample> => {
    const started = performance.now();
    const res = await fetch(`${baseUrl}${route.path}`, {
      method: route.method,
      headers: { "content-type": "application/json" },
      body: route.method === "POST" ? JSON.stringify({ message: "hi" }) : undefined,
    });
    await res.arrayBuffer(); // drain
    return {
      route: route.name,
      status: res.status,
      durationMs: performance.now() - started,
    };
  };

  // Warmup (not measured): fills the JIT and connection pool.
  for (let i = 0; i < WARMUP_REQUESTS; i++) {
    await hit(routes[0]);
  }

  // Measured phase: fixed-concurrency workers hitting the health route, plus
  // a small share of the 401/404 paths.
  const samples: Sample[] = [];
  const deadline = Date.now() + DURATION_S * 1000;
  let counter = 0;
  const worker = async () => {
    while (Date.now() < deadline) {
      counter += 1;
      // Every 10th request alternates between the 401 and 404 probe routes.
      const probe = Math.floor(counter / 10) % 2;
      const route = counter % 10 === 0 ? routes[1 + probe] : routes[0];
      try {
        samples.push(await hit(route));
      } catch {
        samples.push({ route: route.name, status: 599, durationMs: -1 });
      }
    }
  };
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));

  server.close();

  console.log("\nAuxilia API — performance smoke results");
  console.log(`duration=${DURATION_S}s concurrency=${CONCURRENCY} requests=${samples.length}\n`);
  console.table(
    routes.map((route) =>
      summary(
        route.name,
        samples.filter((s) => s.route === route.name),
      ),
    ),
  );

  const health = samples.filter((s) => s.route === "GET /api/health");
  const healthP95 = percentile(
    health.map((s) => s.durationMs).sort((a, b) => a - b),
    95,
  );
  const failures = samples.filter((s) => s.status >= 500 || s.durationMs < 0);

  console.log(
    `\nhealth p95 = ${healthP95.toFixed(1)}ms (budget ${MAX_P95_MS}ms); 5xx = ${failures.length}`,
  );

  if (failures.length > 0) {
    console.error("FAIL: performance run recorded 5xx/transport errors.");
    process.exit(1);
  }
  if (healthP95 > MAX_P95_MS) {
    console.error(`FAIL: health p95 ${healthP95.toFixed(1)}ms exceeds ${MAX_P95_MS}ms budget.`);
    process.exit(1);
  }
  console.log("PASS: latency and error budgets met.");
};

run().catch((error) => {
  console.error("Performance test failed to run:", error);
  process.exit(1);
});
