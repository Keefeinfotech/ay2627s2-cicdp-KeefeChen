/**
 * Stryker mutation testing configuration (nightly / on-demand, NOT a
 * per-PR gate — see .github/workflows/mutation.yml).
 *
 * Scope is deliberately small and high-value: pure, well-tested modules
 * whose behaviour the rest of the system leans on. Widening the scope is an
 * ADR-worthy decision — measure first, then add files here.
 *
 * Run locally:
 *   cd backend && npm run test:mutate
 * (equivalent to `npx stryker run`)
 */

/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  packageManager: "npm",
  testRunner: "vitest",
  vitest: {
    configFile: "vitest.stryker.config.mts",
  },
  coverageAnalysis: "perTest",
  // Mutation of behaviour the whole system depends on:
  // - tokens.ts: JWT sign/verify (auth for every protected route)
  // - AppError.ts: the error envelope/codes every client parses
  mutate: [
    "src/shared/utils/tokens.ts",
    "src/shared/utils/AppError.ts",
  ],
  reporters: ["clear-text", "progress"],
  thresholds: {
    // break the nightly job below this score (ADR required to lower it):
    break: 60,
    low: 70,
    high: 85,
  },
  timeoutMS: 30_000,
  // Wipe nothing; keep the runner honest.
  checkers: ["typescript"],
};
