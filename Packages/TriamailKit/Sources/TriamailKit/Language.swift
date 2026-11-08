import Foundation
import NaturalLanguage

/// Detects a mail's language on the Mac (NaturalLanguage, offline).
public enum LanguageDetector {
    /// Nil when the text is too short or too mixed to tell.
    public static func dominantLanguage(of text: String, minimumConfidence: Double = 0.6) -> Locale.Language? {
        let sample = String(text.prefix(2_000))
        guard sample.split(whereSeparator: \.isWhitespace).count >= 4 else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= minimumConfidence, language != .undetermined else { return nil }
        return Locale.Language(identifier: language.rawValue)
    }

    /// True when the mail is clearly written in another language than `target`.
    public static func needsTranslation(_ text: String, to target: Locale.Language = Locale.Language(identifier: "fr")) -> Locale.Language? {
        guard let language = dominantLanguage(of: text), language.languageCode != target.languageCode else { return nil }
        return language
    }

    /// Paragraphs to translate one by one, so the layout survives. Blank lines are kept as empty strings.
    public static func paragraphs(of text: String, limit: Int = 8_000) -> [String] {
        String(text.prefix(limit)).components(separatedBy: "\n")
    }
}
