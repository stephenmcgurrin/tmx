# Goal: Polish tmx UI and fill feature gaps

Transform the `tmx` tmux session picker from a functional-but-bare fzf wrapper into a polished, informative terminal UI. Phase A (quick wins) delivers Catppuccin-themed color coding, session metadata in the list, Nerd Font glyphs with ASCII fallbacks, git branch in preview, and a cleaner header — all in the existing single-file shell script with zero new dependencies. Phase B adds a `~/.tmxrc` config file, improved directory picker, recent-dir cache, session descriptions, process-tree previews, and window-level jumping.

## Shared Understanding

See [`facts.md`](./facts.md) for the complete, gated fact sheet.

## Execution Plan

See [`plan.md`](./plan.md) for the ordered, gated implementation plan.

## Done Condition

All facts in `facts.md` are verified on a tmux session with 3+ active sessions, including git repos, using `sh -n tmx` for syntax and manual interactive testing for each fact. The branch `polish-ui` is ready to merge.
