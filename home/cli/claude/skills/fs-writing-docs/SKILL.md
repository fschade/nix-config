---
name: fs-writing-docs
description: Write, restructure or fix documentation - README, how-to, reference, tutorial, explanation, ADR. Use when asked to write or rework a doc, when a doc has grown into several documents at once, or when a reader got lost in one. Picks the document type first, then writes only that type.
---

# Writing docs

Most bad docs are not badly written. They are two or three documents wedged
into one: a tutorial that keeps stopping to explain internals, a reference page
that suddenly walks you through a setup, a README that argues about design.
Pick the type first, then write only that type.

The four types and the two questions below are the diátaxis framework, borrowed
with thanks from diataxis.fr (Daniele Procida). Wording here is our own.

Fixing an existing doc, not writing a new one? Its type and its place are
already set, so skip §1 and §5. Go to the shape that type needs (§2) and the
voice (§3), and touch only what is wrong. Reader-test and humanize only what you
changed.

## 1. Pick the type

Ask two things about the reader:

- do they need to **do** something, or to **understand** something?
- are they **learning** the thing, or **working** with it?

|                   | learning    | working   |
| ----------------- | ----------- | --------- |
| **doing**         | tutorial    | how-to    |
| **understanding** | explanation | reference |

If the honest answer is "both", that is two documents. Say so before writing
one word, and let the user decide whether both are wanted.

## 2. Write the shape that type needs

**Tutorial**: a lesson. One path, no choices, no alternatives. It works from
start to finish and the reader ends up with something that runs. No detours
into why, no "you could also".

**How-to**: solves one real task for someone who already knows the basics.
Starts from the goal, names its preconditions, ends when the goal is met.
Teaches nothing on the way.

**Reference**: the machinery. Flags, keys, fields, endpoints, commands.
Structured like the thing it describes, complete, and boring on purpose. No
instructions, no opinions.

**Explanation**: the why. Design decisions, trade-offs, what was rejected and
what for, how the pieces relate. No steps.

## 3. Voice

- Short sentences, active, present tense. Say it once.
- Commands and config in code blocks, with inline comments instead of a
  paragraph describing them.
- No filler openings ("In this section we will..."), no marketing words
  (robust, powerful, seamless, comprehensive), no promises about the future.
- Preconditions and versions at the top, not sprinkled through the steps.
- Second person for tutorial and how-to. Neutral for reference.
- Nothing the reader can see for themselves. A directory listing is not
  documentation.

## 4. Reader-test it

Worth a subagent for a doc someone follows start to finish: a how-to, a
tutorial, a real explanation. A one-paragraph fix or a reference tweak does not
need one, read it back yourself.

The doc is done when someone who was not in the room can use it. Dispatch a
subagent with none of this session's context, hand it only the doc and the task
it should be able to finish, then ask:

- where did you stall?
- what did you have to guess?
- what did you look for and not find?

Fix those three. Do not polish wording that nobody tripped over.

## 5. Placement

- Update the doc that already covers the topic. Don't add a second file beside
  it saying almost the same.
- A new file only when the type is new: a how-to does not belong inside a
  reference page.
- Link it from where a reader actually starts (README, index, the command's
  `--help`). Unlinked docs do not exist.
- Don't write docs nobody asked for.

## 6. Humanize what you wrote

Run the humanizer over the prose you just produced, before showing it. It is
fresh model output, so it carries the tells. Only what you wrote in this pass:
a doc the user has been keeping in their own voice is theirs, and the humanizer
rewrites more than it should when it is pointed at one.
