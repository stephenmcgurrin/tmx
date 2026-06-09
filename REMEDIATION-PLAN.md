# tmx — Remediation & Test Plan

_Companion to [EVALUATION.md](EVALUATION.md). Drafted 2026-06-09. No code has
been changed — this is the plan of work and the manual verification procedure._

## How to run this work

1. Branch off `main`: `git switch -c fix/eval-rce-and-hardening`.
2. Tackle the fixes in the priority order below. Each is independent and can be
   committed separately, so a regression in one does not block the others.
3. After each fix, run its **Verify** block before moving on.
4. Run the full **Manual test plan** (final section) once all fixes are in.
5. Open a PR for review before merging to `main`.

A scratch tmux server keeps testing isolated from your live sessions:

```sh
export TMX_TEST_SOCKET=tmx-test
alias ttmux='tmux -L "$TMX_TEST_SOCKET"'
# seed a few sessions to play with
ttmux new-session -ds alpha   -c "$HOME"
ttmux new-session -ds beta    -c /tmp
ttmux new-session -ds gamma   -c "$HOME"
```

> Note: `tmx` calls `tmux` via `$TMUX_BIN` with no `-L`, so it talks to your
> default server. For destructive tests (kill, rename) either accept that they
> act on real sessions, or temporarily point `TMUX_BIN` at a wrapper. The
> non-destructive tests are safe against seeded throwaway sessions.

---

## Fix 1 — 🔴 Eliminate the `eval` command injection (`scan_dirs`, line 301)

**Goal.** No user-influenced path or rc value ever reaches `eval`. The scanner
must still honour `TMX_SCAN_DEPTH` and `TMX_EXCLUDE_PATHS`, and must cope with
directory names containing quotes, spaces, `$`, `;`, and `&`.

**Approach.** Drop `eval` and `find`'s `-not -path` accumulation. Filter the
exclude list with a post-`find` `grep -E`, since `TMX_EXCLUDE_PATHS` is already
a pipe-alternation. Add a numeric guard on the depth so a malformed rc value
cannot inject `find` predicates.

Proposed replacement for `scan_dirs`:

```sh
scan_dirs() {
  _exclude="${TMX_EXCLUDE_PATHS:-node_modules|__pycache__|.git|target|dist}"
  _depth="${TMX_SCAN_DEPTH:-3}"
  case "$_depth" in *[!0-9]*|'') _depth=3 ;; esac   # numeric guard
  find "$1" -maxdepth "$_depth" -type d -not -path '*/.*' 2>/dev/null \
    | grep -Ev "/(${_exclude})(/|$)" \
    | sort
}
```

**Notes / trade-offs to confirm during implementation:**
- The original `-not -path '*/\..*'` excluded dotted paths; `-not -path '*/.*'`
  is the cleaner equivalent — verify it still hides `.git` et al. as before.
- If `TMX_EXCLUDE_PATHS` is ever empty, `grep -Ev "/()(/|$)"` would match every
  path. Guard: `[ -n "$_exclude" ] || _exclude='__nomatch__'`, or skip the grep
  when empty.
- `grep -E` matches the pattern anywhere in the path segment; the `/(...)(/|$)`
  anchoring confines it to whole path components, matching `find`'s old
  `*/name/*` intent. Confirm a project literally named `dist-tools` is **not**
  wrongly excluded by the `dist` pattern (the `(/|$)` boundary should protect
  it — verify).

**Verify:**

```sh
# 1. Malicious directory name no longer executes — should list, not run.
mkdir -p "/tmp/tmxtest/';touch \$HOME/PWNED;'"
rm -f "$HOME/PWNED"
sh -c '. ./tmx >/dev/null 2>&1' 2>/dev/null   # not how it's invoked; see below
# Practical check: call the function directly
sh -c 'TMX_SCAN_DEPTH=3; TMX_EXCLUDE_PATHS="node_modules"; \
       set -- /tmp/tmxtest; \
       find "$1" -maxdepth 3 -type d -not -path "*/.*" | grep -Ev "/(node_modules)(/|$)"'
test ! -e "$HOME/PWNED" && echo "PASS: no execution" || echo "FAIL: PWNED created"

# 2. Spaces / quotes in names survive
mkdir -p "/tmp/tmxtest/Bob's Stuff" "/tmp/tmxtest/a b c"
# re-run the find|grep above; both dirs should appear in output

# 3. Excludes still work; near-miss names are kept
mkdir -p /tmp/tmxtest/node_modules /tmp/tmxtest/dist-tools
# node_modules absent from output, dist-tools present

rm -rf /tmp/tmxtest
```

---

## Fix 2 — 🟠 Replace `sed` rename rewrite with `awk` (lines 526–527)

**Goal.** Renaming a session updates the MRU file by exact line match, with no
regex/`sed` metacharacter hazards from the old or new name.

**Approach.** Swap the `sed -i` pair for an `awk` exact-match rewrite into a
temp file, then `mv`.

Proposed replacement for the MRU-update block in `--internal-rename`:

```sh
# Update MRU: replace old name with new name (exact match, no regex)
if [ -f "$MRU_FILE" ]; then
  awk -v old="$session" -v new="$newname" \
    '$0==old{print new; next} {print}' "$MRU_FILE" > "${MRU_FILE}.tmp" 2>/dev/null \
    && mv "${MRU_FILE}.tmp" "$MRU_FILE" \
    || rm -f "${MRU_FILE}.tmp"
fi
```

**Verify:**

```sh
printf 'plain\na.b.c\nx/y\nq&r\n' > /tmp/mru.test
awk -v old='a.b.c' -v new='renamed' '$0==old{print new;next}{print}' /tmp/mru.test
#   expect: plain / renamed / x/y / q&r  — only the exact line changed
awk -v old='x/y' -v new='zzz' '$0==old{print new;next}{print}' /tmp/mru.test
#   expect the x/y line becomes zzz, no others touched
rm -f /tmp/mru.test
```

Then a live check: create session `a.b`, attach, rename to `c&d` via `r`, and
confirm `~/.cache/tmx/mru` shows `c&d` on the correct line and `tmx --last`
still resolves.

---

## Fix 3 — 🟠 Reconcile the shell dialect

**Decision required (recommend option A).**

- **Option A (recommended):** change the shebang `tmx:1` to
  `#!/usr/bin/env bash`, and amend README line 21 ("POSIX `sh`") to state bash.
  Lowest effort, matches what the `$'\t'` usage already requires. The `sed -i ''`
  fallback can stay.
- **Option B:** keep `sh`, remove every bashism. Replace each `$'\t'` (lines 88,
  246, 419, 422, 424, 426, 429, 519, 521, 652, 684) with a tab variable set once
  near the top:
  ```sh
  _TAB="$(printf '\t')"
  ```
  then use `"$1$_TAB"` / `"$session$_TAB"` in the greps and `printf` args. Also
  audit `printf '%b'` (line 115) and confirm `tr -d '\000-\037\177'` (line 391)
  behaves under `dash`.

**Why it matters:** under `dash` (Debian/Ubuntu `/bin/sh`), `$'\t'` is the
literal string `$'\t'`, so every notes/colour lookup silently mismatches and
those features quietly fail.

**Verify (proves the bug, then the fix):**

```sh
# Reproduce the failure on a strict POSIX shell:
dash -c $'x="$1\t"; echo "[$x]"' _ foo    # prints [foo$\t] — literal, broken
bash -c $'x="$1\t"; echo "[$x]"' _ foo    # prints [foo<TAB>] — correct

# After Option A: confirm the chosen interpreter is bash
head -1 tmx                                # #!/usr/bin/env bash
# After Option B: confirm no $'...' remain
grep -n "\$'" tmx                          # expect no output
```

Functional check (either option): set a colour tag on a session via `Ctrl-l`,
exit, re-open `tmx`, confirm the coloured dot appears, and inspect
`~/.tmx-session-notes` — fields must be genuinely tab-separated:

```sh
sed -n 'l' ~/.tmx-session-notes           # tabs show as \t in the output
```

---

## Fix 4 — 🟡 Hardening (temp files, notes anchoring, rc docs)

These are small and can ride in one commit.

**4a. Gate the `mv` on a successful write.** Across the `.tmp` writers (lines
50–51, 520–522, 552–553, 611–612, 652–653, 684–685) replace the pattern
`grep ... > x.tmp 2>/dev/null || true; mv x.tmp x` with a guarded form so a
failed/empty write never clobbers good data:

```sh
if grep -Fxv "$session" "$HIDDEN_FILE" > "${HIDDEN_FILE}.tmp" 2>/dev/null; then
  mv "${HIDDEN_FILE}.tmp" "$HIDDEN_FILE"
else
  # grep exit 1 == "no lines matched/remained" is legitimate (file now empty)
  mv "${HIDDEN_FILE}.tmp" "$HIDDEN_FILE"   # keep, but only on exit 0/1
  # safer: case "$?" in 0|1) mv ... ;; *) rm -f "${HIDDEN_FILE}.tmp" ;; esac
fi
```

> Caution to resolve during implementation: `grep` returns exit 1 when **no
> lines match**, which here is a _legitimate_ "list is now empty" outcome, not
> an error. Distinguish exit `0`/`1` (proceed with `mv`) from `>1` (real error,
> `rm` the tmp and keep the original). Decide per call site; do not blanket-fail
> on exit 1 or you will break the "remove last entry" case.

**4b. Anchor the notes lookups.** `_color_tag_for_session` (line 88) and the
description lookup (line 246) use unanchored `grep -F "$1"$'\t'`, which collides
when one name is a suffix of another (`api` vs `myapi`). Switch to an exact
first-field match:

```sh
_tag="$(awk -F'\t' -v s="$1" '$1==s{print $3; exit}' "$NOTES_FILE" 2>/dev/null)"
# and for description:
_desc="$(awk -F'\t' -v s="$s" '$1==s{print $2; exit}' "$NOTES_FILE" 2>/dev/null)"
```

This also removes the remaining `$'\t'` dependency in those reads (helps Fix 3
Option B).

**4c. Document the rc security implication.** In README's Config section, add a
line: "`~/.tmxrc` is executed as shell on every run; treat it as code and keep
it writable only by you." Optionally `chmod`-check it at source time and warn if
group/other-writable.

**Verify:**

```sh
# 4a: simulate the "remove the only entry" case — file must end up empty, not gone
printf 'solo\n' > /tmp/h.test
grep -Fxv 'solo' /tmp/h.test > /tmp/h.test.tmp; echo "grep exit=$?"  # exit 1, tmp empty
# confirm your chosen logic keeps an empty file rather than discarding it
rm -f /tmp/h.test /tmp/h.test.tmp

# 4b: suffix-collision no longer cross-contaminates
printf 'api\tprod desc\tred\nmyapi\tdev desc\tblue\n' > /tmp/n.test
awk -F'\t' -v s=api '$1==s{print $3}' /tmp/n.test     # expect: red (not blue)
awk -F'\t' -v s=myapi '$1==s{print $3}' /tmp/n.test   # expect: blue
rm -f /tmp/n.test
```

---

## Fix 5 — ⚪ Housekeeping

**5a. `tmx_dev_to_bin.sh`** points at `~/Projects/tmx-dev/tmx`, which does not
exist (repo is at `/Volumes/Seagate/Personal/GitHub/tmx-dev`). Make it relative
or delete it:

```sh
#!/bin/sh
cp "$(cd "$(dirname "$0")" && pwd)/tmx" ~/bin/tmx && chmod +x ~/bin/tmx
```

**5b. `.gitignore`** — add `._*` (AppleDouble) and `goals/` if those planning
artifacts shouldn't be tracked. Untrack any already committed:

```sh
printf '._*\n' >> .gitignore
git rm -r --cached --ignore-unmatch '._*' .DS_Store
```

**Verify:** `git status` clean of `._*`; `git ls-files | grep -E '^\._'` empty.

---

## Manual test plan (run after all fixes land)

Seed throwaway sessions first (see top). Launch with `tmx`.

### A. Core navigation & attach
1. `tmx` → picker opens, sessions listed with `w`/`c`/activity columns. ✅
2. `j`/`k`/`g`/`G` move the cursor; `/` enters search, `Esc` exits search. ✅
3. `Enter` on a session attaches (or `switch-client` if already inside tmux). ✅
4. From inside tmux, `Ctrl-d` on another session attaches and detaches its other
   clients. ✅
5. `tmx --last` jumps to the immediately previous session. ✅

### B. The injection fix (Fix 1) — the headline check
6. `mkdir -p "$HOME/'; touch \$HOME/PWNED; '"` then `rm -f "$HOME/PWNED"`.
7. `tmx` → `Ctrl-n` → new name → directory picker scans `$HOME`.
8. **PASS** = picker lists the oddly-named dir and `$HOME/PWNED` does **not**
   exist afterwards. **FAIL** = `PWNED` appears. Clean up the test dir after.
9. `mkdir -p "$HOME/My Project's Code"` and confirm it appears selectable and
   creating a session in it works (path with space + apostrophe).

### C. New session + directory picker
10. `Ctrl-n`, enter a name, pick a directory → session created in that dir,
    attached. Confirm with `tmux display-message -p '#{pane_current_path}'`. ✅
11. `Ctrl-n`, `Esc` at the dir picker → falls back to `$PWD`. ✅
12. In the dir picker, `Ctrl-f` pins a dir → re-open picker, dir shows under
    `---bookmarks---`; `Ctrl-f` again unpins. (`~/.cache/tmx/bookmarks`.) ✅
13. Excludes honoured: a `node_modules` dir is absent; a `dist-tools` dir is
    present (boundary check from Fix 1). ✅

### D. Rename (Fix 2)
14. Create session `a.b`, `r` → rename to `c&d`. List shows `c&d`; no error. ✅
15. `cat ~/.cache/tmx/mru` → the entry is exactly `c&d`, neighbours intact. ✅
16. Rename a session that is currently hidden → it stays in
    `~/.tmx-hidden-sessions` under the new name. ✅

### E. Notes, colours, shell dialect (Fix 3, 4b)
17. `Ctrl-e` → set a description with spaces → preview shows it; re-open tmx and
    it persists. ✅
18. `Ctrl-l` → pick `red` → coloured dot before the name; re-open, persists. ✅
19. `sed -n 'l' ~/.tmx-session-notes` → fields are real tabs (`\t`). ✅
20. Create two sessions `api` and `myapi`, colour only `myapi` blue → confirm
    `api` shows **no** dot (suffix-collision fixed). ✅
21. `Ctrl-l` → `(none)` removes the tag. ✅
22. If Option B chosen: run the script under `dash ./tmx` and confirm notes
    still work; if Option A, confirm shebang is bash.

### F. Hide / show / kill
23. `Ctrl-h` hides a session → vanishes from the main list. ✅
24. `Ctrl-a` toggles the `━━━ Hidden ━━━` section into view; hidden sessions
    appear indented; `Ctrl-a` again hides the section. ✅
25. `Ctrl-h` on a hidden session unhides it. ✅
26. `Ctrl-x` on a session → `y/N` prompt; `N` cancels, `y` kills and the row
    disappears. ✅
27. `Ctrl-w` drills into windows; `Ctrl-x` there kills the **window** (context
    aware), with confirm; `Esc` returns to the session list. ✅

### G. Window view & previews
28. `Ctrl-w` lists windows with active marker; `Enter` on `1: name` jumps to
    that window in its parent session. ✅
29. Preview pane shows git branch, running processes, description, and per-pane
    capture for the highlighted session. ✅
30. `?` toggles the keybinding help into the preview and back. ✅

### H. Robustness / regression (Fix 4a)
31. Hide exactly one session so the hidden file has a single line, then unhide
    it → `~/.tmx-hidden-sessions` ends up empty (or absent), **not** leaving a
    stale entry, and no error. ✅
32. Run `tmx` with no `~/.tmxrc` present → defaults apply, no error. ✅
33. Run with a deliberately broken `~/.tmxrc` (`TMX_SCAN_DEPTH=abc`) → scanner
    falls back to depth 3, no crash (Fix 1 numeric guard). ✅
34. `tmx --help` prints usage and exits 0. ✅

### I. Lint / static pass
35. `shellcheck tmx` (with the correct shell directive for the chosen dialect) —
    review and resolve or justify each warning, especially SC2086 (word
    splitting) and any remaining SC2046/SC2294 (eval) — the latter should be
    **gone** after Fix 1. ✅

---

## Definition of done

- `grep -n 'eval' tmx` returns nothing (or only a justified, non-path eval).
- Test B (injection) passes — no `PWNED` artifact.
- `shellcheck` is clean or every remaining warning is annotated.
- Notes/colours survive a round-trip and the suffix-collision test (E20) passes.
- All manual sections A–H pass on the chosen shell.
- `EVALUATION.md` findings 1–4 are each either fixed or consciously deferred
  with a one-line rationale in the PR description.
