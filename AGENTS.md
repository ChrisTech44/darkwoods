# Project working rules

Read `AGENT_BRIEF.md` as the authoritative project specification. Apply subsequent
user instructions as amendments, work in verified increments, keep the game
runnable, and maintain `docs/development_log.md`.

## Keep GitHub current

The user has authorized ongoing GitHub updates. After each coherent, verified
increment, update the development log and any affected player documentation,
commit the intended changes, and push the current branch to `origin` before
finishing the task. The normal project branch is `main`. Do not leave completed,
verified work only in local commits.

- Run the brief's required import/startup checks and applicable verification
  before committing. For documentation changes, also check links, screenshots,
  rules against the implementation, and `git diff --check`.
- Fetch before publishing and preserve remote work. If the branch has diverged,
  reconcile safely and reverify any affected behavior. Never force-push, rewrite
  published history, or include unrelated changes.
- Push verified increments during extended work, not just at the end of a large
  task. Keep temporary artifacts, credentials, and unverified changes out of
  published commits.
- Confirm that the remote branch points to the published commit. If authentication,
  network access, or repository permissions block publication, keep the local
  commit and report the exact blocker; do not claim GitHub is updated.
- Routine pushes to this project's configured remote are already authorized;
  do not request confirmation again unless the action exceeds that scope.
