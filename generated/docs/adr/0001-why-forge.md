# ADR 0001: Why the tool is a Bash program

- Status: Accepted

## Context

`workspace-forge` generates one workspace from a fixed template tree, and the templates need no
variable substitution.

The tool must run on an Ubuntu machine with Bash and standard commands, and a generation runs
offline. A general template engine implements none of the required rules: create-only output, a dry
run that writes nothing, protected paths and six exit codes. The tool needs code for those rules
whatever generates the files.

Cookiecutter and Copier are Python programs. Cookiecutter renders template variables and runs
pre-generation and post-generation hooks. Copier adds update and migration commands, and this tool
has no update mode: creation is the only operation. Both add a Python runtime and a package
installation.

## Decision

Implement `workspace-forge` as a Bash executable with six Bash libraries, and use no template engine.

## Consequences

- The tool needs Bash 4 and the standard commands preflight verifies, with no Python and no package
  installation.
- The tool implements create-only output, the dry run, the protected paths and the exit codes
  directly.
- The development suite runs in Bash, and it needs `just` and `shellcheck` and nothing else.
- The tool runs only on Linux and WSL2, where Bash 4 and those commands exist.
- A new feature is Bash code with a test, not an engine plugin or a configuration key.
- The cost: no template variables, no filters and no engine hooks. A workspace that needs a per-run
  value needs new code and a new test.
