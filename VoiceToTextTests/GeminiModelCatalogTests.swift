import Testing
@testable import VoiceToText

@Suite("GeminiModelCatalog")
struct GeminiModelCatalogTests {

    @Test("keeps only models that support generateContent")
    func filtersToGenerateContentOnly() {
        let models = [
            GeminiModelCatalog.ListModelsResponse.Model(
                name: "models/gemini-3.1-flash-lite",
                supportedGenerationMethods: ["generateContent"]
            ),
            GeminiModelCatalog.ListModelsResponse.Model(
                name: "models/embedding-001",
                supportedGenerationMethods: ["embedContent"]
            )
        ]

        #expect(GeminiModelCatalog.modelNames(from: models) == ["gemini-3.1-flash-lite"])
    }

    @Test("strips the models/ prefix from the name")
    func stripsModelsPrefix() {
        let models = [
            GeminiModelCatalog.ListModelsResponse.Model(
                name: "models/gemini-2.5-flash",
                supportedGenerationMethods: ["generateContent"]
            )
        ]

        #expect(GeminiModelCatalog.modelNames(from: models) == ["gemini-2.5-flash"])
    }

    @Test("a model with no supportedGenerationMethods is dropped, not crashed on")
    func dropsModelsWithNoMethods() {
        let models = [
            GeminiModelCatalog.ListModelsResponse.Model(name: "models/mystery", supportedGenerationMethods: nil)
        ]

        #expect(GeminiModelCatalog.modelNames(from: models).isEmpty)
    }

    @Test("an empty selection defaults to the first model on offer")
    func emptySelectionTakesFirstModel() {
        #expect(
            GeminiModelCatalog.defaultedSelection(current: "", from: ["gemini-3.1-flash-lite", "gemini-2.5-flash"])
                == "gemini-3.1-flash-lite"
        )
    }

    @Test("a selection that survived the refresh is kept, not reset to the first model")
    func keepsStillValidSelection() {
        #expect(
            GeminiModelCatalog.defaultedSelection(current: "gemini-2.5-flash", from: ["gemini-3.1-flash-lite", "gemini-2.5-flash"])
                == "gemini-2.5-flash"
        )
    }

    @Test("a selection Google no longer offers falls back to the first model")
    func replacesRetiredSelection() {
        #expect(
            GeminiModelCatalog.defaultedSelection(current: "gemini-1.0-retired", from: ["gemini-3.1-flash-lite"])
                == "gemini-3.1-flash-lite"
        )
    }

    @Test("an empty model list leaves a hand-typed selection alone")
    func emptyListDoesNotClobberManualEntry() {
        #expect(GeminiModelCatalog.defaultedSelection(current: "typed-by-hand", from: []) == "typed-by-hand")
        #expect(GeminiModelCatalog.defaultedSelection(current: "", from: []) == "")
    }
}
