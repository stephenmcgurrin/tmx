# Ideas for tmx

A scratchpad of features that fit tmx's philosophy: **fast, keyboard-driven,
fzf-native, and ruthlessly simple**. No config dialogs, no TUI sprawl. Every
interaction should feel instant and fzfindable.

---

### Project-aware session grouping

Sessions in the same project directory (or sharing a common ancestor like
`~/Projects/foo`) could be visually grouped with a lightweight header or
indented block. Would make the list scannable when you have 15+ sessions
spread across a few projects.

### Fuzzy directory picker

Right now `Ctrl-n` uses fzf in exact-match mode for the directory picker.
Switching to fuzzy matching (or making it configurable) would let you type
`prj/tmx` and land on `~/Projects/tmx-dev` without typing the full path
prefix.

### Session search by window title

`Ctrl-f` or `/` could search across session+window names simultaneously — not
just session names. Type `vim` and see every session with a window running
vim, with the matching window name highlighted in the preview.

### Bookmarks / pinned directories ✅ (v1.3.0)

Let the user pin directories (`Ctrl-p` in the dir picker) that always appear
at the top of the directory list, above recent dirs. Stored as a plaintext
file in `~/.cache/tmx/bookmarks`. A dead-simple way to keep your top 5–10
project roots one keystroke away.

### Tmuxinator / tmuxp-lite templates

A minimal template system: a `~/.tmx-templates/` directory of shell scripts
that each create a session layout (named windows, split panes, set working
dirs). The new-session flow could offer a `--template` flag or fzf picker
before the directory picker. No YAML, no dependency — just sourced shell.

### Preview pane dimensions

In the preview for a session, show the current pane's dimensions
(`80x24`) and the window layout name (e.g., `main-vertical`). Helps
distinguish identically-named sessions at a glance when you have multiple
terminal sizes or layouts going.

### Sort by most-recently-used across sessions

A global MRU list that tracks which sessions you've switched to (not just
which are active) and surfaces them at the top regardless of actual tmux
activity timestamps. Could be a simple `~/.cache/tmx/mru` file appended on
every attach.

### Per-session color tagging ✅ (v1.3.0)

Let users assign a color label to a session (`Ctrl-l` → pick from a small
palette). The session line gets a colored bar or dot. Useful for visually
partitioning "work" vs "personal" vs "experiment" sessions. Stored in
`~/.tmx-session-notes` alongside descriptions.

### Quick-last: jump to previous session ✅ (v1.3.0)

A `tmx --last` flag that immediately attaches to whichever session you were in
before the current one. Like `cd -` for tmux sessions. Uses the MRU file.

### Window-level kill ✅ (v1.3.0)

Extend `Ctrl-x` so that in window drill-down view it kills just that window
instead of the whole session. A confirmation prompt with the window name
prevents accidents.

### Copy session name to clipboard

`Ctrl-y` in the picker to yank the selected session name into the system
clipboard. Small quality-of-life thing for scripting or sharing session names
with teammates.
