const title = process.env.PR_TITLE?.trim() ?? "";
const conventionalCommitTitle =
  /^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9][a-zA-Z0-9._/-]*\))?!?: \S.*$/;

if (!conventionalCommitTitle.test(title)) {
  console.error(
    'PR title must follow Conventional Commits, for example "feat(tasks): add deadline reminders".',
  );
  process.exit(1);
}

console.log(`Conventional Commit PR title accepted: ${title}`);
