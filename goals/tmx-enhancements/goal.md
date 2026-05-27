# Goal: tmx enhancements — bookmarks, color tags, jump-to-last, window kill

Deliver four independent enhancements from IDEAS.md that the user selected:
bookmarks/pinned directories in the folder picker, per-session color tags,
jump-to-last-session hotkey, and window-level kill from the window preview.

See `facts.md` for the shared understanding of what each feature does.
See `plan.md` for the implementation plan with ordered steps and per-feature
verification.

## Done condition

- All four features implemented, syntax-checked with `sh -n`
- All keybinds registered and conflict-free
- `tmx --help` updated for each new bind
- Deployed to `~/bin/tmx` via `tmx_dev_to_bin.sh`
- User confirms each feature works
