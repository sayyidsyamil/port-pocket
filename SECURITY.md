# Security

Port Pocket is an early preview. The latest source on `main` is the maintained version.

## Reporting

Report sensitive vulnerabilities privately through [GitHub's vulnerability reporting](https://github.com/sayyidsyamil/port-pocket/security/advisories/new). Do not put exploit details, private process information, tokens, or personal paths in public issues.

For ordinary bugs, use the public issue forms.

## Current boundaries

- Discovery uses local `lsof` output and does not scan the network.
- Stop sends `SIGTERM` only after confirmation and checks process ownership, executable path, and listener identity.
- A small protected-process list is a usability guard, not a comprehensive security boundary.
- Process state can change between validation and signal delivery; stopping is not transactionally atomic.
- No privileged helper, administrator escalation, analytics, or background network service is included.
- Preview builds are ad-hoc signed, not Developer ID signed or notarized.
