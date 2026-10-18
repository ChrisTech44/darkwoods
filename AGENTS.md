# Project working rules

Read `AGENT_BRIEF.md` as the maintained project specification (refreshed 18 October
2026). Subsequent user instructions take precedence. Use source and execution
evidence to distinguish implemented behavior from design; document mismatches.
Work in verified increments, keep the game runnable, and maintain
`docs/development_log.md`.

Current graphics/interface priority: read `docs/graphics_readability_plan.md`.
It records confirmed defects and a staged map/Tab-help/hint overhaul, not a shipped
redesign. Capture and inspect actual graphical output for visual changes; label
forced all-escape fixtures, frozen enemies and altered lighting. Preserve clue
discovery and host authority. Do not silently change gameplay during UI work.

Read `docs/audio_multiplayer_design.md` before future audio/online voice work.
Maintain the brief and design documents in Markdown only; the Word brief was
removed at the user's request. Audio assets, ENet gameplay and opt-in proximity
voice have implementations; their individual acceptance gates still require
execution evidence. Document platform, real-microphone, listening and Internet
limits, and keep microphone capture disabled during graphics audits. Older
design documents may contain superseded status paragraphs; verify before claiming
a feature is absent or accepted.

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
