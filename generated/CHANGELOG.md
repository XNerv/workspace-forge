# Changelog

Changes to `workspace-forge` are recorded in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the version numbers
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

No change yet.

## [0.1.0]

Version 0.1.0 was not published and is not tagged. The entries under this heading record the first
implementation.

### Added

- The `forge` executable with `-p`/`--path`, `-n`/`--dry-run`, `-h`/`--help` and `-v`/`--version`.
- Six libraries: `common`, `args`, `preflight`, `files`, `tree` and `templates`.
- Preflight checks for Bash 4, the platform, the required commands, `HOME` and the destination parent.
- Protected-path checks: the exact `$HOME` and `/` rules, sensitive configuration paths, system paths,
  other users' homes and the temporary-root exception.
- The create-only refusal of an existing destination with exit code 3, in a real run and a dry run.
- The directory tree with twelve directories and one README per directory.
- Template installation for the root configuration, the docs, the scripts, the data stages, the
  experiments, the projects and the infrastructure area.
- Seven per-directory `.gitignore` files under `data/` and the three nested-repository categories.
- The skeleton scripts `backup.sh`, `setup.sh`, `clean.sh` and `doctor.sh`, with `--help` and named
  stub stages.
- The generated `justfile`, which forwards its four recipes to the scripts.
- `--dry-run` output with every planned absolute path and simulated counters.
- Exit codes 0 to 5, with code 6 reserved.
- The standalone build at `dist/workspace-forge-<version>/`, with a `.tar.gz` archive and a `.sha256`
  checksum.
- Nine executable tests, the shared test library and the test runner.
- The `justfile` recipes `test`, `lint`, `build`, `install`, `uninstall` and `release`.
- The documentation: this README, the usage manual, the architecture document, the contributing
  guide, three ADRs and the template guide.
- The MIT license.
