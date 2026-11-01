# Contributing to Port Pocket

Port Pocket is a small native utility. Keep contributions focused and avoid adding dependencies for tasks the platform already handles.

## Development

Requirements: macOS 13+, Apple Command Line Tools, and Git.

```bash
git clone https://github.com/sayyidsyamil/port-pocket.git
cd port-pocket
bash scripts/build.sh
"build/Port Pocket.app/Contents/MacOS/PortPocket" --integration-test
open "build/Port Pocket.app"
```

Quit the running app before replacing an installed build. Do not test process stopping against unrelated work: the integration check creates and stops its own disposable server.

## Interface guidelines

- Standard macOS typography and semantic colors.
- Compact rows, understated separators, minimal chrome.
- No mascots, marketing copy, gradients, or decorative status cards.
- Keyboard/accessibility labels for controls with icons.
- Keep light and dark appearances usable.
- Preserve positioning below the menu bar and check filtering, empty states, and scrolling.

## Before submitting

1. Build and run the integration check above.
2. Check shell changes with `bash -n scripts/build.sh scripts/install.sh`.
3. Explain the problem, approach, and verification in your pull request.
4. For visual changes, attach screenshots using example data, not private paths.

Regenerate documentation previews with:

```bash
"build/Port Pocket.app/Contents/MacOS/PortPocket" --capture-preview docs/screenshots
```

The parser checks cover IPv4/IPv6, deduplication, sorting, empty output, and protected processes. The integration check verifies real discovery and graceful termination. Neither replaces checking the native panel on a Mac.

## Scope

Discovery is read-only and limited to local TCP listeners. Stop must remain explicit, confirmed, limited to the current user, and revalidate process identity. Do not add privileged termination or automatic process killing.

Contributions are licensed under the project’s MIT license.
