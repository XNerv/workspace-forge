# Root orchestrator for the two halves of this repository.
#
# `spec/` is the source of truth; `generated/` is the tool it produces. The name
# says which half a recipe acts on: `generated-*` enters the tool, `spec-*` reads
# the specification, `root-*` checks this repository itself. No recipe carries
# logic of its own: arguments are forwarded verbatim, exactly like the generated
# workspace's justfile.

set shell := ["bash", "-uc"]
set positional-arguments := true

# List the recipes; the default when nobody names one.
default:
    @just --list

# Internal: without the tool tree there is nothing for a generated-* recipe to
# run, and the fix is a generation run, not a shell command.
_need-generated:
    @test -d generated || { printf 'generated/ is absent: an agent must run spec/workspace-forge.prompt.md first\n' >&2; exit 1; }

# Run the tool's test suite (requires just and shellcheck).
generated-test: _need-generated
    @cd generated && bash tests/run.sh

# Lint the tool's Bash sources with ShellCheck.
generated-lint: _need-generated
    @cd generated && command -v shellcheck > /dev/null 2>&1 || { echo "shellcheck is required" >&2; exit 1; }
    @cd generated && shellcheck forge lib/*.sh scripts/*.sh tests/*.sh

# Build the standalone bundle and checksum into generated/dist/.
generated-build: _need-generated
    @cd generated && bash scripts/build-standalone.sh

# Plan only: forces --dry-run and prints what would be created, writing nothing.
generated-plan *args: _need-generated
    @./generated/forge --dry-run "$@"

# Create the workspace; a relative path resolves at the repository root.
generated-create *args: _need-generated
    @./generated/forge "$@"

# Install a symbolic link at ~/.local/bin/forge pointing at this checkout.
generated-install: _need-generated
    @cd generated && just install

# Remove only that link; never a regular file or another program's link.
generated-uninstall: _need-generated
    @cd generated && just uninstall

# Run this repository's own suite: the host report and its tests.
root-test:
    @bash tests/run.sh

# Audit the specification against the repository it describes.
spec-audit:
    @bash spec/audit/run.sh

# Notes. No recipe above adds behaviour of its own:
#
#   just generated-plan -p DIR         plan only (same as create -n; -n is idempotent)
#   just generated-plan                plan for $HOME/workspace
#   just generated-create -p DIR       create DIR, relative to the repository root
#   just generated-create --path=DIR   same, using the equal-sign form
#   just generated-create              create $HOME/workspace, like ./forge
#
#   just generated-install             the guard logic lives in generated/justfile, so
#                                      this recipe only enters the tool and delegates
#   just generated-uninstall           removes the link only when it points here
#
#   just root-test                     the doctor suite, not the tool's suite
#   just spec-audit                    reads spec/ and the repository, writes nothing
#
# Any flag the tool rejects is rejected here with the same exit code.
