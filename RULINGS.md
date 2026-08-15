# RULINGS.md

Decisions this project's owner has already made. A recorded ruling stands
until the owner changes it.

Read this file when a decision is in front of you, not for general context.
When new evidence — a bug report, a pull request, a user request, a changed
constraint — suggests a ruling needs revisiting, flag it for the owner rather
than acting against it. See `~/projects/Agents/AGENTS.md` under "Rulings".

Newest first. Each entry gives the date, what was ruled, and enough evidence
for the next reader to judge whether the situation has changed.

Only decisions that could be raised again belong here — contentious calls,
questions likely to recur, and rulings that may need revisiting when
circumstances change. Routine decisions nobody will ever question stay out;
see `~/projects/Agents/AGENTS.md` under "What earns a place in `RULINGS.md`".

---

## 2026-08-15 — Author address is `exodist7@gmail.com`

**Ruling: `dist.ini` uses `Chad Granum <exodist7@gmail.com>`.**

The cpan.org mail system is gone, so anything sent to `exodist@cpan.org` — the
address this distribution has published for its whole life — is lost. Fixed in
the adoption branch rather than deferred, so it ships with the next release.

Revisit if: never, unless the address itself changes.

## 2026-08-15 — No local `agent_scripts/`, no `TEMPLATE.pod`

**Ruling: run the auditors from `~/projects/Agents/agent_scripts/` by absolute
path. Do not copy them into this repository, and do not add `TEMPLATE.pod`.**

Local copies exist so contributors without the shared checkout can run the
gates; this project has none, so five copies would be maintenance with no
reader. New modules are rare here and `Test2::API` is a live example to copy
from, which is what `TEMPLATE.pod` would provide.

Pre-existing findings across `lib/` at adoption time, recorded as pre-existing
rather than as work: `find-long-subs` 7, `audit-methods-not-functions` 15,
`audit-readonly-attrs` 19, `audit-banned-words` 1, `find-large-modules` 0. The
gates apply to the touched set, so these only matter when the file in question
is edited.

Revisit if: outside contributors start running the gates, or the project gains
a reason to add modules often enough for a POD skeleton to pay for itself.

## 2026-08-15 — perltidy is adopted, but nothing is reformatted in bulk

**Ruling: `.perltidyrc` is the shared config verbatim; existing files are left
alone until they are edited, and then only the edited sections are tidied.**

The account's shared `templates/perltidyrc` is now `.perltidyrc`, including
`--wn`. The old root `perltidyrc` — a stale variant that was the only one of
the two shipping in the tarball — was deleted; no perltidy config ships.

Running perltidy across existing files would reformat a dual-life distribution
wholesale and bury every real change in whitespace churn, including in the
core tarball diff. Tidy what you touch, nothing more.

Revisit if: a file is being rewritten anyway, where tidying it whole costs
nothing extra.

## 2026-08-15 — Existing test layout stays; new agent tests go in `t/AI/`

**Ruling: preserve the current `t/` structure. New agent-authored tests go
under `t/AI/`; agents may edit existing tests in place.**

The repository predates coding agents and has 370 test files across
`t/acceptance`, `t/behavior`, `t/modules`, `t/regression`, `t/Legacy`,
`t/Legacy_And_Test2`, and the parallel `t/Test2/` tree. Neither shared scheme
in `~/projects/Agents/TESTING.md` fits without renaming all of it — churn on a
dual-life tarball, broken references in old bug reports, no user-visible gain.

New human tests fall into the existing structure. Entirely AI-authored tests
go under `t/AI/`, mirroring the same subdirectory layout, so provenance is
visible from the path without adding a header to 370 files. Editing an
existing non-AI test in place is fine and does not move it.

Revisit if: the split needs more granularity or better tracking than a single
directory boundary provides.

## 2026-08-15 — Perl 5.6 is a courtesy floor, not a supported version

**Ruling: the packaged floor stays `5.006002`; the supported and tested floor
is `5.008001`.**

Contributors, CI, and the maintainers target 5.8 and up. A few people still run
5.6, maintain their own compatibility work around it, and occasionally send
patches. Declaring 5.006002 costs nothing and keeps their lives easier;
raising the floor to 5.8 would break things for them in worse ways than an
unsupported-but-declared 5.6 does. See
https://github.com/Test-More/test-more/issues/1087, where this was explained
recently.

What this means in practice:

- Do not raise `perl = 5.006002` in `dist.ini` or `MIN_PERL_VERSION`.
- Do not intentionally break 5.6.
- Do not spend effort, add compatibility machinery, or block a release on 5.6.
- 5.6-only breakage is not a release blocker; patches from 5.6 users are
  welcome.

Recorded in `AGENTS_OVERRIDE.md` as the minimum-version declaration, and as a
comment beside the floor in `dist.ini`.

Revisit if: the last 5.6 users stop patching, or a core feature the project
needs cannot be expressed without breaking 5.6.

## 2026-08-15 — `AI_AND_LLM_POLICY.txt` ships with the distribution

**Ruling: carry the canonical policy at the repository root and let it ship.**

Byte-for-byte copy of `~/projects/Agents/AI_AND_LLM_POLICY.txt`, the shared
default. It is not excluded from `[GatherDir]` even though the `.md` files are
— the policy is contributor-facing text worth carrying wherever the
distribution goes.

Revisit if: the project adopts a different AI/LLM policy, in which case the
replacement text goes in this same file and the departure is declared in
`AGENTS_OVERRIDE.md`.

## 2026-08-15 — No `.md` file ships except `README.md`

**Ruling: `[GatherDir]` excludes every `.md` file.**

`README.md` still ships because `[ReadmeFromPod / Markdown]` generates it in
the build tree. Everything else — `AGENTS.md`, `AGENTS_OVERRIDE.md`,
`RULINGS.md`, `CLAUDE.md` — is repository-only tooling. `CLAUDE.md` had been
shipping to CPAN, and thus into the perl core tarball, only because it sat in
the tree while `[GatherDir]` had no `.md` exclusion.

This is a deliberate departure from `~/projects/Agents/DZIL_GUIDE.md`, which
says a dual-life distribution does not exclude internal `.md` files; recorded
in `AGENTS_OVERRIDE.md`.

Revisit if: a `.md` file ever becomes user-facing documentation the
distribution must carry.

## 2026-08-15 — Agent instruction files are tracked in git

**Ruling: `CLAUDE.md`, `AGENTS.md`, and `AGENTS_OVERRIDE.md` are committed.**

`CLAUDE.md` had been listed in `.gitignore`, so the harness entry point existed
only in the owner's working copy. An untracked entry point breaks the bootstrap
chain for every fresh clone, which is the point of adopting
`~/projects/Agents`. The `CLAUDE.md` ignore line was removed; `/.claude/` and
`/worktrees/` are ignored instead, since those are agent scratch space rather
than project content.

Revisit if: the repository ever needs to keep agent instructions private, or a
harness starts writing project-visible state into the entry files.
