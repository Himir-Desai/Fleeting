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
