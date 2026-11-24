import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    setupFiles: ["tests/setup.ts"],
    include: ["tests/**/*.test.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      include: ["src/**/*.ts"],
      exclude: [
        "src/server.ts",
        "src/index.ts",
        "src/database.ts",
        "src/config/database.ts",
        "src/config/swagger.ts",
        "src/config/logger.ts",
        "src/types/**",
        "src/shared/utils/totp.util.ts",
        "src/modules/groups/**",
        "src/modules/audit/**",
        "src/modules/roadmaps/**",
      ],
      thresholds: {
        // Ratchet baseline: the suite currently enforces these values and CI
        // fails if coverage regresses below them. Raise each threshold as the
        // remaining modules are covered. Do not lower these without an ADR.
        // Raised 2026-11-24 from statements 58 / branches 48 / functions 59 /
        // lines 58 to statements 85 / branches 80 / functions 90 / lines 89
        // after measuring the current suite (85.84 / 80.73 / 90.42 / 89.85).
        statements: 85,
        branches: 80,
        functions: 90,
        lines: 89,
      },
    },
  },
});
