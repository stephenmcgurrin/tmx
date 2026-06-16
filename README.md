# tmx — tmux session picker

Interactive tmux session manager via `fzf` with live preview.

> **⚠️ Caveat emptor** — this is barely open source. It's the thing I use
daily, fixed to the point where others might enjoy it too. No roadmap, no
support, but can copy.

## Features

- Session list with live pane-content preview — see what's running before you switch
- Window drill-down (`Ctrl-w`) to jump directly to a specific window
- Hide sessions you don't want cluttering the list (`Ctrl-h`)
- Session descriptions/notes (`Ctrl-e`) stored in `~/.tmx-session-notes`
- New-session flow with directory picker and recent-dir cache (`Ctrl-n`)
- Configurable colors via env vars (Catppuccin-flavored by default)
- Optional Nerd Font glyphs

## Requirements

- tmux 2.6+, fzf 0.21+, bash 4+

## Install

```bash
cp tmx ~/bin/tmx && chmod +x ~/bin/tmx
```

Requires `~/bin` in `PATH` (or anywhere you like).

## Usage

```
tmx          # session picker
tmx --last   # jump to previous session
```

### Keybindings

| Key | Action |
|-----|--------|
| `j`/`k` `g`/`G` | Navigate |
| `/` `Esc` | Search / exit search |
| `Enter` | Attach to session |
| `Ctrl-n` | Create new session |
| `Ctrl-d` | Attach & detach others |
| `Ctrl-w` | Drill into windows (`Esc` to return) |
| `r` | Rename session |
| `Ctrl-h` | Hide/unhide session |
| `Ctrl-a` | Toggle hidden sessions (⚠️ conflicts with default tmux prefix) |
| `Ctrl-x` | Kill session / kill window (context-aware, with confirm) |
| `Ctrl-e` | Edit session description |
| `Ctrl-l` | Set color tag (pick from 8-color palette) |
| `Ctrl-p` | Jump to previous session (instant toggle) |
| `?` | Toggle help in preview |
| `q` | Quit |

Session lines show the session name in green (current) or amber (attached
by others), or unadorned (unattached), plus window count, client count,
and last activity. Color-tagged sessions show a colored dot before the name.

### Hidden sessions

`Ctrl-h` hides/unhides a session (stored in `~/.tmx-hidden-sessions`).
`Ctrl-a` toggles the hidden-section visibility in the picker.

### Color tags

`Ctrl-l` opens a palette to assign a color label to a session. The colored dot
appears before the session name. Colors are stored in
`~/.tmx-session-notes` alongside descriptions. Select `(none)` to remove a tag.

#### Auto-color by session name

Define a `tmx_auto_color()` function in `~/.tmxrc` to automatically assign
colors when a new session is created. The function receives the session name
as `$1` and should `echo` a color name (or nothing for no tag):

```sh
tmx_auto_color() {
  case "$1" in
    *PERS*)     echo "magenta" ;;
    *INTERNAL*) echo "red" ;;
    *DOTS*)     echo "blue" ;;
    *NBD*)      echo "green" ;;
  esac
}
```

Available colors: `red`, `green`, `blue`, `yellow`, `magenta`, `cyan`,
`white`, `gray`. The manual `Ctrl-l` palette always takes precedence on
individual sessions.

### Bookmarked directories

In the new-session directory picker (`Ctrl-n`), `Ctrl-f` pins/unpins the
currently selected directory. Bookmarked dirs appear in a `---bookmarks---`
section at the very top of the list. Stored in `~/.cache/tmx/bookmarks`.

### Quick-last

`tmx --last` jumps directly to your previous session without opening the
picker. Tracks session order via `~/.cache/tmx/mru`.

### Config

Copy `tmxrc.sample` to `~/.tmxrc` as a starting point, then edit to taste.
The file is executed as shell code on every run; keep it writable only by you.

```bash
cp tmxrc.sample ~/.tmxrc
```

All available settings (most are commented out — uncomment what you need):

```sh
TMX_SCAN_DEPTH=3               # find depth for dir picker
TMX_EXCLUDE_PATHS="node_modules|__pycache__|.git|target|dist"
TMX_SORT_ORDER=alpha            # alpha | recent
TMX_PREVIEW_WINDOW="right,75%,border-left,wrap"
TMX_RECENT_DIRS_MAX=50
TMX_NERD_FONTS=0                # set to 1 for Nerd Font glyphs

# Colors (truecolor hex):
TMX_COLOR_CURRENT="\033[38;2;166;227;161m"   # current session dot
TMX_COLOR_ATTACHED="\033[38;2;249;226;175m"  # attached-by-others dot
TMX_COLOR_WINDOWS="\033[38;2;148;226;213m"   # window count
TMX_COLOR_CLIENTS="\033[38;2;250;179;135m"   # client count
TMX_COLOR_ACTIVITY="\033[38;2;166;173;200m"  # last-activity label
```

### tmux popup

Add this to `~/.tmux.conf` (adjust the bind key to taste):

```
bind P display-popup -E -w 90% -h 90% -T "tmx" "$HOME/bin/tmx"
```

> If your tmux `prefix` is `C-a`, pick a different bind — `Ctrl-a` is used by
tmx to toggle hidden sessions and will be swallowed by tmux before tmx sees it.

## License

MIT
