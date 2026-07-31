---
name: fs-qa
description: QA pass over a change or an area - code, comments, docs, gates, in that order. Reports and holds by default, runs through with --full, fixes the working tree with --apply, commits per area with --commit, one phase with --only, uncommitted files only with --dirty. Use when the user asks for a QA run, a full check, or wants work finished properly before committing.
argument-hint: "[path] [--dirty] [--full] [--apply] [--commit] [--only code|comments|docs|gates] | help"
disable-model-invocation: true
---

# QA pass

Four checks in a fixed order, named for what each looks at: code, comments,
docs, gates. The order holds because each rests on the one before. Code can
change code, comments describe the code, docs describe both, gates confirm the
result. Backwards means doing the work twice.

## Usage

    /fs-qa [path] [--dirty] [--full] [--apply] [--commit] [--only code|comments|docs|gates]

- **path**: every file under it, read whole, no diff. `./` is a path like any
  other and means the whole repo. With no path the current diff is the subject
  (`git status` plus the commits ahead of the upstream); for a pure diff
  `/code-review` digs deeper into code defects, so name it, then carry on. The
  two modes catch different drift: with no path the drift coming in, with
  `./ --only code` the drift that already settled.
- **`--dirty`**: only the uncommitted files (`git status`), the commits ahead
  of the upstream stay out. With a path, the uncommitted files under it.
- **`--full`**: run through without stopping. The default holds after each phase
  (reporting) or each area (applying) and waits for an ok. The hold is where the
  user redirects the next step, so it is worth keeping unless they ask.
- **`--apply`**: fix things, working tree only, nothing gets committed. The
  default writes nothing, it only reports.
- **`--commit`**: record the fixes as one commit per area, implies `--apply`.
- **`--only <phase>`**: run one phase and stop, the cheapest way to ask a single
  question of a whole repo. Combines with `--apply` or `--commit` to apply just
  that phase.
- `/fs-qa help` prints this section and stops.

## The file list

From git, never a directory walk:

    git ls-files -- <path>
    git ls-files --others --exclude-standard -- <path>

That keeps `.git`, build output and caches out, picks up files not committed
yet, and needs no exclusion list to maintain. Drop binaries and lock files on
top: an image is thousands of meaningless lines, a lock is generated. Outside a
git repo, walk the path and skip the same classes.

## The neighbourhood

Style is a relation, not a property: a line is out of line with other lines. The
diff holds one side of that, so with no path the changed files alone cannot
answer it. Each of them brings its neighbours into the reading:

    git ls-files -- <dir of the changed file>

The files beside it, and where its directory holds only the one file, the
nearest directory of the same kind. Read whole, like the subject, and never
written: they are the yardstick. That is the whole extra cost, the
neighbourhood, not the repo. With a path the files are already there and this
section is moot.

Reading a file is not owning it. Two areas may share a neighbour; what the
file-per-area split governs is who writes, and a neighbour is written by nobody.

Where a changed file has no neighbours, a new top-level directory with one file
in it, the style and duplicate-mechanism checks have no yardstick. That goes in
the report as unanswerable. Answering it from another repo, or from how the
convention "usually" goes, is the failure mode this section exists for.

## Areas

An area is one top-level subsystem: a top-level directory, or a coherent group
the repo's layout points at (a service, a package). Split the path into areas,
count files and lines, name them back to the user, and get a nod before reading.

Areas are the unit of work for code and comments: one subagent each, and the
split hands every file to exactly one area, so no file is written twice. Docs
and gates are not per area, they are global (see their sections).

## 1. Code

One subagent per area reads its files whole, plus their neighbourhood when the
subject is the diff, and returns two finding sets from that single reading: code
here, comments in §2. No file is read twice inside an area. For code it looks
for:

- correctness: wrong logic, wrong assumptions about what a command returns
- swallowed errors: ignored returns, empty catch blocks, fallbacks that hide
  the failure
- things that break quietly when a neighbouring file changes
- style drift: code that does not read like its neighbours, a comment placed
  where the file puts them above and here beside, a name against the local
  convention. the repo should read as one hand, not a stack of sessions
- duplicate mechanisms: two ways to do the same thing where one would do, four
  patterns for injecting the same env, two ways to mount a secret. a module
  that breaks the pattern its siblings follow. the loudest tell that different
  sessions built different corners
- a gitignored path (`tmp/`, `dist/`, `.direnv/`) named from tracked code

Skip what the gates already enforce, formatters and linters and secret
scanners. Say so in the prompt, or attention drains into lint.

Per finding: file, line, what goes wrong, how it was verified. A claim about
behaviour, that something never runs, silently fails, resolves elsewhere or gets
ignored, needs the command and its output: reading is unreliable exactly there,
`grep -n` proves a line exists, never that it does what the finding says. A
claim about structure, dead config or a swallowed return or a comment that lies,
rests on file, line and reasoning. When behaviour cannot be reproduced here, say
why and file it as a suspicion, not a fix.

A claim about style or a duplicate mechanism rests on the neighbours: two of
them at least, each with file and line, doing it the other way. One is
coincidence, two are a convention. Without that pair the finding is taste, and
taste goes into the summary as a probable false positive, never into the
findings and never into an edit.

The direction is fixed. The change adapts to the repo, never the repo to the
change, however much better the new pattern reads. A better pattern is a
migration: report it, leave it standing, the user decides. Under `--apply`,
editing a neighbour to match the file under review is out, in every phase.

## 2. Comments

Out of the same reading as §1: every comment in the area checked against the
code around it, accuracy and rot and restatement, all files and not only the
changed ones. Held as its own phase with its own hold. `rules/comments.md`
decides how a rewritten comment reads. (`--only comments` on its own has no code
pass to share the reading with, so it dispatches the comment-analyzer subagent
by itself.)

## 3. Docs

Global, not per area, and an audit, not a rewrite. Two questions per document:
does it still match the code, and does a section describe work that no longer
exists. Check what the change touched, plus every README or MANUAL naming a
command, path or flag that moved. A doc that needs fixing goes to the
fs-writing-docs skill, which picks the type, reader-tests and humanizes. A doc
the user keeps in their own voice is reported, not touched, unless they ask.

A convention nobody wrote down is a doc finding too, and the one that pays off
twice: every convention the code phase had to derive from the neighbours is a
line some CLAUDE.md is missing, and the next session then aligns to text instead
of doing the archaeology again. Reach decides which file, and reach is not
where the code sits: a convention of this repo goes into its CLAUDE.md, a rule
that holds in every repo into the global config, and a tree that is only hosted
here, a deployed config or a vendored dependency, gets neither. Collect them,
propose them as the lines they would be, and stop there. An unwritten convention
is a claim about intent, so it is the user's to confirm; `--apply` does not
write it, not even with `--full`.

## 4. Gates

Global. Run the repo's own gates, never an invented command; CLAUDE.md says
where to find them. Under `--commit` with a pre-commit hook, each area's commit
already runs them, so committing gates continuously; in every other mode run
them once at the end. Run a changed hook or guard script's own tests too.

## Running it

Reading source is the expensive part. Everything here pays it once.

**Reporting (default).** Read every area in parallel, one subagent each,
returning code and comment findings together. Then the global passes: docs and
gates, both cheap. Present phase by phase over what came back: all areas' code
as one picture, hold; comments, hold; docs, hold; gates. Nothing is written.
The parallel read means the code phase costs the slowest area, not their sum.

**Applying (`--apply`).** Go area by area. One subagent takes an area through
fixing its code and comments in one context, since the comments it checks are
mostly the ones it just wrote. Areas edit in parallel, disjoint files, no
collision. The fixes land in the working tree and stay there: run the gates
once over the result, report red as red, and leave committing to the user.

**Committing (`--commit`).** The same editing, plus the recording. Committing
is serial: one index, and the gates judge the whole tree, so the main thread
waits for the editors, then per area stages by name, lets the commit run the
gate, and moves on. A red gate stops the sequence: earlier areas stand as
commits, the rest sit uncommitted; the breaking area may not be the one being
committed, so name it from the failing files and wait. Never commit around a
red gate or a half-fixed area. Docs fixes and any gate-only fixes land as their
own commit after the areas. One commit per area, coherent, hashes listed at the
end.

Judgement stays with the user either way: anything you would call a probable
false positive stays untouched and goes into the summary instead.

## The report file

None, unless the user asks, and then the user names the path: the skill picks no
location and persists nothing on its own. A report written on request records
the commit it was taken at in its header.

Working from a saved report is the one cheap re-run. It was taken at some
commit, so ask git what moved since and which area each changed file belongs to:

    git diff --name-only <sha> -- <area>
    git status --porcelain -- <area>

An area that has not moved keeps its findings and starts no subagent. An area
that moved has its files re-read before anything is written, since a finding
about a changed file is a claim about a file that is gone. Say which areas fall
into which group before starting.

## Finishing

Summarise per area: what was found, applied, left, and why. Under `--commit`
one commit per area, never one for the whole pass; under `--apply` the fixes
sit in the working tree and the commits are the user's.
