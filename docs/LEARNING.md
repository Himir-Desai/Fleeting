# Learning Swift by building Fleeting

Fleeting is being built by someone fluent in other languages and new to Swift and iOS. This file is
both the **teaching contract** and the **progress log** — it records how instruction is delivered,
what has been covered, and when to stop explaining.

Swift is taught here as a **translation**, not from zero. Fundamentals (functions, types, classes,
async, data structures) are assumed. What gets explained is what Swift does *differently*, what it
has *no equivalent* for, and what is *idiomatic* versus merely legal.

---

## The ladder

Four rungs. Each one hands over more of the thinking. The trigger to climb is **demonstrated
understanding, not phase number** — the phase column is an expectation, not a schedule.

### Rung 1 · Walkthrough — *"I write, then I explain"*
Expected during **Phase 0–1**.

Code is written first, then explained in chat: the new Swift concepts it introduced, quoted back
against the actual lines, framed as *"in the language you know this would be X; Swift does Y
because Z."* Nothing is assumed to be obvious just because it compiles.

### Rung 2 · Fill the blank — *"you decide, then I write"*
Expected around **Phase 2–4**.

Before writing a file, its skeleton is shown with two or three deliberate blanks — a type choice, a
signature, an access level, a `let` versus `var`. The blanks target the concept the file is meant
to teach, never trivia. A correct answer means the file gets written; a wrong one gets a correction
and a second attempt at the same idea from a different angle. **Guessing is not a failure state** —
the wrong answer is the more useful teaching material.

### Rung 3 · Design first — *"you choose the shape"*
Expected around **Phase 5–6**.

The design question comes before any code: *struct or class here, and why? Should this be an enum
with associated values or three separate types? Does this need an actor?* The implementation
follows the chosen design — including down a chosen path that turns out to be wrong, because the
compiler error that follows teaches the constraint better than a warning would have.

### Rung 4 · Review — *"I write, you find the problems"*
Expected from **Phase 7**.

Code is written with no accompanying explanation. It gets read and questioned; only what's asked
about gets explained. This is the terminal state, and reaching it is the actual goal.

**Advancement rule.** Climb a rung after roughly a phase of answering without hints. Drop back a
rung whenever an unfamiliar area appears — arriving at concurrency or at CloudKit resets the level
for that area regardless of overall progress. Rungs are per-topic, not global.

---

## Concept ladder by phase

Each phase is a natural teaching vehicle for a specific cluster of Swift ideas. The ordering is a
consequence of what the app needs, not a syllabus imposed on it — which is why it works.

| Phase | Swift & iOS concepts it teaches |
|---|---|
| **0 · Foundations** | Value vs reference semantics (`struct` / `class` / `enum`). Optionals and the absence of null. Enums with associated values as real sum types. Protocols as capabilities rather than inheritance. Access control (`internal` by default, `public` at module edges). Swift Package Manager, modules, and why `import` is the unit of architecture. |
| **1 · Capture** | SwiftUI's declarative model — a view as a *function of state*, not an object you mutate. `@State` and state ownership. `@Observable` and the Observation framework. `some View` and opaque return types. Result builders (why `VStack { }` is not a closure you'd recognise). SwiftData `@Model`. |
| **2 · Decay** | Pure functions and testability. `Date`, `TimeInterval`, `Calendar` and why date maths is nobody's friend. Protocol-based dependency injection via `Clock`. Computed properties. `Comparable`, `Hashable`, `Identifiable` and protocol conformance as a design tool. The Swift Testing framework (`@Test`, `#expect`). |
| **3 · Classification** | Protocol-oriented polymorphism with three implementations of one interface. `some` vs `any` and existentials. Generics with constraints. `async`/`await`, `Task`, and structured concurrency. `throws`, `Result`, typed errors. `Sendable` and what Swift 6 is actually protecting you from. |
| **4 · Sharpen** | Actors and isolation. `AsyncSequence` and `AsyncStream` for streaming model output. Task cancellation and cooperative cancellation checks. Macros — what `@Generable` expands to and why guided generation beats parsing JSON. `@MainActor`. |
| **5 · Review** | Higher-order functions and the collection algebra (`map`, `filter`, `reduce`, `sorted(by:)`, `prefix`). Closures and capture semantics. `KeyPath`. SwiftUI gestures, transitions, `matchedGeometryEffect`, and the animation model. |
| **6 · Ambient** | Extensions and retroactive conformance. App extensions and process boundaries. Codable and serialisation across those boundaries. `UserDefaults` / App Groups. App Intents and how a macro-driven declaration becomes a Siri capability. Background task scheduling. |
| **7 · Sync** | ARC, reference cycles, `weak` and `unowned`. CloudKit's constraints leaking into schema design. Schema versioning and migration. Conflict resolution as a design problem, not an API call. |
| **8 · Ship** | Accessibility as an API surface. Instruments and profiling. Localisation-shaped code. Build configurations and release engineering. |

---

## Progress log

Updated as concepts are actually covered — not when they're mentioned in passing, but when they've
been used, explained, and answered back correctly.

**Current rung: 1 · Walkthrough** · Current phase: 0 · Foundations

| Concept | Status | Covered in |
|---|---|---|
| *(nothing yet — Phase 0 not started)* | | |

Legend: 🟢 confident · 🟡 explained, not yet applied unaided · 🔴 explained, still shaky

---

## Rules for the teaching, not the code

- **Production code stays production code.** No tutorial comments in real files. Teaching lives in
  chat and in this document. See [ADR-0011](DECISIONS.md).
- **Explain against the actual lines just written**, never against a toy example. The codebase is
  the textbook.
- **Lead with the contrast.** Every new concept is introduced as a difference from a language
  already known, then justified on Swift's own terms.
- **Name the idiom explicitly.** Code that compiles and code a Swift developer would write are
  different things, and the gap is most of the learning.
- **Don't explain the same thing twice.** If it's 🟢 in the progress log, it's assumed from then on.
