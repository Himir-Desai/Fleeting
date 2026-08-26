import Core
import Foundation

// Seeded data for screenshots, for exercising decay by hand, and for profiling against a store
// the size of a year's capture.
//
// Debug builds only. Kept out of ``AppEnvironment`` so the composition root stays a list of what
// the app is wired from, not a fixture file.
#if DEBUG
    @MainActor
    extension AppEnvironment {
        /// Launch argument that fills an empty store with thoughts at a spread of ages, for
        /// screenshots and for exercising decay by hand. Debug builds only.
        static let seedDemoArgument = "--seed-demo"

        /// One seeded thought, described by age and kind.
        private struct DemoThought {
            let body: String
            let age: Double
            let kind: ThoughtKind
            let streak: Int
            let sharpened: Bool

            init(
                _ body: String,
                age: Double,
                kind: ThoughtKind,
                streak: Int = 0,
                sharpened: Bool = false
            ) {
                self.body = body
                self.age = age
                self.kind = kind
                self.streak = streak
                self.sharpened = sharpened
            }
        }

        /// Fills in a finished interview, so the sharpened state is reachable without waiting
        /// for a model.
        /// - Parameters:
        ///   - thought: The idea to sharpen.
        ///   - date: When the interview happened.
        private static func attachDemoSharpening(to thought: inout Thought, at date: Date) {
            thought.beginSharpening(
                prompts: [
                    "Who reads this and actually changes what they use?",
                    "What is the hardest part of making it real?",
                    "What is the smallest thing you could do this week?"
                ],
                at: date
            )
            let answers = [
                "developers sick of every tool becoming a suite",
                "finding one genuinely good tool a week, forever",
                "write three issues and send them to ten people"
            ]
            for (question, answer) in zip(thought.sharpening?.questions ?? [], answers) {
                thought.answerSharpening(answer, to: question.id, at: date)
            }
            thought.attachWriteUp(
                WriteUp(
                    title: "A letter about tools that do one thing",
                    detail: """
                    A weekly letter about tools that do exactly one thing well. It is for \
                    developers sick of every tool becoming a suite. The hard part is finding one \
                    genuinely good tool a week, forever. The first thing to try is writing three \
                    issues and sending them to ten people.
                    """,
                    generatedAt: date
                ),
                at: date
            )
        }

        /// Launch argument that fills the store with several hundred thoughts, so scrolling and
        /// the decay engine can be profiled against something the size of a year's capture.
        static let seedManyArgument = "--seed-many"

        /// How many thoughts `--seed-many` inserts. Roughly a year at a thought a day.
        private static let manyCount = 400

        /// Fills the store with a large, deterministic backlog if asked.
        func seedManyIfRequested() async {
            guard ProcessInfo.processInfo.arguments.contains(Self.seedManyArgument),
                  let existing = try? await thoughts.thoughts(in: .all), existing.isEmpty
            else { return }

            let now = clock.now
            let kinds = ThoughtKind.allCases
            for index in 0 ..< Self.manyCount {
                let age = Double(index) * 0.25
                var thought = Thought(
                    body: "thought number \(index) about something worth remembering",
                    capturedAt: now.addingTimeInterval(-age * .day)
                )
                thought.applyClassification(kind: kinds[index % kinds.count], title: nil)
                try? await thoughts.add(thought)
            }
        }

        /// Inserts demo thoughts if asked and the store is empty.
        func seedDemoDataIfRequested() async {
            guard ProcessInfo.processInfo.arguments.contains(Self.seedDemoArgument),
                  let existing = try? await thoughts.thoughts(in: .all), existing.isEmpty
            else { return }

            let now = clock.now
            let demo = [
                DemoThought("ship the decay engine before it decays", age: 0.2, kind: .todo),
                DemoThought(
                    "stretch every morning before coffee",
                    age: 1.5,
                    kind: .habit,
                    streak: 6
                ),
                DemoThought(
                    "newsletter about tools that do one thing",
                    age: 40,
                    kind: .idea,
                    sharpened: true
                ),
                DemoThought("pay the parking fine", age: 13, kind: .todo),
                DemoThought(
                    "learn to sail? or a boat-shaped midlife crisis",
                    age: 80,
                    kind: .idea
                )
            ]

            for entry in demo {
                let captured = now.addingTimeInterval(-entry.age * .day)
                var thought = Thought(
                    body: entry.body,
                    capturedAt: captured,
                    streak: entry.streak > 0
                        ? Streak(count: entry.streak, lastMarkedAt: captured)
                        : nil
                )
                thought.applyClassification(kind: entry.kind, title: nil)
                if entry.sharpened {
                    Self.attachDemoSharpening(to: &thought, at: captured)
                }
                try? await thoughts.add(thought)
            }
        }
    }
#endif
