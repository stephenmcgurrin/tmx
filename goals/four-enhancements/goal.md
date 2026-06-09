# Goal: Four tmx enhancements

Add four features to tmx that stay within its fzf-native, keyboard-driven, plaintext-file philosophy: bookmarked directories in the folder picker, per-session color tagging, quick-last session switching, and context-aware window kill in drill-down view.

See [facts.md](facts.md) for the shared understanding of what each feature does.
See [plan.md](plan.md) for the ordered implementation steps.

## Done when

- All 17 facts from facts.md are satisfied
- `bash -n tmx` passes
- Manual smoke test confirms existing functionality is unchanged
- All four features work end-to-end in a live tmux session
- README and --internal-help are updated
- Changes committed and pushed to main
- Release tagged as v1.3.0
