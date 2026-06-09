# tmx — Project Evaluation & Security Review

_Reviewed: 2026-06-09 · Target: `tmx` (871 lines, single POSIX-ish `sh` script), `tmxrc.sample`, installer, docs._

## Summary

`tmx` is a well-organised, genuinely useful single-file fzf front-end for tmux.
The structure is clean — globals, helpers, an internal-dispatch `case` for fzf
callbacks, then `main` — and defensive habits are visible throughout (`mktemp`
for state, `clean_sel`/`skip_header` sanitising, `set -eu` in main, an `EXIT`
trap, confirmation prompts before destructive actions, `--` is mostly avoided
because arguments are passed safely). For a personal daily-driver it is in good
shape.

There is, however, **one genuine command-injection vulnerability** (the `eval`
in the directory scanner) and a cluster of **portability and robustness bugs**
that undermine the stated "POSIX `sh`" claim. These are detailed below, ranked
by severity.

---

## 🔴 High — Command injection via `eval` in `scan_dirs` (line 301)

```sh
scan_dirs() {
  _exclude="${TMX_EXCLUDE_PATHS:-node_modules|__pycache__|.git|target|dist}"
  _args="-maxdepth ${TMX_SCAN_DEPTH:-3} -type d -not -path '*/\..*'"
  IFS='|'
  for _pat in $_exclude; do
    [ -n "$_pat" ] && _args="$_args -not -path '*/$_pat/*'"
  done
  IFS="$_oldIFS"
  eval "find '$1' $_args 2>/dev/null" | sort   # ← here
}
```

`$1` is a directory path that the user does **not** control: it is
`$HOME`, then every entry under `/Volumes/*` (macOS) or `/mnt/*` and `/media/*`
(Linux) — see `pick_directory` (lines 311–346). Those paths are wrapped in
single quotes and handed to `eval`. A directory or mounted volume whose **name
contains a single quote** breaks out of the quoting and the remainder is
re-parsed as shell.

**Exploit sketch.** A directory named:

```
';touch /tmp/pwned;'
```

turns the eval string into:

```
find '/Volumes/';touch /tmp/pwned;'/...' ...
```

i.e. `touch /tmp/pwned` runs. Because `pick_directory` scans **every mounted
volume and removable drive**, the attack surface includes a malicious USB
stick, a network share, or a downloaded/extracted folder with a crafted name.
Merely pressing `Ctrl-n` (new session → directory picker) is enough to trigger
arbitrary code execution. Even a perfectly innocent directory such as
`Bob's Stuff` will at minimum throw a parse error and silently break the
scanner.

`TMX_EXCLUDE_PATHS` and `TMX_SCAN_DEPTH` are also interpolated into the eval,
but since `~/.tmxrc` is already sourced as shell, those are not an escalation —
the path argument is the real problem.

**Remedy.** Eliminate `eval` entirely. `find` does not need it. Two options:

1. Build the prune list without re-parsing. Since this is `sh` (no arrays),
   filter with a post-`find` pipe:
   ```sh
   scan_dirs() {
     _exclude="${TMX_EXCLUDE_PATHS:-node_modules|__pycache__|.git|target|dist}"
     find "$1" -maxdepth "${TMX_SCAN_DEPTH:-3}" -type d -not -path '*/.*' 2>/dev/null \
       | grep -Ev "/($_exclude)(/|$)" \
       | sort
   }
   ```
   (`$_exclude` is already a pipe-alternation, which is exactly what `grep -E`
   wants. Validate `TMX_SCAN_DEPTH` is numeric first.)

2. If you must keep `find`'s native `-not -path`, accumulate args with the
   positional-parameter idiom (`set --`) and invoke `find "$@"` — never `eval`.

Also worth a numeric guard on `TMX_SCAN_DEPTH` so a malformed rc value can't
inject `find` predicates:

```sh
case "$TMX_SCAN_DEPTH" in *[!0-9]*) TMX_SCAN_DEPTH=3 ;; esac
```

---

## 🟠 Medium — `sed` substitution injection on rename (lines 526–527)

```sh
sed -i '' "s/^${session}$/${newname}/" "$MRU_FILE" 2>/dev/null || \
  sed -i    "s/^${session}$/${newname}/" "$MRU_FILE" 2>/dev/null || true
```

Both `$session` (old name) and `$newname` (read from the user) are interpolated
raw into a `sed` expression. `newname` is only whitespace-trimmed (line 514),
not escaped. A session name or new name containing `/`, `&`, `.`, `[`, `*`, or
`\` will either corrupt the substitution or rewrite the wrong MRU entry. This is
not arbitrary code execution (sed is not a shell), but it is a correctness and
data-integrity bug, and `&`/`\1` give an attacker-influenced name some control
over the output.

**Remedy.** Do the replacement without `sed` regex semantics — a fixed-string
line swap is safer and POSIX-clean:

```sh
[ -f "$MRU_FILE" ] && {
  awk -v old="$session" -v new="$newname" \
    '$0==old{print new; next} {print}' "$MRU_FILE" > "${MRU_FILE}.tmp" &&
  mv "${MRU_FILE}.tmp" "$MRU_FILE"
}
```

---

## 🟠 Medium — Bashisms under a `#!/usr/bin/env sh` shebang

The script advertises "POSIX `sh`" (README line 21, shebang line 1) but uses
constructs that are **not** POSIX and fail silently on a strict `sh` such as
Debian/Ubuntu's `dash`:

- **`$'\t'` ANSI-C quoting** — lines 88, 246, 419, 422, 424, 426, 429, 519,
  521, 652, 684. Under `dash`, `$'\t'` is the literal four characters `$'\t'`,
  not a tab. Since the notes file is **tab-delimited**, every description and
  colour-tag lookup/write silently mismatches. This is the most consequential
  portability bug: on a non-bash `/bin/sh` the notes and colour features quietly
  stop working with no error.
- **`sed -i ''`** (line 526) — BSD/macOS form. The `|| sed -i` fallback covers
  GNU, so this one is handled, but it is worth a comment.
- **`printf '%b'`** (line 115) and **`tr -d '\000-\037\177'`** (line 391) are
  broadly supported but edge-case dependent.

**Remedy.** Either (a) change the shebang to `#!/usr/bin/env bash` and drop the
"POSIX" claim, which is the least effort and matches reality, or (b) replace
`$'\t'` with a tab held in a variable initialised once via
`_TAB="$(printf '\t')"` and use `"$1$_TAB"` in the greps. Given the script
already relies on bash-ish behaviour, option (a) is the honest choice.

---

## 🟡 Low — Non-atomic temp-file writes in `$HOME`

Throughout, state files are updated via `grep > file.tmp; mv file.tmp file`
(lines 50–51, 63–65, 403–405, 422–423, 520–522, 552–553, 611–612, 652–653,
684–685). Observations:

- The `.tmp` names are **predictable** and live in `$HOME` / `~/.cache/tmx`.
  In a single-user home directory the symlink/race risk is low, but it is not
  zero on a shared box with a permissive umask.
- Several writes use `grep ... > tmp 2>/dev/null || true` followed by an
  unconditional `mv`. If `grep` fails for a reason other than "no match" (disk
  full, permission), the `|| true` swallows it and the `mv` clobbers the real
  file with a truncated/empty `.tmp`. Low probability, but it silently eats
  user data (hidden list, notes, bookmarks) when it does happen.

**Remedy.** Gate the `mv` on the redirection actually succeeding (drop the
`|| true` and check `&&`), and consider `mktemp` in the same directory for the
scratch file. Not urgent for personal use.

---

## 🟡 Low — Unanchored `grep -F` notes lookups can collide

`_color_tag_for_session` (line 88) and the description lookup (line 246) use
`grep -F "$1"$'\t'` — fixed-string but **not** line-anchored. The line format is
`name<TAB>desc<TAB>color`, so searching `foo<TAB>` also matches a line for
`xfoo<TAB>...`. Two sessions where one name is a suffix of another (`api` vs
`myapi`) can therefore pick up each other's colour/description.

**Remedy.** Anchor to start of line. With fixed strings that means
`grep` for `^name<TAB>` via `grep -E "^$(escape "$1")\t"`, or switch the notes
store to an `awk -F'\t' '$1==name'` lookup, which is exact and avoids the
escaping question altogether.

---

## 🟡 Low — `~/.tmxrc` is sourced as arbitrary shell (by design)

`. "${HOME}/.tmxrc"` (line 22) executes the config as code, before `set -eu`
and before any validation. This is the conventional rc-file model and is the
user's own file, so it is acceptable — but two notes:

1. It is sourced **before** the `need tmux` / `need fzf` checks and before
   `set -eu`, so a broken rc fails in confusing ways. Consider sourcing inside a
   subshell-validated block, or at least documenting that rc errors surface
   early.
2. The `TMX_COLOR_*` values flow unescaped into `printf` format-adjacent
   positions; a hostile rc could embed terminal escape sequences. Since the rc
   is user-owned this is self-inflicted only — worth a one-line caveat in the
   README's config section, which currently says merely "shell-sourced" without
   the security implication.

---

## ⚪ Correctness & robustness notes (non-security)

- **`tmx_dev_to_bin.sh` is broken/stale.** It copies from
  `~/Projects/tmx-dev/tmx`, but this repo lives at
  `/Volumes/Seagate/Personal/GitHub/tmx-dev`. The installer points at a path
  that does not exist on this machine. Either fix the path, make it relative
  (`cp "$(dirname "$0")/tmx" ~/bin/`), or delete it — the README's manual `cp`
  is clearer anyway.
- **`._*` AppleDouble files and `.DS_Store` are committed / present.** The repo
  root and `goals/` are littered with `._tmx`, `._README.md`, etc. `.gitignore`
  ignores `.DS_Store` but not `._*`. Add `._*` to `.gitignore` and untrack any
  that were committed; they leak nothing sensitive but are noise.
- **`.gitignore` ignores `.tmx-hidden-sessions`** — but that file lives in
  `$HOME`, not the repo, so the entry has no effect here. Harmless, but it
  suggests an earlier layout. Worth removing for clarity.
- **`render_sessions` shells out heavily per row.** For each session it runs
  `list-windows`, `list-clients`, `display-message`, `date`, plus a notes
  `grep` — and the preview runs `pgrep`/`ps` per pane. On a host with many
  sessions the picker will feel sluggish and the preview noticeably so. Not a
  defect, but the obvious scaling ceiling if the session count ever grows.
- **`--last` reads line 2 of the MRU** (`sed -n '2p'`, line 475). If the current
  session was never `mru_update`'d (e.g. attached outside tmx), line 2 may not
  be "the previous" session. Minor semantic wrinkle.
- **`set -eu` is only active in `main`.** The entire internal-dispatch `case`
  (lines 446–766) runs without it — deliberate, per the comment on line 436, to
  survive fzf reload races. Reasonable, but it means a typo in a dispatch
  handler fails silently rather than loudly. Acceptable trade-off; noted for
  maintainers.

---

## What is done well

- `mktemp` for the show-hidden/window state files with an `EXIT` trap cleanup
  (lines 798–801) — no predictable `/tmp` race for the hot-path state.
- fzf `{}` placeholders are passed to `$SCRIPT --internal-* {}`; fzf
  single-quotes the substitution, and the handlers re-sanitise with
  `clean_sel`/`skip_header`. The fzf-callback boundary is handled with care.
- Destructive actions (kill session, kill window) require explicit `y/N`
  confirmation (lines 545–547, 565–567).
- Session-name creation strips control characters (line 391), closing the
  obvious terminal-injection-on-create vector.
- `set -eu`, the args guard (`[ $# -eq 0 ] || exit 0`, line 775), and the
  absolute-path `SCRIPT` resolution (lines 15–19) are all sensible.

---

## Recommended priority order

1. **Fix the `eval` in `scan_dirs`** (High — real RCE via crafted directory
   name on any mounted volume). Replace with the `grep -Ev` pipe shown above.
2. **De-`sed` the rename MRU rewrite** (Medium — data corruption / injection on
   names with regex metacharacters).
3. **Reconcile the shell claim** — switch the shebang to `bash` (recommended) or
   purge the `$'\t'` bashisms (Medium — silent feature breakage on `dash`).
4. Harden the temp-file `mv`s, anchor the notes greps, and add a security note
   to the rc documentation (Low).
5. Fix or remove `tmx_dev_to_bin.sh` and add `._*` to `.gitignore` (housekeeping).
