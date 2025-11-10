# tmx — local tmux session picker with fzf

Pick a tmux session using `fzf`.  
Press **Enter** to attach (or switch if already inside tmux).  
Press **Ctrl-D** to attach and detach other clients.

---

## Requirements

- tmux 2.6+
- fzf 0.21+
- macOS, POSIX `sh` (works from zsh, bash)

---

## Installation (macOS with Homebrew)

```bash
brew install tmux fzf
```

Copy the `tmx` script into your `~/bin` directory and make it executable:
```bash
chmod +x ~/bin/tmx
```

Ensure `~/bin` is in your PATH (most Oh My Zsh setups already include it).

---

## To use inside tmux

Add the following to your `~/.tmux.conf` file:

```tmux
# Prefix + P opens fzf in a popup; closes when you select.
bind-key -T prefix P display-popup -E -w 80% -h 80% -T "tmx" "$HOME/bin/tmx"
```

Reload your tmux configuration:
```bash
tmux source-file ~/.tmux.conf
```

Now press **Prefix + P** to open the `tmx` picker inside a popup window.

---

## Usage Outside tmux

From any terminal (not already in tmux), run:
```bash
tmx
```

Use the arrow keys or type to filter.  
- **Enter** attaches to the selected session.  
- **Ctrl-D** steals the session (detaches others, then attaches you).  
- The preview pane lists windows/panes for the highlighted session and falls back to the last 200 lines of its active pane if window metadata is unavailable.

If no sessions exist:
```bash
tmux new -s mysession
```

---

## Manual testing

These are the manual checks to run after changes (outside tmux and from a popup):

1. `tmux new -s demo -d` to seed a session with windows/panes you expect to see
2. Run `./tmx` from a normal shell; confirm the preview lists window names and shows pane output if windows disappear
3. From inside tmux, run `tmux display-popup -E "$PWD/tmx"`; ensure the preview updates as you move the cursor and that selection still attaches/switches correctly

---

## License

MIT
