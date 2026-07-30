---
name: fs-qa
description: QA pass over a change or an area - review, comments, docs, gates, in that order. Reports and holds after each phase, runs through with --full, changes and commits with --apply. Use when the user asks for a QA run, a full check, or wants work finished properly before committing.
argument-hint: "[path] [--full] [--apply] [--only review|comments|docs|gates] | help"
disable-model-invocation: true
---

# QA pass

Four phases in a fixed order. Review can change code, comments describe the
code, docs describe both, gates confirm the result. Backwards means doing the
work twice.

## Usage

    /fs-qa [path] [--full] [--apply] [--only <phase>]

- **path**: every file under it, read in full, no diff involved. `./` is a path
  like any other and means the whole repo. Without one, the current diff is
  under review: `git status` plus the commits ahead of the upstream.
- **`--full`**: run the four phases in one go. Without it the run holds after
  each phase, reports, and waits for an ok, which is also where the user can
  redirect the next one.
- **`--apply`**: change things. Per area: apply, run the gates, commit that
  area, move on. Without it nothing is written, the run only reports.
- **`--only <phase>`**: run one of `review`, `comments`, `docs`, `gates` and
  stop. The cheapest way to ask a single question of a whole repo.

The file list comes from git, never from walking the directory:

    git ls-files -- <path>
    git ls-files --others --exclude-standard -- <path>

That keeps `.git`, build output, caches and everything the repo already ignores
out of the reading pass, without a list of exclusions to maintain, and it picks
up new files that are not committed yet. Drop binaries and lock files on top: an
image counts as thousands of lines and says nothing, a lock file is generated.
Outside a git repo, walk the path but skip the same classes.

`/fs-qa help` prints this section and stops.

A path holding several areas gets split along them. Count files and lines
first, name the areas back to the user, then work them one at a time.

On a diff, tell the user to run `/code-review` themselves first. It is the
better diff reviewer and it cannot be invoked from here.

## How it runs

Each area runs in its own subagent. Reading is the expensive part, so phases
that read the same files share one: an area's reviewer also collects the
comment findings, and while applying, the fixer carries the comment pass.
The phases stay separate in what comes back and how it is held, they only stop
paying for the same files twice. Subagents return findings, this thread keeps
them and never the source. That is what lets a whole repo pass through one
session, the reading happens over there and not here.

The two modes walk the grid the other way round. A reporting run goes phase by
phase, every area at once, so a phase lands as one picture to judge. An
applying run goes area by area through all four phases, so each area ends
finished, gated and committed, and a failure in the last one leaves the earlier
work on disk rather than stranded.

That also decides what runs at the same time. Reporting only reads, so the
areas of a phase start together in one go, and the phase takes as long as its
slowest area instead of all of them added up. Applying edits in parallel too:
the split gives every file to exactly one area, so the fixing subagents never
share a path. Only committing is serial. There is one git index and the gates
judge the whole tree, so the main thread waits for the editors, then stages
each area by name and commits them in order, gates per commit. Editing costs
the slowest area, committing adds the gates.

While applying, one subagent takes an area through fixing and comments in one
context. Reading a file is the expensive part, and the comments it looks at are
largely the ones it just wrote, so a second agent would pay the whole reading
pass again to review the first one's work. Docs and gates stay outside it, they
need small files and commands rather than the sources.

It may narrow that comment pass to what it touched only when phase 2 findings
for the area already exist, from a report or an earlier phase in the same run.
Without them nothing else covers the rest of the area, and a repo taken over
from someone else is exactly the case where the untouched files carry the rot.

Findings go into `tmp/qa-report.md`, grouped by area and split into what to
fix, what to leave, and what came back clean. A report costs the whole reading
pass, so it gets paid once: when the file is already there, do not review again
by default.

The report carries the commit it was taken at. Write `git rev-parse HEAD` into
its header, and note per area whether that area was dirty at the time.

The next run is a diff. Ask git which files moved since, and which area each
belongs to:

    git diff --name-only <sha> -- <area>
    git status --porcelain -- <area>

An area that has not moved does not get read again. Its findings stand and its
subagent never starts, which is where the second run gets cheap: only what
changed is paid for twice. For an area that did move, keep the findings but have
its subagent re-read the files before anything is written, since a finding about
a changed file is a claim about a file that no longer exists. Say which areas
fall into which group before starting.

A red gate ends the commit sequence. Areas already committed stand, the edits
of the remaining ones sit uncommitted in the tree. The gates judge the whole
tree, so the area whose edits broke them may not be the one being committed:
name it, the failing files give it away, and wait. Never commit around a red
gate and never commit a half-fixed area. Everything else the user has said
about commits still holds: coherent units, and the hashes listed back at the
end.

Applying still leaves the judgement calls. Anything you would have flagged as a
probable false positive stays untouched and goes into the summary instead.

## 1. Review

Each subagent reads whole files and looks for:

- correctness: wrong logic, wrong assumptions about what a command returns
- swallowed errors: ignored returns, empty catch blocks, fallbacks that hide
  the failure
- things that break quietly when a neighbouring file changes

Skip what the repo's gates already enforce, formatters and linters and secret
scanners. Put that in the prompt, otherwise attention goes to lint.

Per finding: file, line, what goes wrong, how it was verified.

What counts as verified depends on what the finding claims. A claim about
behaviour, that something never runs, silently fails, resolves elsewhere or gets
ignored, needs the command and its output, because reading is unreliable exactly
there. A claim about structure, dead config or a swallowed return or a comment
that lies, is carried by the file and line plus the reasoning. When behaviour
cannot be reproduced here, say why and file it as a suspicion rather than a fix:
`grep -n` proves that a line exists, never that it does what the finding says.

## 2. Comments

The comment findings come out of the same reading as the review: every comment
in the area checked against the code around it, accuracy and rot and
restatement, all files and not only changed ones. Presented as its own phase
with its own hold. Only `--only comments` dispatches the comment-analyzer
subagent by itself, there is no review pass to share with then. The fixing
happens here either way. Voice and failure modes are in rules/comments.md,
that file decides how a rewritten comment reads.

## 3. Docs

Two questions per document: does it still match the code, and does a section
describe work that no longer exists. Check what the change touched, plus every
README or MANUAL naming a command, path or flag that moved.

Fresh prose goes through the humanizer. A doc the user has been keeping in
their own voice does not, unless they ask for it.

## 4. Gates

Run the project's own gates, never an invented command. CLAUDE.md says where to
look for them; every repo answers that differently. When a hook or guard script
changed, run its tests too.

## Finishing

Summarise per area: what was found, what was applied, what was left and why.
One commit per area, never one for the whole pass.
