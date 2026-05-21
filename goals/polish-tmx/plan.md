# Plan: Polish tmx UI and fill feature gaps

## Solution Approach

All changes live in the single file `tmx`. Phase A is a focused set of modifications to the existing `render_sessions()`, `preview_session()`, and fzf invocation sections. Phase B adds `~/.tmxrc` sourcing, a dir cache, session notes, and window jumping — all new code block additions. Both phases maintain POSIX `sh` compatibility and zero new binary deps (git is optional).

---

## Branch

```bash
git checkout -b polish-ui
```

---

## Phase A — Quick Wins

### Step A1: Add Catppuccin ANSI color helpers and session metadata collection

**Files:** `tmx`

**What:**
- Add a `catppuccin()` function at the top of the helper section that maps color names to ANSI escape codes using the Mocha palette hex values:
  - `green` → `\033[38;2;166;227;161m`
  - `yellow` → `\033[38;2;249;226;175m`
  - `cyan` → `\033[38;2;137;220;235m`
  - `mauve` → `\033[38;2;203;166;247m`
  - `surface2` → `\033[38;2;88;91;112m`
  - `reset` → `\033[0m`
- Add a `glyph()` helper returning Nerd Font v3+ glyphs with ASCII fallback detection:
  - Check `$TMX_NERD_FONTS` env var; if `0`, use ASCII fallbacks
  - `glyph session_current` → `` (nf-fa-circle) or `(*)`
  - `glyph session_attached` → `` (nf-fa-dot_circle_o) or `(•)`
  - `glyph create_new` → `` (nf-md-plus_circle) or `(+)`
  - `glyph git_branch` → `` (nf-fa-git_branch) or `git:`
  - `glyph folder` → `` (nf-md-folder_multiple) or `📁`
  - `glyph window` → `` (nf-md-window_shutter) or `W:`
  - `glyph client` → `` (nf-md-account) or `C:`
- Add helper functions:
  - `session_window_count()` — `tmux list-windows -t "$1" 2>/dev/null | wc -l | tr -d ' '`
  - `session_client_count()` — `tmux list-clients -F '#{client_session}' 2>/dev/null | grep -Fxc "$1" || echo 0`
  - `session_activity_relative()` — get `#{session_activity}` epoch, compute human-readable relative time ("5m ago", "2h ago", "1d ago")
  - `session_is_current()` — compare `$1` against `tmux display-message -p '#S'` when `$TMUX` is set
- Add `git_branch_for_session()` — get active pane's cwd via `#{pane_current_path}`, run `git -C <path> branch --show-current 2>/dev/null`

**Verification:**
```bash
# In a tmux session:
sh tmx --help  # still works, no regressions
# Manually test helpers by sourcing and calling:
. ./tmux  # won't work directly; instead test via --internal-preview
```

### Step A2: Rewrite `render_sessions()` with colored, sorted, metadata-rich output

**Files:** `tmx` — `render_sessions()` function

**What:**
- Sort sessions alphabetically with `sort` before the loop.
- For each session, collect: window count, client count, relative activity, is-current, is-hidden.
- Format each line: `[marker] [session-name]  W:3  C:2  5m ago` using Catppuccin ANSI codes.
  - Current session: green `` (nf-fa-circle) marker + green session name
  - Attached (others): yellow `` (nf-fa-dot_circle_o) marker + yellow session name
  - Unattached: no marker, default color
- `[  Create new session]` line: cyan `` (nf-md-plus_circle) prefix + cyan text.
- `glyph()` helper auto-detects Nerd Font support or respects `TMX_NERD_FONTS=0` for ASCII fallbacks.
- Hidden section header: already dimmed — switch to Catppuccin surface2.
- Hidden session entries: dim via surface2 wrapper, but preserve their status markers.
- The `show_hidden` parameter remains unchanged.

**Verification:**
```bash
# Inside tmux with multiple sessions:
sh tmx --internal-render /tmp/test-flag
# Verify: alphabetical order, colors present, metadata columns align
echo 1 > /tmp/test-flag
sh tmx --internal-render /tmp/test-flag
# Verify: hidden section appears with dimmed entries
```

### Step A3: Shorten the fzf header

**Files:** `tmx` — fzf `--header` string in main section

**What:** Replace the 130-char header with:
```
j/k:nav  /:search  Enter:attach  Ctrl-d:detach  r:rename  Ctrl-x:kill  Ctrl-a:hidden  q:quit
```

**Verification:**
```bash
# Visual check when running tmx
# Or grep the source:
grep -F '--header' tmx | wc -c  # should be < 100 chars
```

### Step A4: Add git branch to preview pane

**Files:** `tmx` — `preview_session()` function

**What:**
- In the session preview branch of `preview_session()`, before listing windows, attempt to get git branch from the session's first active pane's cwd.
- If found, add a line in the preview header: ` main` (nf-fa-git_branch glyph) + branch name in Catppuccin mauve.
- If git is not available or not a repo, omit silently.
- Detection via: get session's active window's active pane path, run `git -C <path> branch --show-current 2>/dev/null`.

**Verification:**
```bash
# In a tmux session with a git repo:
sh tmx --internal-preview "session-in-git-repo"
# Should show "Branch: main" (or whatever branch)
sh tmx --internal-preview "session-not-in-git-repo"
# Should show normal preview without branch line
# Without git installed:
# Should show normal preview, no errors
```

### Step A5: End-to-end smoke test of Phase A

**What:** Run the full script and verify all quick wins work together.

**Verification:**
```bash
# Syntax check
sh -n tmx

# Help works
sh tmx --help

# Full interactive test (manual):
# 1. Open tmux with 3+ sessions, some with git repos
# 2. Run tmx
# 3. Verify: sessions sorted alphabetically
# 4. Verify: current session in green with ●
# 5. Verify: window count and activity time shown
# 6. Verify: git branch in preview for repo sessions
# 7. Verify: shortened header
# 8. Verify: ctrl-a toggle still works
# 9. Verify: rename, kill, hide work
# 10. Verify: attach and detach work
```

---

## Phase B — Deeper Changes

### Step B1: Add `~/.tmxrc` config sourcing

**Files:** `tmx`

**What:**
- Before the `need` checks in main, source `~/.tmxrc` if it exists: `[ -f "${HOME}/.tmxrc" ] && . "${HOME}/.tmxrc"`
- Define defaults for all config vars BEFORE sourcing, so the rc file overrides:
  - `TMX_SCAN_DEPTH="${TMX_SCAN_DEPTH:-3}"`
  - `TMX_EXCLUDE_PATHS="${TMX_EXCLUDE_PATHS:-node_modules|__pycache__|.git|target|dist}"`
  - `TMX_SORT_ORDER="${TMX_SORT_ORDER:-alpha}"`
  - `TMX_PREVIEW_WINDOW="${TMX_PREVIEW_WINDOW:-right,75%,border-left,wrap}"`
- Use `${TMX_SORT_ORDER}` in `render_sessions()` to control sort method.
- Use `${TMX_PREVIEW_WINDOW}` in the fzf `--preview-window` flag.
- Use `${TMX_SCAN_DEPTH}` and `${TMX_EXCLUDE_PATHS}` in `scan_dirs()`.

**Verification:**
```bash
# Create test rc file:
echo 'TMX_SCAN_DEPTH=2' > /tmp/test-tmxrc
HOME=/tmp sh tmx  # should not crash
# Check that scan uses depth 2 (manual)
rm /tmp/test-tmxrc
```

### Step B2: Improve directory picker preview

**Files:** `tmx` — `pick_directory()` and a new `preview_directory()` helper

**What:**
- Replace the inline `--preview 'case {} in ... esac'` with a call to `$SCRIPT --internal-preview-dir {}`
- `--internal-preview-dir` handler:
  - Show directory path
  - Show git branch and status if repo: `git -C {} status --short 2>/dev/null | head -20`
  - Show file count: `ls -1 {} | wc -l | tr -d ' '`
  - Show last modified: `ls -lt {} | head -5`
  - Fall back to simple `ls -la` if nothing else works

**Verification:**
```bash
sh tmx --internal-preview-dir /some/git/repo
# Should show git branch, status, file count
sh tmx --internal-preview-dir /tmp
# Should show file listing, no git info
```

### Step B3: Add recent-directories cache

**Files:** `tmx` — new helper + modification to `pick_directory()`

**What:**
- Cache file at `~/.cache/tmx/dirs` (mkdir -p the parent).
- On session creation, append the chosen dir to the cache file.
- Deduplicate: if dir is already in cache, move it to top.
- Cap at 50 entries — trim oldest.
- In `pick_directory()`, prepend cached dirs above the `$HOME` scan with a ` Recent` header (nf-md-folder_multiple glyph).
- Cache entries are separated from scanned entries by a `---recent---` sentinel (same pattern as `---external---`).

**Verification:**
```bash
# Create a session, check cache was written:
cat ~/.cache/tmx/dirs
# Run picker again, verify recent dirs appear first
```

### Step B4: Add session descriptions

**Files:** `tmx` — new helpers + modification to `preview_session()` and keybinds

**What:**
- Notes file at `~/.tmx-session-notes` (format: `name<TAB>description`, one per line).
- `--internal-set-description <session>` handler: prompts for description text, writes to notes file.
- Bind `Ctrl-e` (edit description) to `$SCRIPT --internal-set-description {}` + reload.
- `preview_session()` reads the notes file and shows description in the preview header if present.
- On session rename, description is migrated to new name.
- On session kill, description is removed.

**Verification:**
```bash
# Set a description via Ctrl-e, verify it appears in preview
sh tmx --internal-preview "session-with-desc"
cat ~/.tmx-session-notes
# Rename session, verify description follows
# Kill session, verify description is removed
```

### Step B5: Add process-tree to preview

**Files:** `tmx` — `preview_session()` function

**What:**
- In the pane section of preview, after showing captured content, show the process running in each pane.
- Use `tmux list-panes -t "$s:$idx.$pi" -F '#{pane_pid}'` to get pane PID.
- Use `ps -o pid,comm --ppid <pid> 2>/dev/null` or inspect `/proc/<pid>/children` on Linux.
- Format as compact tree under the pane capture:
  ```
    ┌─ Pane 0 (active) ─
    │ $ ls -la
    │ ▸ zsh (pid 12345)
    │   ▸ nvim (pid 12346)
    └─────────────
  ```
- Gracefully degrade: if `ps` fails or `/proc` unavailable, omit the tree.

**Verification:**
```bash
sh tmx --internal-preview "session-with-processes"
# Should show process tree under each pane
sh tmx --internal-preview "session-on-busybox"  # no /proc
# Should show pane content without tree, no errors
```

### Step B6: Window-level jumping

**Files:** `tmx` — new handler + fzf bind

**What:**
- `--internal-list-windows <session>` handler: outputs window list with index and name, same format as preview but as fzf-selectable lines.
- `Ctrl-w` bind: `reload($SCRIPT --internal-list-windows {})` — replaces the session list with the windows of the selected session.
- Selecting a window attaches to `session:window_index`.
- `Esc` in window view reloads back to the session list: `reload($SCRIPT --internal-render "$SHOW_HIDDEN_FILE")`.
- Window list preview shows pane content for that window (reuse `preview_session` logic scoped to one window).

**Verification:**
```bash
# In tmx: press Ctrl-w on a multi-window session
# Verify window list appears
# Select a window — should attach to that specific window
# Press Esc — should return to session list
```

### Step B7: End-to-end smoke test of Phase B

**Verification:**
```bash
sh -n tmx  # syntax
sh tmx --help  # help

# Create ~/.tmxrc with custom values, verify they take effect
# Full interactive test of all phase B features
# Verify no regressions from Phase A
# Verify POSIX sh compatibility: dash -n tmx (on Linux) or sh -n tmx (macOS)
```

---

## Risks and Open Questions

1. **Nerd Font availability**: Not all users have Nerd Fonts. The `glyph()` helper with `TMX_NERD_FONTS=0` override and ASCII fallback handles this, but auto-detection is unreliable. Default: use Nerd Font glyphs; document the override in README.
2. **ANSI color width in fzf**: fzf may count ANSI escape codes as display width, breaking column alignment. Mitigation: test `--ansi` with fixed-width columns and adjust with padding.
3. **Performance of per-session metadata**: Calling `tmux list-clients`, `tmux list-windows`, and `tmux display-message` for every session in the render loop could be slow with 20+ sessions. Mitigation: benchmark first; if slow, collect metadata in batch before the loop.
4. **`sort` compatibility**: `sort` flags are POSIX, but locale behavior differs. Use `LC_ALL=C sort` for consistency.
5. **git as optional dep**: Already handled — all git calls use `2>/dev/null` and fall through gracefully.
6. **`~/.cache/tmx/` permissions**: Must handle cases where `$HOME/.cache` doesn't exist or isn't writable. Use `mkdir -p` and check with `[ -w ... ]`, fall back to no cache.
7. **Window jumping UX**: Switching fzf from session list to window list and back could be disorienting. The Esc-to-return pattern is established but needs a clear header indicator.
