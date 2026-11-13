/**
 * File Name: run-all-tests.mjs
 * Description: Automation entry point for running Auxilia's test suites
 * locally or on a developer machine. Mirrors what CI does, with flags for
 * the layers that need infrastructure (Docker stack for E2E, a deployed
 * URL for smoke checks).
 *
 * Usage:
 *   node scripts/run-all-tests.mjs              # unit + integration + frontend + contract + new suites
 *   node scripts/run-all-tests.mjs --e2e        # also build & run the docker stack + Playwright
 *   node scripts/run-all-tests.mjs --smoke URL  # post-deploy smoke checks against URL
 *   node scripts/run-all-tests.mjs --perf       # include the API performance smoke test
 *
 * Exits non-zero if any executed suite fails.
 */

import { spawnSync } from "node:child_process";
import process from "node:process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const wantsE2E = args.includes("--e2e");
const wantsPerf = args.includes("--perf");
const smokeIndex = args.indexOf("--smoke");
const smokeUrl = smokeIndex !== -1 ? args[smokeIndex + 1] : null;

const isWindows = process.platform === "win32";
const npmCmd = isWindows ? "npm.cmd" : "npm";
const npxCmd = isWindows ? "npx.cmd" : "npx";
const flutterCmd = isWindows ? "flutter.bat" : "flutter";

const results = [];
const run = (label, command, commandArgs, cwd, env = {}) => {
  console.log(`\n=== ${label} ===`);
  const started = Date.now();
  const result = spawnSync(command, commandArgs, {
    cwd,
    stdio: "inherit",
    env: { ...process.env, ...env },
    shell: false,
  });
  const durationS = ((Date.now() - started) / 1000).toFixed(1);
  const ok = result.status === 0;
  results.push({ label, ok, durationS });
  console.log(`${ok ? "PASS" : "FAIL"} (${durationS}s) — ${label}`);
  return ok;
};

const backend = path.join(root, "backend");
const frontend = path.join(root, "frontend");
const e2e = path.join(root, "e2e");

// Backend: everything vitest knows about (unit, integration, contract,
// security, functional, regression, ai).
run("Backend: lint (typecheck + eslint)", npmCmd, ["run", "lint"], backend);
run("Backend: tests", npmCmd, ["test"], backend);

if (wantsPerf) {
  run("Backend: performance smoke", npmCmd, ["run", "test:performance"], backend);
}

// Frontend
run("Frontend: static analysis", flutterCmd, ["analyze", "--no-fatal-infos"], frontend);
run("Frontend: tests", flutterCmd, ["test"], frontend);

// E2E against the docker-compose stack
if (wantsE2E) {
  const docker = isWindows ? "docker" : "docker";
  run("E2E: build stack", docker, ["compose", "up", "-d", "--build"], root);
  run(
    "E2E: wait for frontend",
    process.execPath,
    [
      "-e",
      `const url='http://localhost:8080';const deadline=Date.now()+180000;(async()=>{let ok=false;while(Date.now()<deadline){try{const r=await fetch(url);if(r.ok){ok=true;break;}}catch{}await new Promise(r=>setTimeout(r,3000));}process.exit(ok?0:1)})();`,
    ],
    root,
  );
  run("E2E: npm install", npmCmd, ["ci"], e2e);
  run("E2E: install browsers", npxCmd, ["playwright", "install", "--with-deps", "chromium"], e2e);
  run("E2E: playwright (chromium)", npxCmd, ["playwright", "test", "--project=chromium"], e2e);
  run("E2E: stack down", docker, ["compose", "down"], root);
}

// Post-deployment smoke checks against a deployed environment
if (smokeUrl) {
  run("Smoke: post-deploy checks", process.execPath, [path.join(root, "scripts", "smoke-test.mjs"), smokeUrl], root);
}

// Summary
console.log("\n=== SUMMARY ===");
let failed = 0;
for (const { label, ok, durationS } of results) {
  console.log(`${ok ? "PASS" : "FAIL"}  ${durationS.padStart(6)}s  ${label}`);
  if (!ok) failed += 1;
}
console.log(failed === 0 ? "\nAll selected suites passed." : `\n${failed} suite(s) failed.`);
process.exit(failed === 0 ? 0 : 1);
