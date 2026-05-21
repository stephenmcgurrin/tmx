# tmx — tmux session picker

Interactive tmux session manager via `fzf` with live preview.

## Requirements

- tmux 2.6+, fzf 0.21+, POSIX `sh`

## Install

```bash
cp tmx ~/bin/tmx && chmod +x ~/bin/tmx
```

Requires `~/bin` in `PATH` (or anywhere you like).

## Usage

```
tmx
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
| `Ctrl-a` | Toggle hidden sessions |
| `Ctrl-x` | Kill session (with confirm) |
| `Ctrl-e` | Edit session description |
| `?` | Toggle help in preview |
| `q` | Quit |

Session lines show `●` (current, green), `◎` (attached by others, amber), or
unadorned (unattached), plus window count, client count, and last activity.

### Config

Optional `~/.tmxrc` (shell-sourced):

```sh
TMX_SCAN_DEPTH=3               # find depth for dir picker
TMX_EXCLUDE_PATHS="node_modules|__pycache__|.git|target|dist"
TMX_SORT_ORDER=alpha            # alpha | recent
TMX_PREVIEW_WINDOW="right,75%,border-left,wrap"
TMX_RECENT_DIRS_MAX=50
TMX_NERD_FONTS=0                # set to 1 for Nerd Font glyphs
```

### tmux popup

```
bind-key -T prefix P display-popup -E -w 90% -h 90% -T "tmx" "$HOME/bin/tmx"
```

## License

MIT
