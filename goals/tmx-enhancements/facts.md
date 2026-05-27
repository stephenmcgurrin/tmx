# Facts — tmx enhancement batch (features from IDEAS.md)

- Bookmarks / pinned directories appear at top of directory picker above scanned results, stored in ~/.tmx-bookmarks (one-per-line plaintext)
- Ctrl-p in directory picker bookmarks/unbookmarks the current selection
- Per-session color tags stored as optional third field in ~/.tmx-session-notes (session\tnote\tcolor)
- Ctrl-t cycles color tag through a small palette (magenta, cyan, yellow, green, blue, reset) prompted via fzf mini-picker or tty cycle prompt
- Color tag renders as a colored prefix dot on the session line in the main picker
- Ctrl-l jumps directly to the last-visited session without opening the fzf picker (from terminal: tmx --last)
- Last session tracked in $TMX_STATE_FILE.last, written on every attach_normal / attach_detach_others call
- Ctrl-x in window preview view kills the selected window instead of the session (detected via ${TMX_STATE_FILE}.win marker)
- After killing the last window, return to session list (Esc behavior)
- All new binds use free keys (Ctrl-p, Ctrl-t, Ctrl-l) — no conflicts with existing binds
