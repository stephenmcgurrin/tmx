# Facts: Polish tmx UI and fill feature gaps

## Phase A — Quick Wins (highest impact, lowest risk)

- Sessions in the fzf list are sorted alphabetically by default (pipe `render_sessions` through `sort`).
- Each session line is formatted as a fixed-width table: `marker session-name  W:3  C:2  5m ago` using ANSI escape codes for coloring inline with fzf's `--ansi` flag.
- Catppuccin Mocha palette is used for all colors: green (#a6e3a1) for current session, yellow (#f9e2af) for attached, cyan (#89dceb) for "create new", mauve (#cba6f7) for active-window labels in preview, surface2 (#585b70) dimmed text for hidden sessions and inactive elements.
- The `[+  Create new session]` entry is prefixed with a sparkle emoji and colored in Catppuccin cyan via inline ANSI escapes in `render_sessions()`.
- The current session (when running inside tmux) is detected via `$TMUX` and prefixed with a green `●` bullet using ANSI green from render_sessions output.
- Sessions with other attached clients are prefixed with a yellow `◎` bullet. Client count comes from `tmux list-clients -F '#{client_session}' | grep -c`.
- Unattached sessions have no prefix marker and use default fzf foreground.
- Window count per session uses `tmux list-windows -t "$session" | wc -l | tr -d ' '` in render loop.
- Last-activity time uses `tmux display-message -t "$session" -p '#{session_activity_string}'` formatted as relative ("5m ago", "2h ago") by comparing epoch timestamps.
- `Ctrl-a` toggle preserves all formatting on hidden sessions — hidden entries reuse the same render path with a dim ANSI wrapper.
- The fzf `--header` line is shortened to: `j/k:nav  /:search  Enter:attach  Ctrl-d:detach  r:rename  Ctrl-x:kill  Ctrl-a:hidden  q:quit`.
- The preview pane shows the git branch for the active pane's working directory via `git -C <pane_cwd> branch --show-current 2>/dev/null`.
- Git branch is displayed in the preview header area alongside the window name, falling back silently when git is absent or dir is not a repo.
- The `--preview-window` label stays `right,75%,border-left,wrap` by default but is configurable via `TMX_PREVIEW_WINDOW` env/shell var.

## Phase B — Deeper Changes

- A `~/.tmxrc` file is sourced (`.` builtin) if it exists before the main fzf invocation; all config vars use `TMX_` prefix to avoid collisions.
- Configurable vars include: `TMX_SCAN_DEPTH` (default 3), `TMX_EXCLUDE_PATHS` (default `node_modules|__pycache__|.git|target|dist`), `TMX_SORT_ORDER` (default `alpha`, alt `recent`), `TMX_PREVIEW_WINDOW` (default `right,75%,border-left,wrap`).
- The directory picker preview replaces raw `ls -la` with: git branch + status summary (clean/dirty/staged), file count, last-modified marker, and directory tree overview (1 level deep).
- A recent-directories cache is stored at `~/.cache/tmx/dirs` (one path per line, MRU-ordered, max 50 entries); the dir picker prepends these above the `$HOME` scan.
- Sessions can carry a one-line description persisted in `~/.tmx-session-notes` (format: `session_name<TAB>description`). Description is shown in the preview pane header area.
- The preview pane shows a process-tree summary per pane using `ps` or `/proc` inspection of the pane's foreground process, formatted as a compact tree.
- Window-level jumping: pressing `Ctrl-w` on a session opens a sub-menu (reloads fzf with windows of that session), selecting a window attaches directly to it.
- All existing functionality (rename, kill, hide/unhide, attach, detach-others, search mode) continues to work unchanged.
- The script remains a single POSIX `sh` file with zero new binary dependencies beyond tmux, fzf, and git (git is optional — gracefully degrades).
- All new features degrade gracefully on systems without the optional deps (git, /proc) by omitting that section of output.
