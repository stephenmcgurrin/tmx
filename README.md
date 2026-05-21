# tmx — tmux session picker

Interactive tmux session manager using `fzf` with live preview, hidden sessions,
session rename, session kill, and vim-style navigation.

## Requirements

- tmux 2.6+
- fzf 0.21+
- POSIX `sh` (works on macOS, Linux, BSD)

## Install

```bash
# macOS
brew install tmux fzf

# Linux (apt)
sudo apt install tmux fzf

# Install tmx
cp tmx ~/bin/tmx && chmod +x ~/bin/tmx
```

Ensure `~/bin` is in your `PATH`.

## Usage

```bash
tmx
```

### Session list colors

| Marker | Meaning |
|--------|---------|
| `●` (green) | Current session |
| `◎` (yellow) | Session with other attached clients |
| (plain) | Unattached session |
| (cyan) | `Create new session` entry |

Each session line shows window count, client count, and last-activity time.

### Keybindings

| Key | Action |
|-----|--------|
| `j` / `k` | Move down / up |
| `g` / `G` | Jump to top / bottom |
| `/` | Enter search mode |
| `Esc` | Exit search mode / return from window view |
| `q` | Quit |
| `Enter` | Attach to session |
| `Ctrl-d` | Attach and detach other clients |
| `r` | Rename selected session |
| `Ctrl-h` | Toggle hide/unhide session |
| `Ctrl-a` | Toggle hidden sessions visibility |
| `Ctrl-x` | Kill session (with confirmation) |
| `Ctrl-e` | Edit session description |
| `Ctrl-w` | Drill into session windows (select to jump directly) |

### Preview pane

The right-side preview shows:
- Git branch for the session's active pane directory
- Session description (if set via `Ctrl-e`)
- Window list with active window highlighted in green
- Pane content (first 15 lines) with active pane in peach
- Process tree showing child processes of each pane

### Window jumping

Press `Ctrl-w` on a session to see its windows. Select a window to attach
directly to it. Press `Esc` to return to the session list.
| `Ctrl-e` | Edit session description |
| `Ctrl-w` | Jump to windows (Esc to return) |

### Config

Optional `~/.tmxrc` (sourced as shell):

```sh
TMX_SCAN_DEPTH=3               # find depth for dir picker
TMX_EXCLUDE_PATHS="node_modules|__pycache__|.git|target|dist"
TMX_SORT_ORDER=alpha            # alpha | recent
TMX_PREVIEW_WINDOW="right,50%,border-left"
TMX_NERD_FONTS=0                # set to 1 for Nerd Font glyphs
```

### Session list

Sessions are sorted alphabetically (case-insensitive). Each line shows:

```
● session-name   2w 1c  5m ago
```

- Green `●` = current session, yellow `◎` = has attached clients
- `2w` = window count, `1c` = client count, `5m ago` = last activity
- The preview pane shows window/pane content, git branch, and session description

### Creating a new session

Select `[+ ] Create new session`, enter a name, then pick a base directory from
the fzf picker. Press `Esc` to skip and use the current directory.

The directory picker scans `$HOME` (depth 3) and, on macOS, external volumes
under `/Volumes`. On Linux, `/mnt` and `/media` are scanned for external drives.

Recent directories are cached to `~/.cache/tmx/dirs` (MRU-ordered, max 50 by
default) and appear at the top of the picker.

The directory preview shows git branch, status, file count, and last-modified files.

### Window jumping

Press `Ctrl-w` on a session to drill into its windows. Each window shows its
panes and running processes in the preview pane. Press `Esc` to return to the
session list.

### Session descriptions

Press `Ctrl-e` on a session to add a persistent description (shown in the
preview pane). Descriptions are stored in `~/.cache/tmx/notes`.

### Hidden sessions

Press `Ctrl-h` on a session to hide it from the default view. Press `Ctrl-a` to
toggle showing hidden sessions (indented, in a dimmed section). Hidden sessions
are stored in `~/.tmx-hidden-sessions`.

Hidden sessions are stored in `~/.tmx-hidden-sessions`.

## Configuration

Optional `~/.tmxrc` (shell-sourced, all vars optional):

```sh
# ~/.tmxrc
TMX_SCAN_DEPTH=3                    # find depth for directory picker
TMX_EXCLUDE_PATHS="node_modules|__pycache__|.git|target|dist"
TMX_SORT_ORDER=alpha                # alpha | recent
TMX_PREVIEW_WINDOW="right,75%,border-left,wrap"
TMX_RECENT_DIRS_MAX=50              # max cached recent directories
TMX_NERD_FONTS=0                    # set to 0 to force ASCII glyphs
```

## tmux popup integration

Add to `~/.tmux.conf`:

```tmux
bind-key -T prefix P display-popup -E -w 90% -h 90% -T "tmx" "$HOME/bin/tmx"
```

Then `Prefix + P` opens tmx in a popup.

## License

MIT
