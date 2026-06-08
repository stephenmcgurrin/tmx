# Plan — Auto-color by session name

## What

When a new session is created, automatically assign a color tag based on pattern matching against the session name. Patterns are defined in `~/.tmxrc` as a shell function.

## Config: `~/.tmxrc`

The user defines a shell function `tmx_auto_color` that takes a session name as `$1` and echoes a color name (or nothing for no color):

```sh
# ~/.tmxrc — auto-color rules for new sessions
tmx_auto_color() {
  case "$1" in
    work-*)    echo "blue" ;;
    personal-*) echo "green" ;;
    tmp*|temp*) echo "yellow" ;;
    *)         ;;  # no color
  esac
}
```

This is dead simple: it's just shell. No new file format to learn, no parser to write. `~/.tmxrc` is already sourced before the main fzf loop, so the function is available anywhere in tmx.

Available color names (same palette already used by Ctrl-l): `red`, `green`, `blue`, `yellow`, `magenta`, `cyan`, `white`, `gray`.

## Changes

### Single file: `tmx`

1. **In `create_session()`** (after `attach_normal "$name"`):
   - If `tmx_auto_color` is defined as a function (`command -v tmx_auto_color >/dev/null 2>&1`):
     - Call `tmx_auto_color "$name"` to get the color name
     - Ignore empty or "(none)" results
     - If color returned, write to `~/.tmx-session-notes` in three-field format:
       ```
       session\tdescription\tcolor
       ```
     - Preserve any existing description (the session might have been created via `tmux new` outside tmx, then described later — on next tmx run auto-color fires and adds the color without nuking the description)

2. **In `--help` output**:
   - Add a line documenting `tmx_auto_color` in the config section

3. **In `--internal-set-color` handler** (optional polish):
   - Already works — the auto-color just seeds the notes file, and the user can still override with Ctrl-l

### ~15 net new lines in `tmx`

## Implementation note

`create_session()` is in the dispatch section (runs before `set -eu`), so `tmx_auto_color` must be defined in `~/.tmxrc` and that file is sourced before dispatch since config loading happens at the top of the script (line ~580: `[ -f "${HOME}/.tmxrc" ] && . "${HOME}/.tmxrc"`). This is fine — the function definition survives into the dispatch handlers.

Actually wait — looking at the script structure: the dispatch section runs *before* `set -eu` and *before* the `~/.tmxrc` source line. Config sourcing is down in the main section. Let me double-check the exact line order...

Config is sourced at the top of the main section (after `set -eu`). The dispatch handlers run *before* main, so `tmx_auto_color` wouldn't be visible there.

**Fix:** Move the `~/.tmxrc` source to the very top of the script, before the dispatch section. This also benefits other dispatch handlers that might want config values (e.g., `--internal-set-color` could respect a custom palette).

### Step order:
1. Move `[ -f "${HOME}/.tmxrc" ] && . "${HOME}/.tmxrc"` from main section to top of file (right after the global variable definitions, before the dispatch `case` block)
2. Add `tmx_auto_color` call to `create_session()`
3. Add docs to `--help`

## Verification

```bash
# Setup: add tmx_auto_color to ~/.tmxrc with a test rule
cat >> ~/.tmxrc <<'EOF'
tmx_auto_color() {
  case "$1" in
    test-*) echo "cyan" ;;
    *) ;;
  esac
}
EOF

# Create a session
tmx
# Ctrl-n → name: test-foo → pick any dir → attach
# Check the notes file
grep "test-foo" ~/.tmx-session-notes
# Should show: test-foo<TAB><TAB>cyan

# Verify color renders in picker
tmx
# test-foo should have a cyan ● dot

# Override still works
# Ctrl-l on test-foo → pick "red"
# Dot changes to red
```
