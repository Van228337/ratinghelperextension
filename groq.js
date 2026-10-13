// groq.js - Модуль взаимодействия с AI через защищённый серверный шлюз и локальный фильтр с защитой от транслита

const SusuGroq = {
  _cachedGatewayUrl: null,

  async getGatewayUrl() {
    if (this._cachedGatewayUrl) return this._cachedGatewayUrl;
    try {
      if (typeof SusuSupabase !== "undefined" && typeof SusuSupabase.getConfig === "function") {
        const url = await SusuSupabase.getConfig("google_drive_script_url");
        if (url) {
          this._cachedGatewayUrl = url.trim();
          return this._cachedGatewayUrl;
        }
      }
    } catch {}
    return "";
  },

  // 1. Нормализация омоглифов и транслита
  normalizeText(str) {
    if (!str) return { raw: "", homoglyph: "", translit: "" };
    const lower = str.toLowerCase();

    // Замена латинских букв-близнецов на кириллицу (омоглифы)
    const homoglyphs = {
      "a": "а", "b": "в", "c": "с", "e": "е", "h": "н", "k": "к", "m": "м",
      "o": "о", "p": "р", "t": "т", "x": "х", "y": "у", "u": "у", "i": "и",
      "j": "й", "w": "в", "v": "в", "z": "з", "g": "г", "n": "п", "r": "г",
      "d": "д", "l": "л", "s": "с", "f": "ф", "q": "к",
      "0": "о", "1": "и", "3": "з", "4": "ч", "@": "а", "$": "с"
    };

    let hText = "";
    for (const ch of lower) {
      hText += homoglyphs[ch] || ch;
    }

    // Фонетический транслит
    const translitMap = [
      [/shch/g, "щ"], [/sch/g, "щ"], [/ch/g, "ч"], [/sh/g, "ш"], [/zh/g, "ж"],
      [/kh/g, "х"], [/ts/g, "ц"], [/ya/g, "я"], [/yu/g, "ю"], [/yo/g, "ё"],
      [/hui/g, "хуй"], [/huy/g, "хуй"], [/xui/g, "хуй"], [/xuy/g, "хуй"],
      [/pizd/g, "пизд"], [/blya/g, "бля"], [/suka/g, "сука"], [/ebat/g, "ебат"], [/yob/g, "ёб"]
    ];

    let tText = lower;
    for (const [pat, rep] of translitMap) {
      tText = tText.replace(pat, rep);
    }
    let thText = "";
    for (const ch of tText) {
      thText += homoglyphs[ch] || ch;
    }

    return { raw: lower, homoglyph: hText, translit: thText };
  },

  // 2. Первичный структурный фильтр на клиенте (с защитой от транслита и спецсимволов)
  localPreFilter(text) {
    if (!text || typeof text !== "string") {
      return { allowed: false, reason: "Текст отзыва не может быть пустым" };
    }
    const cleaned = text.trim();
    if (cleaned.length < 15) {
      return { allowed: false, reason: "Отзыв слишком короткий (минимум 15 символов)" };
    }
    if (cleaned.length > 1200) {
      return { allowed: false, reason: "Отзыв слишком длинный (максимум 1200 символов)" };
    }

    // Проверка на количество слов (минимум 3 реальных слова)
    const words = cleaned.split(/\s+/).filter((w) => w.length >= 2);
    if (words.length < 3) {
      return { allowed: false, reason: "Пожалуйста, напишите развернутый совет хотя бы из 3-4 слов" };
    }

    // Проверка на долю букв (не менее 60% текста)
    const letterCount = (cleaned.match(/[a-zа-яё]/gi) || []).length;
    if (letterCount / cleaned.length < 0.6) {
      return { allowed: false, reason: "Текст содержит слишком много бессмысленных символов или знаков" };
    }

    // Защита от спама повторяющимися символами
    if (/(.)\1{4,}/.test(cleaned)) {
      return { allowed: false, reason: "Текст содержит спам повторяющимися символами" };
    }

    // Бессмысленный набор согласных букв
    if (/[бвгджзйклмнпрстфхцчшщ]{6,}|[bcdfghjklmnpqrstvwxyz]{6,}/i.test(cleaned)) {
      return { allowed: false, reason: "Обнаружен бессмысленный набор букв" };
    }

    // Защита от спам-ссылок, рекламы и казино
    const spamRegex = /(https?:\/\/|t\.me\/|vk\.com\/|bit\.ly|v\.gd|\.xyz\b|\.top\b|казино|ставки|крипт|промокод|вейп|курилка)/i;
    if (spamRegex.test(cleaned)) {
      return { allowed: false, reason: "Публикация ссылок и рекламы запрещена" };
    }

    // 3. Проверка ненормативной лексики с учётом транслита, омоглифов и скрытия точками
    const { raw, homoglyph, translit } = this.normalizeText(cleaned);

    const safeWords = new Set([
      "тебя", "себя", "колебания", "колебание", "колеблется", "колеблюсь", "потребовать", "потребовал", "требовать", "требования", "требует", "требуют",
      "потребность", "употреблять", "употребление", "хлеб", "хлеба", "гребля", "лебедь", "лебедка", "стебель", "стебли", "сабля",
      "рубль", "рубли", "дубль", "дубли", "судебный", "судьба", "психует", "психолог", "страхует", "страховка",
      "худеть", "худой", "художник", "художественный", "люблю", "влюблен", "скребут", "гребут"
    ]);

    const versionsToCheck = [raw, homoglyph, translit];

    for (const ver of versionsToCheck) {
      // А. Проверка по токенам слов
      const tokens = ver.replace(/[^a-zа-яё0-9\s]/gi, " ").split(/\s+/).filter(Boolean);
      for (const w of tokens) {
        if (safeWords.has(w)) continue;

        if (/^(за|на|по|про|вы|до|от|при|пере|с|под|у|долбо|раз|в|съ|об)?([её]б[а-яё]*|[её]пт[а-яё]*)$/.test(w)) {
          if (!/^(теб|себ|треб|колеб|хлеб|лебед|стеб|греб|скреб|потреб|влюб)/.test(w)) {
            return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
          }
        }

        if (/^(на|по|за|до|при|не|от|раз|о|ни)?ху[йеяиюё][а-яё]*$/.test(w)) {
          if (!/^(псих|страх|худож|худе|худо)/.test(w)) {
            return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
          }
        }

        if (/[а-яё]*п[ие]зд[а-яё]*/.test(w)) {
          return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
        }

        if (/^(бля|бляд[а-яё]*|блят[а-яё]*)$/.test(w)) {
          return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
        }

        if (/^сук[аиеоу]([а-яё]+)?$/.test(w) && !/^сукно/.test(w)) {
          return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
        }

        if (/^(муд[ао][кчелг][а-яё]*|пид[оа]р[а-яё]*|шлюх[а-яё]*|чмо|ублюд[а-яё]*|мраз[а-яё]*|паскуд[а-яё]*|г[ао]ндон[а-яё]*|дроч[а-яё]*|письк[а-яё]*|сиськ[а-яё]*|жоп[а-яё]*|перд[а-яё]*|сперм[а-яё]*|вагин[а-яё]*|елда[а-яё]*|трах[а-яё]*|минет[а-яё]*|залуп[а-яё]*|дебил[а-яё]*|даун[а-яё]*|лошар[а-яё]*|аутист[а-яё]*|шмар[а-яё]*)$/.test(w)) {
          return { allowed: false, reason: "Текст содержит ненормативную лексику, пошлости или оскорбления" };
        }
      }

      // Б. Проверка слов со скрывающими символами (х.у.й, х_у_й, х-у-й и т.д.)
      const cleanedWords = ver.split(/\s+/).map((w) => w.replace(/[^а-яёa-z]/g, "")).filter(Boolean);
      for (const cw of cleanedWords) {
        if (safeWords.has(cw)) continue;
        if (/^(на|по|за|до|при|не|от|раз|о|ни)?ху[йеяиюё][а-яё]*$/.test(cw) && !/^(псих|страх|худож|худе|худо)/.test(cw)) {
          return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
        }
        if (/п[ие]зд[а-яё]*/.test(cw)) {
          return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
        }
      }
    }

    return { allowed: true };
  },

  // 3. Двухуровневая модерация через защищённый серверный шлюз
  async moderateReview(text) {
    // Шаг 1: Мгновенная локальная проверка структуры текста, мата и транслита (0 ms)
    const localCheck = this.localPreFilter(text);
    if (!localCheck.allowed) {
      return localCheck;
    }

    // Шаг 2: Серверная проверка через шлюз (академический AI-анализ на осмысленность)
    try {
      const gatewayUrl = await this.getGatewayUrl();
      if (!gatewayUrl) {
        return { allowed: true };
      }

      const res = await fetch(gatewayUrl, {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify({
          action: "moderateReview",
          text: text.trim()
        })
      });

      if (res.ok) {
        const data = await res.json();
        if (data && typeof data.allowed === "boolean") {
          return data;
        }
      }
    } catch (e) {
      console.warn("Gateway moderation fallback:", e);
    }

    return { allowed: true };
  },

  // 4. Генерация AI-выжимки о преподавателе через защищённый серверный шлюз
  async generateTeacherSummary(teacherName, reviews) {
    if (!reviews || reviews.length === 0) return "";
    try {
      const gatewayUrl = await this.getGatewayUrl();
      if (!gatewayUrl) return "";

      const res = await fetch(gatewayUrl, {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify({
          action: "generateSummary",
          teacherName,
          reviews: reviews.slice(0, 15).map((r) => ({
            text: r.text,
            difficulty: r.difficulty,
            gives_avtomat: r.gives_avtomat,
            attendance_strict: r.attendance_strict
          }))
        })
      });

      if (res.ok) {
        const data = await res.json();
        if (data && data.success && data.summary) {
          return data.summary.trim();
        }
      }
    } catch (e) {
      console.warn("Gateway summary failed:", e);
    }
    return "";
  }
};

if (typeof window !== "undefined") {
  window.SusuGroq = SusuGroq;
}
if (typeof module !== "undefined" && module.exports) {
  module.exports = SusuGroq;
}
