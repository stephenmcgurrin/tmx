# Plan: Fix tmx regression bugs

## Context

The refactored `tmx` (298 lines) introduced architectural bugs because the `$0 --flag` callback pattern spawns fresh shell processes, but state management wasn't adapted to this multi-process model. The original script ran as a single process so all state was in-process. The new design requires inter-process state sharing.

## Root Cause Analysis

**The architecture**: fzf `--bind` commands call back into the script via `$0 --flag`. Each bind fires a new shell process that runs the script from top to bottom. 

**The bugs**: Three classes of issues emerged from this model:

### 1. STATE_FILE isolation (CRITICAL)
Every `$0 --*` invocation hits `mktemp` at the top, creating a *different* temp file. When `--toggle-show-hidden` writes `show_hidden=1` to its temp file, that process exits (trap deletes the file), and `--menu` reads from its own fresh/empty temp file. State never propagates.

**Fix**: Export `TMX_STATE_FILE` before fzf runs. Sub-invocations check for the env var instead of calling `mktemp`.

### 2. Variable name mismatch in --toggle-show-hidden
```sh
cur=0
[ -f "$STATE_FILE" ] && . "$STATE_FILE"   # sources "show_hidden=..."
if [ "$cur" = "1" ]; then                 # checks $cur, not $show_hidden
```
The state file stores `show_hidden=X` but the handler never reads that variable. `$cur` stays 0 always.

**Fix**: Use `show_hidden` consistently (the variable name the state file writes).

### 3. Functions called before definition (POSIX portability)
`build_menu`, `preview_session`, `scan_dirs`, `pick_directory`, `create_session` are all defined *after* the CLI dispatch `case` block that calls them. In bash this works (functions parsed at read time), but in POSIX `sh` (dash, etc.) a function must be executed (defined) before it's called. The README claims POSIX `sh` compatibility.

**Fix**: Move all function definitions above the CLI dispatch.

### 4. `$0` fragility in fzf bind strings
`$0` is expanded by the outer shell into the fzf bind string. If the user invoked the script as `sh ./tmx`, `$0` is `./tmx`. fzf subshells run `./tmx --menu` — works if cwd is unchanged. If invoked as `tmx` from PATH, `$0` may be just `tmx` and requires PATH resolution in the fzf subshell. If `$0` contains spaces (unlikely), the bind string breaks.

**Fix**: Resolve script to absolute path at startup and use the resolved path in bind strings.

### 5. `r` (rename) not unbound in search mode
New bind `r:execute(...)` fires even during search. In search mode, `r` should be a search character, not the rename action. The original unbinds `j,k,g,G,q` for search; the new version needs to also unbind `r` (and rebind on esc).

**Fix**: Add `r` to the `/` unbind and `esc` rebind lists.

### 6. remove_from_hidden in --toggle-hidden: subtle but correct
`skip_header` returns 1 (false) for headers, 0 (true) for valid sessions. The dispatch uses `skip_header "$s" || exit 0` which is correct but reads awkwardly. **Not a bug**.

## Files to modify

- `tmx` — all fixes in one file

## Steps

- [ ] 1. Resolve script path to absolute at startup: fallback chain from `$0`
- [ ] 2. Fix STATE_FILE: export `TMX_STATE_FILE` after `mktemp`, check env var on sub-invocations
- [ ] 3. Move ALL function definitions above the CLI dispatch `case` block
- [ ] 4. Fix `cur` → `show_hidden` in `--toggle-show-hidden` handler
- [ ] 5. Replace `$0` with resolved `$SCRIPT` in all fzf `--bind` and `--preview` strings
- [ ] 6. Add `r` to search-mode unbind (`/`) and rebind (`esc`) lists
- [ ] 7. Verify syntax: `sh -n tmx`
- [ ] 8. Verify `--help` works
- [ ] 9. State-file inheritance test: simulate fzf calling `$SCRIPT --menu`

## Verification

```bash
# Syntax
sh -n tmx

# Help
sh tmx --help

# State file inheritance (simulate what fzf does)
export TMX_STATE_FILE="/tmp/tmx-test-$$"
echo 'show_hidden=1' > "$TMX_STATE_FILE"
sh tmx --menu | grep -q "Hidden" && echo "PASS: hidden section shown" || echo "FAIL"
rm -f "$TMX_STATE_FILE"
```
