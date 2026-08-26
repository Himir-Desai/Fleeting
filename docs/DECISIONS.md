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
