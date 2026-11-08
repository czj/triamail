import Foundation
import Testing
@testable import TriamailKit

@Suite struct LanguageTests {
    @Test func detectsEnglishAndAsksForTranslation() {
        let text = "Hello, we are pleased to send you our latest price list for the coming season. Let us know if you have any question."
        #expect(LanguageDetector.dominantLanguage(of: text)?.languageCode == "en")
        #expect(LanguageDetector.needsTranslation(text)?.languageCode == "en")
    }

    @Test func frenchNeedsNoTranslation() {
        let text = "Bonjour, nous avons le plaisir de vous adresser notre nouvelle liste de prix pour la saison prochaine."
        #expect(LanguageDetector.dominantLanguage(of: text)?.languageCode == "fr")
        #expect(LanguageDetector.needsTranslation(text) == nil)
    }

    @Test func tooShortToTell() {
        #expect(LanguageDetector.dominantLanguage(of: "OK merci") == nil)
    }

    @Test func paragraphsKeepBlankLines() {
        #expect(LanguageDetector.paragraphs(of: "Hello\n\nBye") == ["Hello", "", "Bye"])
    }
}
