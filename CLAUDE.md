# Working agreement — Fleeting

## Read first
1. **[ARCHITECTURE.md](ARCHITECTURE.md)** — the file map, the dependency rule, and where new code goes.
2. **[docs/DECISIONS.md](docs/DECISIONS.md)** — ten ADRs covering every load-bearing choice. Do not
   relitigate one without saying so explicitly.
3. **[docs/ROADMAP.md](docs/ROADMAP.md)** — which phase we're in and what "done" means for it.

## What this app is
An iOS quick-capture app for thoughts that arrive at bad moments. Two ideas carry the whole product:
**capture in under two seconds**, and **everything decays** so the list can never become a graveyard.
Read the README's principles table before proposing any feature.

## Documentation is not optional
The docs are maintained continuously, without being asked:

- **README.md** — update the roadmap status table and the feature tour whenever behaviour ships.
- **ARCHITECTURE.md** — update the file map in the *same commit* that adds, moves, or removes a file.
  A stale map is worse than none.
- **docs/DECISIONS.md** — append an ADR for any choice with a real alternative. Record the alternative
  and the cost, not just the outcome.
- **docs/ROADMAP.md** — flip status markers as phases progress; move anything descoped to *Deferred*
  with a reason.

## Hard rules
- **Never block the capture field.** No modal, alert, permission prompt, onboarding, or review prompt
  may stand between a cold launch and a focused keyboard. This outranks every other consideration.
- **Respect the dependency direction.** `Core` imports nothing. Features never import each other or
  `Persistence`. If a dependency feels necessary, the design is wrong.
- **Never mutate raw captured text.** Generated titles and write-ups live in their own fields.
- **Decay never deletes.** Expiry archives; only an explicit human action destroys anything.
- **Intelligence is always optional.** Every AI call needs a defined behaviour when the model is
  missing, slow, or wrong. Implement new capabilities in all three implementations.
- **Never call `Date()` outside the composition root.** Inject `Clock`.

## Teaching is part of the job
The developer is fluent in other languages and new to Swift. **[docs/LEARNING.md](docs/LEARNING.md)
is a contract, not a note** — read the current rung before writing code, teach at that rung, and
update the progress log as concepts land. Teach Swift as a translation from languages already known;
never explain programming fundamentals.

## Git
Commit at meaningful units of work, not in one dump at the end — the history is part of what an
employer reads. Tag the commit that completes a phase (`phase-0-foundations`). Subject lines say what
changed and why it mattered. Any commit that moves, adds, or removes a file updates the file map in
`ARCHITECTURE.md` **in that same commit**.

## Style
Small files, one type each. **Javadoc-style `///` doc comments saying what an API does** — not why,
not tutorials. Rationale goes in the ADR log. Match the surrounding code. Swift 6 strict concurrency
— no `@unchecked Sendable` without a justifying comment.
