/*
 * File Name: lcov-to-html.mjs
 * Description: Renders an HTML Istanbul coverage report from an lcov.info
 *              file. Used to produce a browsable report for the Flutter web
 *              frontend, which emits lcov.info but has no native HTML output.
 *
 * The lcov.info parser below is deliberately minimal (SF/DA/LF/LH records);
 * istanbul-lib-coverage renders the actual report.
 *
 * Usage: node scripts/lcov-to-html.mjs <lcov.info> <output-dir>
 * Run from the repository root or the frontend/ directory - SF paths inside
 * lcov.info are resolved relative to the lcov file's parent's parent.
 */

import fs from "node:fs";
import path from "node:path";

import libCoverage from "istanbul-lib-coverage";
import libReport from "istanbul-lib-report";
import reports from "istanbul-reports";

const args = process.argv.slice(2);
if (args.length !== 2) {
  console.error("Usage: node scripts/lcov-to-html.mjs <lcov.info> <output-dir>");
  process.exit(1);
}

const [lcovPath, outDir] = args;
if (!fs.existsSync(lcovPath)) {
  console.error(`lcov file not found: ${lcovPath}`);
  process.exit(1);
}

const projectRoot = path.resolve(path.dirname(lcovPath), "..");
const source = fs.readFileSync(lcovPath, "utf8");

const files = [];
let current = null;
for (const rawLine of source.split(/\r?\n/)) {
  const line = rawLine.trim();
  if (line.startsWith("SF:")) {
    current = { path: line.slice(3), stmts: [] };
  } else if (line.startsWith("DA:") && current) {
    const [lineNo, hits] = line.slice(3).split(",");
    current.stmts.push({ line: Number(lineNo), hits: Number(hits || 0) });
  } else if (line === "end_of_record" && current) {
    files.push(current);
    current = null;
  }
}

const map = libCoverage.createCoverageMap({});
for (const file of files) {
  const statementMap = {};
  const s = {};
  file.stmts.forEach((statement, index) => {
    statementMap[String(index)] = {
      start: { line: statement.line, column: 0 },
      end: { line: statement.line, column: 10_000 },
    };
    s[String(index)] = statement.hits;
  });

  map.addFileCoverage({
    // Resolve Windows-style separators against the project root for readability.
    path: path.isAbsolute(file.path)
      ? file.path
      : path.join(projectRoot, file.path),
    statementMap,
    fnMap: {},
    branchMap: {},
    s,
    f: {},
    b: {},
  });
}

if (map.files().length === 0) {
  console.error("No files parsed from lcov input - is the format lcov.info?");
  process.exit(1);
}

const context = libReport.createContext({ dir: outDir, coverageMap: map });
reports.create("html", {}).execute(context);

console.log(
  `HTML coverage report written to ${path.resolve(outDir, "index.html")} ` +
    `(${map.files().length} files)`,
);
