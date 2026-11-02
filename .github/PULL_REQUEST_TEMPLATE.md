# Pull request

## What changes

Describe what this pull request changes and why. Explain the behavior before and
after the change, and mention any affected template, library or workflow.

Related issue:

## Checklist

- [ ] Tests: new or updated tests cover the change, and `bash tests/run.sh` passes.
- [ ] Lint: `shellcheck forge lib/*.sh scripts/*.sh tests/*.sh` passes.
- [ ] Documentation: README, `docs/` and template documentation reflect the change.
- [ ] Changelog: `CHANGELOG.md` records the change when it is user-visible.
- [ ] Security: create-only behavior, path protections and the closed option set are preserved; no secrets, tokens or credentials are added.
- [ ] Portability: the change works on the supported Linux and WSL2 baseline with Bash 4+, and no macOS or native Windows support is implied.
