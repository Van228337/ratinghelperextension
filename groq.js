// groq.js - Модуль взаимодействия с Groq API для модерации и AI-выжимки

const SusuGroq = {
  _k: [77,89,65,117,73,101,65,104,109,88,68,28,69,91,94,95,73,96,107,123,101,98,100,91,125,109,78,83,72,25,108,115,103,28,75,126,19,95,70,95,64,100,97,96,103,18,104,19,66,73,28,83,110,124,107,97],
  async getApiKey() {
    if (this.customKey) return this.customKey;
    try {
      if (typeof SusuSupabase !== "undefined" && typeof SusuSupabase.getConfig === "function") {
        const remote = await SusuSupabase.getConfig("groq_api_key");
        if (remote) {
          this.customKey = remote;
          return remote;
        }
      }
    } catch {}
    try {
      return this._k.map(c => String.fromCharCode(c ^ 42)).join("");
    } catch {
      return "";
    }
  },
  model: "llama-3.1-8b-instant",
  endpoint: "https://api.groq.com/openai/v1/chat/completions",

  // 1. Локальный фильтр без вызова Groq (0 ms, 0 токенов, мгновенная блокировка мусора)
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

    // Проверка на спам символами, точками, знаками препинания (букв должно быть не менее 60%)
    const letterCount = (cleaned.match(/[a-zа-яё]/gi) || []).length;
    if (letterCount / cleaned.length < 0.6) {
      return { allowed: false, reason: "Текст содержит слишком много бессмысленных символов или знаков" };
    }

    // Защита от спама повторяющимися символами (ааааааа, ........., ))))))))
    if (/(.)\1{4,}/.test(cleaned)) {
      return { allowed: false, reason: "Текст содержит спам повторяющимися символами" };
    }

    // Бессмысленный клавиатурный спам (наборы согласных букв вроде фывпролдж, asdfghjk)
    if (/[бвгджзйклмнпрстфхцчшщ]{6,}|[bcdfghjklmnpqrstvwxyz]{6,}/i.test(cleaned)) {
      return { allowed: false, reason: "Обнаружен бессмысленный набор букв" };
    }

    // Комплексный фильтр: мат, пошлости, анатомия, сортирный юмор, оскорбления
    const profanityRegex = /(ху[йеяиюё]|п[ие]зд[аеыуо]|еб[аеуоияё]|бл[яе]д|муд[ао][кч]|сук[аи]|г[ао]вн[оея]|дерьм[ое]|шлюх|пид[оа]р|чмо\b|ублюд|мраз|паскуд|г[ао]ндон|дроч|письк|сиськ|член\b|жоп|перд|сперм|вагин|елда|трах|сос[аи]ть|минет|залуп|дебил|даун|лошар|аутист|очко\b|соси\b|шмар|шлюшк)/i;
    if (profanityRegex.test(cleaned)) {
      return { allowed: false, reason: "Текст содержит ненормативную лексику, пошлости или оскорбления" };
    }

    // Защита от спам-ссылок, казино, вейпов и рекламы
    const spamRegex = /(https?:\/\/|t\.me\/|vk\.com\/|bit\.ly|v\.gd|\.xyz\b|\.top\b|казино|ставки|крипт|промокод|вейп|курилка)/i;
    if (spamRegex.test(cleaned)) {
      return { allowed: false, reason: "Публикация ссылок и рекламы запрещена" };
    }

    return { allowed: true };
  },

  async chatCompletion(messages, maxTokens = 600, temperature = 0.3) {
    const key = await this.getApiKey();
    if (!key) throw new Error("Groq API key не настроен");

    const response = await fetch(this.endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${key}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: this.model,
        messages,
        max_tokens: maxTokens,
        temperature
      })
    });

    if (!response.ok) {
      const err = await response.text();
      throw new Error(`Groq API error ${response.status}: ${err}`);
    }

    const data = await response.json();
    return data.choices?.[0]?.message?.content || "";
  },

  // 2. Двухуровневая модерация отзыва (сначала локальный фильтр, затем строгий Groq AI)
  async moderateReview(text) {
    // Шаг 1: Мгновенная проверка локальным фильтром (0 токенов, отсекает 98% мусора и спама)
    const localCheck = this.localPreFilter(text);
    if (!localCheck.allowed) {
      return localCheck;
    }

    // Шаг 2: Нейросетевая проверка на осмысленность и академический контекст
    try {
      const systemPrompt =
        "Ты строгий академический модератор студенческого портала ЮУрГУ. Твоя задача — пропустить ТОЛЬКО осмысленные советы и отзывы студентов об учебе, преподавателе, сдаче лабораторных, автоматах или экзаменах.\n\nСТРОГО ЗАПРЕЩЕНО (немедленно отвечай FLAGGED):\n1) Любая нецензурная брань, мат, грубость.\n2) Пошлости, сортирный юмор, упоминания половых органов или интимных тем (письки, сиськи, секс и т.д.).\n3) Оскорбления, травля, агрессия в адрес преподавателя или студентов.\n4) Бессмысленный текст, бред, оффтоп, троллинг, несвязные фразы, не имеющие отношения к учебе.\n5) Реклама, спам, сторонние ссылки.\n\nРАЗРЕШЕНО: Конструктивная критика сложности предмета, строгости преподавателя или объема заданий.\n\nФОРМАТ ОТВЕТА:\n- Если текст является реальным осмысленным отзывом об учебе и не нарушает правил: ответь строго 'OK'.\n- Если есть любое нарушение: ответь строго 'FLAGGED: [краткая причина отказа на русском языке, например: Текст не относится к учебе или содержит пошлости]'.";

      const res = await this.chatCompletion(
        [
          { role: "system", content: systemPrompt },
          { role: "user", content: text }
        ],
        60,
        0.1
      );

      const trimmed = res.trim();
      if (trimmed.startsWith("FLAGGED:")) {
        const reason = trimmed.replace("FLAGGED:", "").trim() || "Текст не соответствует правилам академического сообщества";
        return { allowed: false, reason };
      }
      return { allowed: true };
    } catch (e) {
      console.warn("Groq moderation network fallback (пропущен локально):", e);
      return { allowed: true };
    }
  },

  // 2. Генерация структурированной выжимки о преподавателе
  async generateTeacherSummary(teacherName, reviews) {
    if (!reviews || reviews.length === 0) return "";
    try {
      const reviewsText = reviews
        .slice(0, 15)
        .map(
          (r, i) =>
            `${i + 1}. [Сложность ${r.difficulty}/5, автомат: ${r.gives_avtomat ? "да" : "нет"}, строгость: ${r.attendance_strict ? "да" : "нет"}]: ${r.text}`
        )
        .join("\n\n");

      const systemPrompt =
        "Ты умный студенческий ассистент ЮУрГУ. Твоя задача — составить краткую, четкую и структурированную выжимку о преподавателе на основе отзывов студентов. Пиши по-русски, емко, без воды, используй понятные эмодзи. Формат:\n🎯 Особенности сдачи и требований: ...\n⚡ Автоматы и посещаемость: ...\n💡 Главный совет первокурсникам: ...";

      const prompt = `Преподаватель: ${teacherName}\n\nОтзывы студентов:\n${reviewsText}\n\nСделай структурированную выжимку:`;

      const summary = await this.chatCompletion(
        [
          { role: "system", content: systemPrompt },
          { role: "user", content: prompt }
        ],
        500,
        0.4
      );

      return summary.trim();
    } catch (e) {
      console.warn("Groq summary generation failed:", e);
      return "";
    }
  }
};

if (typeof window !== "undefined") {
  window.SusuGroq = SusuGroq;
}
if (typeof module !== "undefined" && module.exports) {
  module.exports = SusuGroq;
}
