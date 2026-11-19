// Vitest configuration for Stryker mutation runs only.
// Excludes suites that are process-hostile or pointless under mutation
// analysis: the Pact provider verification (spawns the Rust FFI verifier and
// exits the process) and the in-memory-Mongo suite (spawns mongod). Neither
// covers the mutated files (tokens.ts / AppError.ts), so this loses nothing.

import baseConfig from "./vitest.config.mts";
import { defineConfig, mergeConfig } from "vitest/config";

export default mergeConfig(
  baseConfig,
  defineConfig({
    test: {
      include: ["tests/**/*.test.ts"],
      exclude: ["tests/contract/**", "tests/mongodb/**", "node_modules/**"],
      coverage: {
        thresholds: {
          statements: 0,
          branches: 0,
          functions: 0,
          lines: 0,
        },
      },
    },
  }),
);
