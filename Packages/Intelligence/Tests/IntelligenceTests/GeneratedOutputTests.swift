#if canImport(FoundationModels)
    import Core
    import Foundation
    @testable import Intelligence
    import Testing

    @Suite("Generated output validation")
    struct GeneratedOutputTests {
        @available(iOS 26, macOS 26, *)
        @Test("invalid confidence falls back instead of accepting a malformed classification")
        func invalidConfidence() {
            for confidence in [Double.nan, .infinity, -0.1, 1.1] {
                let output = GeneratedClassification(
                    kind: "habit", title: "Run", confidence: confidence,
                    cadenceCount: 1, cadenceUnit: "days"
                )
                #expect(output.asDomain == .unknown)
            }
        }

        @available(iOS 26, macOS 26, *)
        @Test("cadence belongs only to habits")
        func cadenceRequiresHabit() {
            let output = GeneratedClassification(
                kind: " todo ", title: " Call mum ", confidence: 0.9,
                cadenceCount: 1, cadenceUnit: "weeks"
            )
            #expect(output.asDomain.kind == .todo)
            #expect(output.asDomain.title == "Call mum")
            #expect(output.asDomain.cadence == nil)
        }

        @available(iOS 26, macOS 26, *)
        @Test("duplicate and blank questions cannot create an unusable interview")
        func invalidInterview() {
            let output = GeneratedQuestions(questions: ["Who?", " who? ", " "])
            #expect(output.validatedQuestions.isEmpty)
            let valid = GeneratedQuestions(questions: [" Who? ", "Why?", "How?", "When?"])
            #expect(valid.validatedQuestions == ["Who?", "Why?", "How?"])
        }

        @available(iOS 26, macOS 26, *)
        @Test("empty write-ups fall back rather than replacing the idea with blank content")
        func blankWriteUp() {
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            #expect(GeneratedWriteUp(title: " ", detail: "An idea").asDomain(generatedAt: date) == nil)
            #expect(GeneratedWriteUp(title: "An idea", detail: "\n").asDomain(generatedAt: date) == nil)
            let valid = GeneratedWriteUp(title: " Title ", detail: " Detail ").asDomain(generatedAt: date)
            #expect(valid?.title == "Title")
            #expect(valid?.detail == "Detail")
            #expect(valid?.generatedAt == date)
        }
    }
#endif
