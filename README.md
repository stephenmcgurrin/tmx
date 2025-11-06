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

## To use inside tmux: 
Add the following to your .tmux.conf file
#Prefix + P opens fzf in a popup; closes when you select.

'''tmux
bind-key -T prefix P display-popup -E -w 80% -h 80% -T "tmx" "$HOME/bin/tmx"
