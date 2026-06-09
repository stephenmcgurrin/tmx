# Plan: Four tmx enhancements

## Solution approach

All four features are added to the single `tmx` shell script. No new files, no new dependencies. Each feature is self-contained in its own section of the codebase, touching specific functions and fzf bindings. MRU tracking is a cross-cutting concern shared between quick-last and future sort ordering.

## Steps

### 1. MRU tracking (foundation for quick-last)

**Files:** `tmx` only

**Changes:**
- New `mru_update()` helper function — writes session name to `~/.cache/tmx/mru`, deduplicating (removes old entry, prepends new one to the top)
- Call `mru_update "$1"` at the end of `attach_normal()` and `attach_detach_others()`
- In `--internal-rename` handler (§ line 386): after renaming, update MRU file — replace old session name with new name throughout the file to keep entries consistent
- Ensure `~/.cache/tmx` directory exists (mkdir -p), same pattern as recent dirs cache

**Lines touched:** ~197-212 (attach functions), ~386-400 (rename handler), new helper ~18 lines

**Verification:**
```bash
# Check MRU file is created on attach
tmx  # attach to session A, then quit
cat ~/.cache/tmx/mru  # should list session A

# Check dedup on re-attach
tmx  # re-attach to session A, quit
cat ~/.cache/tmx/mru  # session A appears once, at top

# Check rename updates MRU
# (rename session A to B via tmx, then verify MRU shows B not A)
```

### 2. Quick-last flag (`tmx --last`)

**Files:** `tmx`, README.md

**Changes:**
- Add `--last` case to internal dispatch (line ~339, after `--help|-h`):
  - Read line 1 and 2 from `~/.cache/tmx/mru`
  - If fewer than 2 entries: `printf 'No previous session.\n' >&2; exit 0`
  - Otherwise: `attach_normal "$prev_session"`
- Add `--last` to `--help` output (line ~344 area)
- Update README usage section

**Lines touched:** dispatch case ~8 lines, help ~2 lines, README ~3 lines

**Verification:**
```bash
# Two sessions exist in MRU
tmx --last  # should jump to previous session

# Only one session
tmx --last  # should print "No previous session." and exit 0
```

### 3. Bookmarked directories

**Files:** `tmx`, README.md

**Changes:**
- New `BOOKMARK_FILE="${HOME}/.cache/tmx/bookmarks"` global (line ~11 area)
- `pick_directory()` (§ line 229):
  - Load bookmarks from file before building `_input`
  - Prepend `---bookmarks---` section at the very top of `_input` (above recent)
  - Add `case "$dir" in ---bookmarks---) dir="" ;; esac` sentinel handling (after line 296)
- New fzf bind in directory picker fzf call (line ~288):
  - `--bind "ctrl-p:execute-silent($SCRIPT --internal-toggle-bookmark {})"` 
- New `--internal-toggle-bookmark` handler in dispatch:
  - Read file, grep -Fx for the dir; if found remove it, else append it
  - Same dedup pattern as toggle_hidden
- `--internal-help`: add `Ctrl-p: toggle bookmark` line (after line 446)
- README: add Ctrl-p to keybindings table

**Lines touched:** ~25 net new lines across all sections

**Verification:**
```bash
# Bookmark a dir
echo "/tmp/testdir" >> ~/.cache/tmx/bookmarks
# Launch tmx, Ctrl-n to dir picker — /tmp/testdir appears in ---bookmarks--- section at top

# Toggle via Ctrl-p in picker: adds/removes from file
# Sentinel line behaves like Esc (falls through to current dir)
```

### 4. Per-session color tags

**Files:** `tmx`, README.md

**Changes:**
- New helper `_color_tag_for_session()` — reads `~/.tmx-session-notes`, extracts third tab-delimited field for the given session, returns ANSI escape or empty
- New helper `_color_palette()` — small function returning ANSI codes keyed by color name:
  ```
  red → \033[38;2;243;139;168m
  green → \033[38;2;166;227;161m
  blue → \033[38;2;137;180;250m
  yellow → \033[38;2;249;226;175m
  magenta → \033[38;2;203;166;247m
  cyan → \033[38;2;148;226;213m
  white → \033[38;2;205;214;244m
  gray → \033[38;2;108;112;134m
  ```
- `render_sessions()` (§ line 55): for each session, call `_color_tag_for_session "$s"` and prepend colored dot `● ` (or colored `● `) before status marker
- New `--internal-set-color` handler in dispatch:
  - Opens fzf palette inline via `/dev/tty` (like session rename prompt does)
  - Colors shown as colored preview lines
  - On selection: update `~/.tmx-session-notes` with third field (or remove if "(none)")
  - Then `reload` to refresh the session list showing new colors
- New fzf bind in main picker:
  - `--bind "ctrl-l:execute($SCRIPT --internal-set-color {})+reload($SCRIPT --internal-render \"$SHOW_HIDDEN_FILE\")"` 
- `--internal-help`: add `Ctrl-l: color tag` line
- README: add Ctrl-l to keybindings table, document color palette

**Important:** The color fzf palette must use `/dev/tty` for input because the main fzf is already consuming stdin. Use `fzf ... < /dev/tty` pattern (same approach as `create_session` name prompt).

**Lines touched:** ~50 net new lines

**Verification:**
```bash
# Tag a session
# (Ctrl-l in picker, select "red")
grep "mysession" ~/.tmx-session-notes  # should show session<TAB><TAB>red

# Verify rendering: session line shows red dot before status marker
# Verify (none) clears the tag
```

### 5. Window-level kill

**Files:** `tmx`, README.md

**Changes:**
- New `--internal-kill-window` handler in dispatch:
  - Read parent session from `${TMX_STATE_FILE}.winsession`
  - Parse window index from `$2` (remove `● ` and `: name` parts)
  - Get window name: `tmux list-windows -t "$session" -F '#{window_name}' -f '#{==:#{window_index},<idx>}'`
  - Prompt "Kill window $session:$idx ($name)? [y/N]" via /dev/tty
  - If yes: `tmux kill-window -t "$session:$idx"`
  - After kill: check `tmux list-windows -t "$session"` count
    - If windows remain: reload with `$SCRIPT --internal-list-windows "$session"`
    - If empty: clean up .win file, reload with `$SCRIPT --internal-render ...`
- Modify `ctrl-x` bind in main fzf (line 594):
  - Change from: `--bind "ctrl-x:execute($SCRIPT --internal-kill-session {})+reload(...)"` 
  - To: `--bind "ctrl-x:execute(if [ -f \"$SHOW_HIDDEN_FILE.win\" ]; then $SCRIPT --internal-kill-window {}; else $SCRIPT --internal-kill-session {}; fi)+reload(...)"`
- `--internal-help`: update Ctrl-x description to "Ctrl-x: kill session/window (context-aware)"
- README: update Ctrl-x description

**Lines touched:** ~30 net new lines

**Verification:**
```bash
# In window drill-down view (Ctrl-w), select a window, press Ctrl-x
# Should prompt with window name, kill on 'y'
# If more windows remain, list reloads
# If last window, returns to session list
```

### 6. Integration & docs cleanup

- Update `--internal-help` to include all new keybinds (Ctrl-p in dir picker note, Ctrl-l, Ctrl-x context-aware, --last flag)
- Update README keybindings table with new entries
- Add `--last` to `--help` output
- Ensure `trap` cleanup handles bookmark and MRU temp files if any
- Run `bash -n tmx` for syntax check after all changes
- Manual smoke test: launch tmx, verify all existing binds still work, then test each new feature

## Risks

- **MRU file on session rename**: if a session is renamed, MRU entries with the old name become stale. Mitigated by updating the MRU file in the rename handler.
- **Color palette fzf with /dev/tty**: need to ensure the sub-fzf doesn't interfere with the main fzf input. Using `< /dev/tty` and `>/dev/tty` should isolate it — same pattern as name prompt and rename prompt.
- **Window kill in sub-fzf bind**: the inline `if [ -f ... ]` check in the fzf bind must handle quoting correctly since it runs via `sh -c`. Double-quote carefully.
- **Bookmark toggle in dir picker**: `execute-silent` is used because we don't want the toggle to disrupt the dir picker flow. The reload to refresh the bookmark section isn't needed since the dir picker uses static input (bookmarks are loaded once at picker launch). Users will see changes on next `Ctrl-n`.
