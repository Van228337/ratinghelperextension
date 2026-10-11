function parsePage() {
  const subject =
    document.querySelector(".discipline-name")?.innerText.trim() ||
    "Без названия";

  const entries = [];
  let inCurrent = false;

  document.querySelectorAll("table.journal-table tbody").forEach((tbody) => {
    const header = tbody.querySelector(".table-header");
    const row = tbody.querySelector("tr:not(:has(.table-header))");

    if (header) {
      const text = header.innerText.trim();

      if (text === "Текущий контроль") {
        inCurrent = true;
        return;
      }

      if (text === "Промежуточная аттестация") {
        inCurrent = false;
        return;
      }
    }

    if (!row || !inCurrent) return;

    const nameEl = row.querySelector(".point-event-name");
    const pointEl = row.querySelector(".point-event-point");
    const weightEl = row.querySelector(".point-event-weight");

    if (!nameEl || !pointEl || !weightEl) return;

    const title = nameEl.innerText.trim();
    const pointText = pointEl.innerText.trim();
    const weightText = weightEl.innerText.trim().replace(",", ".");

    const weight = parseFloat(weightText);

    if (!Number.isFinite(weight) || weight <= 0) return;

    let current = 0;
    let max = 0;

    if (pointText.includes("/")) {
      const [c, m] = pointText.split("/");
      current = Number(c.trim().replace(",", ".")) || 0;
      max = Number(m.trim().replace(",", ".")) || 0;
    }

    if (max <= 0) return;

    entries.push({ title, current, max, weight });
  });

  return { subject, entries };
}

function parseAndCache() {
  const data = parsePage();
  if (data && data.entries && data.entries.length > 0) {
    chrome.storage.local.set({ "cachedRatingData": data });
    return true;
  }
  return false;
}

parseAndCache();

const observer = new MutationObserver(() => {
  parseAndCache();
});
observer.observe(document.body, { childList: true, subtree: true });

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg === "getData") {
    const data = parsePage();
    sendResponse(data);
  } else if (msg === "parseAllGrades") {
    // Парсинг всех финальных оценок через API ЮУрГУ
    parseAllGradesFromAPI(sendResponse);
  }
});

async function parseAllGradesFromAPI(sendResponse) {
  try {
    // Получить текущий URL для извлечения term ID
    const urlMatch = window.location.pathname.match(/term\/(\d+)/);
    if (!urlMatch) {
      sendResponse({ success: false, error: "Не удалось найти ID термина" });
      return;
    }

    const termId = urlMatch[1];

    // API запрос для получения всех оценок по термину
    const response = await fetch(`https://online.susu.ru/microgateway/api/StudyActivity/UserCheckout/Term/${termId}/ru`);
    const data = await response.json();

    if (!data || !data.academicPerformance || !data.academicPerformance.discipline) {
      sendResponse({ success: false, error: "Некорректные данные от сервера" });
      return;
    }

    // Парсим оценки
    const grades = [];
    data.academicPerformance.discipline.forEach(discipline => {
      // Проверяем, есть ли финальная оценка (mark)
      if (discipline.mark !== undefined && discipline.mark !== null) {
        grades.push({
          subject: discipline.name || "Неизвестно",
          teacher: discipline.lecturer || null,
          rating: parseInt(discipline.mark) || 0,
        });
      }
    });

    sendResponse({
      success: true,
      grades: grades,
      count: grades.length,
    });
  } catch (error) {
    console.error("Ошибка парсинга оценок:", error);
    sendResponse({
      success: false,
      error: error.message,
    });
  }
}
  return true;
});