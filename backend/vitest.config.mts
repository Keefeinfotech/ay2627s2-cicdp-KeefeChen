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
        statements: 49,
        branches: 39,
        functions: 48,
        lines: 50,
      },
    },
  },
});
