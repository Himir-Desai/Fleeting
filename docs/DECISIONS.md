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
