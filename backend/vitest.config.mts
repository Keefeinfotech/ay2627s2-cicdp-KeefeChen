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
        "src/modules/sync/**",
      ],
      thresholds: {
        statements: 80,
        branches: 60,
        functions: 80,
        lines: 80,
      },
    },
  },
});
