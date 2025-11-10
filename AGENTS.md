# Repository Guidelines

## Project Structure & Module Organization
The repository is intentionally minimal: `tmx` at the root is the only executable and must remain a POSIX-compliant `sh` script so users can drop it into `~/bin`. Project docs (`README.md`, `AGENTS.md`) live beside the script; add any future modules under directories named after their responsibility (e.g., `scripts/` for helpers) to keep the root clean. Assets such as demo GIFs or screenshots should land under `docs/assets/` to avoid bloating releases.

## Build, Test, and Development Commands
Running `./tmx` exercises the script in the current shell; pass through `TMUX` env vars to simulate inside-session behavior if needed. Use `shellcheck tmx` before every PR to catch portability issues, and run `shfmt -w tmx` (two-space indent, repository style) to enforce consistent formatting. `env TMUX=1 ./tmx` helps ensure logic works when invoked from within tmux without having to attach.

## Coding Style & Naming Conventions
Keep functions lowercase_with_underscores (`create_session`, `attach_normal`) and prefer short verbs for helpers. Use two-space indentation, POSIX-safe parameter expansion, and double quotes around variables to avoid word splitting. Guard external binaries via the shared `need()` helper instead of inline `command -v` checks, and keep user-facing strings concise so fzf previews stay readable.

## Testing Guidelines
There is no formal automated test suite, so rely on `shellcheck` plus manual tmux runs. Create at least one session (`tmux new -s demo -d`) and verify the picker lists, creates, and switches sessions both outside tmux and via `tmux display-popup -E "$PWD/tmx"`. Document any new manual test recipes in `README.md` so future contributors can replay them.

## Commit & Pull Request Guidelines
Recent history favors short, present-tense summaries (“added a preview for the tmx tool”); follow that pattern and keep the first line under ~60 characters. Every PR should describe behavior changes, include reproduction steps, and mention any dependency bumps; attach screenshots or terminal captures when UI/UX output changes. Reference related issues with `Fixes #123` where applicable and confirm that `shellcheck` runs clean before requesting review.

## Security & Configuration Tips
Limit dependencies to tmux and fzf; if a feature needs more, explain why and note install instructions for macOS and Linux. Never store user-specific paths directly in the script—respect `$HOME` and `$PWD` so the tool remains drop-in. Sanitize any user-provided names (trim, avoid spaces) just as `create_session` currently does, and reuse those helpers to avoid regression.
