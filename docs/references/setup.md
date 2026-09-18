# Local run and preview

The bridge needs macOS command-line tools and a connected Stadia controller.
Local execution defaults to dry run:

```bash
./scripts/run-bridge.sh
# Equivalent explicit source invocation:
swift run stadia-controller-bridge --config config/mappings.json
```

Add `--no-dry-run` for live input actions. Use `--prompt-accessibility` when
requesting the required Accessibility permission. For the installed service,
use [deployment and recovery](deployment.md), including its stable app identity.

## Controller guide

```bash
./scripts/run-controller-guide.sh
./scripts/run-controller-guide.sh --port 8174
```

The default guide is `http://localhost:8173/`; stop it with Control-C. It rereads
`config/mappings.json` on page load/Refresh, exposes only guide assets and
`/api/mappings`, and never edits mappings. Production guide operations are in
[the release contract](repo-contract.md).

## Mappings

The running bridge watches `config/mappings.json`. Code changes need a restart;
new actions or schema require reinstalling the staged launchd binary.
`appProfiles` matches the frontmost bundle ID; only `alwaysOn` controls work
outside a matching profile.

Keep dictation and submit separate. Dictation completion is asynchronous, so
automatic Enter on trigger release can submit partial or previous text.
For Ghostty-specific routing and API constraints, use
`docs/architecture/ghostty-integration.md` and
`docs/references/ghostty-mapping-rationale.md`.
