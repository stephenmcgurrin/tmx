# Goal: Auto-color by session name

Automatically assign a color tag to new sessions based on pattern matching against the session name, using a `tmx_auto_color()` shell function defined in `~/.tmxrc`.

## Done

- `tmx_auto_color()` is callable from `create_session()` (line ~437 of `tmx`)
- `tmxrc.sample` includes a commented example (line ~40)
- `~/.tmxrc` user config has active patterns (PERS→magenta, INTERNAL→red, DOTS→blue, NBD→green)
- Documented in `--help` output and README config section
- Verified: sessions created with matching names auto-tag on create, user can override with Ctrl-l
