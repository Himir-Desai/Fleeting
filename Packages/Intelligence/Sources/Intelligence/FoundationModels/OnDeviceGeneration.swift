#if canImport(FoundationModels)
    import FoundationModels

    /// Generates constrained responses using only Apple's on-device model.
    @available(iOS 26, macOS 26, *)
    enum OnDeviceGeneration {
        /// Generates a value if the model supports it and the complete request fits.
        static func respond<Content: Generable>(
            instructions: String,
            prompt: String,
            generating type: Content.Type,
            maximumResponseTokens: Int
        ) async throws -> Content? {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { return nil }
            if #available(iOS 27, macOS 27, *) {
                guard model.capabilities.contains(.guidedGeneration) else { return nil }
            }

            let session = LanguageModelSession(model: model, instructions: instructions)
            if #available(iOS 26.4, macOS 26.4, *) {
                let historyTokens = try await model.tokenCount(for: session.transcript)
                let promptTokens = try await model.tokenCount(for: prompt)
                let schemaTokens = try await model.tokenCount(for: Content.generationSchema)
                // Reserve space for the response and framework formatting; never truncate notes.
                guard historyTokens + promptTokens + schemaTokens + maximumResponseTokens + 128
                    <= model.contextSize else { return nil }
            }
            try Task.checkCancellation()
            let options = GenerationOptions(
                samplingMode: .greedy,
                maximumResponseTokens: maximumResponseTokens
            )
            if #available(iOS 27, macOS 27, *) {
                return try await session.respond(
                    to: prompt,
                    generating: type,
                    options: options,
                    contextOptions: ContextOptions(includeSchemaInPrompt: true)
                ).content
            }
            return try await session.respond(
                to: prompt, generating: type, options: options
            ).content
        }
    }
#endif
