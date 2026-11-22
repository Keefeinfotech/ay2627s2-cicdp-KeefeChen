/**
 * File Name: playwright.config.ts
 * Description: Playwright configuration for the Auxilia E2E suite.
 *
 * Compatibility testing is built in via the `projects` matrix:
 *   - chromium (Desktop Chrome, 1280x720)
 *   - firefox  (Desktop Firefox, 1280x720)
 *   - webkit   (Desktop Safari, 1280x720)
 *   - mobile-chrome (Pixel 7-class viewport)
 *
 * Target selection:
 *   - default: http://localhost:8080 (docker-compose frontend)
 *   - override with E2E_BASE_URL, e.g. a staging deployment.
 *
 * The API is expected on the same host:3000 by default; override with
 * E2E_API_URL. The suite intentionally asserts on user-visible behaviour and
 * public HTTP contracts only (black box), never on internals.
 */

import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 60_000,
  expect: {
    timeout: 10_000,
  },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  // A deployed free-tier service can return a transient 503 while waking up;
  // one retry absorbs that without masking real failures. Keep local runs
  // strict so CI and developer machines fail fast on genuine regressions.
  retries: process.env.CI || process.env.E2E_BASE_URL ? 1 : 0,
  // Eleven parallel workers overwhelm a sleeping Render service. Cap external
  // runs at two workers; local compose and CI keep their existing settings.
  workers: process.env.CI || process.env.E2E_BASE_URL ? 2 : undefined,
  reporter: process.env.CI
    ? [
        ["line"],
        ["html", { open: "never" }],
        ["junit", { outputFile: "test-results/junit.xml" }],
      ]
    : [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:8080",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    // The app honours prefers-reduced-motion by rendering a static
    // background instead of the autoplay intro video — this keeps the test
    // matrix fast and avoids codec-related crashes in headless Firefox.
    reducedMotion: "reduce",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "firefox",
      use: { ...devices["Desktop Firefox"] },
    },
    {
      name: "webkit",
      use: { ...devices["Desktop Safari"] },
    },
    {
      name: "mobile-chrome",
      use: { ...devices["Pixel 7"] },
    },
  ],
});
