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
}
