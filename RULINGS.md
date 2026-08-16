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

## 2026-08-15 — The `all_*` + `end()` exception covers the explicit spelling only

**Ruling: `verify_build` stays a build-time check. It does not chase the
implicit `end` that `is()` applies at comparison time.**

A builder that uses `all_items`, `all_keys`, or `all_values` together with
`end()` while specifying no items or fields can only match an empty structure,
which discards the `all_*` checks. `Test2::Compare::Array`, `Bag`, and `Hash`
throw on that combination from `verify_build`, called by `Test2::Compare::build`
once the builder block finishes.

The same dead construct reaches `is($got, array { all_items ... })` with no
`end()` written at all: `Test2::Compare::_convert` clones the check and sets
`ending => 'implicit'` long after the build hook has run, so `verify_build`
cannot see it. Those users are not left without guidance — `Test2::Tools::Compare::is`
already passes the assertion and emits the "NOTICE OF BEHAVIOR CHANGE" alert
naming `end()` and `etc()`, and a user who then writes `end()` gets the
exception, which names `etc()`. That alert is a plain warning on an ordinary
run, but the same branch throws when `AUTHOR_TESTING` is set, so for a
distribution author the current impact is already a dead test file.

Rejected: moving or duplicating the check into convert or compare time. That
crosses a layer, runs on every comparison instead of once per build, and makes
a comparison throw mid-assertion — a new error policy for the module. Rejected
also: letting `all_*` suppress implicit end, which would contradict the rule
that `all_*` never affects bounds and would silently exempt these checks from
the announced implicit-`end()` transition.

**Revisit when** the implicit-`end()` default actually lands. At that point
`all_*` without `etc()` starts failing with a bare "SHOULD NOT EXIST" table and
no pointer to `etc()`, and the guidance may need to move somewhere the compare
path can reach.

Evidence: https://github.com/Test-More/test-more/issues/1086

---

## 2026-08-15 — Downstream verification is a tool, not a test

**Ruling: `xt/downstream.t` is replaced by `agent_scripts/verify-downstream`.**

The `.t` asserted nothing about this library — every `ok()` only checked that
`cpanm` exited zero. It never ran in CI or at install time (gated behind
`DOWNSTREAM_TESTS`, excluded from the distribution), hardcoded one perlbrew
perl, discovered its tarball by globbing the working directory, and cleaned up
its perlbrew library only when everything passed — four orphaned libraries
were sitting on the development box from past failures. It produced no
structured result and captured no logs, and it had no support for the triage
that actually follows a failure.

Decided so far:

- The tool and its data live in `agent_scripts/`, excluded from the
  distribution.
- `xt/downstream.t` is deleted. The two lists move to
  `agent_scripts/downstream/dists.list` and
  `agent_scripts/downstream/known-broken.list` with `git mv`, keeping their
  history. `dist.ini` swaps the `^xt/downstream` exclusion for
  `^agent_scripts/`.

- Failures are classified mechanically. `verify-downstream baseline` installs
  the previous CPAN release of `Test-Simple` into a second perlbrew library and
  retries only the recorded failures, separating `already-broken` from
  `new-failure`.
- CPAN Testers is not queried by the tool. The agent checks it during triage,
  so a network failure never blocks a verification run.
- Installs stay serial, one attempt, with `HARNESS_OPTIONS=j8` so each
  downstream suite runs its own tests in parallel. A retry drops
  `HARNESS_OPTIONS` entirely — some suites do not pass under concurrency — so
  a dist that fails in parallel and passes serially is classified
  `serial-only` rather than counted as a regression.

- One annotated list, not two. A known-broken entry carries when it broke and
  why: `Test::Aggregate  # known-broken since 1.302150: relies on
  Test::Builder internals removed in the Test2 overhaul`. The existing
  known-broken file has no reasons at all, which is why nobody can retire an
  entry from it.
- The tool **removes** a known-broken annotation automatically when that dist
  starts passing, on every run — the current list is stale and several entries
  are believed fixed. It **never adds** one: a new breakage is only marked
  acceptable by the owner, and that is not a decision an agent can make.

- Each run keeps a directory under `agent_scripts/downstream/runs/<timestamp>/`
  (gitignored): `state.json` plus the captured `cpanm` log for every dist. The
  state file is what makes the failure → baseline → report chain resumable,
  and the logs are the difference between triage and guesswork.
- Documentation lives in the tool's POD. `AGENTS.md` points at it rather than
  repeating it.
- **The perl is the owner's choice, asked before every run.** The agent offers
  the last five stable majors that `perlbrew available` can install — latest
  `.Y` of each `5.X`, newest first, one line each — and the owner may name any
  older perl instead. Perl ships roughly one stable major a year, so five
  majors is the five-year window without a release-date lookup. The perl used
  is recorded in `state.json` and named in every report.
- The perlbrew library is kept after a run. `verify-downstream clean <run-id>`
  removes one; `clean --orphans` reaps stale `@TestMore*` libraries.

Revisit if: downstream verification ever needs to run unattended in CI, where
a test-shaped entry point would matter again; or a measured full-run time
justifies sharding the list across several perlbrew libraries.

## 2026-08-15 — No local *copies of shared auditors*, no `TEMPLATE.pod`

**Ruling: run the shared auditors from `~/projects/Agents/agent_scripts/` by
absolute path. Do not copy them into this repository, and do not add
`TEMPLATE.pod`.**

This covers the five cross-project auditors only. Project-specific tooling —
`agent_scripts/verify-downstream` and its data files — belongs in
`agent_scripts/` as usual, excluded from the distribution.

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

`AI_AND_LLM_POLICY.md` is deliberately not treated the same way: it is
contributor-facing text worth carrying wherever the distribution goes, so
`[GatherFile]` gathers it back by name after the blanket exclusion drops it.
Replacing it with a project-specific policy would be declared in
`AGENTS_OVERRIDE.md`.

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
