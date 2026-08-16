# AGENTS.md

## MANDATORY: read the universal agent rules first

This project opts into shared agent guidance while keeping its own documents
authoritative for project-specific rules and design.

- Repository: `git@github.com:exodist/Agents.git`
- Expected location: `~/projects/Agents`

If `~/projects/Agents` does not exist, clone it before doing anything else:

    git clone git@github.com:exodist/Agents.git ~/projects/Agents

Then read `~/projects/Agents/AGENTS.md` and follow the shared guidance this
project has adopted. It points at task-specific guides and procedures.

All documents in THIS repository take priority over the shared repository.
Read the project documents named below; `AGENTS_OVERRIDE.md` records
declarations and explicit shared-rule overrides when present.

---

## What this project is

Test::More, Test::Builder, and the Test2 core: the assertion and event layer
almost every Perl test suite on CPAN loads.

CPAN distribution name: `Test-Simple` — also the name to query CPAN Testers
with; the procedure is in `~/projects/Agents/CPAN_TESTERS.md`.

The directory is `test-more/` on disk; the distribution is `Test-Simple` on
CPAN and the GitHub repository is `Test-More/test-more`. All three names refer
to this one project. `~/projects/Test-More/Test2` is a symlink to this same
checkout, not a separate repository.

This distribution is **dual-life**: it also ships inside the Perl core, so
packaging and compatibility rules are tighter than usual. See
`AGENTS_OVERRIDE.md` and `~/projects/Agents/DZIL_GUIDE.md` under "Distribution
shapes".

---

## Mission-critical: the bar here is higher than elsewhere

This distribution ships in the Perl core and sits underneath nearly every test
suite on CPAN. A mistake here breaks thousands of distributions at once, and
the fix cannot be shipped on our schedule alone. Quality control is stricter
and churn is a cost in its own right.

- **Every change proves its value.** Fixes and features are targeted at a real,
  demonstrated problem. "Cleanup", "modernisation", and refactors that do not
  change behavior are not reasons to touch this code.
- **Smallest change that solves the problem**, with correctness ranking above
  smallness. A larger change that is actually correct beats a minimal one that
  is not.
- **Dependencies.** Weigh any new prerequisite carefully. A **non-core**
  dependency is not a decision this project can make on its own — it requires
  discussion with the external Perl core teams. Do not propose one as if it
  were an internal call.
- **Preserving a bug can be the right answer.** Where a fix would break many
  or important CPAN modules, documenting and preserving the behavior is a
  legitimate outcome. Raise it as a decision; do not fix quietly.

### Where change belongs

| Layer | Status | What may change |
|---|---|---|
| `Test2::V*`, and the Test2 internals they expose | Active | New features and functionality live here. Ordinary care applies. |
| `Test::Builder` | Middle ground | Overhauled into a compatibility wrapper around `Test2::API`, so it *can* be changed — but `Test::More`, `Test::Simple`, and a long tail of `Test::*` tools sit on it, **including modules that monkeypatch it**. Back-compat requirements are severe. Changes are rare and deliberate. |
| `Test::More`, `Test::Simple` | Legacy | Documentation may be updated freely. Functionality and code change only when absolutely needed, with justification. Bugs here may be documented and preserved rather than fixed. |

New functionality goes in the Test2 layer. If a change appears to require
editing `Test::More` or `Test::Simple`, that is a signal to stop and check
whether it belongs in Test2 instead.

---

## Canonical sources of truth

1. **`RULINGS.md`** — decisions already made. Read it when a decision is in
   front of you.
2. **`AGENTS_OVERRIDE.md`** — this project's declarations and overrides.
3. **This file** — project context and conventions.

There is no `ARCHITECTURE.md`; the POD in `lib/Test2/Manual/` is the closest
thing to a design document.

---

## Testing

```
~/projects/Agents/bin/agent-test-lock -- prove --timer -Ilib -j16 -r t/
```

- 370 test files. `-Ilib` is required — several tests load modules that also
  exist in the installed perl.
- `xt/` ships and `[RunExtraTests]` runs it, so `dzil test` and every release
  run the author tests — POD spelling and POD syntax. The command above covers
  `t/` only; run `dzil test` before a release, or
  `prove -Ilib xt/author/pod-spell.t` after touching POD.
- A new word that the spelling test rejects but that is correct goes in the
  stopword list at the bottom of `xt/author/pod-spell.t`.
- Downstream verification is **not** part of the suite. See below.
- CI covers perl 5.8 through the current release on Linux, macOS, and Windows.

### Test layout

The existing layout is kept as it is: `t/{acceptance,behavior,modules,regression}`,
`t/Legacy`, `t/Legacy_And_Test2`, the parallel `t/Test2/` tree, and `t/lib`.
New tests written by an agent go under `t/AI/`, mirroring that layout. Editing
an existing test in place is fine and does not move it. Full rule:
`AGENTS_OVERRIDE.md` under "Test layout and provenance".

### Downstream verification

`agent_scripts/verify-downstream` installs a list of downstream distributions
against a candidate tarball in a throwaway perlbrew library, then classifies
what broke. It takes hours, needs network, and is run when asked — never as
part of ordinary test runs, and never on your own initiative.

```
perldoc agent_scripts/verify-downstream
```

Read that first: it carries the procedure, including the rule that the owner
chooses the perl and the owner decides what a failure means.

---

## Project-specific pre-review gates

No auditors are copied into this repository. Run the canonical ones by
absolute path against the files you touched:

```
perl ~/projects/Agents/agent_scripts/audit-methods-not-functions <paths>
perl ~/projects/Agents/agent_scripts/audit-readonly-attrs        <paths>
perl ~/projects/Agents/agent_scripts/audit-banned-words          <paths>
perl ~/projects/Agents/agent_scripts/find-long-subs              <paths>
```

`lib/` carries pre-existing findings from before adoption; they are recorded
in `RULINGS.md` and are not pending work.

`audit-project-wiring` reports two expected findings: WIR006 (no
`TEMPLATE.pod`, ruled out) and WIR107 against `lib/Test2/Require/Perl.pm`,
which is a `use v5.10` inside a POD example, not shipped code.

---

## Architecture quick-reference

Foundational rules to internalise before writing code here:

- **`use base`, not `use parent`.** `parent` is not core before 5.10.1 and the
  packaged floor is 5.006002. `lib/Test2/V1/Handle.pm` is the sole exception.
- **`Test2::Util::HashBase` for objects** — the bundled copy, never the CPAN
  `Object::HashBase`. A dual-life distribution cannot take a non-core
  dependency (`[OnlyCorePrereqs]`).
- **No new prerequisites** without checking they are core as of the
  `starting_version` in `dist.ini`.
- **Nothing later than 5.8 in shipped code.** No signatures, no `say`, no
  postfix deref, no `//` in modules that must load on the packaged floor.
- Events flow from tools to a `Test2::Hub` to a `Test2::Formatter`. Reaching
  around that path is how output ordering bugs get created.
