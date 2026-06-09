# Plan — tmx enhancement batch

## Solution Approach

Four independent features, implemented in the single `tmx` script. Order grouped by shared touchpoints: last-session tracking first (touches `attach_normal`/`attach_detach_others`), then window-level kill, then bookmarks, then color tags. Each adds a new `--internal-*` dispatch handler plus fzf binds.

---

## 1. Jump to Last Session (Ctrl-l)

**Files:** `tmx` (single file)

**Steps:**

1. Add `--last` dispatch above `--help`. Reads `$TMX_STATE_FILE.last`, if found calls `attach_normal "$last"`, if not found or file missing, runs normal fzf flow (exec `$SCRIPT`).
2. In `attach_normal` and `attach_detach_others`, write `$1` to `$TMX_STATE_FILE.last` before the tmux command.
3. Add `ctrl-l` bind in the fzf invocation: `--bind "ctrl-l:execute-silent($SCRIPT --last)"` — this exits fzf and jumps. Or use `execute(...)` with an exit-zero approach; need to ensure fzf terminates cleanly. Best approach: `--bind "ctrl-l:become($SCRIPT --last)"` (fzf 0.35+ `become` replaces fzf with the command, clean exit + attach). If `become` not available, fall back to SIGINT-pattern or `execute(...)+abort`.
4. Mention `Ctrl-l` and `--last` in `--help` output.
5. **Verification:** `tmx --last` jumps to previous session. Inside fzf, `Ctrl-l` exits picker and jumps. Fresh terminal with no prior session: `tmx --last` runs normal picker.

**Risks:** `become` requires fzf ≥0.35 (released 2022). The user may have an older fzf — check with `fzf --version`. Fallback: `execute(...)+abort` works but leaves fzf on screen briefly.

---

## 2. Window-Level Kill from Window Preview (Ctrl-x)

**Files:** `tmx` (single file)

**Steps:**

1. Add `--internal-kill-window` dispatch handler. Takes the rendered window line from fzf, extracts window index. Requires `$TMX_STATE_FILE.winsession` (set by `--internal-list-windows`). Prompts confirmation: `Kill window <session>:<idx>? [y/N]`. Runs `tmux kill-window -t <session>:<idx>`. Removes session from hidden file if last window killed.
2. Modify the `ctrl-x` bind in fzf to conditionally dispatch. Read `$TMX_STATE_FILE.win` — if `1`, route to `--internal-kill-window`, else to `--internal-kill-session`. Can't do this in a single bind expression cleanly; instead: make the `ctrl-x` bind always go to a new `--internal-kill` handler that checks the `.win` file and dispatches appropriately.
3. After killing a window, reload the window list: `+reload($SCRIPT --internal-list-windows ...)`. Problem: we need the session name for the reload. One approach: store it as `${TMX_STATE_FILE}.winsession` already. The `--internal-kill-window` handler writes the session name to a temp output file, and the bind uses `execute(...)` which can't pipe to reload. Better: kill executes via `execute-silent(...)`, then the `+reload(...)` reads `${TMX_STATE_FILE}.winsession` to re-render the window list. So the bind becomes two-part: `execute-silent($SCRIPT --internal-kill-window)+reload($SCRIPT --internal-list-windows ...)` — but `--internal-list-windows` also needs the session name. Store session name in a known path. Use `cat` inside reload: `reload($SCRIPT --internal-list-windows "$(cat ${TMX_STATE_FILE}.winsession)")`.
4. After killing the last window, the `--internal-kill-window` handler should remove the `.win` marker so reload returns the session list.
5. Update `--help` to mention Ctrl-x kills windows in window view.
6. **Verification:** Ctrl-w into a session with 2+ windows, Ctrl-x on one, confirm prompt, window disappears. Try on the last window — returns to session list. Try Ctrl-x in main view — still kills session as before.

---

## 3. Bookmarks / Pinned Directories (Ctrl-p)

**Files:** `tmx` (single file), `~/.tmx-bookmarks` (new data file)

**Steps:**

1. Define `BOOKMARKS_FILE="${HOME}/.tmx-bookmarks"` in the globals section alongside `HIDDEN_FILE`/`NOTES_FILE`.
2. Add `--internal-bookmark` and `--internal-unbookmark` dispatch handlers:
   - `--internal-bookmark` takes a path, appends to `$BOOKMARKS_FILE`.
   - `--internal-unbookmark` takes a path, removes from `$BOOKMARKS_FILE` via grep -Fxv.
3. Add `--internal-toggle-bookmark` that checks if the path is already bookmarked and toggles.
4. In `pick_directory()`, read `$BOOKMARKS_FILE` before building `_input`. If bookmarks exist, prepend them with a `---bookmarks---` header line.
5. In the directory picker fzf, add `Ctrl-p` bind: execute-silent toggle + reload. Since the fzf uses `|| true` (no `$()` anymore after your fix), the bind just reloads the directory listing. But the listing is generated from shell variables, not a script reload — tricky. Approach: add `--internal-render-dirs` dispatch that runs `pick_directory`'s list-building logic and prints the dir list. Then the fzf reads from that: `fzf ... --bind "ctrl-p:execute-silent($SCRIPT --internal-toggle-bookmark {})+reload($SCRIPT --internal-render-dirs)"`. And the initial stdin becomes a pipe from `$SCRIPT --internal-render-dirs` instead of the current inline `_input` construction.
6. The bookmarks sentinel line `---bookmarks---` must be filtered out in selection (like `---recent---` and `---external---` already are).
7. Update `--help` for `Ctrl-p`.
8. **Verification:** `Ctrl-p` on a directory bookmarks it. Next time in dir picker, it appears at top under bookmarks header. `Ctrl-p` again unbookmarks it. Bookmarks persist in `~/.tmx-bookmarks`.

---

## 4. Per-Session Color Tags (Ctrl-t)

**Files:** `tmx` (single file), `~/.tmx-session-notes` (format extended)

**Steps:**

1. Extend `--internal-set-description` or add `--internal-set-color` dispatch. The color tag is stored as an optional third tab field in `~/.tmx-session-notes`: `session\tdescription\tcolor`.
2. Palette: map names to ANSI codes: `magenta` → `\033[38;2;245;194;231m`, `cyan` → `\033[38;2;137;220;235m`, `yellow` → `\033[38;2;249;226;175m`, `green` → `\033[38;2;166;227;161m`, `blue` → `\033[38;2;137;180;250m`, `reset` → (no color prefix).
3. Add `--internal-set-color` handler: takes session name, prompts via `/dev/tty` for color choice (simple: "Color (magenta/cyan/yellow/green/blue/reset/none):").
4. In `render_sessions()`, after the existing session line formats, check `$NOTES_FILE` for a color tag. If found, insert a colored `●` prefix right after the `●`/`◎`/indent. E.g., `● ◎ mysession` where the first `●` is the user's color tag.
5. If the session already has a `●` prefix (current session), the color tag goes before it. Current session: `● ● mysession` (user-tag + green current indicator).
6. Add the `Ctrl-t` bind in the main fzf: `--bind "ctrl-t:execute-silent($SCRIPT --internal-set-color {})+reload($SCRIPT --internal-render \"$SHOW_HIDDEN_FILE\")"`.
7. Update `--help`.
8. **Verification:** Ctrl-t on a session, choose a color, the session line gains a colored dot. Re-opening tmx shows it persists. Choosing "reset" removes the dot. Color survives session rename (the notes file is keyed by name, so rename will orphan — acceptable, same as descriptions).

---

## Order of Implementation

1. **Jump to Last Session** — smallest, touches only attach helpers + new dispatch
2. **Window-Level Kill** — medium, touches window view flow
3. **Bookmarks** — larger, refactors directory picker into internal dispatch
4. **Per-Session Color Tags** — medium, touches render pipeline + storage

Each is independent; they can be built in any order.

## Verification (all features)

- `sh -n tmx` passes syntax check
- Each new `--internal-*` handler works when called directly
- Fzf binds don't break existing navigation (j/k/g/G/q, enter, esc, ctrl-d, etc.)
- No keybind conflicts
- Old `~/.tmx-session-notes` files with just `session\tnote` format still parse correctly
