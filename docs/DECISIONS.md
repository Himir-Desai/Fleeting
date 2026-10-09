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

## ADR-0049 · The icon is the app's own mark

**Status:** Accepted · Design pass

**Context.** The icon was three shortening lines of a note — a fair picture of "written down, and
already going", drawn before the app had a visual vocabulary of its own. By the end of the design
pass it did: the sprout marks a kept habit and a saved thought, and the vine grows down the capture
page (ADR-0042). The icon was the only surface still speaking the old language, and it was the first
one anyone sees.

**Decision.** The icon is the sprout, drawn at icon scale, in the accent on the page colour.

The geometry is a **transcript** of `SproutMark`: the same stem curve, the same two opposed leaves,
the same proportions, restated in CoreGraphics because `Tools/MakeIcon.swift` is a standalone script
that cannot import DesignSystem. That is the one duplication here, and it is deliberate — an icon
that merely *resembled* the in-app mark would drift from it at the first change, whereas a
transcript that drifts is a visible bug.

Both appearances are rendered from the one path, each in its own accent on its own page colour, and
`Contents.json` carries the dark variant under a `luminosity` appearance. The icon therefore matches
the app the phone is about to open, in whichever mode it is in.

**Alternatives.**
- *Keep the note lines* — rejected: it names a feature the app has (decay) rather than the thing the
  app is, and it shares no vocabulary with any screen.
- *Export a PNG from the SwiftUI view* — rejected: it needs a simulator and a running app to render
  what is meant to be a build artefact. The script needs nothing but Xcode.
- *Move `SproutMark`'s path into a shared, script-importable module* — rejected for now: it would
  mean a package existing solely so one script can import it, to remove twenty lines of duplication
  that a side-by-side diff catches.

**Consequences.** `MakeIcon.swift` takes an output path and an appearance, so both icons come from
one command each and neither is hand-edited. `Docs/ASSETS.md` documents both invocations. If the
palette's accent or surface changes, the icons are stale until regenerated — which was already true,
and is now true of two files rather than one.

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

---

## ADR-0051 · Keeping a habit shows the mark before the card leaves

**Status:** Accepted · Design pass

**Context.** ADR-0048 made a kept habit leave the home screen the moment it is marked, which is
right: the card's job is to say "this is due", and once it is not, the card is clutter. But it left
the tap with **no acknowledgement at all**. The sprout was pressed, and the card was gone before the
finger lifted — indistinguishable from a mis-tap that dismissed something, or from the app losing
the mark.

Everywhere else in the app, the sprout *grows* to confirm something took (ADR-0042). The home screen
was the one place it was the control and never the confirmation.

**Decision.** Pressing the sprout grows it, and only then does the card leave — sliding down and
fading, the same exit a saved thought's receipt makes. The write is deferred until the drawing
finishes, because the card has to still be on screen to carry the acknowledgement: a card that
vanished on touch would take the confirmation with it.

The card draws the sprout at its own progress rather than using `GrowingSprout`, which grows on
appear. Here the growth is the *response to the press*, so the card shows a faint fully-drawn sprout
at rest — a control has to look like a control — and redraws it in full colour as the tap lands.

Under Reduce Motion the mark is recorded immediately and the sprout is simply drawn complete. The
answer to "no motion" is the end state, never a wait for an animation that is not playing
(ADR-0020).

**Alternatives.**
- *Haptic only* — rejected: it confirms nothing to someone who cannot feel it, and the app already
  has a visual vocabulary for "this took".
- *Leave immediately and show a toast* — rejected: a receipt belongs to a thought being filed
  (ADR-0038); keeping a habit is not a filing, and a toast for a one-tap action is a second thing to
  read.
- *Keep the trailing-edge exit* — rejected: the receipt goes down and away, and two exits for two
  confirmations makes them two features rather than one gesture in one app.

**Consequences.** `HabitCard` owns two pieces of state — how far the sprout has grown, and whether a
mark is under way — and the second one exists so a second tap during the animation cannot mark
twice. The strip animates on `Motion.card` rather than `Motion.commit`: this is a card leaving a
list, which is what `Motion.card` is for, and at commit speed the slide was over before the eye
could follow it.

The 0.85 second delay before the write is the part to be suspicious of. It is timed to the growth
animation rather than derived from it, so a change to `Motion.growth` can leave the card departing
before its own mark is drawn.

---

## ADR-0052 · Adopt iOS 27 Foundation Models while keeping inference on-device

**Date:** 2026-09-22

**Context.** iOS 27 updates the on-device model and introduces capability inspection and explicit
context options. The user requested the new intelligence integration and explicitly chose to keep
all processing on-device. Apple recommends checking prompts against each new system model.

**Decision.** Keep `SystemLanguageModel.default` as the only model. Route every generation through
`OnDeviceGeneration`, checking guided-generation support on iOS 27 and including the schema in
its context options. On iOS 26.4+, measure the instructions, input and schema, reserve a bounded
response plus formatting overhead, and decline oversized requests without truncating source text.
The existing resilient service supplies local rules on unavailable models, errors and timeouts.
Use greedy generation and task-specific response budgets. Constrain kinds, confidence, cadence
units and question count in the schema; validate output before admitting it to the domain.
Reminders now also use structured generation. Prompt instructions preserve the writer's language
and treat notes and answers as source material rather than instructions.

**Alternatives.** Private Cloud Compute offers larger context and reasoning, but changes where
notes are processed and conflicts with the user's on-device preference. Requesting reasoning
levels from the on-device model without evidence that it supports them would introduce failures.
Raising the minimum OS to 27 would unnecessarily remove existing iOS 26 support.

**Consequences.** Building requires Xcode 27; deployment remains iOS 26+. Oversized inputs may use
less capable local rules, and the token estimate is conservative rather than a guarantee that a
request will fit. Invalid questions or blank write-ups fall back instead of reaching the UI.
No network inference, additional entitlement, or new permission prompt is introduced.

**Validation.** All 36 Intelligence package tests pass, including four new output-validation tests;
the app and widgets build against the iOS 27 simulator SDK. Live model quality has not been
validated. On an eligible iOS 27 device, evaluate one-off tasks, explicit and unspecified habit
cadences, non-English notes, long notes, and Sharpen answers with unresolved details. Check that
classification follows intent, cadence is not invented, questions differ, and write-ups add no
facts. Repeat with Apple Intelligence disabled and with Rules only selected.

**References.** [Apple's Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)
and the installed iOS 27 FoundationModels SDK interface.

---

## ADR-0053 · Dated checklists wait for a daily review decision

**Date:** 2026-09-22

**Context.** The user wants short-deadline tasks for today, tomorrow and individual days in a
seven-button week picker. They explicitly chose review first: an unfinished item moves to today
only after choosing Not finished. Completed tasks must remain visible with a strike-through.

**Decision.** Add Plan between Thoughts and Review, retaining Settings last and capture first.
`DailyTodo` is independent of `Thought`: it has a civil calendar day, text and optional completion
time, and never enters the decay/archive pipeline. A `PlanDay` stores a Gregorian date key rather
than a midnight timestamp, so travelling between time zones cannot change its assigned date.
Week boundaries follow the user's calendar; the active app wakes at the next local day boundary
and refreshes on foreground. Overdue status is derived on read, including after days away, so no
background job or midnight write is necessary.

Review gets a Daily tasks segment. Finished stamps completion while retaining the original day;
Not finished moves the same identifier to today. Completed rows remain in that day's list and
animate a line across wrapped text with Reduce Motion respected. Completion can be undone.
Tasks can be entered for any selected day; entering a past day puts that task in Review too.

Schema V5 preserves every V4 thought column and adds a separate checklist entity by lightweight
migration. The complete task is encoded into one payload, so CloudKit cannot merge a scheduled
day and a completion timestamp from different task versions. Repository operations use fresh
contexts so foreground reads can see widget writes. A failed save does not clear the draft or
remove a pending decision.

Today and Tomorrow widgets offer home-screen checkboxes; Today also offers lock-screen counts.
Their timelines include a projected midnight entry and request later refreshes. Widget completion
is an explicit, idempotent finish action, never a toggle based on stale rendered state. Widgets
require a shared App Group; personal-team builds explain the limitation and open Plan. URLs carry
only an optional date, never task text. iOS controls actual widget rendering/refresh timing.

**Alternatives.** Reusing thought todos would mix daily commitments with decay and weekly pruning.
Automatically carrying tasks over would contradict the requested review-first behavior. Requiring
a background job to run exactly at midnight would miss reviews when iOS suspends the app.

**Validation.** Domain tests cover overdue decisions, repeated completion, multi-day gaps, future
tasks, invalid dates, time zones and a 23-hour day. Feature tests cover the week, midnight reload,
failed writes, persistence across models and past-day entry. Persistence tests cover fresh reads
across app/widget repositories and disk reopen. Migration tests cover the old V1 lifecycle and V4
thought preservation while creating the checklist table. Focused simulator tests cover adding,
completion after relaunch and both review decisions. Physical-device widget interaction with a
provisioned App Group remains a device acceptance check.


## ADR-0054 · Plan and Thoughts share their to-dos

**Date:** 2026-09-23

**Context.** The user clarified that Plan tasks and captured thought to-dos are the same items,
and requested the existing thought editing and action controls in Plan. This supersedes ADR-0053's
separate-storage decision.

**Decision.** Thought is the source of truth for task text, identity, due date and completion.
DailyTodo is now a checklist projection. Plan creates confirmed Thought todos; captured todos
appear using their due date, or capture date if undated. Dates use the existing dueAt instant
interpreted in the current local time zone, matching thought scheduling. The week picker still
uses civil PlanDay values, but due days can change when traveling across time zones.

The Plan text button opens the very same ThoughtDetailView through app-layer navigation, with
its editing, type, snooze, archive and delete controls. The separate checkbox completes/reopens
the shared item. Both surfaces publish through one change notifier, including widget reloads.
SwiftData thought operations fetch through fresh contexts so widget and app changes are visible.
Unfinished todos are excluded from automatic archive sweeps so an overdue task stays available
until the user makes the requested review-first decision. Explicit archive, snooze and type
changes remain effective; completed todos remain visible on their day in Plan.

Old V5 standalone checklist rows are imported into Thought with the same IDs and completion dates.
Insertion and legacy-row removal commit together. If a shared record already exists it wins;
subsequent reads cannot recreate a deleted imported task. The V5 table remains for compatibility.

**Alternatives.** Keeping two records and synchronizing edits would create conflicts and allow
completion or deletion to diverge. Rebuilding the detail UI inside Plan would duplicate the same
controls and violate feature boundaries. A new schema for independent civil-day scheduling would
preserve dates during travel, but would create another date field alongside existing dueAt.

**Validation.** Repository regressions cover bidirectional changes, migration without resurrection,
widget completion, explicit archive/type filtering, and overdue retention. Focused Plan UI tests
exercise entry, shared editing/deletion, persistence, daily review and large text.


## ADR-0055 · Commit the generated project for Xcode Cloud discovery

**Date:** 2026-09-24

**Context.** Xcode Cloud reports that Fleeting.xcodeproj does not exist at the repository root.
The project was ignored, and the current app changes had not reached main. The user now has a
paid developer team and requested merging the current work into main and using main afterward.

**Decision.** Keep project.yml as the source of truth, but commit the generated regular project,
shared Fleeting scheme, workspace, Cloud product manifest, Info.plists and entitlements. Declare
the selected signing team and automatic signing in the spec. Match app/widget versions and derive
plist versions from build settings. Personal-team project files and user Xcode state remain ignored.
Regenerate and commit these files together after spec changes. Xcode Cloud should use main and
Xcode 27+; its archive action uses Release.

**Alternative.** Generating everything in a cloud post-clone script would retain fewer generated
files but would not provide the project and shared scheme during initial product discovery.

**Validation.** Verify the committed checkout builds without first running XcodeGen. This checks
project discovery and build inputs; Apple signing and TestFlight upload remain cloud-side checks.


## ADR-0056 · Complete same-account cloud saving without replacing SwiftData

**Date:** 2026-09-26

**Context.** The user now has a paid developer account and wants all saved app data to follow their
Apple Account. The private CloudKit store already contains thoughts and Plan's task projections,
but incoming records did not notify feature models, settings stayed local, and enabling App Groups
changed the database location without importing free-account data.

**Decision.** Keep SwiftData's private CloudKit mirroring for saved content. Observe persistent
store remote changes and completed CloudKit imports in Persistence and forward them through the
existing change notifier. Features re-fetch through their existing fresh contexts; details preserve
unsaved text and review reconciles remaining cards without resetting completed decisions. Foreground
activation also notifies screens. Register for silent pushes after capture is visible.

Mirror sorting, decay profiles, reminder preferences and capture-hint dismissal with iCloud
key-value storage. Use local defaults as an offline cache; existing cloud values win at startup,
missing values are seeded from explicit local choices, remote updates are not echoed, and incoming
initial cloud synchronization may supersede seeded values. Cache invalidation and the same notifier
refresh behavior and UI. Notification permission and delivery history stay specific to each device.
Concurrent edits to the same preference use the key-value service's conflict handling, not a union.

Before attaching CloudKit, import a previous device-local database into the App Group store.
Preserve identifiers, prefer existing destination rows, save in one transaction, then write a local
completion marker. Retain the original file for recovery; the marker prevents later resurrection
of deleted imported records. An import failure keeps using the original local store and logs the
failure. No records are deleted as part of the upgrade. Reset-store test launches skip cloud sync.

**Alternatives.** Replacing storage with a custom CloudKit engine would make synchronization and
conflict handling our responsibility without helping this same-account milestone. Storing tiny
preferences as new SwiftData entities would require schema evolution and asynchronous reads for
currently synchronous settings. Polling for incoming data would waste work while missing event
semantics. Moving raw SQLite files risks losing WAL transactions; importing records avoids that.

**Consequences.** iCloud operates asynchronously. “iCloud enabled” means the container attached and
an account is available, not proof of a completed transfer. Device acceptance is still required,
including offline changes, deletion, provisioning and production schema deployment. Simultaneous
edits to the same content remain subject to CloudKit merging; this is not collaborative editing.
Cross-account sharing is a separate future storage decision.

**References.** [SwiftData sync](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices),
[iCloud preferences](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore),
and [CloudKit diagnostics](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer).


## ADR-0057 · Three destinations, with review and settings in context

**Date:** 2026-09-26

**Context.** The user wants to simplify existing navigation before adding lists. Review is a
finite activity rather than a permanent destination, and Settings need not occupy the tab bar.
This supersedes ADR-0040's separate Review tab and the five-tab arrangement in ADR-0053.

**Decision.** Keep Home, Thoughts and Plan. Thoughts places its review invitation on a separate
line below the thought count. Plan's existing invitation pushes daily review within Plan; the
`fleeting://daily-review` route does the same. Remove the combined review picker. Back returns to
the originating list. Settings opens in a dismissible sheet from each page's top-right control:
Home and detail/review screens use a gear, Thoughts includes it alongside filters, and Plan groups
it with Today. Dismissal preserves the selected tab, navigation and drafts.

**Alternative.** Keeping the tabs would retain the navigation complexity the user explicitly
rejected. Adding separate settings and filter buttons would crowd the same corner; menus combine
secondary actions while keeping review invitations visible on their relevant pages.

**Validation.** Focused simulator tests cover the three tabs, Settings access and dismissal from
each, the position of thought review beneath the summary, and daily-review decisions/back navigation.


## ADR-0058 · Direct toolbar actions, serif typography and explicit entry areas

**Date:** 2026-09-26

**Context.** The user wants Settings visible beside existing toolbar actions, a more substantial
Home writing area, smaller habit cards, consistent serif typography, and Return-to-save on Plan.

**Decision.** Use adjacent toolbar buttons grouped by the system into a pill: Filter / Settings
on Thoughts, Today / Settings on Plan. This replaces ADR-0057's hidden Settings menu item.
Home's capture field reserves multiple lines in a recessed writing area; habit cards use smaller
vertical insets while retaining 44-point action targets. All text tokens use serif size/weight
variations, with serif navigation titles and inherited serif styles for default SwiftUI controls.
This supersedes ADR-0037's split serif/sans typography and ADR-0039's borderless capture field.

Plan uses a single-line task-entry TextField: Return submits and retains focus for the next task.
A conditional bottom safe-area bar provides a padded Done button above the keyboard; it is absent
when editing ends. A multiline input would preserve newline behavior contrary to the requested
checklist flow. Longer saved tasks still wrap in their rows.

**Validation.** Focused UI checks exercise Return submission, continued keyboard focus, Done's
position above the keyboard and disappearance after dismissal, and direct Settings access.


## ADR-0059 · Balanced toolbar pills and borderless writing

**Date:** 2026-09-27

**Context.** The user requested balanced pill padding, a borderless but spacious Home field,
floating glass keyboard controls, aligned Plan row icons, and larger left-aligned page headings.

**Decision.** `ToolbarPill` uses equal 44-point action targets and explicit outer padding inside
one capsule. Main-page controls live in a shared header because UIKit's toolbar adaptation
collapses the filter-plus-settings group into a single menu. `PageHeading` aligns a serif title
with trailing actions and supplies Home's title; pushed pages retain native back navigation. Capture keeps its reserved writing height
without a field background. Keyboard controls use individual glass capsules with margins instead
of full-width bars. Dismiss controls follow actual software-keyboard visibility; capture retains
Save for hardware-keyboard input. Plan uses matching 44-point leading/trailing columns and smaller
inter-column spacing, with plus and disclosure icons centered on the same trailing column.

**Alternatives.** Shrinking completion tap targets would reduce whitespace but impair usability.
Relying on focus alone would show keyboard dismissal controls even when a hardware keyboard is in
use. Native grouped toolbar spacing does not provide the requested balanced icon insets.

**Validation.** Focused UI checks cover direct Settings access, Return-to-save, keyboard controls,
and capture at the largest Dynamic Type size; screenshots check toolbar and Home layout.


## ADR-0060 · Explicit thought collections and Plan as a built-in list

**Date:** 2026-10-05

**Context.** The user wants optional lists at capture and browsing, with glass expansion in
opposite directions, and Plan generalized without losing its calendar or review features.

**Decision.** A thought has one optional `listID`. Named custom collections are SwiftData records;
Plan uses a fixed domain ID across devices and needs no duplicate built-in database row. All
thoughts remains the default aggregate browsing scope. Kind/archive filters compose with membership.
List creation is inline above the keyboard and preserves the capture draft. Both selectors share
a primitive-data DesignSystem component with a Liquid Glass matched-geometry transition and a
Reduce Motion fallback. The initial editor supports creation, rename and deletion; its final
page design is pending the user's specification. Deleting a custom list clears membership in
the same store transaction and never deletes thoughts. Detail supports moving existing thoughts.

The generic `ThoughtListTaskRepository` projects dated to-dos from a supplied list ID, defaulting
to Plan. The app, widgets and in-memory fallback use it. Import of legacy checklist rows now
belongs to the single thought repository; the duplicate SwiftData checklist actor is removed.
Plan's presentation keeps its date picker, explicit carry-forward, completion history and widgets.
V5→V6 migrates every previously shared to-do, including archived/completed ones, into Plan.
Automatic captures classified as to-dos and unfiled thoughts explicitly changed to to-dos still
enter Plan; explicit custom-list choices take precedence. Existing no-auto-expiry behavior for
to-dos remains, and Plan membership protects the rest of that list from expiry too.

**Alternatives.** A separate Plan store repeats storage and lifecycle rules. Assigning every
new to-do to Plan would override custom-list choices. Multiple memberships require an additional
selection model and delete semantics the requested single-list selector does not need. Treating
list names as identifiers makes renames break membership and device synchronization.

**Validation.** Storage regressions cover stable identity, case-insensitive names, non-destructive
list deletion and scoped task decisions. Migration preserves old records and completion dates.
Feature tests cover classification membership, capture into Plan and combined list/kind/archive
filters. Focused simulator tests exercise both glass selectors, draft-preserving creation and
Plan's daily review.

**API reference.** [Apple's custom Liquid Glass guidance](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).


## ADR-0061 · Text list controls, inline creation and keyboard-preserving dismissal

**Date:** 2026-10-05

**Context.** The first list selectors had inconsistent spacing, uniform purple text, an icon-only
collapsed state, and extra heading/close/new-list controls. The user requested a simpler dropdown
with restrained selection emphasis and outside dismissal that preserves capture focus.

**Decision.** Both directions use a 16-point panel inset, equally sized rows and one-pixel inset
separators. Unselected names use muted text; only the selected choice uses purple. The compact
control reads “Lists” or a selected name capped at ten characters plus ellipsis, with a fixed width
and full accessible label. Remove the internal heading and close button. An empty New list field
appears immediately on opening; Return or an inline check commits it. Outside taps dismiss the
selector and restore capture focus rather than dismissing the keyboard. VoiceOver uses Escape.

The glass surface keeps its identity while its width and measured height change. Opening and
closing share an anchored, critically damped spring, with no overshoot, timer, or input lockout.
Reduce Motion disables the spatial animation. Button press feedback is immediate. These choices
apply the installed `apple-design` skill’s principles using native SwiftUI.

**Alternative.** A close button duplicates outside dismissal and competes with the list choices.
A second new-list button makes a common operation require another step. Independent popover
surfaces lose the shared glass origin. A fullscreen accessibility button above the picker masks
its choices; the transparent outside-tap layer is excluded from accessibility, while the picker
supplies Escape.


## ADR-0062 · App-wide Apple-design pass

**Context.** The user requested evaluation and improvement of the entire app with the installed
apple-design skill. The audit exposed dark-mode foreground errors, oversized control glyphs at
accessibility sizes, undersized targets, keyboard focus churn, unclear return labels and visual
success feedback after failed writes.

**Decision.** Keep the existing product structure and serif identity. Share immediate custom-button
press feedback, a semantic foreground for purple fills, stable glyph sizes, adaptive page headers,
and stronger accessibility presentation of floating glass. Reading text continues to scale fully;
compact navigation text and icon targets do not consume its space. Group thought properties and
adapt settings/detail controls to available width. Preserve the fading body while keeping expiry
metadata and row actions readable. Use critically damped transitions for ordinary state changes,
and projected release travel for review gestures. Native controls retain native interaction behavior.

Make submission and decision feedback reflect actual writes. Plan keeps focus while saving.
Review failures retain the current card and tally; detail actions return success and dismiss only
after successful writes. Inline errors allow retry without adding a launch modal or alert flow.

**Alternatives.** Replacing the serif with the default sans would override the user’s established
preference. Scaling decorative glyphs like reading text steals its space. Applying opacity to an
entire row compounds muted metadata contrast. A visual overhaul of navigation or data behavior
would exceed this design pass. Physical animation polish is not inferred from static screenshots.

**Validation.** Feature regressions, four-appearance contrast tests, focused keyboard and review
interaction checks, and nine-destination screenshot routes in both appearances. Details and
remaining device-only acceptance are in `docs/DESIGN_AUDIT.md`.


## ADR-0063 · Native list-menu animation and explicit scrolling thought review

**Date:** 2026-10-06

**Context.** The user prefers the thought-kind filter's animation and requests the same for both
list controls. They also find Let go, Snooze and Keep imprecise, and prefer daily task review's
scrolling cards and in-card decisions.

**Decision.** Use the same SwiftUI Menu with an inline Picker for list selection. Remove custom
morphing geometry, spring timing and outside-tap capture. The system handles presentation and
reversal, including the menu above Home's keyboard. Keep the compact Lists/selected-name label.
New list opens a small anchored naming field from the native menu, retaining creation and draft
preservation. This replaces ADR-0061's always-visible input in a custom expanding panel in favor
of the user's requested system-menu behavior.

Thought review uses daily review's scrolling cards and the same shared native capsule controls.
Actions are Keep active (refresh now and remain visible), Hide for 7 days (pause visibility until
the displayed return date), and Archive (move to Archived without deletion). Avoid calling the
pause a reminder because the operation changes visibility; it does not schedule a dedicated
notification. Preserve optional answer capture, progress, summary, retries and horizontal
archive/keep shortcuts. Vertical gestures scroll the list. Decisions can target any pending card,
so choosing a later card must not erase the current card's draft answer or count a decision twice.

**Alternatives.** Tuning another custom spring cannot guarantee parity with the native menu.
Keeping an independently animated glass panel would repeat the inconsistency the user rejected.
A centered single-card stack does not match the requested task-review design. Ambiguous labels
force users to infer whether they are preserving or deleting their thoughts.

**Reference.** [SwiftUI Menu](https://developer.apple.com/documentation/swiftui/menu).


Directional card shortcuts use UIKit's gesture representable with an early horizontal-only
recognition decision. Ignoring vertical movement after a SwiftUI drag has already begun can
capture the scroll instead. Large-text scrolling and small/deliberate horizontal drags verify
both paths. [Apple gesture representable](https://developer.apple.com/documentation/swiftui/uigesturerecognizerrepresentable).


## ADR-0064 · Stacked list sheets and persistent list details

**Date:** 2026-10-06

**Context.** The user requests list management to open from below like Settings, one collection
including protected Plan, a separate creation action, metadata fields, and direct editing from
the selected list on Thoughts. Shared lists are explicitly deferred until their next message.

**Decision.** Use native sheet presentation for management and stack the shared list editor over
it. Use the same editor for Home/Thoughts creation and direct editing; preserve Home’s draft and
restore its focus on dismissal. Reuse Card, SectionLabel, typography/color tokens and native
controls rather than designing another panel animation. Plan is a plain row in the same section;
custom rows disclose their editable details. The separate Create list button is the manager’s
only creation entry. Existing picker creation entries also open the same complete form.

Lists persist a description and default thought kind. V7 adds defaulted fields through a
lightweight migration; existing lists remain Unsorted with empty descriptions. Capture honors
custom-list defaults, explicit choices take precedence, and Unsorted keeps existing background
classification. Description is stored for future list routing; this change adds no automatic
routing engine or sharing service. Removing a list continues to unfile thoughts without deletion.

**Alternatives.** A navigation push repeats the inconsistency with Settings. Separate create and
edit forms drift in behavior and design. Changing V6 in place breaks versioned stores. Converting
existing thoughts when a list default changes would rewrite a person’s earlier choices; defaults
apply only to subsequent captures. Implementing sharing now contradicts the requested deferral.


## ADR-0065 · Contextual Lists navigation, shared input controls and warm dark surfaces

**Date:** 2026-10-06

**Context.** The user requests four round default-type choices, an untitled editor with cross and
Create at opposite corners, one keyboard-down control throughout editing, a trash icon for list
deletion, and a Lists action extending the selected Thoughts tab. Dark palette changes require
approval; the user explicitly approved warm ink/espresso before implementation.

**Decision.** Preserve the native TabView and NavigationStacks, hide the system tab bar at each
stack, and supply one glass navigation bar. Thoughts’ selected capsule expands to two tab widths
and contains the contextual native Lists menu. Native Layout interpolation and matched geometry
share one spring without bounce; Reduce Motion removes movement. List selection changes the page
heading and returns to the inbox root. Thoughts’ primary button restores the all-lists view.

Reuse `RoundIconButton` and `ThoughtKindPicker` for the four choices and trash action. Use native
sheet toolbar placements with a leading cross, trailing Create/Save and no title. Reuse one glass
keyboard-down button and accessory modifier in every input flow. Each editing presentation observes keyboard notifications through the same modifier. Apply page
accessibility identifiers before its inset so they cannot overwrite the keyboard button’s own
identifier. Hiding the keyboard changes focus only and never clears a draft.

Dark surfaces become espresso/cocoa with warm ivory, taupe metadata and lavender accents; the
user’s off-white light palette remains unchanged. Brighten lavender text slightly after the
cocoa-card contrast audit showed 4.47:1, below AA; rerun all four appearance combinations.

**Alternatives.** Four independent peer tabs misrepresent Lists as another destination. A separate
floating list button would contradict the requested shared selected capsule. Replacing native
navigation stacks would risk losing their push state and sheet behavior. Independent type and
keyboard controls would drift again. Updating colors before approval would violate the user’s
explicit request. Sharing remains outside this revision.


## ADR-0066 · Native contextual tab set and sage on near-black brown

**Date:** 2026-10-06

**Context.** The custom bar remained full-width with three controls, had uneven grouped padding,
looked less like the system glass, and did not distinguish Thoughts from Lists. The user requests
checking native APIs before retaining custom navigation, noting Phone’s changing tab count. They
also request darker brown surfaces and an accent that complements them.

**Decision.** Replace the custom bar with native TabView. The public TabContent.hidden API allows
Lists to appear only in the Thoughts section, producing a compact three-tab bar elsewhere and a
four-tab bar there. A distinct Lists selection clarifies the active view. TabContent.popover
anchors the choices to its tab while preserving the bar. The selection binding also handles
re-tapping the already selected Lists tab. Synchronize selection after creation/deletion and
restore Thoughts after dismissing an unselected list chooser. Remove AppNavigationBar and the
navigation-specific GlassListPicker rendering branch. The system owns Liquid Glass and padding.

Animate only the tab-set expansion/contraction at the app level; keep selection/popover animation
native. Applying an extra spring within the section produced an intermittent XCTest animation-idle
pause during verification. Dark becomes near-black brown with muted sage controls; light retains
its existing purple/off-white palette. All contrast pairings continue to pass.

**Alternatives.** A refined custom bar would still duplicate a native feature. A two-tab highlight
would obscure which content is selected. Tab context menus target sidebar representations and
are not the needed tap interaction; a public tab popover supplies it directly. UIKit also exposes
setTabs(_:animated:), confirming dynamic tab counts are a supported system capability.

**Sources.** [Apple TabView](https://developer.apple.com/documentation/swiftui/tabview),
[TabContent popover](https://developer.apple.com/documentation/swiftui/tabcontent/popover(ispresented:attachmentanchor:arrowedge:content:)),
[UITabBarController](https://developer.apple.com/documentation/uikit/uitabbarcontroller).

**Verification.** Simulator assertions for native tab count, selected state, symmetric expanded
bounds, repeated list opening, persistent bar, list creation/editing/deletion and largest text.


## ADR-0067 · Permanent native tabs and selection after choosing a list

**Date:** 2026-10-06

**Context.** The user prefers a shared Thoughts/Lists pill with independent inner highlights, but
explicitly chooses an always-visible native Lists tab when native APIs do not support that pill.
Opening the chooser alone must not suggest that a list is being viewed.

**Decision.** Use the fallback: four native tabs on Home, Thoughts, Lists and Plan. Public
UITabGroup/TabSection APIs define hierarchy/sidebar grouping; the iPhone bar exposes one selected
tab and no grouped background around two distinct items. Remove contextual hiding and bar-count
animation. The Lists selection callback opens the native tab popover and leaves selection intact.
Do not reset the navigation stack until a destination is actually chosen. Choosing a collection
highlights Lists; All thoughts highlights Thoughts. Cancel/dismiss preserves the existing page.
Load the existing inbox/list data when the chooser opens, including from Home or Plan on a fresh
launch. Creation/deletion continue to synchronize selection with list membership. Keep native glass,
spacing, accessibility and the existing sage accent; no custom navigation replacement.

**Alternatives.** A custom shared capsule would violate the requested fallback priority. Selecting
Lists merely to open its popover incorrectly describes the current content. TabSection is not a
public way to draw the requested grouped iPhone pill.

**Sources.** [UITabGroup](https://developer.apple.com/documentation/uikit/uitabgroup),
[selectedTab](https://developer.apple.com/documentation/uikit/uitabbarcontroller/selectedtab),
[tab navigation](https://developer.apple.com/documentation/swiftui/enhancing-your-app-content-with-tab-navigation).


## ADR-0068 · Real Lists destination and shared selection/assignment controls

**Date:** 2026-10-06

**Context.** The user explicitly replaces the earlier chooser-preserves-tab requirement. Lists
must immediately select its own empty destination, stay selected while choosing, and forget its
navigation selection when left. They request actual lists plus Add List/Edit Lists, shared thought
assignment menus, unchanged row spacing with better typography, and a circular close bubble.

**Decision.** Keep four native tabs. Lists has an explicit inbox scope with an empty canvas until
a collection is selected. Clear only navigation membership filtering on exit; never write thought
membership when navigating. Remove All thoughts from navigation choices, because Thoughts already
serves that purpose. Selecting a collection does not switch tabs a second time.

Extract ListSelectionChoices into DesignSystem using string IDs. Reuse its rows, ticks, separators
and management actions for navigation and thought properties. Assignment retains No list and calls
the existing domain operation, including Plan’s dated-todo behavior. App-coordinated creation can
return the created list to the thought editor and opt out of navigation selection. Management
opened there likewise avoids redirecting the editor’s underlying tab.

Use title3 serif names and a four-point leading inset in the manager, preserving row min-height
and existing vertical insets. Use native icon-only labeling with circular border shape for Close.

**Alternatives.** Reusing navigation’s nil selection as saved assignment would unfile thoughts
without a user request. Keeping separate menu implementations repeats the drift the user identified.
Reducing row heights would contradict their explicit spacing preference. A custom tab bar remains
outside scope; this revision preserves the native Apple component.


## ADR-0069 · Native iCloud list collaboration over the original store

**Date:** 2026-10-06

**Context.** The user requests live shared lists using Apple's link/AirDrop/iCloud features without
hosting a server. They approve the proposal: custom lists first, protected personal Plan, native
invitation/management UI, editor/viewer access, personal habit progress/hiding and manual archiving.
SwiftData's public CloudKit configuration exposes private sync but no shared-database configuration.

**Decision.** Use NSPersistentCloudKitContainer with private and shared store descriptions in the
existing iCloud container. Generate the exact managed-object model using Apple's public
NSManagedObjectModel.makeManagedObjectModel bridge from the versioned SwiftData schema. Upgrade to
V8 through the existing migration plan, release SwiftData, then open the original private SQLite
file through Core Data. Preserve store UUID, existing record IDs and cloud metadata; keep a
coordinated, journal-aware pre-upgrade recovery snapshot. Cloud attachment failure retries the same
durable store locally before the existing memory fallback. Widgets/intents use the same foundation.

Share a custom list and its optional inverse thought relationship, including archived/completed
history. Repair graph membership before creating a share so unrelated lists and Plan cannot enter
it. Personal activity lives in a separate private entity with scalar IDs and no relationships to
the shared graph. To-do completion/archive/content are common; streaks, hiding and attention are
personal. Shared thoughts require manual archiving to avoid one person's decay settings archiving
content for everyone. Store-level native permissions and view-only controls enforce access.

UICloudSharingController supplies invitations and management (links, Messages/AirDrop where the
system offers them). New shares use publicPermission.none. Owners can choose invited-only or
anyone-link access and read/write permissions; participants can leave. Sharing/deleting Plan is
protected. Shared-list deletion requires stopping sharing first; existing shared thoughts cannot
move across shares. Default listing/name validation tolerates same-named received lists from
other owners. Native scene delegates accept cold/warm invitations, validate the container, and
route to the exact list after its shared zone imports. Async share/accept callbacks have bounded,
single-resume waits. Closing an editor while preparing prevents a late share sheet appearing elsewhere.

**Alternatives and cost.** A hosted backend contradicts the user's scope. A second CloudKit
collaboration container would duplicate the private store, identity and synchronization logic.
Hand-written CKRecord replication would require conflict, token, deletion, retry and migration
machinery already provided by Core Data. A copied/rebuilt private store risks losing mirroring
metadata and duplicating existing cloud records. Retaining only SwiftData does not expose the
required shared scope. The cost is a Core Data repository over the existing model, a second local
store, and signed two-account acceptance/schema deployment before release. Native sync is eventual,
not real-time; no external website or account system is introduced.

**Sources.** [Apple Core Data sharing](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users),
[SwiftData/Core Data coexistence](https://developer.apple.com/documentation/coredata/adopting-swiftdata-for-a-core-data-app),
[UICloudSharingController](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller),
[SwiftUI scene delegates](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor).

**Verification.** Tests cover model/store compatibility, preserved V7 identity/history/recovery,
share graph isolation, owner/editor/viewer writes, personal activity, durable offline reopening,
and focused unsigned UI flows. These do not claim an actual CloudKit invitation was delivered.
The signed two-account checklist is recorded in ICLOUD.md.
