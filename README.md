# tmx — tmux session picker

Interactive tmux session manager using `fzf` with live preview, hidden sessions, and vim-style navigation.

## Requirements

- tmux 2.6+
- fzf 0.21+
- POSIX `sh`

## Install

```bash
brew install tmux fzf
cp tmx ~/bin/tmx && chmod +x ~/bin/tmx
```

Ensure `~/bin` is in your PATH.

## Usage

```bash
tmx
```

### Navigation (vim-style)

| Key | Action |
|-----|--------|
| `j` / `k` | Move down / up |
| `g` / `G` | Jump to top / bottom |
| `/` | Enter search mode |
| `Esc` | Exit search mode |
| `q` | Quit |
| `Enter` | Attach to session |
| `Ctrl-d` | Attach and detach other clients |

### Session management

| Key | Action |
|-----|--------|
| `Ctrl-h` | Toggle hide/unhide a session |
| `Ctrl-a` | Toggle hidden sessions visibility |

### Creating a new session

Select `[+ ] Create new session`, enter a name, then pick a base directory from the fzf picker. Press `Esc` to skip and use the current directory.

## tmux popup integration

Add to `~/.tmux.conf`:

```tmux
bind-key -T prefix P display-popup -E -w 90% -h 90% -T "tmx" "$HOME/bin/tmx"
```

Then `Prefix + P` opens tmx in a popup.

## License

MIT
