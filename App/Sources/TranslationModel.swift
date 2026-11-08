import Foundation
import Observation
@preconcurrency import Translation
import TriamailKit

/// Automatic translation of foreign mails into French, on the Mac (Translation framework).
/// The only background work in the app: it changes nothing and nothing leaves the Mac.
@MainActor @Observable
final class TranslationModel {
    enum State: Equatable {
        case translating
        case done(String)
        /// The language pack is not installed yet: one click downloads it.
        case needsDownload
        case failed(String)
    }

    private(set) var languages: [MailMessage.ID: Locale.Language] = [:]
    private(set) var states: [MailMessage.ID: State] = [:]
    private let target = Locale.Language(identifier: "fr")

    func language(of message: MailMessage) -> Locale.Language? { languages[message.id] }
    func state(of message: MailMessage) -> State? { states[message.id] }

    /// Detects every new mail's language, then translates the foreign ones whose language is installed.
    func process(_ messages: [MailMessage]) async {
        for message in messages where languages[message.id] == nil && states[message.id] == nil {
            guard let language = LanguageDetector.needsTranslation(message.plainText, to: target) else { continue }
            languages[message.id] = language
        }
        for message in messages {
            guard let language = languages[message.id], states[message.id] == nil else { continue }
            let status = await LanguageAvailability().status(from: language, to: target)
            guard status == .installed else {
                states[message.id] = .needsDownload
                continue
            }
            await translate(message, from: language, with: TranslationSession(installedSource: language, target: target))
        }
    }

    /// Used by the view's `.translationTask` once the user has accepted the download.
    func translate(_ message: MailMessage, with session: TranslationSession) async {
        guard let language = languages[message.id] else { return }
        await translate(message, from: language, with: session)
    }

    private func translate(_ message: MailMessage, from language: Locale.Language, with session: TranslationSession) async {
        states[message.id] = .translating
        do {
            let text = try await Self.translate(LanguageDetector.paragraphs(of: message.plainText), with: session)
            states[message.id] = .done(text)
        } catch {
            states[message.id] = .failed(error.localizedDescription)
        }
    }

    /// Paragraph by paragraph, so the layout survives; blank lines stay blank.
    nonisolated private static func translate(_ paragraphs: [String], with session: TranslationSession) async throws -> String {
        let requests = paragraphs.enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
        var translated = paragraphs
        for response in try await session.translations(from: requests) {
            if let index = response.clientIdentifier.flatMap(Int.init) {
                translated[index] = response.targetText
            }
        }
        return translated.joined(separator: "\n")
    }
}

extension Locale.Language {
    /// "EN → FR"
    var shortCode: String { (languageCode?.identifier ?? "?").uppercased() }
}
