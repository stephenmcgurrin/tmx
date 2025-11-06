# tmx — local tmux session picker with fzf

Pick a tmux session using `fzf`.
Press **Enter** to attach (or switch if already inside tmux).
Press **Ctrl-D** to attach and detach other clients.

## Requirements

- tmux 2.6+
- fzf 0.21+
- macOS, POSIX `sh` (works from zsh, bash)

macOS with Homebrew:

```bash
brew install tmux fzf
