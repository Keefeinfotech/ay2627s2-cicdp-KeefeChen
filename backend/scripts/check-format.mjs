import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import * as prettier from "prettier";

const baseSha = process.env.BASE_SHA;
const headSha = process.env.HEAD_SHA;
const zeroSha = /^0+$/;
const gitArgs = ["diff", "--name-only", "--diff-filter=ACMR"];

// Resolve git from a fixed absolute path instead of relying on PATH, which
// may contain writable entries that could shadow the real binary (S4036).
// Set GIT_BINARY to override the default on unusual installations.
const gitBinary =
  process.env.GIT_BINARY ||
  (process.platform === "win32"
    ? "C:\\Program Files\\Git\\cmd\\git.exe"
    : "/usr/bin/git");

if (baseSha && headSha && !zeroSha.test(baseSha)) {
  gitArgs.push(`${baseSha}...${headSha}`);
} else {
  gitArgs.push("HEAD");
}

const repoRoot = execFileSync(gitBinary, ["rev-parse", "--show-toplevel"], {
  encoding: "utf8",
}).trim();

// After a force push the base SHA can be unreachable from any ref, and a
// shallow checkout may not contain it. Fall back to the files touched by the
// tip commit so the check still covers something instead of hard-failing.
let diffOutput = "";
try {
  diffOutput = execFileSync(gitBinary, gitArgs, {
    cwd: repoRoot,
    encoding: "utf8",
  });
} catch (err) {
  const reason = err instanceof Error ? err.message : String(err);
  console.warn(
    `Could not diff ${gitArgs.slice(3).join(" ")}: ${reason.split("\n")[0]}`,
  );
  console.warn("Falling back to the files changed by the tip commit (HEAD).");
  diffOutput = execFileSync(
    gitBinary,
    ["diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"],
    { cwd: repoRoot, encoding: "utf8" },
  );
}

const changedFiles = diffOutput
  .split(/\r?\n/)
  .filter(Boolean)
  .map((file) => file.replaceAll("\\", "/"))
  .filter((file) => /\.(?:ts|mts|js|mjs|json)$/.test(file))
  .filter((file) => !file.split("/").includes("node_modules"))
  .filter((file) => !file.split("/").includes("coverage"))
  .filter((file) => !file.split("/").includes("dist"))
  .filter((file) => path.basename(file) !== "package-lock.json");

if (changedFiles.length === 0) {
  console.log(
    "No changed backend source or configuration files need formatting.",
  );
  process.exit(0);
}

const unformatted = [];
for (const file of changedFiles) {
  const absolutePath = path.resolve(repoRoot, file);
  const source = readFileSync(absolutePath, "utf8");
  const formatted = await prettier.check(source, { filepath: absolutePath });
  if (!formatted) unformatted.push(file);
}

if (unformatted.length > 0) {
  console.error("Run Prettier on these changed backend files:");
  for (const file of unformatted) console.error(`  ${file}`);
  process.exit(1);
}

console.log(
  `Prettier check passed for ${changedFiles.length} changed backend files.`,
);
