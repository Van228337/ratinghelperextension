import Foundation

public struct ModerationCheckResult: Sendable {
    public let allowed: Bool
    public let reason: String?

    public init(allowed: Bool, reason: String? = nil) {
        self.allowed = allowed
        self.reason = reason
    }
}

public struct TextPreFilter: Sendable {
    public static func preFilter(_ text: String) -> ModerationCheckResult {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count < 15 {
            return ModerationCheckResult(allowed: false, reason: "Отзыв слишком короткий (минимум 15 символов).")
        }
        if cleaned.count > 1200 {
            return ModerationCheckResult(allowed: false, reason: "Отзыв слишком длинный (максимум 1200 символов).")
        }

        // Check words count
        let words = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { $0.count >= 2 }
        if words.count < 3 {
            return ModerationCheckResult(allowed: false, reason: "Пожалуйста, напишите развернутый совет хотя бы из 3-4 слов.")
        }

        // Check letter proportion (at least 60%)
        let letterRegex = try? NSRegularExpression(pattern: "[a-zA-Zа-яА-ЯёЁ]")
        let letterCount = letterRegex?.numberOfMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) ?? 0
        if Double(letterCount) / Double(cleaned.count) < 0.6 {
            return ModerationCheckResult(allowed: false, reason: "Текст содержит слишком много бессмысленных символов или знаков.")
        }

        // Spam repeating characters (5 or more identical chars)
        let repeatRegex = try? NSRegularExpression(pattern: "(.)\\1{4,}")
        if let rep = repeatRegex, rep.numberOfMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) > 0 {
            return ModerationCheckResult(allowed: false, reason: "Текст содержит спам повторяющимися символами.")
        }

        // Consonant mash
        let consonantRegex = try? NSRegularExpression(pattern: "[бвгджзйклмнпрстфхцчшщБВГДЖЗЙКЛМНПРСТФХЦЧШЩ]{6,}|[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{6,}")
        if let con = consonantRegex, con.numberOfMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) > 0 {
            return ModerationCheckResult(allowed: false, reason: "Обнаружен бессмысленный набор согласных букв.")
        }

        // Links and ad spam
        let spamRegex = try? NSRegularExpression(
            pattern: "(https?://|t\\.me/|vk\\.com/|bit\\.ly|v\\.gd|\\.xyz\\b|\\.top\\b|казино|ставки|крипт|промокод|вейп|курилка)",
            options: .caseInsensitive
        )
        if let sp = spamRegex, sp.numberOfMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) > 0 {
            return ModerationCheckResult(allowed: false, reason: "Публикация ссылок и рекламы запрещена.")
        }

        // Check profanity with homoglyphs & transliteration
        if containsProfanity(cleaned) {
            return ModerationCheckResult(allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления.")
        }

        return ModerationCheckResult(allowed: true)
    }

    private static func normalizeHomoglyphs(_ str: String) -> String {
        let homoglyphs: [Character: Character] = [
            "a": "а", "b": "в", "c": "с", "e": "е", "h": "н", "k": "к", "m": "м",
            "o": "о", "p": "р", "t": "т", "x": "х", "y": "у", "u": "у", "i": "и",
            "j": "й", "w": "в", "v": "в", "z": "з", "g": "г", "n": "п", "r": "г",
            "d": "д", "l": "л", "s": "с", "f": "ф", "q": "к",
            "0": "о", "1": "и", "3": "з", "4": "ч", "@": "а", "$": "с"
        ]
        return String(str.map { homoglyphs[$0] ?? $0 })
    }

    private static func normalizeTranslit(_ str: String) -> String {
        var text = str
        let translitMap: [(String, String)] = [
            ("shch", "щ"), ("sch", "щ"), ("ch", "ч"), ("sh", "ш"), ("zh", "ж"),
            ("kh", "х"), ("ts", "ц"), ("ya", "я"), ("yu", "ю"), ("yo", "ё"),
            ("hui", "хуй"), ("huy", "хуй"), ("xui", "хуй"), ("xuy", "хуй"),
            ("pizd", "пизд"), ("blya", "бля"), ("suka", "сука"), ("ebat", "ебат"), ("yob", "ёб")
        ]
        for (pat, rep) in translitMap {
            text = text.replacingOccurrences(of: pat, with: rep)
        }
        return normalizeHomoglyphs(text)
    }

    private static func containsProfanity(_ text: String) -> Bool {
        let lower = text.lowercased()
        let homoglyph = normalizeHomoglyphs(lower)
        let translit = normalizeTranslit(lower)

        let safeWords: Set<String> = [
            "тебя", "себя", "колебания", "колебание", "колеблется", "колеблюсь", "потребовать", "потребовал", "требовать", "требования", "требует", "требуют",
            "потребность", "употреблять", "употребление", "хлеб", "хлеба", "гребля", "лебедь", "лебедка", "стебель", "стебли", "сабля",
            "рубль", "рубли", "дубль", "дубли", "судебный", "судьба", "психует", "психолог", "страхует", "страховка",
            "худеть", "худой", "художник", "художественный", "люблю", "влюблен", "скребут", "гребут"
        ]

        let versions = [lower, homoglyph, translit]

        for ver in versions {
            let tokens = ver.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            for token in tokens {
                if safeWords.contains(token) { continue }

                // Check profanity stems
                if matches(token, pattern: "^(за|на|по|про|вы|до|от|при|пере|с|под|у|долбо|раз|в|съ|об)?([её]б[а-яё]*|[её]пт[а-яё]*)$") {
                    if !matches(token, pattern: "^(теб|себ|треб|колеб|хлеб|лебед|стеб|греб|скреб|потреб|влюб)") {
                        return true
                    }
                }
                if matches(token, pattern: "^(на|по|за|до|при|не|от|раз|о|ни)?ху[йеяиюё][а-яё]*$") {
                    if !matches(token, pattern: "^(псих|страх|худож|худе|худо)") {
                        return true
                    }
                }
                if matches(token, pattern: "[а-яё]*п[ие]зд[а-яё]*") {
                    return true
                }
                if matches(token, pattern: "^(бля|бляд[а-яё]*|блят[а-яё]*)$") {
                    return true
                }
                if matches(token, pattern: "^сук[аиеоу]([а-яё]+)?$") && !token.hasPrefix("сукно") {
                    return true
                }
                if matches(token, pattern: "^(муд[ао][кчелг][а-яё]*|пид[оа]р[а-яё]*|шлюх[а-яё]*|чмо|ублюд[а-яё]*|мраз[а-яё]*|паскуд[а-яё]*|г[ао]ндон[а-яё]*|дроч[а-яё]*|письк[а-яё]*|сиськ[а-яё]*|жоп[а-яё]*|перд[а-яё]*|сперм[а-яё]*|вагин[а-яё]*|елда[а-яё]*|трах[а-яё]*|минет[а-яё]*|залуп[а-яё]*|дебил[а-яё]*|даун[а-яё]*|лошар[а-яё]*|аутист[а-яё]*|шмар[а-яё]*)$") {
                    return true
                }
            }
        }

        return false
    }

    private static func matches(_ string: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        let range = NSRange(string.startIndex..., in: string)
        return regex.numberOfMatches(in: string, range: range) > 0
    }
}
