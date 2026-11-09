// Enforce the repository's branch naming standard (see docs/release/BRANCHING.md).
// Allowed: feature/ bugfix/ hotfix/ refactor/ release/ bot branches.
const branch = process.env.BRANCH_NAME?.trim() ?? "";

if (branch === "main" || branch === "develop") {
  console.error(
    `Branch "${branch}" is protected and cannot be a PR head branch.`,
  );
  process.exit(1);
}

const allowed =
  /^(feature|bugfix|hotfix|refactor|release|dependabot|renovate)\/[a-z0-9][a-z0-9._/-]*$/;

if (!allowed.test(branch)) {
  console.error(
    `Branch "${branch}" does not follow the naming convention. Use one of: feature/<slug>, bugfix/<slug>, hotfix/<slug>, refactor/<slug> (see docs/release/BRANCHING.md).`,
  );
  process.exit(1);
}

console.log(`Branch name accepted: ${branch}`);
