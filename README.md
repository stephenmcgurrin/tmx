# tmx — tmux session picker with live preview

Interactive tmux session picker using `fzf` with live preview of windows and panes.
Press **Enter** to attach (or switch if already inside tmux).
Press **Ctrl-D** to attach and detach other clients.

## Features

- **Live session preview** — see all windows and panes with real content
- **Color-coded windows** — active windows highlighted in green, others in blue
- **Multi-pane visualization** — side-by-side view of split panes with borders
- **Create new sessions** — quick session creation from the picker
- **Smart pane capture** — shows recent content from each pane

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
# Prefix + P opens tmx in a popup with live preview
bind-key -T prefix P display-popup -E -w 90% -h 90% -T "tmx" "$HOME/bin/tmx"
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
- The **preview pane** (75% width on right) shows:
  - All windows with color-coded headers (active/inactive)
  - Each pane's recent content (~15 lines)
  - Visual separators for multi-pane layouts
  - Real-time content from running applications (vim, Claude Code, etc.)

If no sessions exist:
```bash
tmux new -s mysession
```

---

## Manual testing

These are the manual checks to run after changes:

1. Create test session: `tmux new -s demo -d`
2. Add multiple windows/panes with different content
3. Run `./tmx` from a normal shell:
   - Confirm preview shows all windows with color-coded headers
   - Verify multi-pane layouts display correctly with borders
   - Check that pane content is captured (including alternate screen apps like vim, Claude Code)
4. From inside tmux, run `tmux display-popup -E "$PWD/tmx"`:
   - Ensure preview updates as you navigate
   - Verify selection attaches/switches correctly

---

## License

MIT
