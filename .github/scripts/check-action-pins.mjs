#!/usr/bin/env node
/*
 * check-action-pins.mjs — Actions Hardening (OWASP DevSecOps).
 *
 * Validates that every third-party GitHub Action used in
 * `.github/workflows/**` is pinned to a full 40-char commit SHA.
 *
 * Usage:
 *   node .github/scripts/check-action-pins.mjs           # check only (CI gate)
 *   node .github/scripts/check-action-pins.mjs --fix     # pin by resolving SHAs
 */
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = process.env.GITHUB_WORKSPACE ?? process.cwd();
const fix = process.argv.includes("--fix");

const files = [];
const walk = (dir) => {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p);
    else if (/\.ya?ml$/.test(entry.name)) files.push(p);
  }
};
walk(path.join(root, ".github", "workflows"));

function gh(args) {
  return JSON.parse(
    execFileSync("gh", args, { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] }),
  );
}

/** Resolve the canonical commit SHA of a repo ref via `gh api` (tags first). */
function resolveSha(repo, ref) {
  try {
    const r = gh(["api", `repos/${repo}/git/refs/tags/${ref}`]);
    let sha = r.object.sha;
    if (r.object.type === "tag") sha = gh(["api", `repos/${repo}/git/tags/${sha}`]).object.sha;
    return sha;
  } catch { /* not a tag */ }
  try {
    const r = gh(["api", `repos/${repo}/git/refs/heads/${ref}`]);
    if (r.object.type === "commit") return r.object.sha;
  } catch { /* not a branch */ }
  return null;
}

let unpinned = 0;
let pinnedFix = 0;

for (const file of files) {
  const original = fs.readFileSync(file, "utf8");
  const text = original.replace(
    /(uses:\s+)([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@)([A-Za-z0-9_.-]+)/g,
    (m, a, b, ref) => {
      if (/^[0-9a-f]{40}$/.test(ref)) return m;
      const repo = b.trim().replace(/@$/, "");
      if (fix) {
        const sha = resolveSha(repo, ref);
        if (sha) {
          pinnedFix++;
          console.log(`  pinned: ${repo}@${ref} -> ${sha} (${path.relative(root, file)})`);
          return `${a}${b}${sha}`;
        }
        console.error(`  could not resolve SHA for ${repo}@${ref} in ${file}`);
        return m;
      }
      unpinned++;
      console.log(`  UNPINNED: ${repo}@${ref} (${path.relative(root, file)})`);
      return m;
    },
  );
  if (text !== original) fs.writeFileSync(file, text);
}

if (pinnedFix > 0) console.log(`Pinned ${pinnedFix} action(s) in --fix mode.`);
if (unpinned > 0) {
  console.error(
    `\n${unpinned} action(s) are not pinned to full commit SHAs. ` +
      `Run: node .github/scripts/check-action-pins.mjs --fix`,
  );
  process.exit(1);
}
console.log("OK: all workflow actions pinned to commit SHAs.");
