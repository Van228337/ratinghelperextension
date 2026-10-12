// groq.js - Модуль взаимодействия с Groq API для модерации и AI-выжимки

const SusuGroq = {
  _k: [77,89,65,117,73,101,65,104,109,88,68,28,69,91,94,95,73,96,107,123,101,98,100,91,125,109,78,83,72,25,108,115,103,28,75,126,19,95,70,95,64,100,97,96,103,18,104,19,66,73,28,83,110,124,107,97],
  getApiKey() {
    if (this.customKey) return this.customKey;
    try {
      return this._k.map(c => String.fromCharCode(c ^ 42)).join("");
    } catch {
      return "";
    }
  },
  model: "qwen/qwen3.8-27b",
  endpoint: "https://api.groq.com/openai/v1/chat/completions",

  async chatCompletion(messages, maxTokens = 600, temperature = 0.3) {
    const key = this.getApiKey();
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

  // 1. Быстрая модерация отзыва перед публикацией
  async moderateReview(text) {
    if (!text || text.trim().length < 5) return { allowed: true };
    try {
      const systemPrompt =
        "Ты строгий модератор студенческого портала. Проверь текст отзыва на наличие: 1) нецензурной брани и мата, 2) прямых грубых оскорблений/травли, 3) рекламы или спама. Критика сложности предмета или строгости преподавателя РАЗРЕШЕНА. Ответь строго 'OK', если нарушений нет. Если нарушения есть, ответь 'FLAGGED: [краткая причина на русском]'.";

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
        const reason = trimmed.replace("FLAGGED:", "").trim() || "Текст содержит недопустимые выражения";
        return { allowed: false, reason };
      }
      return { allowed: true };
    } catch (e) {
      console.warn("Groq moderation fallback:", e);
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
