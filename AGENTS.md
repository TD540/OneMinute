# Development workflow

- Use the shared `development` branch for routine development and feature commits. Do not commit feature work directly to `main`.
- Never create a branch without the user's explicit approval. If `development` does not exist, ask before creating it.
- Short-lived feature or fix branches may be proposed, but create and use them only when the user explicitly approves.
- After an approved feature or fix branch is successfully merged into `development`, return to `development` and clean up the branch locally and, if pushed, on the remote. Remove any associated temporary worktree. Verify that all work is merged before deleting; do not discard unmerged work.
- Merge `development` into `main` only when the user explicitly requests or approves it. Do not push to `main` without the user's authorization.
- These project-specific rules take precedence over the parent guidance to commit directly on the current branch.

# Xcode Cloud

- Treat pushes and merges to `main` as a potential Xcode Cloud build trigger for both the iOS and watchOS apps.
- The Xcode Cloud manifest at `OneMinute.xcodeproj/xcshareddata/xcodecloud/manifest.json` lists the `OneMinute` and `OneMinuteWatch` targets. Whether both workflows are enabled and configured to build on pushes to `main` still needs confirmation; the manifest does not specify triggers.
