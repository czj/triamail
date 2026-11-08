import Foundation

/// Who writes: filled in Settings > Profile, never in the repository.
public struct Profile: Codable, Equatable, Sendable {
    public var firstName = ""
    public var fullName = ""
    public var role = ""
    public var company = ""
    /// Free text describing the companies (trade names, legal name, activity).
    public var companies = ""
    public var phone = ""
    public var website = ""
    public var supportURL = ""

    public init() {}

    /// The `{profil.…}` variables of the reply templates.
    public var variables: [String: String] {
        [
            "prenom": firstName,
            "nom_complet": fullName,
            "fonction": role,
            "entreprise": company,
            "entreprises": companies,
            "telephone": phone,
            "site_web": website,
            "url_support": supportURL,
        ]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value(_ key: CodingKeys) throws -> String { try container.decodeIfPresent(String.self, forKey: key) ?? "" }
        firstName = try value(.firstName)
        fullName = try value(.fullName)
        role = try value(.role)
        company = try value(.company)
        companies = try value(.companies)
        phone = try value(.phone)
        website = try value(.website)
        supportURL = try value(.supportURL)
    }
}

extension ReplyTemplate {
    /// Fields asked before writing: `{argument name="Intention et ton"}` → "Intention et ton".
    public var arguments: [String] {
        var seen: [String] = []
        for match in prompt.matches(of: /\{argument name="([^"]+)"[^}]*\}/) where !seen.contains(String(match.1)) {
            seen.append(String(match.1))
        }
        return seen
    }

    /// The prompt sent to the model: profile, mail thread and fields filled in.
    public func render(profile: Profile, selection: String, arguments values: [String: String] = [:]) -> String {
        var text = prompt.replacing(/\{argument name="([^"]+)"[^}]*\}/) { values[String($0.1)] ?? "" }
        text = text.replacing(/\{profil\.([a-z_]+)\}/) { profile.variables[String($0.1)] ?? "" }
        return text.replacingOccurrences(of: "{selection}", with: selection)
    }

    /// "repondre" → "Repondre", "dites-m-en-plus" → "Dites m en plus": a readable name from the file name.
    public var title: String {
        let words = id.replacingOccurrences(of: "-", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

extension MailMessage {
    /// The thread as the templates expect it in `{selection}`.
    public var quotedForPrompt: String {
        "De : \(from)\nÀ : \(to)\nDate : \(date.formatted(date: .long, time: .shortened))\nObjet : \(subject)\n\n\(plainText)"
    }
}
