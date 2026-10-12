/**
 * Google Apps Script Web App: Защищённый шлюз Rating Helper
 * 
 * Назначение:
 *  1. Groq AI Модерация и Выжимка (ключи и системные промпты скрыты на сервере Google)
 *  2. Хранилище материалов на Google Диске (прямые ссылки на скачивание)
 *  3. 100% обход любых блокировок Cloudflare/Groq в РФ без всяких VPN
 *
 * Инструкция по обновлению:
 *  1. Откройте https://script.google.com/ и выберите ваш проект.
 *  2. Замените весь код скрипта на содержимое этого файла.
 *  3. Нажмите "Развернуть" (Deploy) -> "Управление развертываниями" (Manage deployments).
 *  4. Нажмите иконку карандаша (Редактировать) -> выберите: "Новая версия" (New version).
 *  5. Нажмите "Развернуть" (Deploy).
 */

// Приватный API-ключ Groq (хранится ТОЛЬКО в настройках Google Apps Script)
// Рекомендуется задать через: Настройки проекта -> Свойства скрипта -> Имя: GROQ_API_KEY
var GROQ_API_KEY = PropertiesService.getScriptProperties().getProperty("GROQ_API_KEY") 
  || "YOUR_GROQ_API_KEY_HERE";

// Функция вызова Groq API с серверов Google (обходит Cloudflare 403 в РФ)
function callGroqApi(model, messages, maxTokens, temperature) {
  var url = "https://api.groq.com/openai/v1/chat/completions";
  var payload = {
    model: model || "qwen/qwen3.8-27b",
    messages: messages,
    max_tokens: maxTokens || 500,
    temperature: temperature !== undefined ? temperature : 0.3
  };

  var options = {
    method: "post",
    contentType: "application/json",
    headers: {
      "Authorization": "Bearer " + GROQ_API_KEY
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  var res = UrlFetchApp.fetch(url, options);
  var code = res.getResponseCode();
  var text = res.getContentText();

  if (code >= 200 && code < 300) {
    var json = JSON.parse(text);
    return (json.choices && json.choices[0] && json.choices[0].message) 
      ? json.choices[0].message.content 
      : "";
  }
  throw new Error("Groq API error " + code + ": " + text);
}

// Серверный фильтр ненормативной лексики
function serverProfanityCheck(text) {
  var safeWords = [
    "тебя", "себя", "колебания", "колебание", "потребовать", "потребовал", "требовать", 
    "требования", "потребность", "употреблять", "хлеб", "гребля", "лебедь", "стебель", 
    "сабля", "рубль", "дубль", "судебный", "судьба", "психует", "психолог", "страхует", 
    "страховка", "худеть", "худой", "художник", "художественный"
  ];
  var words = text.toLowerCase().replace(/[^a-zа-яё0-9\s]/gi, " ").split(/\s+/).filter(Boolean);

  for (var i = 0; i < words.length; i++) {
    var w = words[i];
    if (safeWords.indexOf(w) !== -1) continue;

    if (/^(за|на|по|про|вы|до|от|при|пере|с|под|у|долбо|раз)?([её]б[а-яё]*|[её]пт[а-яё]*)$/.test(w)) {
      if (!/^(теб|себ|треб|колеб|хлеб|лебед|стеб|греб)/.test(w)) {
        return { allowed: false, reason: "Текст содержит ненормативную лексику или оскорбления" };
      }
    }
    if (/^(на|по|за|до|при|не|от|раз|о)?ху[йеяиюё][а-яё]*$/.test(w)) {
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
  return { allowed: true };
}

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return responseJSON({ success: false, error: "Empty request body" });
    }

    var data = JSON.parse(e.postData.contents);

    // 1. Защищённая серверная AI-модерация отзыва
    if (data.action === "moderateReview") {
      var text = (data.text || "").trim();
      if (!text) {
        return responseJSON({ success: true, allowed: false, reason: "Пустой текст отзыва" });
      }

      // Шаг А: Проверка ненормативной лексики на сервере
      var pCheck = serverProfanityCheck(text);
      if (!pCheck.allowed) {
        return responseJSON({ success: true, allowed: false, reason: pCheck.reason });
      }

      // Шаг Б: AI-проверка на академический контекст
      try {
        var modSystemPrompt = "Ты строгий академический модератор студенческого учебного портала. Твоя задача — пропустить ТОЛЬКО осмысленные советы и отзывы студентов об учебе, преподавателе, сдаче лабораторных, автоматах или экзаменах.\n\nСТРОГО ЗАПРЕЩЕНО (немедленно отвечай FLAGGED):\n1) Любая нецензурная брань, мат, грубость.\n2) Пошлости, сортирный юмор, упоминания половых органов или интимных тем.\n3) Оскорбления, травля, агрессия в адрес преподавателя или студентов.\n4) Бессмысленный текст, бред, оффтоп, троллинг, несвязные фразы, не имеющие отношения к учебе.\n5) Реклама, спам, сторонние ссылки.\n\nРАЗРЕШЕНО: Конструктивная критика сложности предмета, строгости преподавателя или объема заданий.\n\nФОРМАТ ОТВЕТА:\n- Если текст является реальным осмысленным отзывом об учебе и не нарушает правил: ответь строго 'OK'.\n- Если есть любое нарушение: ответь строго 'FLAGGED: [краткая причина отказа на русском языке]'.";

        var aiRes = callGroqApi("qwen/qwen3.8-27b", [
          { role: "system", content: modSystemPrompt },
          { role: "user", content: text }
        ], 60, 0.1);

        var trimmed = aiRes.trim();
        if (trimmed.indexOf("FLAGGED:") === 0) {
          var rText = trimmed.replace("FLAGGED:", "").trim() || "Текст не соответствует правилам академического сообщества";
          return responseJSON({ success: true, allowed: false, reason: rText });
        }
        return responseJSON({ success: true, allowed: true });
      } catch (aiErr) {
        // Если Groq временно недоступен, пропускаем проверенный по словарю отзыв
        return responseJSON({ success: true, allowed: true });
      }
    }

    // 2. Защищённая серверная генерация структурированной выжимки о преподавателе
    if (data.action === "generateSummary") {
      var teacherName = data.teacherName || "";
      var reviews = data.reviews || [];
      if (!reviews || reviews.length === 0) {
        return responseJSON({ success: false, error: "No reviews provided" });
      }

      var reviewsText = reviews.slice(0, 15).map(function(r, i) {
        return (i + 1) + ". [Сложность " + (r.difficulty || 3) + "/5, автомат: " + (r.gives_avtomat ? "да" : "нет") + ", строгость: " + (r.attendance_strict ? "да" : "нет") + "]: " + r.text;
      }).join("\n\n");

      var summarySystemPrompt = "Ты умный студенческий ассистент. Твоя задача — составить краткую, четкую и структурированную выжимку о преподавателе на основе отзывов студентов. Пиши по-русски, емко, без воды, используй понятные эмодзи. Формат:\n🎯 Особенности сдачи и требований: ...\n⚡ Автоматы и посещаемость: ...\n💡 Главный совет по сдаче предмета: ...";

      var userPrompt = "Преподаватель: " + teacherName + "\n\nОтзывы студентов:\n${reviewsText}\n\nСделай структурированную выжимку:";
      userPrompt = userPrompt.replace("${reviewsText}", reviewsText);

      var summaryText = callGroqApi("qwen/qwen3.8-27b", [
        { role: "system", content: summarySystemPrompt },
        { role: "user", content: userPrompt }
      ], 500, 0.4);

      return responseJSON({ success: true, summary: summaryText.trim() });
    }

    // 3. Загрузка файлов на Google Диск
    var fileName = data.fileName || ("material_" + new Date().getTime());
    var mimeType = data.mimeType || "application/octet-stream";
    var fileData = data.fileData;

    if (fileData) {
      var folderName = "STUDENT_MATERIALS";
      var folders = DriveApp.getFoldersByName(folderName);
      var folder = folders.hasNext() ? folders.next() : DriveApp.createFolder(folderName);

      var decoded = Utilities.base64Decode(fileData);
      var blob = Utilities.newBlob(decoded, mimeType, fileName);
      var file = folder.createFile(blob);

      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      var downloadUrl = "https://drive.google.com/uc?export=download&id=" + file.getId();

      return responseJSON({
        success: true,
        fileId: file.getId(),
        downloadUrl: downloadUrl,
        viewUrl: file.getUrl()
      });
    }

    return responseJSON({ success: false, error: "Unknown action" });

  } catch (err) {
    return responseJSON({ success: false, error: err.toString() });
  }
}

function responseJSON(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function doGet(e) {
  return responseJSON({ status: "ok", message: "Rating Helper Gateway is online" });
}
