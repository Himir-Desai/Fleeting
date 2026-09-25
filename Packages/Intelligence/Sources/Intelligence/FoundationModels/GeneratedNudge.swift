#if canImport(FoundationModels)
    import FoundationModels

    /// A short reminder grounded in the captured note.
    @available(iOS 26, macOS 26, *)
    @Generable
    struct GeneratedNudge {
        @Guide(description: "One gentle sentence under twenty words, using the note's own wording")
        var line: String
    }
#endif
