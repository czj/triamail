import Foundation
import FoundationModels
import TriamailKit

/// Sends a prompt to the chosen model: the Mac's own, or Mistral.
enum AIService {
    static func complete(_ prompt: String, settings: SharedSettings) async throws -> String {
        switch settings.aiProvider {
        case .appleLocal:
            guard case .available = SystemLanguageModel.default.availability else {
                throw AIFailure.unavailable("Le modèle local de macOS n'est pas disponible sur ce Mac (Apple Intelligence). Choisis Mistral dans Réglages > IA.")
            }
            let response = try await LanguageModelSession().respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        case .mistral:
            guard let key = MistralClient.storedKey(), !key.isEmpty else {
                throw AIFailure.unavailable("Aucune clé Mistral : ajoute-la dans Réglages > IA.")
            }
            return try await MistralClient(apiKey: key, model: settings.mistralModel).complete(prompt: prompt)
        }
    }

    static var localModelStatus: String {
        switch SystemLanguageModel.default.availability {
        case .available: "Disponible sur ce Mac."
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible: "Ce Mac ne peut pas faire tourner le modèle local."
            case .appleIntelligenceNotEnabled: "Active Apple Intelligence dans Réglages Système."
            case .modelNotReady: "Le modèle est en cours de téléchargement."
            @unknown default: "Indisponible."
            }
        }
    }
}

/// Replies being written in the background, one per mail: you keep triaging meanwhile.
@MainActor @Observable
final class ReplyModel {
    enum State: Equatable {
        case writing(String)
        case ready(String)
        case failed(String)
        case saved
    }

    private(set) var states: [MailMessage.ID: State] = [:]
    private let source: any MailSource

    init(source: any MailSource) {
        self.source = source
    }

    func state(of message: MailMessage) -> State? { states[message.id] }

    /// The drafting in progress per mail: a new one (another template) replaces it, the old answer is dropped.
    private var tasks: [MailMessage.ID: Task<Void, Never>] = [:]

    func write(_ message: MailMessage, template: ReplyTemplate, arguments: [String: String], settings: SharedSettings) {
        tasks[message.id]?.cancel()
        states[message.id] = .writing(template.title)
        let prompt = template.render(profile: settings.profile, selection: message.quotedForPrompt, arguments: arguments)
        tasks[message.id] = Task {
            let state: State
            do {
                state = .ready(try await AIService.complete(prompt, settings: settings))
            } catch {
                state = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled else { return }
            states[message.id] = state
            tasks[message.id] = nil
        }
    }

    func update(_ message: MailMessage, text: String) {
        states[message.id] = .ready(text)
    }

    func discard(_ message: MailMessage) {
        tasks[message.id]?.cancel()
        tasks[message.id] = nil
        states[message.id] = nil
    }

    /// The reviewed text goes to Gmail's drafts, in the thread; sending stays a deliberate act.
    func saveDraft(_ message: MailMessage) async {
        guard case let .ready(text) = states[message.id] else { return }
        do {
            _ = try await source.createDraft(ReplyDraft(original: message, body: text))
            states[message.id] = .saved
        } catch {
            states[message.id] = .failed("Brouillon non créé : \(error.localizedDescription)")
        }
    }
}

/// Summaries of a mail or its whole thread, on click (C7).
@MainActor @Observable
final class SummaryModel {
    enum State: Equatable {
        case working
        case done(String)
        case failed(String)
    }

    private(set) var states: [MailMessage.ID: State] = [:]
    private let source: any MailSource

    init(source: any MailSource) {
        self.source = source
    }

    func state(of message: MailMessage) -> State? { states[message.id] }

    func summarize(_ message: MailMessage, settings: SharedSettings) {
        states[message.id] = .working
        Task {
            do {
                let thread = try await source.thread(of: message)
                let prompt = SummaryPrompt.make(thread: thread.isEmpty ? [message] : thread, account: message.account)
                states[message.id] = .done(try await AIService.complete(prompt, settings: settings))
            } catch {
                states[message.id] = .failed(error.localizedDescription)
            }
        }
    }

    func dismiss(_ message: MailMessage) {
        states[message.id] = nil
    }
}
