# AGENTS_OVERRIDE.md

This project's answers to the choices the universal agent rules deliberately
leave open, plus every deliberate departure from them.

Universal rules live in `~/projects/Agents` (see `AGENTS.md` for the clone
URL). Every project-local document already takes priority over shared rules;
this file keeps declarations and explicit overrides easy to find.

---

## Declarations

### Minimum Perl version

> **Minimum: 5.006002**
>
> **Supported and tested: 5.008001**

The packaged floor is a courtesy to the few people who still run 5.6 and
maintain their own compatibility work around it. Do not raise it, and do not
intentionally break 5.6 — but do not spend effort, add compatibility
machinery, or block a release on it either. Everything the project actually
tests and supports starts at 5.8.

Reason: see `RULINGS.md`, "Perl 5.6 is a courtesy floor, not a supported
version", and https://github.com/Test-More/test-more/issues/1087.

### Subroutine signatures

> **Policy: disabled**

> **Enabling pragma: not applicable**

Argument handling follows the surrounding code using `@_`.

Reason: signatures need perl 5.20 at the earliest and are only stable at 5.36.
The compatibility floor cannot express them.

### POD placement

> **Layout: all at bottom, under `__END__`**

Legacy `Test::*` modules that interleave POD with code — `Test::More` most of
all — keep the layout they have. Do not restructure them. New files and new
POD follow the default.

Reason: the Test2 tree and `Test::Builder` already put everything under
`__END__`. Reflowing `Test::More`'s interleaved POD would be a large diff on
the most-read file in the distribution for no reader benefit.

### Test layout and provenance

> **Scheme: existing project layout, plus a `t/AI/` tree for agent-authored tests**

The existing directories stay exactly as they are:

```text
t/
    acceptance/  behavior/  modules/  regression/
    Legacy/  Legacy_And_Test2/
    Test2/       acceptance/  behavior/  legacy/  modules/  regression/
    lib/
    AI/          (agent-authored tests only, mirroring the layout above)
```

- **Human-authored tests** go wherever they fit in the existing tree.
- **Tests authored by an agent** go under `t/AI/`, mirroring the same
  subdirectory layout.
- An agent **may edit an existing test in place** — moving it is not required
  and not wanted.
- No `# Test origin:` headers. The directory is the provenance signal.

> **Layout audit: none.** `audit-test-layout` targets the shared
> category-and-origin scheme and is neither copied nor run here.

Reason: 370 test files predating coding agents. Renaming them buys nothing and
churns a dual-life tarball. See `RULINGS.md`.

### perltidy

> **Config: shared — `~/projects/Agents/templates/perltidyrc`, copied verbatim to `.perltidyrc`**

The older root `perltidyrc` was deleted — it was a stale duplicate and the
only one of the two that shipped in the tarball. No perltidy config ships.

**Existing files are not reformatted.** Do not run perltidy over a file to
tidy it. When you edit a file, the sections you touch may be tidied; the rest
of the file stays as it is. See `RULINGS.md`.

Reason: the shared config is what the account standardises on; a mass reformat
of a dual-life distribution would bury real changes in whitespace churn.

---

## Overrides

### Dual-life distribution

This distribution also ships inside the Perl core, which overrides several
packaging rules at once (see `~/projects/Agents/DZIL_GUIDE.md`, "Distribution
shapes"):

- Plain `[MakeMaker]`, not `[MakeMaker::Awesome]` — the core build has to be
  able to consume the generated `Makefile.PL`.
- `[OnlyCorePrereqs]` with `starting_version = 5.040000`: every prerequisite
  must itself be core as of that perl.
- A 5.006002 perl floor, per the declaration above.
- The directory name differs from the distribution name: `test-more/` on disk,
  `Test-Simple` on CPAN.

### No local `agent_scripts/`

Shared guidance: projects keep copies of the cross-project auditors in their
own `agent_scripts/`.

Here: there is no `agent_scripts/` directory. The auditors are run from
`~/projects/Agents/agent_scripts/` by absolute path, which the shared rules
allow. See `RULINGS.md`.

### `use base`, not `use parent`

Shared guidance: `parent` for inheritance, not `base`.

Here: `use base`. `parent` is not core before perl 5.10.1 and the packaged
floor is 5.006002. `lib/Test2/V1/Handle.pm` is the sole existing exception.

### Internal `.md` files do not ship

Shared guidance: a dual-life distribution does not exclude internal `.md`
files, because the core tarball comparison expects the tree as-is.

Here: `[GatherDir]` excludes every `.md` file. `README.md` still ships because
`[ReadmeFromPod / Markdown]` generates it in the build tree.

Reason: agent instructions and internal notes are repository tooling, not
something the perl core tarball should carry. See `RULINGS.md`.

---

## Prior rulings

Recorded in `RULINGS.md`, not here. This file holds declarations and
shared-rule overrides; a ruling is neither.
