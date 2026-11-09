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

}

/// A reply template: one `.md` file in `modeles/`, an optional front matter, then the prompt.
///
///     ---
///     titre: Répondre
///     bouton: Répondre
///     raccourci: cmd+shift+1
///     icone: arrowshape.turn.up.left
///     ---
///     prompt…
///
/// Without front matter (older or hand-written files), the title comes from the file name.
public struct ReplyTemplate: Identifiable, Hashable, Sendable {
    /// The file name without extension; empty for a template not saved yet.
    public var id: String
    public var title: String
    /// The button's label on the mail; the title when empty.
    public var buttonLabel: String
    public var shortcut: TemplateShortcut?
    /// An SF Symbol name.
    public var icon: String?
    public var prompt: String

    public init(id: String, title: String? = nil, buttonLabel: String = "", shortcut: TemplateShortcut? = nil, icon: String? = nil, prompt: String) {
        self.id = id
        self.title = title ?? Self.title(fromFileName: id)
        self.buttonLabel = buttonLabel
        self.shortcut = shortcut
        self.icon = icon
        self.prompt = prompt
    }

    /// Reads a file's text: front matter if any, then the prompt.
    public init(id: String, contents: String) {
        guard let (fields, prompt) = Self.frontMatter(in: contents) else {
            self.init(id: id, prompt: contents)
            return
        }
        self.init(id: id,
                  title: fields["titre"].flatMap { $0.isEmpty ? nil : $0 },
                  buttonLabel: fields["bouton"] ?? "",
                  shortcut: fields["raccourci"].flatMap(TemplateShortcut.init),
                  icon: fields["icone"].flatMap { $0.isEmpty ? nil : $0 },
                  prompt: prompt)
    }

    /// The file's text, front matter first.
    public var fileContents: String {
        var lines = ["---", "titre: \(title.singleLine)"]
        if !buttonLabel.isEmpty { lines.append("bouton: \(buttonLabel.singleLine)") }
        if let shortcut { lines.append("raccourci: \(shortcut.rawValue)") }
        if let icon, !icon.isEmpty { lines.append("icone: \(icon.singleLine)") }
        lines.append("---")
        return lines.joined(separator: "\n") + "\n" + prompt
    }

    public var label: String { buttonLabel.isEmpty ? title : buttonLabel }

    /// "repondre" → "Repondre", "dites-m-en-plus" → "Dites m en plus": a readable name from the file name.
    static func title(fromFileName id: String) -> String {
        let words = id.replacingOccurrences(of: "-", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// `---` on the first line, `key: value` lines, `---`: the fields and the text after them.
    static func frontMatter(in contents: String) -> ([String: String], String)? {
        // "\r\n" is one Character in Swift: Windows line endings would hide every line break.
        let lines = contents.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else { return nil }
        var fields: [String: String] = [:]
        for line in lines[1..<end] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            fields[line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return (fields, lines[(end + 1)...].joined(separator: "\n"))
    }

    /// The app's own shortcuts on the mail window (`.keyboardShortcut` in MainView, InvoicePane) and the
    /// standard menu ones: a template cannot take them. Keep in step when a view adds a shortcut.
    public static let reservedShortcuts: [TemplateShortcut] = [String]([
        "cmd+e", "cmd+s", "cmd+r", "cmd+shift+y", "cmd+shift+k", "cmd+option+0",
        "cmd+1", "cmd+2", "cmd+3", "cmd+4", "cmd+,", "cmd+n", "cmd+w", "cmd+q", "cmd+f",
    ]).compactMap(TemplateShortcut.init)

    /// Why each template's shortcut cannot be used, by template ID: taken by the app, or by another template.
    public static func shortcutProblems(in templates: [ReplyTemplate]) -> [ReplyTemplate.ID: String] {
        var problems: [ReplyTemplate.ID: String] = [:]
        for template in templates {
            guard let shortcut = template.shortcut else { continue }
            if reservedShortcuts.contains(shortcut) {
                problems[template.id] = "\(shortcut.symbols) est déjà un raccourci de Triamail."
            } else if let other = templates.first(where: { $0.id != template.id && $0.shortcut == shortcut }) {
                problems[template.id] = "\(shortcut.symbols) est déjà pris par « \(other.title) »."
            }
        }
        return problems
    }
}

/// A template's keyboard shortcut, stored as `cmd+shift+1`.
public struct TemplateShortcut: Hashable, Sendable {
    public enum Modifier: String, CaseIterable, Sendable {
        // In the order macOS shows them: ⌃⌥⇧⌘.
        case control, option, shift, cmd

        var symbol: String {
            switch self {
            case .control: "⌃"
            case .option: "⌥"
            case .shift: "⇧"
            case .cmd: "⌘"
            }
        }
    }

    public var modifiers: Set<Modifier>
    /// One character, lowercase.
    public var key: Character

    public init(modifiers: Set<Modifier>, key: Character) {
        self.modifiers = modifiers
        self.key = Character(key.lowercased())
    }

    /// "cmd+shift+1"; "command", "opt", "alt", "ctrl" are accepted too.
    public init?(_ text: String) {
        var parts = text.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let last = parts.popLast(), last.count == 1, let key = last.first else { return nil }
        var modifiers: Set<Modifier> = []
        for part in parts {
            switch part {
            case "cmd", "command": modifiers.insert(.cmd)
            case "shift": modifiers.insert(.shift)
            case "option", "opt", "alt": modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            default: return nil
            }
        }
        self.init(modifiers: modifiers, key: key)
    }

    public var rawValue: String {
        (Modifier.allCases.reversed().filter(modifiers.contains).map(\.rawValue) + [String(key)]).joined(separator: "+")
    }

    /// "⇧⌘1", as menus show it.
    public var symbols: String {
        Modifier.allCases.filter(modifiers.contains).map(\.symbol).joined() + key.uppercased()
    }
}

extension String {
    /// "Répondre à l'été !" → "repondre-a-l-ete": a file name from a title.
    var fileNameSlug: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
            .lowercased()
            .replacing(/[^a-z0-9]+/, with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Front matter values hold one line.
    var singleLine: String {
        replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    }
}

extension MailMessage {
    /// The thread as the templates expect it in `{selection}`.
    public var quotedForPrompt: String {
        "De : \(from)\nÀ : \(to)\nDate : \(date.formatted(date: .long, time: .shortened))\nObjet : \(subject)\n\n\(plainText)"
    }
}
