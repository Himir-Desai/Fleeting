# Architecture Decision Records

Every significant choice, why it was made, and what it cost. Newest decisions are appended; a
superseded ADR is marked but never deleted.

**Format:** Context → Decision → Alternatives considered → Consequences.

---

## ADR-0001 · Decay plus a weekly triage ritual is the core mechanic

**Status:** Accepted · Phase 0

**Context.** The stated failure of every existing note app is that captured items live forever, so
the list becomes unreadable and eventually unopened. Fixing capture speed alone would reproduce the
same graveyard, faster.

**Decision.** Every thought carries a **freshness** value that decays on a clock and auto-archives at
zero, *and* a weekly review forces an explicit decision on a curated subset. Automatic pressure plus
a deliberate ritual.

**Alternatives.**
- *Triage ritual only* — nothing decays, the review is the whole mechanism. Rejected: it fails
  completely the first week the review is skipped, which is the week it matters.
- *Ambient resurfacing only* — periodically show an old idea, no pressure. Rejected: pleasant, but
  the pile still grows without bound; it treats the symptom.
- *Hard expiry with deletion* — strongest signal, but destroys data irrecoverably. Rejected outright;
  see the invariant "nothing is destroyed by decay."

**Consequences.** Decay is a first-class domain concept, not a UI garnish — it lives in `Core` as a
pure engine with an injected clock. Freshness must reset on *action* rather than on *viewing*, or the
mechanic silently degrades into an infinite list again. Archive must be searchable so decay never
feels like loss.

---

## ADR-0002 · Modular local Swift packages over a single app target

**Status:** Accepted · Phase 0

**Context.** The app must be structured, documented, and navigable by folder — explicitly not a
handful of enormous files. Layering enforced only by convention erodes under time pressure.

**Decision.** A thin `App` target over local SPM packages: `Core`, `Persistence`, `Intelligence`,
`DesignSystem`, `Features` (one target per feature), `Notifications`.

**Alternatives.**
- *Single target with folder groups* — simpler setup, zero enforcement. Rejected: layering that an
  `import` can violate isn't layering.
- *A separate package per feature* — maximum isolation, but six `Package.swift` files to maintain for
  an app this size. Rejected as ceremony; multiple targets in one `Features` package gives the same
  compile-time isolation.

**Consequences.** Slightly more upfront setup and a longer clean build. In exchange, `Features`
literally cannot import `Persistence`, `Core` tests run without a simulator, and every file has one
obvious home. Cross-feature communication has to be designed rather than improvised.

---

## ADR-0003 · SwiftData with CloudKit, local-first

**Status:** Accepted · Phase 0

**Context.** Data must survive device loss and ideally reach a future iPad or Mac build, without
running a server or asking the user to make an account.

**Decision.** SwiftData persistence with automatic private CloudKit sync. Sync arrives in Phase 7,
but the schema is designed for it from day one.

**Alternatives.**
- *Local-only SwiftData* — simplest, but retrofitting CloudKit later forces a migration.
- *Supabase/Firebase* — enables web access and sharing; rejected as large scope, ongoing cost, and an
  account requirement for a single-user private app.

**Consequences.** CloudKit constrains the schema: every attribute must be optional or defaulted, no
unique constraints, and relationships must be optional. The domain model in `Core` is therefore kept
separate from the `@Model` entity, with an explicit mapping layer, so storage constraints never
distort the domain. Conflict resolution needs a defined policy in Phase 7.

---

## ADR-0004 · On-device Foundation Models, behind a protocol, always optional

**Status:** Accepted · Phase 0

**Context.** The app needs classification, titling, interview questions, write-ups, and daily nudge
copy. It also captures unfiltered 1am thoughts, which is about as private as text gets.

**Decision.** Apple's on-device Foundation Models (iOS 26) as the primary implementation of a single
`IntelligenceService` protocol, with a deterministic `HeuristicIntelligence` fallback and a
`StubIntelligence` for tests. A `ResilientIntelligence` wrapper degrades automatically.

**Alternatives.**
- *Rules only* — ships fastest, but cannot do the Sharpen interview, which is the product.
- *Cloud LLM* — most capable, but costs per call, requires network, needs a key or proxy, and sends
  private thoughts off-device. Rejected as the default; retained as an explicit user-initiated
  escalation (ADR-0006).

**Consequences.** Free, offline, private, no keys. Structured output via `@Generable` guided
generation rather than JSON parsing. The app must remain fully functional with the model absent, so
every AI feature needs a defined degraded state — which also makes the whole layer testable without a
model. Requires an Apple Intelligence capable device for the full experience.

---

## ADR-0005 · One entity with type-specific behaviour, not three sub-apps

**Status:** Accepted · Phase 0

**Context.** Captures are business ideas, todos, and habits — genuinely different lifecycles. The
temptation is to build a task manager and a habit tracker inside the app.

**Decision.** A single `Thought` entity with a `kind`. Kind affects exactly two things: the decay
profile, and the one "next step" affordance (todo → due date + done; habit → streak; idea → Sharpen).
One inbox, one review, one search.

**Alternatives.**
- *Full sub-apps per type* — roughly triples the scope and lands the app squarely in the
  "too complex" category it exists to escape.
- *Ideas only, hand off todos and habits* — very focused, but forces a context switch out of the app
  for exactly the captures described in the problem statement.
- *No types at all* — loses per-kind decay tuning, which is a meaningful part of the mechanic.

**Consequences.** Type-specific UI must stay strictly minimal or this decision collapses into the
rejected option. Classification can be wrong without being harmful, since kind only tunes decay speed
and one affordance — correction stays a single tap.

---

## ADR-0006 · Sharpen is an interview, with a hidden escalation path

**Status:** Accepted · Phase 0

**Context.** "Type a half-baked idea, get a fully-baked one." The obvious implementation — one-shot
expansion — produces the *model's* idea rather than the user's, and a small on-device model
hallucinates the specifics it wasn't given.

**Decision.** Three tiers.
1. **Primary:** the model asks 2–3 short, specific questions; the user answers in a line each; the
   model writes up a structured result grounded in those answers.
2. **Ambient:** stale idea cards in the weekly review carry one provocative question, so sharpening
   also happens as a side effect of the ritual.
3. **Escalation (deliberately understated):** for ideas that outgrow on-device capability, the local
   model composes a rich, context-loaded prompt handed to a full assistant via the share sheet.

**Alternatives.**
- *One-shot expand* — rejected: fast and useless; it invents details.
- *Open chat thread per idea* — rejected as the default: an open-ended text box with no end state is
  the complexity trap, and small on-device models are weak over long multi-turn threads. Its value is
  preserved by tier 3 without the complexity.

**Consequences.** Sharpen is a multi-step stateful flow, so partial progress must persist. The
escalation affordance must stay visually quiet — if it becomes prominent, the app is admitting its
own feature doesn't work. Generated content is stored separately from raw captured text.

---

## ADR-0007 · Curated review, hard-capped at seven

**Status:** Accepted · Phase 0

**Context.** A review that surfaces the entire stale backlog is a review that gets skipped, and a
skipped review breaks the mechanic in ADR-0001.

**Decision.** `ReviewSelector` picks at most seven thoughts that genuinely need a decision —
prioritising imminent expiry and repeated snoozes — and deals them one card at a time.

**Alternatives.**
- *Everything stale, uncapped* — honest about the backlog, but a 40-card session is an abandoned one.
- *Curated plus a weekly AI synthesis* — attractive, deferred rather than rejected; revisit after
  Phase 5 once the base ritual proves itself.

**Consequences.** Selection is a pure, heavily tested function in `Core`. Uncapped backlog still needs
somewhere to go — decay handles it, which is why ADR-0001 and ADR-0007 only work together.

---

## ADR-0008 · Nothing may block the capture field

**Status:** Accepted · Phase 0

**Context.** Stated directly as a requirement: anything the app demands on launch delays the exact
thought the user opened it to record. This is the highest-priority constraint in the project.

**Decision.** A cold launch renders the capture field, focused, with the keyboard up, and nothing
else. No onboarding gate, no permission prompt, no review prompt, no "what's new", no alert. The
weekly review is reachable but never imposed. Permissions are requested from Settings, or from a
notification the user already tapped — never at launch.

**Alternatives.** Standard onboarding and launch-time permission priming, i.e. what every other app
does. Rejected on principle 1.

**Consequences.** Notification permission must be requested lazily, costing some opt-in rate. Any
first-run explanation has to be discoverable rather than modal. This is enforced by a UI test that
fails if any modal is presented before the field is focused, and it constrains every future feature.

---

## ADR-0009 · Daily nudge, weekly review, expiry warning — and nothing else

**Status:** Accepted · Phase 0

**Context.** Decay only works if forgotten thoughts resurface somewhere. But a note app that
notifies aggressively gets deleted.

**Decision.** Three notification types, all outside the app: a **daily** nudge whose copy the
on-device model composes from one genuinely forgotten thought; a **weekly** review invitation; and an
**expiry warning** before something archives. Plus passive widgets. No badges, no in-app prompts.

**Alternatives.**
- *Weekly only* — quietest, but things could archive without ever being seen again.
- *Silent, widget only* — zero-friction, but relies entirely on the user remembering, which is the
  behaviour the app is compensating for.

**Consequences.** Nudge copy must be generated ahead of time in a background task, since the model
can't run at delivery. Requires background task scheduling and a fallback copy string when the model
is unavailable. Notification content must be phrased to restart a thought, not to induce guilt.

---

## ADR-0010 · Named "Fleeting"

**Status:** Accepted · Phase 0

**Decision.** The app and repository are named **Fleeting**, after the thesis: thoughts are fleeting,
and the app treats them that way rather than pretending otherwise.

**Consequences.** Repository and directory renamed from `Memos`. Bundle identifier
`com.himirdesai.Fleeting`; module names take the `Fleeting` prefix where a prefix is needed.

---

## ADR-0011 · The build doubles as a Swift curriculum, without contaminating the code

**Status:** Accepted · Phase 0

**Context.** The developer is fluent in other languages but new to Swift and iOS, and wants to learn
the language *through* building this app rather than receive finished code. The same repository is
also a portfolio artefact an employer will read.

**Decision.** Teaching is delivered through chat and a dedicated [LEARNING.md](LEARNING.md) — a
four-rung ladder that hands over progressively more of the thinking, plus a per-phase concept map and
a progress log. Production files carry **Javadoc-style doc comments describing what an API does** and
nothing more.

**Alternatives.**
- *Inline teaching comments in the real files* — makes browsing the codebase the lesson, but turns
  the repo into a visibly annotated tutorial project and would need stripping before it's shown to
  anyone.
- *A parallel annotated copy of each file* — clean production code plus a full commentary track, but
  it's genuine duplication that drifts out of sync the first time a file changes.

**Consequences.** Development is slower by design: phases include comprehension checkpoints, and from
rung 2 onward code is written only after a design question is answered. Design rationale must be
disciplined about going to the ADR log rather than into comments, which is where it belongs anyway.
The phase order in the roadmap now serves double duty as a teaching sequence — and needs to keep
doing so if phases are reordered.

---

## ADR-0012 · DesignSystem stays domain-free; domain-shaped views live in features

**Status:** Accepted · Phase 1

**Context.** ARCHITECTURE.md originally listed `ThoughtRow` among the shared components in
`DesignSystem`. Building the inbox exposed the contradiction: `DesignSystem` declares no
dependencies, so it cannot name a `Thought`.

**Decision.** `DesignSystem` holds only domain-agnostic material — colour, type, spacing, motion,
and components parameterised by primitives. Any view that takes a domain type lives in the feature
that renders it. `ThoughtRow` therefore lives in `InboxFeature`.

**Alternatives.**
- *Let `DesignSystem` depend on `Core`* — allows a shared `ThoughtRow`, and is what the original
  file map implied. Rejected: the design layer would then have opinions about the domain, and every
  domain change would ripple into styling. The one genuinely shared piece, the freshness treatment,
  can be expressed as a function of a `Double` rather than of a `Thought`.
- *A third package between them* — a real option if several features later need the same row, but
  premature with one consumer.

**Consequences.** A row rendered by two features in future must either be duplicated or promoted
deliberately. That is the intended pressure: duplication is visible, whereas a creeping dependency
from design to domain is not. Phase 2's freshness indicator must be written to take a number, not
a thought.

---

## ADR-0013 · Linear decay with a grace period, and snooze stops the clock

**Status:** Accepted · Phase 2

**Context.** ARCHITECTURE.md originally described the decay profile as a per-kind *half-life*, which
implies exponential decay. Implementing it exposed two problems.

**Decision.** Freshness falls **linearly** from 1 to 0 over a fixed lifetime, after a grace period
at full freshness. The standard policy is two days of grace then a slide to expiry at thirty days.
A snoozed thought is held at full freshness until its snooze ends, so decay is measured from
`max(lastActedAt, snoozedUntil)`.

**Alternatives.**
- *Exponential half-life* — the original plan, and the more natural model of forgetting. Rejected on
  two grounds: it never actually reaches zero, so archiving needs an arbitrary cutoff anyway; and it
  cannot answer "when does this archive?" with a date. "Archives tomorrow" is the single most useful
  thing the row can say, and linear decay makes it exactly true.
- *No grace period* — simpler, but every capture would begin visibly dying the instant it was
  written, which reads as punishment rather than as a signal.
- *Snooze merely hides the thought* — much simpler, but a thought snoozed for a week would return
  a week closer to death, so snoozing would quietly cost you time instead of buying it.

**Consequences.** `FreshnessPolicy` carries `grace` and `lifetime` rather than a half-life, and
`expiryDate(of:)` is exact rather than an estimate. Per-kind rates in Phase 3 become two numbers per
kind instead of one. A degenerate policy where grace equals lifetime is clamped to a hard cliff at
expiry rather than dividing by zero.

---

## ADR-0014 · Classification runs after the save and announces itself

**Status:** Accepted · Phase 3

**Context.** Sorting a thought needs a model call that can take seconds on device. The capture path
must never wait for it, but the result still has to reach a list that may already be on screen.

**Decision.** `save()` stores the thought and returns. Classification runs in an unstructured task
afterwards, writes the result back, and calls `ThoughtChangeNotifier.notify()`. Screens listen to
`ThoughtChangeObserving.changes` and reload. A thought that is never classified stays `unsorted`,
which is a valid state with its own decay profile rather than an error.

**Alternatives.**
- *Classify before storing* — the result would be complete on first render. Rejected outright: it
  puts a model call between the user and their next thought, which ADR-0008 forbids.
- *Reload the list only when it appears* — no new machinery, and what shipped first. Rejected after
  testing on device: the on-device model took several seconds, so capturing and then immediately
  opening the inbox showed "Unsorted" and left it there until the screen was closed and reopened.
  That is precisely the common flow.
- *Poll the store on a timer* — simpler than a notifier, but it burns work forever to catch an
  event that happens seconds after a capture.

**Consequences.** `ThoughtChangeNotifier` is `@unchecked Sendable` with an `NSLock`, because
`changes` must be reachable synchronously from a SwiftUI view body and an actor cannot be. The
inbox also gained pull-to-refresh, so there is a manual path when a notification is missed. UI tests
must not assert *which* kind the model picks — only that something classified it — since the model's
judgement is not the app's promise; the rules themselves are pinned in `HeuristicIntelligenceTests`.

---

## ADR-0015 · A write-up is grounded in answers, and escalation is a share sheet

**Status:** Accepted · Phase 4

**Context.** Sharpen exists because a one-shot expansion invents the specifics the user did not
give (ADR-0006). Holding to that in the implementation forced three choices.

**Decision.**

1. **Answers are the source of truth.** Every model instruction forbids inventing a market, a
   number, a name, or a feature the note and answers do not contain. The heuristic implementation
   assembles the write-up literally from the user's own words, and is the floor the model must beat.
2. **Changing an answer discards the write-up.** A revised answer clears `Sharpening.writeUp`, so a
   result can never claim to be grounded in something the user has since changed.
3. **Escalation is a share sheet carrying a composed prompt,** not a deep link into another app.

**Alternatives.**
- *Keep the write-up when an answer changes, and regenerate on demand* — fewer regenerations, but
  the screen would display a summary contradicting the answers directly above it.
- *Deep-link into Claude or ChatGPT by URL scheme* — one tap rather than two. Rejected: it requires
  guessing which assistants are installed, breaks silently when a scheme changes, hard-codes a
  preference for particular products into a private note-taking app, and the share sheet already
  reaches every one of them plus Notes, Mail, and the clipboard.
- *Have the model compose the escalation prompt* — richer framing. Kept as an override, but the
  default is deterministic assembly so escalation works with no model at all, which is the whole
  point of ADR-0004.

**Consequences.** The interview persists on the thought after every answer, so an interrupted
sharpening resumes rather than restarting — proven by a UI test that leaves the screen and returns.
Storage holds it as JSON through a `StoredSharpening` DTO rather than making the domain `Codable`,
keeping storage shape and domain shape free to diverge. Unreadable interview data degrades to no
interview, never to a lost thought.

---

## ADR-0016 · The write-up is a titled paragraph, and sharpening is reversible

**Status:** Accepted · Phase 4 · Amends [ADR-0006](#adr-0006--sharpen-is-an-interview-with-a-hidden-escalation-path)

**Context.** ADR-0006 specified a four-field write-up: pitch, who it's for, first concrete step,
biggest risk. Built and used, it read like a form rather than like the idea. Four labelled
fragments are easy to generate and harder to think with, and the labels imposed a shape on ideas
that do not all have an audience or a risk worth naming.

**Decision.** The write-up is a **short title and one detailed paragraph** that develops the idea.
The interview is unchanged — the questions still supply the substance — but their answers are
expanded into continuous prose instead of being filed into slots. Sharpening is also **reversible**:
a confirmed *Revert* removes the title, the paragraph and the answers, leaving the note exactly as
captured.

**Alternatives.**
- *Keep the four fields* — more scannable, and each field is trivially traceable to one answer.
  Rejected: it produced a summary you read past rather than an idea you could act on, and it forced
  every idea into the same shape.
- *Paragraph with no title* — simpler still. Rejected: a title is what makes a developed idea
  findable later, and it is the natural thing to show in a list.
- *Make revert undo only the write-up, keeping the answers* — cheaper to re-run. Rejected: the
  answers are part of what was generated *from*, so leaving them behind means a "reverted" note
  still carries invisible state. Revert means back to the note as written, or it means nothing.

**Consequences.** The grounding rule from ADR-0015 is now harder to enforce mechanically: prose has
no per-field mapping, so the heuristic implementation builds its paragraph by framing each answer
with the question that produced it, and a test pins the exact sentence. Revert is destructive and
therefore confirmed, consistent with deletion elsewhere in the app. `StoredWriteUp` changed shape;
existing stored write-ups fail to decode and degrade to no sharpening, which is acceptable
pre-release and is exactly what the corrupt-data path was built for.

---

## ADR-0017 · How a thought earns a place in the review

**Status:** Accepted · Phase 5 · Builds on [ADR-0007](#adr-0007--curated-review-hard-capped-at-seven)

**Context.** ADR-0007 settled that the review is curated and capped at seven. It did not say what
makes a thought worth raising, and the cap alone is not a rule: seven arbitrary thoughts is still a
chore.

**Decision.** A thought earns a place by being **past halfway through its life**, or by having been
**snoozed twice or more** regardless of freshness. Thoughts inside a running snooze are never
raised. Urgency is decay plus a capped bonus for repeated deferral, so a much-deferred thought
cannot crowd out things about to be lost. An empty session says so rather than inventing work.

**Alternatives.**
- *Everything past its grace period* — simpler, but on the standard profile that is nearly the whole
  inbox within a fortnight, and the cap would then be picking seven at random.
- *Only imminent expiry* — sharp and easy to explain, but it misses the thought you have snoozed
  four times, which is the clearest signal in the app that a decision is being avoided.
- *Uncapped deferral bonus* — makes repeated snoozing dominate. Rejected: something archiving
  tomorrow is genuinely more urgent than something you have merely postponed.

**Consequences.** A new user with only fresh thoughts gets an empty review, which is correct and has
to be said plainly rather than looking broken. Because snoozing holds freshness (ADR-0013), a thought
that has just woken is genuinely fresh and is not re-raised — a test pins this, since it reads like
a bug until you see why.

The ambient question on idea cards is stored as the **start of a real interview** rather than as a
one-off answer, so work done in the review carries into Sharpen instead of being thrown away. That
made a latent bug visible: a one-question interview leaves every question answered with no write-up,
and `SharpenModel` used to render an empty screen in that state. It now generates.

---

## ADR-0018 · Nudges are written ahead of time and queued one at a time

**Status:** Accepted · Phase 6

**Context.** ADR-0009 fixed *what* the app may say. Building it exposed a constraint that shapes
*how*: the on-device model cannot run when a notification fires, so copy has to exist before the
delivery is queued.

**Decision.** Each nudge is composed in advance and queued as a **single delivery at a computed
date**, not as a repeating trigger. The queue is rebuilt on launch and whenever the store changes.
Only one expiry warning is ever queued, for the thought closest to archiving. The store moved to the
App Group `group.com.himirdesai.Fleeting` so widgets read the same data through the same repository.

**Alternatives.**
- *Repeating daily and weekly triggers* — survives the app never being opened, and is less code.
  Rejected: the copy would be frozen at whatever was true the day it was scheduled, so a thought
  already archived could still be resurfaced weeks later. Stale copy is worse than a missed nudge.
- *Generic copy that never goes stale* ("You have thoughts waiting") — works with repeating
  triggers. Rejected: a nudge that does not name the thought is a badge with extra steps, and ADR-0009
  requires the daily nudge to resurface something specific.
- *One expiry warning per expiring thought* — more complete. Rejected: several warnings in a row is
  the nagging the app exists to avoid.
- *A second copy of the database for widgets* — avoids the entitlement. Rejected outright; two
  sources of truth for the same thoughts is how data gets lost.

**Consequences.** The queue only stays current while the app is opened from time to time, which is
honest for an app you already open to capture. `NudgeScheduler` cancels and re-queues wholesale, so
anything no longer wanted actively goes away. Its identifiers are namespaced, and a test asserts the
app only ever cancels its own.

The App Group entitlement is stripped by `CODE_SIGNING_ALLOWED=NO`, which is how the test suite and
CI build. `ModelContainerFactory` therefore falls back to the app's private container, and the app
keeps working while widgets see nothing. That degradation is deliberate but must not be silent, so
Settings reports whether the store is shared.

---

## ADR-0019 · Sync is per-column last-writer-wins, so the columns had to change

**Status:** Accepted · Phase 7

**Context.** ADR-0003 chose SwiftData with CloudKit and kept the schema CloudKit-safe from the
start. Turning sync on exposed what "CloudKit-safe" had not covered: CloudKit merges a record
**column by column**. Two devices editing the same thought do not produce one device's version —
they produce a row assembled from both.

Version 1 spread a single idea across two columns. `stateRaw` said *snoozed* and `stateDate` said
*until when*; `streakCount` said *six days* and `streakLastMarkedAt` said *when*. A merge that takes
`stateRaw` from one phone and `stateDate` from the other yields a thought snoozed until the moment
the other device archived it — a state neither device was ever in. A test in `CloudMergeTests` pins
that this really happens.

**Decision.** Values that only mean something together live in **one column**.

- `stateCode` carries the lifecycle position and its date: `snoozed|753000000.0`.
- `streakCode` carries the run length and when it was last marked.
- Content columns — `body`, `title`, `dueAt` — stay separate and stay last-writer-wins, which is
  correct for them: one device's text wins whole, never a blend.
- `isLive` is derived from `stateCode` on every write, so scopes are still filtered by the store.

Version 2 **keeps version 1's columns and keeps writing them**, though it never reads them. That is
what makes the rollback real: install a build from before the migration and it reads current data.
A later version can drop them once no old build is in use.

The migration is a custom stage rather than a lightweight one. A lightweight migration would leave
every `stateCode` at its default, returning the entire archive to the inbox.

**Alternatives.**
- *Lightweight migration, accept the loss* — rejected; it silently un-archives everything.
- *A merge function called on conflict* — SwiftData exposes no such hook, and
  `NSPersistentCloudKitContainer` has already merged by the time anything is observable. A merge
  policy that cannot run is a comment, not a design.
- *Conflict-free counters for `snoozeCount`* — rejected as disproportionate. Two simultaneous
  snoozes count as one; the number only nudges a thought up the review order.
- *Keep the columns split and repair on read* — rejected; a repair cannot tell a torn pair from a
  real one.

**Consequences.** One tear survives by design: `isLive` is derived, so a merge can pair it with the
other device's `stateCode` and show an archived thought in the inbox until the next write. That is
recoverable and never changes what the thought *is* — `CloudMergeTests` asserts both halves.

**iCloud is attached only when the App Group container is reachable.** This is a safety guard, not
an optimisation. `ModelContainer` does not throw when the CloudKit entitlement is missing: it opens,
and the process is then **trapped** from inside CloudKit. `CKContainer` traps for the same reason,
so the question cannot be asked at runtime either — an unentitled process is killed rather than
told. The App Group is written by the same entitlements file and requires the same paid membership,
so a build that has one has the other. A build that had entitlements stripped — CI, and any unsigned
build — has neither, opens a device-local store, and works.

**What is not verified.** Two devices converging has not been observed. It needs two signed installs
under one iCloud account, and this machine has no signing identity, so no build here can carry the
entitlement at all. Everything that does not require it is covered: the migration runs against a
store written by the shipped version 1 schema, and the merge rules are tested as pure functions.
The convergence claim stays open until it has been seen.

---

## ADR-0020 · The contrast audit is a test, and it moved the fade

**Status:** Accepted · Phase 8

**Context.** The palette was tuned by eye against a dark background, and the app forced
`preferredColorScheme(.dark)` so nobody ever saw it any other way. Phase 8 asks for a contrast
audit. An audit done by looking at screenshots is an opinion; it does not survive the next colour
change, and it cannot check the appearance nobody has looked at yet.

**Decision.** Every palette entry is defined as sRGB components first and turned into a `Color`
second, so the contrast between any two of them can be computed. `PaletteContrastTests` checks
every pairing the app actually draws, in all four appearances — light and dark, each at standard
and increased contrast — against the WCAG AA ratio. A colour change that breaks readability fails
the build rather than shipping.

Three things came out of running it:

- **The fade was unreadable.** Ink at the old floor of 0.38 opacity, composited over the page, is
  3.3:1 in dark and worse in light. AA asks for 4.5:1. The floor is now 0.60, which is the number
  the *light* appearance needs — a single floor rather than one per appearance, because two floors
  is a rule nobody would remember. Under increased contrast the text is not faded at all; the
  meter and the "archives in" label carry the signal on their own.
- **One accent could not do both jobs.** The same purple cannot be a fill with white text on it
  and a text colour on the page: making it dark enough for one makes it fail the other. It is now
  `accent` (fills) and `accentText` (text and tints), each audited in its own role.
- **`preferredColorScheme(.dark)` is gone.** Overriding the appearance the user chose is a
  legibility problem for anyone who needs a light screen, and the palette is now defined for both.

Animation follows the same rule. `Motion` tokens existed since Phase 0 and were applied nowhere,
so there was nothing to honour Reduce Motion *with*. There is now a single `View.motion(_:value:)`
that drops the animation when the system asks, and it is the only way animation is applied.

**Alternatives.**
- *Asset catalog colour sets* — the usual way to do adaptive colour. Rejected: the values live in
  a binary plist the tests cannot read, so the audit would have to be done by eye again.
- *Deriving increased-contrast variants by adjusting lightness* — less to write. Rejected: the
  test would then be checking a formula rather than the colours that ship.
- *Keeping the app dark-only and calling it a design choice* — defensible for a 1am capture app.
  Rejected because the reason it was dark-only was that light mode had never been done, and
  writing that up as intent afterwards would be a lie.

**Consequences.** The fade is weaker than it was. Going from 1.0 down to 0.60 is a smaller
gesture than going down to 0.38, and that is a real loss to the app's signature. It is the right
trade: a signal that makes the words unreadable has stopped being a signal. The meter, the colour
shift towards amber, and the "archives tomorrow" label all still carry it, and VoiceOver now reads
the band in words rather than a percentage.

---

## ADR-0021 · The first-run explanation is a line of text, not a screen

**Status:** Accepted · Phase 8

**Context.** Decay is not what a note app usually does. A user who captures a thought and finds it
gone a month later, with no idea why, will conclude the app lost it. Something has to explain
that. ADR-0008 forbids anything standing between a cold launch and a focused field, which rules
out every conventional answer.

**Decision.** One line of text under the capture field, on first launch only: *"Thoughts fade as
they age and file themselves away. Nothing is ever deleted."* It is inline, so the field is still
focused and the keyboard is still up. It has a *Got it* control, and it also retires itself the
moment the first thought is captured — having captured something is proof the explanation was not
needed. It never returns.

**Alternatives.**
- *A carousel or a welcome screen* — the industry default, and the one thing ADR-0008 exists to
  prevent. Rejected outright.
- *A sheet on second launch* — technically not blocking the first capture. Rejected: it is still a
  screen between a user and a field, just delayed, and the second launch is as likely to be the
  1am one as the first.
- *No explanation, let the archive teach it* — tempting, and the archive genuinely does hold
  everything. Rejected: the user has to already trust the app to go looking, and the moment they
  need the explanation is the moment they think it lost their thought.
- *A permanent "how this works" item in Settings* — kept as well, in effect: Settings has always
  shown the decay rates in force. The hint is what makes anyone go and look.

**Consequences.** The explanation is short enough to be read at a glance and easy to miss
entirely, which is the accepted cost of not interrupting. It is dismissed by tapping, by capturing,
or by ignoring, and `--reset-store` clears it so the UI tests see a genuine first launch.

---

## ADR-0022 · Paper and ink, a card list, and elevation that changes shape by appearance

**Status:** Accepted · Design pass

**Context.** Eight phases produced an app that was correct, accessible and completely anonymous.
`DesignSystem` held four type styles, six spacing steps, seven colours and one component, which is
not a vocabulary — it is a list of literals with names. Features paid for the gap: `SettingsView`
hand-built the same headline-and-detail stack five times, three files hardcoded
`Palette.ink.opacity(0.12)` as a separator, and every screen wrote its own empty state. The rows
were also undecided, drawn with a raised fill *and* separators *and* disclosure chevrons — the
visual language of a plain list and of a card list at once.

**Decision.** Three things, together.

*The palette is warm on both sides.* Light is paper and dark is ink; neither is neutral grey. The
page, the recess a user types into, and the card a thought sits on are three distinct surfaces
(`surface`, `surfaceSunken`, `raised`), so a field the user writes in reads as below the page and a
thought the app filed reads as on it.

*The list is cards, not stripes.* Separators are gone, `CardSurface` is the row background, and the
row's content is inset within it. This settles the ambiguity in favour of cards and gives the
freshness rail somewhere to live.

*Elevation is a level, not a shadow.* A drop shadow on a near-black page is invisible, so the same
`Elevation` value is drawn as a shadow in the light appearance and as a hairline in the dark one,
and always as a hairline under increased contrast. `View.elevated(_:cornerRadius:)` is the only
place that decision is made.

The type scale grew from four styles to eight, with one deliberate break: `display` is a serif and
nothing else is. It appears only where the app speaks rather than labels — an empty state, the end
of a review — so the voice is distinctive without the interface becoming a magazine.

**Alternatives.**
- *A neutral grey palette* — safer, and what the app already had. Rejected: it is what every
  SwiftUI app looks like when nobody chose, and this app's whole subject is paper that yellows.
- *Per-kind accent colours* — genuinely useful for scanning a mixed list, and the obvious next
  move once a chip exists to tint. Rejected on two grounds: `DesignSystem` may not know what a kind
  is ([ADR-0012](DECISIONS.md)), so the hues would have to be named neutrally and mapped in the
  feature; and with only three real kinds it buys a rainbow in an app whose one accent is already
  spoken for by freshness. Kinds are distinguished by symbol.
- *A serif everywhere* — distinctive, and wrong: labels and controls set in a serif read as a
  document rather than an interface, and the capture field has to be the most ordinary text box
  on the phone.
- *Shadows in both appearances, tuned darker for dark mode* — rejected because there is nothing
  darker than the page to cast onto. A hairline is the honest equivalent.

**Consequences.** Warming the light surface cost contrast: the fade floor, which had been set at
exactly the AA boundary in [ADR-0020](DECISIONS.md), fell to 4.496:1 against warm paper and the
audit failed the build. The light ink darkened to compensate rather than the floor moving, because
the floor is a design value and the ink is not. Nine new pairings joined the audit, including two
that were not previously testable: the tinted chip is now audited as a background in its own right,
and the meter's middle stop is derived from two audited colours rather than picked, so the whole
slope is covered instead of only its ends.

---

## ADR-0023 · Freshness is drawn twice, in two axes

**Status:** Accepted · Design pass

**Context.** Decay is the mechanic the app exists for, and it was the quietest thing on the screen:
a 3pt meter 56pt wide, plus an opacity fade with a floor at 0.60 that is by design subtle. A user
scrolling the inbox could not tell at a glance which thoughts were nearly gone — which is precisely
the question the list is meant to answer.

**Decision.** The same number is drawn twice, in two axes, saying two different things.

*Horizontally, the meter says how much is left.* `FreshnessMeter` is thicker, wider, and has a
visible spent track behind the fill, so it reads as a proportion rather than a mark. Its tint has
three stops instead of two — accent while healthy, a derived warming colour through the middle, the
warning colour at the end — so it reads as a slope a thought is sliding down rather than a light
that switches from fine to nearly gone.

*Vertically, the rail says which row to look at.* A 3pt capsule down the leading edge of each card,
tinted by the same three stops but not scaled by the value, drawn at full strength only once a
thought is expiring. A column of rails is scannable in a way a column of meters is not, because the
eye compares colour down an edge faster than it compares length across a gap.

**Alternatives.**
- *Make the meter full-width* — the simplest way to make the proportion louder. Rejected: it turns
  every row into a progress bar and competes with the thought's own text for the row's width.
- *Scale the rail's height by freshness too* — a third reading of the same number, and the one
  that first suggested itself. Rejected: two readings of one value is emphasis, three is
  decoration, and a rail whose height varies makes the card look broken rather than the thought
  look old.
- *Tint the whole card* — legible, and far too loud for a screen whose point is calm. It would also
  fight the fade, which is already tinting the content.

**Consequences.** The fade, the meter and the rail now all carry the same signal, which means the
opacity floor is no longer load-bearing on its own — under increased contrast, where the fade stops
entirely ([ADR-0020](DECISIONS.md)), two of the three still speak. The rail lives on `CardSurface`
as a plain `Color`, so `DesignSystem` still knows nothing about a `Thought`
([ADR-0012](DECISIONS.md)); the feature decides what colour to hand it.

---

## ADR-0024 · A capture can override its own lifetime, and that override wins over the kind

**Status:** Accepted · New-thought redesign

**Context.** Decay rate was a pure function of a thought's kind (ADR-0005): a todo dies in a
fortnight, an idea lasts months. The redesigned capture screen lets a person set an explicit
"expires in N days/weeks/months" at the moment of writing, which the kind-only model had no place
to store or honour.

**Decision.** A thought carries an optional `customLifetime` in seconds, set once at capture and
never touched by classification. When present, `DecayEngine.policy(for:)` returns
`FreshnessPolicy(grace: 0, lifetime: customLifetime)` instead of the kind's profile: the whole
chosen span is the decay ramp with no grace, so "expires in two weeks" reaches zero at exactly two
weeks. When absent, decay is unchanged — the kind's profile still governs, which is what every
existing thought and every quick capture uses.

The choice is gated behind a "Custom expiry" toggle in advanced options, off by default, so a
normal capture keeps per-kind decay and only a deliberate act opts into a fixed lifetime.

**Alternatives.**
- *Couple expiry to the type icons* — reuse the type choice to imply a lifetime. Rejected: type and
  lifetime are different questions ("what is this" vs "how long do I want it"), and folding them
  forces a type choice on someone who only wanted to set a duration.
- *A grace period proportional to the custom lifetime* — softer, matching how kind profiles hold new
  captures at full freshness first. Rejected for now: grace 0 makes the label exact and predictable,
  which is the point of letting someone set the number themselves. Revisit if fresh custom-expiry
  thoughts read as already-fading.
- *Store an absolute `expiresAt` date instead of a duration* — rejected: decay is measured from
  `lastActedAt`, which moves when a thought is acted on, so a duration composes with that reference
  while a fixed date would not.

**Consequences.** The store gained a column, so the schema moved to version 3. The new attribute is
optional with a default, making the migration lightweight rather than custom, and version 1's and
version 2's columns are still written so the rollback story of ADR-0019 holds. The wheels are a
capture-time preference that is now fully persisted and honoured by decay; a future "edit expiry on
an existing thought" would reuse the same field.

---

## ADR-0025 · Freshness reads as weight, not a meter

**Status:** Accepted · Thoughts redesign

**Context.** The inbox row drew freshness three ways at once: an opacity fade, a thin meter, and a
tinted rail down the card's edge. It read as a dashboard, which fought the app's calm. The redesign
asked for a simpler list where freshness is felt rather than measured.

**Decision.** A row's freshness is expressed as the **weight of its own words** — semibold while
fresh, stepping down to regular as it fades — plus a gentle opacity fade applied to the whole row
(glyph, text and inline action together). The meter and the rail are gone. `FreshnessStyle` gains a
`weight(for:)` that maps a `Double` to a `Font.Weight`, staying domain-free (ADR-0012).

**Alternatives.**
- *Keep the meter* — precise, but it is exactly the "measured, not felt" reading the redesign moved
  away from, and a column of meters competes with the words for the row's width.
- *Vary row height / spacing by freshness too* — "fresh breathes, faded compresses." Rejected: a
  list whose row heights shift as things decay reads as janky rather than calm; weight and opacity
  carry the signal without moving the layout.
- *Weight alone, no opacity* — rejected: two channels separate the bands more clearly, and the
  opacity is what lets the kind glyph and the inline button fade with the words instead of staying
  bright over a spent thought.

**Consequences.** Weight is never taken below regular and the opacity keeps its audited floor, so a
faded thought stays legible; VoiceOver still speaks the band word, because weight is not perceivable
to everyone. Under increased contrast the opacity fade is suppressed, as the fade always was
(ADR-0020).

---

## ADR-0026 · One filtered stream with a masthead, and no top bar

**Status:** Accepted · Thoughts redesign

**Context.** The Thoughts page was a flat reverse-chronological list with a toolbar carrying
back-to-capture, archive and settings buttons. Once capture and settings became tabs, those buttons
were redundant, and the flat list gave no sense of the shape of the pile or a way to narrow it.

**Decision.** The page is a **single stream** with a row of **filter chips**
(`All · Ideas · To-dos · Habits · Archived`) and a one-line **masthead** ("5 thoughts · 2 fading",
with "N to decide" opening the review). The chips filter in place; Unsorted folds into All. The
trailing **Archived chip is a real filter too**: it swaps the list to archived thoughts, drawn as
restore/delete rows, and archived thoughts never appear under All or any kind. The top toolbar is
gone.

**Alternatives.**
- *Kind sections instead of chips* — grouping the list by kind. Rejected: it splits the one calm
  stream into four and makes "what's fading across everything" harder to see; a filter keeps the
  stream whole and is a lighter touch.
- *An Unsorted chip* — rejected: an unsorted thought is a transient pre-classification state, not a
  category a person curates, so it lives under All rather than earning a chip.
- *Archived as a separate page* — reuse the existing `ArchiveView` behind the chip. Rejected on
  reflection: making Archived the one chip that navigates rather than filters was an inconsistency,
  and inlining it is barely more code — the model already loads the archive, and a small
  `ArchivedListRow` carries the restore/delete a live row does not. `ArchiveFeature` was deleted
  rather than left linked and dead, its coverage ported onto the filter first (ADR-0028).
- *Search across the archive* — `ArchiveView` had a search field the inline filter drops. Deferred:
  the filtered list is enough for now, and search can return as a field above the archived rows.

**Consequences.** Every chip now filters in place, so the page never leaves itself. The model loads
both the live list and the archive on each `load()`, so switching to the Archived filter is instant;
the extra query is cheap at this scale. The masthead becomes the single home for the review entry,
which used to be a row inside the list.

---

## ADR-0027 · The opened thought is the action hub, and it absorbs Sharpen

**Status:** Accepted · Thoughts redesign

**Context.** Actions were scattered across the row: a kind-correction menu, and swipe actions for
done, keep, sharpen, snooze, archive and delete. The redesign asked for a simple list where the row
carries only what is needed at a glance, and opening a thought offers everything else.

**Decision.** Tapping a row **pushes a detail screen** that is the hub: edit the raw text, change
the type, set a custom expiry, keep it (mark a to-do done / continue a habit's streak), snooze,
archive or delete — every action a round chip, consistent with capture. The row keeps only a single
inline button (done / continue streak, for to-dos and habits) and two swipes (delete, archive), plus
snooze on the leading swipe. **Enhance** (Sharpen) moves into the detail; because a feature may not
import another feature (ADR-0012), the detail exposes an `onEnhance` callback that the app layer
routes on to the Sharpen screen.

**Alternatives.**
- *Keep editing behaviour on the row (menus, many swipes)* — rejected: it is the busyness the
  redesign set out to remove, and swipe actions are undiscoverable.
- *Embed the Sharpen flow inside the detail* — rejected twice over: `SharpenView` is a full screen
  with its own scroll, and `InboxFeature` cannot import `SharpenFeature`. Routing Enhance out to the
  existing Sharpen screen reuses all of that work and respects the dependency rule.
- *A sheet rather than a push* — rejected: the detail is a place you go to work on a thought, and a
  push with a back button matches that better than a modal.

**Consequences.** `ThoughtEditor` (text-only) is replaced by `ThoughtDetailView` + a
`ThoughtDetailModel` that writes to the repository and announces changes, so the list behind it
refreshes through the same change signal the inbox already watches. Editing a thought's expiry after
capture is now possible, which is why `ExpirationUnit` moved to `Core` and `Thought` gained
`setCustomLifetime(_:)` (the stored column already existed, ADR-0024). Text is committed when the
detail is left, so an edit is never lost by tapping back.

---

## ADR-0028 · A redesign may not quietly retire an accepted decision

**Status:** Accepted · Thoughts redesign

**Context.** The redesign changed screens faster than it changed the record. Three accepted
decisions were dropped without their ADRs moving to Superseded, and nothing caught it because the
UI tests that enforced them had been edited to match the new screens or were failing unread:
ADR-0008's focused field on cold launch (capture silently began costing a tap), ADR-0021's
first-run explanation (the view was deleted outright), and ADR-0012's dependency rule (`KindGlyph`
was about to be imported across features). `ArchiveFeature` also survived as a linked, dead target
after its page was removed.

**Decision.** An accepted ADR is changed by **superseding it in writing**, in the same commit that
changes the code. A UI test that stops matching the app is either **evidence of a regression** or
evidence the ADR moved — never a test to quietly rewrite. When the behaviour genuinely moved, the
test is repointed at the new control **and the commit says which ADR moved it**. When a screen is
removed, its target, its package product, its `project.yml` entry and its tests go with it, and its
coverage is ported before the deletion lands rather than after.

**Alternatives.**
- *Let the tests define the behaviour* — rejected: the tests had already been edited to accept the
  regression, so they would have ratified it. The ADRs are what say what the app is for.
- *Batch a documentation pass at the end of a redesign* — rejected: this was that pass, and three
  decisions had already been lost by the time it ran.

**Consequences.** `KindGlyph` lives in `Core` rather than a feature, because a third feature needed
it and features never import each other. Test navigation is centralised in `Tests/UITests/
TabNavigation.swift`, so the next navigation change is one edit and not thirty scattered taps that
each invite a quiet rewrite. The full UI suite has to be green before a redesign is called done —
it was 22 tests red when this pass began.

---

## ADR-0029 · Migration tests run in their own process

**Status:** Accepted · Thoughts redesign

**Context.** `PersistenceTests` failed intermittently, and worse, sometimes *passed* while lying.
SwiftData binds an entity name to one class per process. The migration tests are the only ones that
open containers at old schema versions, and version 1's `ThoughtEntity` has neither `isLive` nor
`stateCode`. Sharing a process, whichever class registered first answered everyone's queries — so
archived thoughts came back live, and a snoozed thought round-tripped as `inbox`. When the
mismatch was a cast rather than a missing column, SwiftData trapped and took the whole test process
down, which is what hid the wrong answers: the run died before it could report them.

**Decision.** `SchemaMigrationTests` is its **own test target**, run as its **own `swift test`
invocation**. Within it, a container is opened at the version of whatever entity class the test then
uses — never at an old version with the current `ThoughtEntity`, which is the cast that traps.

**Alternatives.**
- *`--no-parallel`* — what CI was already doing, and it never worked: ordering is not the problem,
  a shared process is. It only made the failure rarer, which is worse.
- *`.serialized` on the suite* — same flaw, and it left the fault looking addressed.
- *One entity class shared across versions* — that is what a versioned schema exists to prevent; the
  old columns are the point of the migration test.

**Consequences.** `swift test` on the Persistence package alone is no longer the whole story, so CI
runs two invocations and the suite's doc comment says so. A version 4 schema adds its cases to this
target, and never to `PersistenceTests`.

---

## ADR-0030 · Sorting is a choice, not a status line

**Status:** Accepted · Settings redesign

**Context.** Settings reported "On-device model" and offered nothing to press. Which classifier
runs is not purely a device fact: the on-device model costs battery and time, its verdicts vary,
and some people would rather the app be predictable than clever. Reporting that as immutable was
the app deciding on the user's behalf and then telling them about it.

**Decision.** Sorting is a **two-chip choice** — *Automatic* or *Rules only* — stored in
`SortingPreference` and honoured by `PreferredIntelligence`, which reads the preference on **every
call** so a change applies to the very next capture without a relaunch. Beneath the choice sits one
line of reality, because what was asked for and what is running are not always the same: asking for
the model on a device without one still gets rules, and the app says so rather than pretending.
`HeuristicReason.userChose` exists so a deliberate choice is never reported as a degradation.

**Alternatives.**
- *Leave it as a status line* — rejected: it is the only screen in the app that could offer the
  choice, and the information alone is not actionable.
- *A single "Use Apple Intelligence" switch* — rejected: a switch implies the model is always
  available, and the off state would have to mean two different things.

**Consequences.** `IntelligenceFactory` gained `rulesOnly()`. The preference is read through a
closure rather than captured, which is what makes it live.

---

## ADR-0031 · The decay rates are editable

**Status:** Accepted · Settings redesign

**Context.** How long each kind of thought lasts is the central rule of the app, and it was a
read-only table. But a fortnight for a to-do is a guess about how someone works, not a law: a
person who thinks a to-do deserves a month is not misusing the app.

**Decision.** Each kind's lifetime is a **stepper**, stored as `DecayProfiles` JSON in
`UserDefaults` and applied at once. Grace stays private — it exists so a fresh capture does not
appear to start dying immediately, which is a feel detail rather than a preference — and is clamped
to the lifetime so shortening a span cannot invert the decay window. A lifetime cannot go below one
day, which would archive a thought the moment it was written. **Reset to defaults** appears only
once the rates are custom.

**Alternatives.**
- *Wheels, as capture uses for a per-thought expiry* — rejected: these are nudged by a day or two,
  not scrolled to, and a wheel inside a scrolling page fights the scroll.
- *A single global "how fast things decay" slider* — rejected: the whole point of kinds is that a
  to-do and an idea rot at different speeds (ADR-0005).

**Consequences.** `DecayEngine` now reads its profiles through a closure, because one engine is
copied by value into the inbox, the sweeper, the review and the widgets, and a stored snapshot
would leave all of them on yesterday's rates. `DecayProfilesCache` holds the current value behind a
lock so that read is cheap and thread-safe.

---

## ADR-0032 · Settings holds controls; facts go in About

**Status:** Accepted · Settings redesign

**Context.** Half of Settings was sections the user could not act on: Storage, Syncing and Widgets
each had a heading, a card and a sentence, and each was purely a report. Given equal visual weight
to the real controls, they made the screen look like a settings screen while offering almost
nothing to set.

**Decision.** A section in Settings is **a control or it is not a section**. Storage, syncing and
widget sharing collapse into an **About** group of one-line facts, because they are decided by the
device and the signing account and there is nothing to press. They are still shown, because a user
whose thoughts are not reaching iCloud needs to know. Anything genuinely wrong — a store that
failed to open, an iCloud account signed out — is lifted into a single `warning` above the facts,
since a degraded store loses thoughts and that deserves a sentence rather than a quiet row.

**Alternatives.**
- *Delete the status entirely* — rejected: silence about a store that will lose thoughts is worse
  than the fault, which is why it was reported in the first place.
- *Keep the sections and add controls to them* — rejected: there is nothing to control. Whether
  CloudKit is reachable is not a preference.

**Consequences.** The screen is a `ScrollView` of cards rather than a `List`, so the sections can
be genuinely different shapes. `SettingsToggle`, `ChoiceChip` and `SettingsStepperRow` put the
controls in the app's own vocabulary, which is what stops Settings looking like the system's.

---

## ADR-0033 · Live is a storage question; awake is a presentation one

**Status:** Accepted · Post-design-pass fix

**Context.** `ThoughtState.isLive` was true for `.snoozed`, and `ThoughtScope.live` was defined as
`state.isLive`. So `thoughts(in: .live)` returned thoughts inside a running snooze, and every
caller had to remember to filter them out. Two of the four remembered: `ReviewSelector` had a
private `isAsleep`, `NudgeSelector` had a private `isAwake`, and the two implementations were
subtly different spellings of the same rule. The two that forgot were `InboxModel.load()` and the
widget's `entry(at:)` — so snoozing a thought hid it only until the next load, and the home screen
counted set-aside thoughts and could show one as the thing about to be lost.

The obvious fix is a fourth filter at the two broken call sites. That was rejected: two selectors
independently reimplementing the same predicate is the design telling us the vocabulary is wrong,
and a fourth copy would only make the fifth omission more likely.

**Decision.** Split the question in the domain. `isLive` keeps its date-free meaning — *not
archived, not completed* — and gains a new `isAwake(at:)` that is `isLive` **and not inside a
running snooze**, with `Thought.isAwake(at:)` forwarding to it. Every surface that shows thoughts
to a person filters on `isAwake(at:)`. Both private copies were deleted in favour of it.

`ThoughtScope.live` deliberately keeps including running snoozes, and now says so. It cannot do
otherwise: the scope compiles to a SwiftData predicate over the stored `isLive` column, that column
is written at save time, and whether a snooze has lapsed depends on the date at *read* time. A
store-side answer would need either a date parameter threaded into every scope or a stored
wake-date column, and the second would reintroduce exactly the multi-column CloudKit tear ADR-0019
was written to eliminate.

**Alternatives.**
- *Make `isLive` false for a running snooze* — rejected: it is the rule the store writes into a
  column, so a date-dependent answer cannot be persisted, and a snoozed thought would fall into the
  `archived` scope and appear in the archive. A snooze is not an archive.
- *Add a `.awake` case to `ThoughtScope`* — rejected: the scope is a storage vocabulary and the
  store cannot answer the question. A case that every implementation had to satisfy in memory would
  be a lie about where the filtering happens.
- *Filter at the two broken call sites only* — rejected above.

**Consequences.** One rule, in `Core`, with the two duplicates deleted. The regression test that
found this asserts a **reload**, not just the optimistic in-memory removal — the original test
stopped one line early, which is precisely why the bug survived. A companion test asserts a lapsed
snooze returns the thought to the list, because a snooze that hid something forever would be an
archive under another name.

---

## ADR-0034 · The review's card gives way; its decisions do not

**Status:** Accepted · Design-pass review

**Context.** `testTheReviewIsOperableAtTheLargestTypeSize` had been failing on `review.drop must be
tappable` since before the design pass. The session was one unscrolling `VStack`: progress, a
spacer, the card, a spacer, the decisions. At accessibility type sizes the card — which carries the
thought's full text, an expiry line and sometimes an interview question and its field — grew taller
than the screen and pushed "Let go" off the bottom edge, where nothing could reach it.

The screen has two kinds of content and only one of them is the point. The card is what you are
being asked about; the three decisions are the asking. A review you cannot answer is not a review.

**Decision.** The card scrolls and the decisions stay put. The card moves into a `ScrollView` whose
content carries a `minHeight` equal to the scroll view's own height, so the card is **centred while
it fits and scrolls from the top once it does not**. The decisions sit outside that scroll view and
are therefore always on screen at every type size.

**Alternatives.**
- *Wrap the whole session in a `ScrollView`* — rejected: the decisions would scroll too, so at the
  largest sizes you would have to scroll past the thought to answer it, and the finite-feeling
  session ADR-0007 argues for would read as a page.
- *Shrink or truncate the card's text at large type* — rejected: the raw captured words are the
  thing being decided about. Truncating them to fit the decision buttons inverts which content the
  screen exists to show.
- *Let the decisions wrap into a column and hope it fits* — rejected: `ViewThatFits` already does
  this and it was not enough. Three capsule buttons stacked vertically are taller than the row they
  replace, so the overflow got worse rather than better.

**Consequences.** The screen keeps its centred single-card look at default type, which is what
stops one card against an empty page reading as a loading state. The `minHeight` needs the scroll
view's measured height, so `ReviewView` tracks it in a `cardArea` state via `onGeometryChange`.

---

## ADR-0035 · Decay is the card's material, not a caption on it

**Status:** Accepted · Design overhaul

**Context.** Everything decays is one of the app's two load-bearing ideas, and it reached the user
as the words "archives in 2 months". ADR-0025 had replaced the meter and rail with font weight, and
weight alone turned out to be too quiet a channel: in the inbox a thought with two months left and
one with six days looked nearly identical. `FreshnessMeter` stayed in `DesignSystem` with zero
callers — the design system still described a product the app had stopped being.

A caption is the app *telling* you something decays. The thesis deserves to be *shown*.

**Decision.** A thought's card expresses its own freshness. As freshness falls the fill blends from
``Palette/raised`` toward ``Palette/surface`` and the elevation drops from `.card` to `.flat`, so a
thought about to be archived has visually almost rejoined the paper it is printed on. The rail
returns as a second reading of the same number. Three channels agree instead of one whispering.

The slope starts at the fading threshold rather than at full freshness: only the back half of a
thought's life is spent visibly sinking, so a fresh thought and a settling one look alike and the
signal means something when it appears.

**Alternatives.**
- *Bring back the meter from ADR-0025* — rejected: a meter is a gauge to read, and a list of five
  gauges is a dashboard. The card itself changing needs no reading at all.
- *Fade the card's opacity* — rejected: opacity fades the text with the surface, and the row's
  content already fades on its own axis. Compounding them would push an old thought under the
  contrast floor ADR-0020 set.
- *Blend all the way to the page colour* — rejected: a card that reached the page stops reading as
  an object and the list loses its edges. `maximumSink` stops at 0.85.

**Consequences.** `CardSurface` gains a `freshness:` initialiser; the plain one still serves cards
that are not thoughts. Increased contrast suppresses the blend entirely, because a surface fading
into its background is the opposite of what that setting asks for.

---

## ADR-0036 · The list is sorted by what you are about to lose

**Status:** Accepted · Design overhaul

**Context.** The inbox was a flat newest-first list under a permanent row of kind chips. Kind
answers "what is this?", which is not the question anyone opens this app with. Nobody launches
Fleeting thinking "show me my habits"; they launch it wondering what is about to disappear. The
chips also ran off the trailing edge on every device narrower than their combined labels.

**Decision.** Urgency is the list's primary axis. Live thoughts group into **Going soon**, **This
month** and **Plenty of time**, most urgent first, with empty bands omitted. Kind and the archive
move into a toolbar menu — a secondary axis deserves a secondary affordance.

`UrgencyBand` lives in `Core` and derives its thresholds from the same numbers the surface
treatment uses, so the section a thought sits in and the way its card is drawn can never disagree.

**Alternatives.**
- *Keep the chips and add sections* — rejected: the screen would ask two organising questions at
  once, and the chips argue for the axis the sections just replaced.
- *Sort by urgency without sections* — rejected: a continuous slope with no headings gives the user
  nothing to stop at, and the point is to make "going soon" a place you can look.
- *Group the archive too* — rejected: an archived thought has no time left to run, so urgency is a
  question that no longer applies to it. It stays one flat run.

**Consequences.** `goToThoughts()` waits on the masthead rather than the deleted `inbox.filter.all`
chip, and tests that assumed newest-first ordering now assert the most urgent thought instead —
they had encoded the old axis.

---

## ADR-0037 · The serif is the user's voice

**Status:** Accepted · Design overhaul

**Context.** ADR-0022 made ``Typography/display`` a serif and used it only where the app speaks: an
empty state, the end of a review. That put the app's distinctive voice on the two screens a user
sees least, and left the thing the app actually exists to hold — their own words — in the same
system sans as every button and label around it.

**Decision.** Invert the rule. **The serif is for the user's own words; the sans is for everything
the app says.** The capture field, a thought in the list, the review's card and the raw note in
Sharpen are all set in the serif. Questions the model asks, section labels, buttons and status
lines stay sans.

A write-up's title is serif too: it was built from the user's answers, so it is their idea written
out, not the app talking.

**Alternatives.**
- *Set everything in the serif* — rejected: that is a magazine, and the interface would compete
  with the content it is meant to be furniture around.
- *Leave the rule as ADR-0022 had it* — rejected: it spends the app's one typographic gesture on
  its least-seen screens.

**Consequences.** ``Typography`` gains `quoted`, `serifBody` and `writtenTitle`. The Sharpen
question moves from `capture` to `subtitle`, because it is the app asking rather than the user
speaking.

---

## ADR-0038 · A save says where the thought went

**Status:** Accepted · Design overhaul

**Context.** Saving cleared the field and fired a haptic. That confirms *something* happened but
says nothing about where the thought went, what it was filed as, or that it has already started
decaying. The decay model was therefore something a user had to discover by opening another tab.

**Decision.** On save the text collapses into a one-line receipt card standing where the words
were, showing the thought, its kind and its lifetime — `idea · 3 months`. It retires itself after
two and a half seconds.

An unsorted capture says "sorting…" rather than naming a kind, because classification has not run
yet and claiming a kind the next screen contradicts would be a lie.

**Alternatives.**
- *A toast or banner* — rejected: it appears beside the work rather than out of it, and the point
  is that the thought the user just typed is the thing that transforms.
- *Leave it on screen until dismissed* — rejected: that is a thing to dismiss standing between the
  user and their next thought, which principle 1 forbids.

**Consequences.** `CaptureModel` gains `receipt` and `clearReceipt()`. Nothing waits on it: the
field is empty and focused the instant the write succeeds, receipt or no receipt.

---

## ADR-0039 · Capture is a page, not a form

**Status:** Accepted · Design overhaul

**Context.** The capture screen — the reason the app exists — drew its field as a rounded recess
with a save button and an advanced-options toggle in a card beneath it. Opening advanced revealed
type icons and two expiry wheels. The metaphor is paper, and paper does not have a well cut into
it; the recess made the most important thing in the app look like one field on a form.

The advanced panel was worse than cosmetic. Principle 1 forbids anything standing between a cold
launch and a captured thought, and expiry wheels at the moment of capture are exactly the "which
folder? what type?" tax the app was built to remove.

**Decision.** The field is the page: no recess, no border, text starting at the top margin. Save
moves to a bar pinned above the keyboard, so it is always under the thumb and never moves as the
thought grows. The advanced panel is deleted outright.

**Alternatives.**
- *Keep advanced but collapse it further* — rejected: a form that is one tap away is still a form
  at the moment of capture, and the wheels duplicated controls the thought's detail already has.
- *Keep the well and move only the save* — rejected: the well is what makes the screen read as a
  form. Moving the button around it does not change what it looks like.

**Consequences.** `CaptureTypeIcon` and capture's copy of `ExpiryWheels` are deleted; the detail
view keeps its own wheels, which is where a decision about an existing thought belongs. A capture
is always automatic now, so classification governs both kind and timing.

---

## ADR-0040 · Review is a place

**Status:** Accepted · Design overhaul

**Context.** Review is where the product's value is actually realised — it is the half of the deal
where the app comes back and makes you decide. It was reachable only as a small tinted text link in
the inbox's header, which made the app's second pillar look like a footnote to its list.

The screen itself leaned on the user: two quiet bordered buttons and one filled prominent one, so
the layout argued for keeping. And a card stack answered only to buttons, never to the thumb.

**Decision.** Review becomes a tab. The three decisions become one equal-weight row — same shape,
same size, differing only in tint — because all three are real decisions and the screen should not
lean. The card takes swipe gestures: left lets go, right keeps, up snoozes.

**Alternatives.**
- *Badge the inbox link with a count* — rejected: it makes the link louder without making review a
  place, and it is still a footnote to a list.
- *Present review on launch when thoughts are waiting* — rejected outright: principle 1 and ADR-0008
  forbid anything between a cold launch and the capture field.
- *Gestures only, dropping the buttons* — rejected: a gesture is a shortcut, never the only way.
  Every decision a swipe can reach is also a button.

**Consequences.** The inbox's "N to decide" link stays, pushing the same view, so the two entry
points cannot drift apart. `Keep` loses `.borderedProminent` and keeps only its accent tint.

---

## ADR-0041 · The accent marks time and action, never identity

**Status:** Accepted · Aesthetic pass

**Context.** After the overhaul the accent purple marked six unrelated things: the freshness rail, a
kind glyph's chip, streak text, the inline action circle, the tab bar, and the review's Keep. A
colour used for everything signals nothing, and the list read as busy in a way that competed with
the thoughts themselves. Two of those uses sat side by side in every row — a tinted chip beside a
tinted rail — so a thought's identity argued with its urgency for the same attention.

**Decision.** One job for the accent: **time and action.** The rail keeps it, the tab bar and the
decisions keep it. Kind glyphs lose their chip and go to muted ink; streak text goes muted; the
inline action circle becomes a soft tint rather than a solid disc, because a filled 44pt accent
puck was the loudest thing on a screen whose subject is the words beside it.

The one urgency heading is warmed and weighted to match. Three identically grey section labels said
the sections differ without saying that one of them matters.

**Alternatives.**
- *Give each kind its own hue* — rejected: four colours to learn, and it would make identity the
  loudest signal on a screen sorted by time.
- *Keep the chips and drop the rail* — rejected: the rail is the freshness reading, which is the
  thesis. The chip is decoration around an icon that was already legible.

**Consequences.** `SectionLabel` gains a tinted initialiser. Capture's text block floats off the
top margin, since with the well gone the placeholder alone at the very top read as a page that had
failed to load.

---

## ADR-0042 · One growing thing

**Status:** Accepted · Aesthetic pass

**Context.** The app is about things that grow if tended and fade if not. Nothing in the interface
said so except colour and elevation, both of which are quiet. The habit streak in particular used a
flame — the wrong metaphor entirely, since fire is what happens to a thing you neglect, not what
you get for tending it.

**Decision.** A line-drawn seedling, `SproutMark`, drawn with `Path.trim` so it grows rather than
appears. It marks the four moments where a thought gains life: a save that reached storage, a habit
kept, a review finished, and a list cleared.

Two leaves, not one — a single leaf read unmistakably as the bowl of a lowercase "p" when it
shipped, which the first screenshot caught. The stem draws first, then the leaves unfurl from it in
sequence.

**Alternatives.**
- *Put it in the chrome too — tab bar, filters, settings* — rejected: chrome should be silent, and
  a decoration that appears everywhere stops being a moment.
- *An SF Symbol of a leaf* — rejected: it cannot be grown, and the growth is the whole point.

**Consequences.** `GrowingSprout` wraps the animation so no call site owns a phase, and Reduce
Motion renders the mark fully grown rather than not at all — it is decoration, so the answer to
"no motion" is the end state. Nothing waits on it: capture is committed before it draws (ADR-0008).

---

## ADR-0043 · The capture bar always offers a way down

**Status:** Accepted · Bug fix

**Context.** At the accessibility type sizes the capture screen had no exit. The keyboard covers
the tab bar completely on this device, the save bar only appeared once there was text to save, and
the first-run hint expanded to fill the page — so a user at those sizes could reach capture and
never leave it. `AccessibilityTests` had been failing on this since the design overhaul made
capture full-bleed.

Tapping the background is supposed to dismiss the keyboard, and does on a normal type size. It is
not a reliable escape when the hint has consumed the page.

**Decision.** The bar is always present, and carries a keyboard-dismiss control on its leading
edge. Save still appears only when there is something to save; the dismiss control does not depend
on state, because the one thing that must never be conditional is the way out. The hint is capped
at four lines.

**Alternatives.**
- *Cap the hint alone* — rejected: it was tried and did not fix it. The hint made the trap worse,
  but the keyboard covering the tab bar is what made it a trap.
- *Move the tab bar above the keyboard* — rejected: the tab bar is the system's, and fighting it
  would cost more than a 44pt button.
- *Dismiss on scroll* — rejected: capture has nothing to scroll.

**Consequences.** `switchToTab` in the UI tests taps this control rather than a coordinate at 55%
of screen height — a magic point chosen when capture had a well, which two layout changes later
was landing on whatever had moved there. `SchemaMigrationTests` is `.serialized` in the same
commit: its cases each register a different schema version for one entity name, and running them
in parallel crashed the process on roughly one run in three.

---

## ADR-0044 · A habit mark can be taken back

**Status:** Accepted · Bug fix

**Context.** Marking a habit kept was a single tap on a control sitting in a list, next to the row
that opens the thought. It is a tap people make by accident. There was no way back: `Streak` could
only ever count up, so an accidental mark could only be undone by abandoning the habit for two days
and letting the whole run lapse. An accidental tap cost a run the user had actually earned.

Worse, the app's whole promise is that nothing is ever destroyed without an explicit decision. A
streak the user could not correct broke that promise in the one place the app asks for a daily
commitment.

**Decision.** `Streak.unmark(previous:)` takes the count back one. Undoing the only mark clears
`lastMarkedAt` as well as the count, so the habit returns to never-started rather than to
zero-with-a-date — otherwise the next mark would see a gap and the habit would read as kept and
broken rather than untouched.

Freshness is deliberately *not* rolled back. Undoing an accidental tap should not also age the
thought, and restoring the previous `lastActedAt` would need a history the model does not keep.

The control lives in the thought's detail beside the streak, not in the list. Undo is a correction,
and a correction belongs where you go to look at the thing, not next to the button that caused it.

**Alternatives.**
- *A confirmation on the mark button* — rejected: it makes the common case slower to protect
  against the rare one, which is the trade this app exists to refuse.
- *An undo toast after marking* — rejected: it expires, and the mistake is usually noticed later.

---

## ADR-0045 · The botanical marks are drawn on the page, not stuck to it

**Status:** Accepted · Aesthetic pass

**Context.** The first pass at the botanical language put every sprout inside a filled circle or a
tinted chip. That is how an icon is treated, and it made the drawings read as stickers applied on
top of the interface rather than as part of its vocabulary. The marks also only ever appeared as a
consequence of pressing something, which reinforced the reading: a reward badge, not a language.

**Decision.** Two rules.

**No containers.** A drawn mark sits directly on the surface it belongs to, with no fill behind it.
The to-do's tick keeps its chip, because a tick is an icon; the sprout does not, because it is a
drawing.

**Ambient before triggered.** At least one botanical mark is on screen before the user does
anything. The review's progress bar is now a vine that gains a leaf per decision — present from the
first card, growing as the session does. A habit's streak in the detail shows its vine on arrival.

**Alternatives.**
- *Keep the chips for tap-target legibility* — rejected: the target is the frame, not the fill, and
  a 44pt `contentShape` gives the same target without the sticker.
- *Put a vine in the tab bar or the filter menu* — rejected: chrome stays silent (ADR-0042), and a
  decoration everywhere is a decoration nowhere.

---

## ADR-0046 · The capture page has something growing on it

**Status:** Accepted · Aesthetic pass

**Context.** Capture became a full-bleed page in ADR-0039, which was right, but it left a screen
that is one line of placeholder text on an otherwise blank field of colour. It read less like paper
than like a screen that had failed to load. The botanical language existed by then but appeared
only in response to an action, so the emptiest screen in the app was also the one with none of it.

**Decision.** A `ClimbingVine` grows up the trailing edge, drawn at 16% opacity behind everything
else and never interactive. It is page texture, not a control: it carries no information, cannot be
tapped, and is hidden from accessibility. It grows once on appear and then simply stays.

The save bar is also hidden while the keyboard is down. It exists to sit on the keyboard, and with
the keyboard away its dismiss control pointed at nothing while leaving a grey slab across an
otherwise quiet page.

**Alternatives.**
- *Fill the space with recent thoughts or a count* — rejected: capture is the one screen that shows
  you nothing, so the moment costs nothing. A preview of the list is the list's job.
- *A static illustration* — rejected: the point of the language is that things grow. A drawing that
  was simply placed would be the sticker problem ADR-0045 just removed.
- *Put it behind the text at full opacity* — rejected: it competed with the placeholder, which is
  the only thing on that screen that matters.

**Consequences.** `GrowthProgress` no longer sizes a `VineRule` to a fraction of its width. Doing
so scaled the whole drawing, so the leaves slid apart as a review advanced and the vine read as a
line being stretched. It now draws the vine once at full width with one leaf per card and reveals
it with a mask, so the leaves stay where they are and only more of the plant becomes visible.

The demo seed grew from five thoughts to seventeen, spread across every urgency band, every kind,
and both live and archived, so a hand test can reach each state without waiting for real time.

---

## ADR-0047 · Habits live on the home screen, and leave the moment you write

**Status:** Accepted · Design pass

**Context.** A habit is the only kind of thought in the app that has to be touched *every day*, and
it was buried three taps deep: open the Thoughts tab, find the row among everything else, tap the
sprout. Nothing about the daily cadence was reflected in where the habit lived. Meanwhile the home
screen — the tab a cold launch lands on — showed one field and a vine, and had space for exactly
the thing that needs daily attention.

**Decision.** Today's habits appear as a horizontal run of cards beneath the capture field on the
home screen, and *stay* in the Thoughts tab as well: one is a daily prompt, the other is the
complete list, and neither replaces the other. Each card carries the habit, its streak, and one tap
to keep it, marking through the same `Thought.markHabitKept` the list calls, so a mark made in
either place is the same event. A habit already kept within the last day shows a tick instead of a
sprout and stops being tappable, because a second tap would change nothing.

The cards leave the instant the field takes focus, and stay away while there is text to save.
Writing down a thought is not a screen you share: the moment someone starts, the only thing that
matters is what is in their head.

**The cost, stated plainly.** The keyboard no longer rises on its own at launch. ADR-0008's promise
is that nothing may stand between a cold launch and capture, and that is intact — the field is
still the first thing on screen, still needs no navigation, and is one tap from writing. But the
keyboard covers the bottom two thirds of the phone, so an auto-raised keyboard and a habit strip
cannot both exist. Capture now costs one tap where it cost none.

The ambient surfaces are not made to pay that tax. The widget, the lock screen control, Control
Center and Siri all promise a field with the cursor already in it, so `fleeting://capture` selects
the home tab and raises the keyboard through `CaptureFocus`. The tap is only charged to someone who
opened the app by hand, which is exactly the person who might have opened it to keep a habit.

**Alternatives.**
- *A habits tab of its own* — rejected: a fifth tab for one kind of thought, and a place you still
  have to choose to visit. The point is that it is in front of you without being asked for.
- *Keep the keyboard up and put the habits above the field* — rejected: at the accessibility type
  sizes the keyboard already covers the tab bar (ADR-0043), so anything below the field is
  unreachable and anything above it pushes the field off the top.
- *Show habits in the receipt's place after a save* — rejected: the receipt is a moment about the
  thought just filed (ADR-0038), and a daily prompt is not a response to a capture.
- *Move habits out of the Thoughts tab* — rejected explicitly, and by the request: the list is
  where a habit is edited, snoozed, archived and undone. The home screen offers one action.

**Consequences.** `CaptureView` takes an optional `DailyHabitsModel` and an optional `CaptureFocus`,
both defaulted to `nil`, so a preview or a test can still build the bare capture screen. The
`New thought` tab is now `Home`, since it holds two things. The UI tests that asserted a keyboard at
launch now assert a hittable field that focuses on one tap.

The compensation is the part worth guarding, because it is what makes the traded tap affordable, so
it is tested rather than asserted: `--focus-capture` drives the same `CaptureFocus` the URL does, and
a UI test proves a launch from an ambient surface still arrives with the keyboard up and the habits
out of the way. URL matching lives on `CaptureFocus` rather than in the composition root so it can
be tested without a simulator. A further UI test marks a habit on the home screen and finds the same
thought still live under the Habits filter, which is what "the same event in both places" has to mean.

`AppEnvironment.prepare` now notifies the change stream when it finishes. Seeding and the sweep both
run *after* the home screen has drawn, and without this the strip showed an empty store it had read
before the store was filled — caught by the new UI test rather than by inspection.

---

## ADR-0048 · A habit has a cadence, and the home screen shows only what is due

**Status:** Accepted · Design pass

**Context.** ADR-0047 put habits on the home screen, and shipping it exposed that the app had no
concept of *how often* a habit is meant to be kept. Every habit was implicitly daily. A weekly
habit therefore sat on the home screen six days out of seven asking to be done again, and a habit
kept an hour ago stayed on screen wearing a tick — a card occupying the most valuable space in the
app to tell you there was nothing to do.

**Decision.** A habit carries a `HabitCadence`: daily, every few days, weekly, fortnightly, or
monthly. It decides three things at once, which is why it is one value rather than three settings.

1. **When the habit is due.** `Thought.isDue(at:)` is false for a habit kept within its current
   period, and the home screen lists only habits that are due. A kept habit therefore leaves the
   screen the instant it is marked, rather than turning into a tick.
2. **What a run is counted in.** A weekly habit kept four times is a four *week* streak. Marking
   twice in one period still does nothing, and a run still survives one miss and breaks on two —
   the rules that were already there, now measured in the habit's own period.
3. **How fast the habit decays.** A habit's lifetime becomes two whole periods when that is longer
   than the configured rate.

Point 3 is a bug the cadence work uncovered rather than a feature. The shipped habit rate is seven
days, so a monthly habit would have been swept into the archive three weeks before it was ever due
again: the app would have destroyed a habit for obeying the rhythm the app itself inferred. A test
now asserts the lifetime exceeds the period for every cadence.

The cadence is read out of the note's own wording at classification time — "run every morning" is
daily, "call mum on sundays" is weekly — by all three intelligence implementations, and corrected
on the thought's own page, which is where a decision about a thought belongs. Where the words say
nothing about frequency, nothing is inferred and the default applies: a guess is worse than a
default here, because a wrong cadence silently changes when the app asks.

Provenance reuses `KindSource` rather than declaring a parallel enum. The question is identical —
did nobody say, did the app guess, or did a person decide — and a chosen cadence is never
overwritten by a later classification, exactly as a confirmed kind is not.

The cards are also a vertical stack rather than a horizontal run. The horizontal one was chosen
when the strip showed every habit and had to be bounded; now that it shows only what is due, the
list is short by construction and every item can simply be read.

**Alternatives.**
- *An arbitrary "every N days" number* — rejected: a stepper at the moment of correction is a form,
  and five named rhythms cover what people actually mean. The custom-lifetime wheels already exist
  for anyone who wants a number.
- *Keep showing kept habits, greyed or ticked* — rejected, and by the request: the home screen is
  the most valuable space in the app, and a card that says "nothing to do" is the least valuable
  thing that could be in it. The Thoughts tab is where the full roll call lives.
- *Infer cadence but do not let it be edited* — rejected: the inference reads words, and most notes
  do not name a frequency at all. An uneditable guess would be a rhythm imposed on the user.
- *A separate `CadenceSource` enum* — rejected: three identical cases, and two enums that must
  agree forever.

**Consequences.** Schema version 4 adds `cadenceRaw` and `cadenceSourceRaw`, both optional, so the
migration is lightweight and an existing habit becomes daily — which is exactly what it already
was. A test asserts that, because a migration that changed how often an existing habit is asked
for would silently rewrite someone's routine.

The heuristic's habit markers are now derived from its cadence phrases rather than duplicated. They
had already drifted: "every other day" named a cadence but did not sort as a habit, so the cadence
was never read. The lists cannot disagree now because there is only one.

---

## ADR-0050 · A cadence is a number and a unit

**Status:** Accepted · Design pass

**Context.** ADR-0048 gave habits a cadence as five named rhythms: daily, every few days, weekly,
fortnightly, monthly. That ADR explicitly rejected an arbitrary number, on the grounds that five
names cover what people actually mean and a stepper at the moment of correction is a form.

Shipping it showed the reasoning was wrong in two places. `everyFewDays` is not a rhythm anyone
holds — it is the enum apologising for not having the case you wanted — and it had to be given an
arbitrary period anyway to compute anything. Meanwhile the app *already* asked people for a duration
as a number and a unit: the custom-lifetime wheels. The app was therefore asserting that a duration
is a number for expiry and a menu for cadence, which is not a distinction anyone using it would
recognise.

**Decision.** `HabitCadence` is a `count` and an `ExpirationUnit`, and the detail page sets it with
the same two wheels the expiry section uses. "Every 3 days" is sayable, and so is anything else,
without the app having had to anticipate it.

`ExpirationUnit` is reused rather than a cadence-specific unit declared. Days, weeks and months are
already spelled there for hand-set lifetimes; one vocabulary for durations means one place to add a
unit and no way for two lists to disagree.

The common rhythms keep their English names in the interface — `label` says "Daily" and "Weekly",
never "every 1 days" — and `daily`, `weekly` and `monthly` remain as named constants, so call sites
and tests read as they did. A count below one is clamped to one at construction: "every zero days"
is not a rhythm, and clamping once means no caller defends against it.

**Alternatives.**
- *Keep the five cases and add a `custom(days:)`* — rejected: a sixth case that is a superset of the
  other five, and every switch over it has to handle both spellings of the same rhythm forever.
- *A plain day count* — rejected: it cannot express "every month", which is not 30 days, and it
  would put "every 28 days" in front of someone who said "monthly".
- *A stepper rather than wheels* — rejected: reaching 30 is thirty taps, and the expiry section had
  already answered this question with wheels.

**Consequences.** The stored spelling is `"3 days"` — the count, a space, the unit's raw value — in
one optional column, readable by eye, and unreadable values fall back to the default rather than
throwing. A habit stored by the previous build as `"weekly"` no longer parses and becomes daily.
That is a real regression for anyone running the previous build, and it is accepted only because
that is this machine and this phone; on a shipped app it would have needed a migration reading both
spellings.

Both intelligence implementations now answer with a count and a unit. The Foundation Models prompt
asks for a number and a unit and treats a count of zero as "the note named no frequency", which must
stay `nil` so the default applies rather than a rhythm being invented. The heuristic's phrase table
gains "every three days" and its kin, and its habit markers are still derived from that one table.

`CadenceSection` shows the rhythm as a sentence — "Every 3 days" — above the wheels, singularising
the unit so it reads as English. The wheels stop at 30 rather than the expiry wheels' 60: a habit
kept every 31 months is not a habit, and a shorter wheel is a faster one to spin.
