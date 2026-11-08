import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import * as prettier from "prettier";

const baseSha = process.env.BASE_SHA;
const headSha = process.env.HEAD_SHA;
const zeroSha = /^0+$/;
const gitArgs = ["diff", "--name-only", "--diff-filter=ACMR"];

if (baseSha && headSha && !zeroSha.test(baseSha)) {
  gitArgs.push(`${baseSha}...${headSha}`);
} else {
  gitArgs.push("HEAD");
}

const repoRoot = execFileSync("git", ["rev-parse", "--show-toplevel"], {
  encoding: "utf8",
}).trim();

const changedFiles = execFileSync("git", gitArgs, {
  cwd: repoRoot,
  encoding: "utf8",
})
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
