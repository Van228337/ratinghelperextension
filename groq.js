// groq.js - Модуль взаимодействия с AI через защищённый серверный шлюз (без секретов на клиенте)

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

  // 1. Первичный структурный фильтр на клиенте (защита от пустого ввода, спама и рекламы)
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

    return { allowed: true };
  },

  // 2. Двухуровневая модерация через защищённый серверный шлюз
  async moderateReview(text) {
    // Шаг 1: Мгновенная локальная проверка структуры текста (0 ms)
    const localCheck = this.localPreFilter(text);
    if (!localCheck.allowed) {
      return localCheck;
    }

    // Шаг 2: Серверная проверка через шлюз (проверка ненормативной лексики и академический AI-анализ)
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

  // 3. Генерация AI-выжимки о преподавателе через защищённый серверный шлюз
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
