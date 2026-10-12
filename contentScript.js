// contentScript.js

function isSubjectPage() {
  const parts = window.location.pathname.split("/").filter(Boolean);
  return (
    parts[0] === "study-activity" &&
    parts[1] === "journal" &&
    parts.length >= 3 &&
    parts[2] !== "term"
  );
}

function getSubjectIdFromUrl() {
  const parts = window.location.pathname.split("/").filter(Boolean);
  if (parts[0] === "study-activity" && parts[1] === "journal" && parts.length >= 3 && parts[2] !== "term") {
    return parts[2];
  }
  return null;
}

// Извлечение чистого названия предмета БЕЗ виджетов и артефактов
function getCleanSubjectName() {
  const disciplineEl = document.querySelector(".discipline-name");
  if (!disciplineEl) return "";
  const clone = disciplineEl.cloneNode(true);
  clone.querySelectorAll("#susu-rating-inline-widget, [id^='susu-']").forEach((e) => e.remove());
  let text = clone.innerText.trim();
  return text.replace(/[🎓⚡].*$/, "").replace(/Рейтинг:.*$/, "").trim();
}

// Сканирование карточек на странице общего списка дисциплин
function scanOverviewPage() {
  const cards = document.querySelectorAll(".card-data");
  if (!cards || cards.length === 0) return;

  chrome.storage.local.get("subjects_meta", (res) => {
    const meta = res.subjects_meta || {};
    let changed = false;

    cards.forEach((card) => {
      const nameEl = card.querySelector(".discipline-name");
      const teacherEl = card.querySelector("p");
      const name = nameEl?.innerText.trim();
      const teacher = teacherEl?.innerText.trim();

      // Ищем ссылку на страницу журнала с UUID предмета
      const a = card.closest("a") || card.parentElement?.querySelector("a") || card.querySelector("a");
      const href = a?.getAttribute("href") || a?.href || "";
      const uuidMatch = href.match(/journal\/([0-9a-f-]{36})/i);
      const subjectId = uuidMatch ? uuidMatch[1] : null;

      if (name) {
        const existing = meta[name] || {};
        if (existing.teacher !== teacher || (subjectId && existing.subjectId !== subjectId)) {
          meta[name] = {
            ...existing,
            subjectName: name,
            ...(teacher ? { teacher } : {}),
            ...(subjectId ? { subjectId } : {})
          };
          if (subjectId) {
            meta[subjectId] = meta[name];
          }
          changed = true;
        }
      }
    });

    if (changed) {
      chrome.storage.local.set({ subjects_meta: meta });
    }
  });
}

function parsePage() {
  const subject = getCleanSubjectName();
  const subjectId = getSubjectIdFromUrl();
  const entries = [];
  let inCurrent = false;

  document.querySelectorAll("table.journal-table tbody").forEach((tbody) => {
    const header = tbody.querySelector(".table-header");

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

    if (!inCurrent) return;

    const rows = tbody.querySelectorAll("tr:not(:has(.table-header))");
    rows.forEach((row) => {
      const nameEl = row.querySelector(".point-event-name");
      const pointEl = row.querySelector(".point-event-point");
      const weightEl = row.querySelector(".point-event-weight");

      if (!nameEl || !pointEl || !weightEl) return;

      const title = nameEl.innerText.trim();
      const pointText = pointEl.innerText.trim();
      const weightText = weightEl.innerText.trim().replace(",", ".");

      const weight = parseFloat(weightText);

      // Пропускаем строки без нормального веса
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
  });

  return { subject, subjectId, entries };
}

function waitForJournal(timeout = 3000) {
  return new Promise((resolve) => {
    if (!isSubjectPage()) {
      resolve({ notInSubject: true, subject: "", entries: [] });
      return;
    }

    const start = Date.now();

    const check = () => {
      const data = parsePage();

      if (data.entries.length > 0) {
        resolve(data);
        return;
      }

      if (Date.now() - start > timeout) {
        if (!data.subject) {
          resolve({ notInSubject: true, subject: "", entries: [] });
        } else {
          resolve(data);
        }
        return;
      }

      setTimeout(check, 250);
    };

    check();
  });
}

// === ОПРЕДЕЛЕНИЕ ТЕМЫ САЙТА (СВЕТЛАЯ / ТЕМНАЯ) ===
function isSiteDarkTheme() {
  if (
    document.body.classList.contains("dark") ||
    document.documentElement.classList.contains("dark") ||
    document.body.classList.contains("theme-dark")
  ) {
    return true;
  }
  const bg = window.getComputedStyle(document.body).backgroundColor;
  const match = bg.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  if (match) {
    const [r, g, b] = [Number(match[1]), Number(match[2]), Number(match[3])];
    return 0.299 * r + 0.587 * g + 0.114 * b < 128;
  }
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
}

// === ИНФОРМАТИВНЫЙ ИНТЕРАКТИВНЫЙ ВИДЖЕТ (ФИЧА 6) ===
function getAcademicGradeInline(pct) {
  if (pct >= 84.01) return { label: "Отлично (5)", badgeBg: "#14532d", badgeText: "#86efac", lightBg: "#dcfce7", lightText: "#15803d" };
  if (pct >= 74.01) return { label: "Хорошо (4)", badgeBg: "#1e3a8a", badgeText: "#93c5fd", lightBg: "#dbeafe", lightText: "#1d4ed8" };
  if (pct >= 59.01) return { label: "Удовлетворительно (3)", badgeBg: "#78350f", badgeText: "#fde68a", lightBg: "#fef3c7", lightText: "#b45309" };
  return { label: "Незачёт (2)", badgeBg: "#7f1d1d", badgeText: "#fca5a5", lightBg: "#fee2e2", lightText: "#b91c1c" };
}

function injectInlineStyles() {
  let style = document.getElementById("susu-rating-inline-styles");
  if (!style) {
    style = document.createElement("style");
    style.id = "susu-rating-inline-styles";
    document.head.appendChild(style);
  }

  const isDark = isSiteDarkTheme();
  style.textContent = `
    .susu-rating-card-widget {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      margin: 10px 0 16px 0;
      padding: 10px 14px;
      border-radius: 10px;
      font-family: system-ui, -apple-system, sans-serif;
      font-size: 13px;
      box-shadow: ${isDark ? "0 3px 10px rgba(0,0,0,0.5)" : "0 2px 8px rgba(0,0,0,0.06)"};
      background: ${isDark ? "#1e293b !important" : "#ffffff !important"};
      border: 1px solid ${isDark ? "#334155 !important" : "#e2e8f0 !important"};
      color: ${isDark ? "#f8fafc !important" : "#0f172a !important"};
      box-sizing: border-box;
      z-index: 99;
    }
    .susu-widget-left {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }
    .susu-widget-title-tag {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-weight: 700;
      font-size: 13px;
      color: ${isDark ? "#60a5fa !important" : "#2563eb !important"};
    }
    .susu-widget-teacher-tag {
      font-size: 12px;
      color: ${isDark ? "#cbd5e1 !important" : "#64748b !important"};
    }
    .susu-stat-item {
      display: inline-flex;
      align-items: baseline;
      gap: 4px;
      color: ${isDark ? "#cbd5e1 !important" : "#475569 !important"};
    }
    .susu-stat-item strong {
      font-size: 14px;
      color: ${isDark ? "#f8fafc !important" : "#0f172a !important"};
    }
    .susu-stat-item strong.highlight-green {
      color: #22c55e !important;
    }
    .susu-grade-pill-tag {
      padding: 3px 8px;
      border-radius: 12px;
      font-size: 11px;
      font-weight: 700;
      line-height: 1.2;
    }
    .susu-goal-hint-tag {
      font-size: 12px;
      color: ${isDark ? "#94a3b8 !important" : "#64748b !important"};
    }
    .susu-goal-hint-tag span {
      color: ${isDark ? "#38bdf8 !important" : "#0284c7 !important"};
      font-weight: 600;
    }
  `;
}

function renderInlineWidget() {
  if (!isSubjectPage()) {
    const existing = document.getElementById("susu-rating-inline-widget");
    if (existing) existing.remove();
    return;
  }

  chrome.storage.local.get(["settings", "subjects_meta"], (res) => {
    const settings = res.settings || {};
    if (settings.inlineWidget === false) {
      const existing = document.getElementById("susu-rating-inline-widget");
      if (existing) existing.remove();
      return;
    }

    const data = parsePage();
    if (!data || !data.entries || data.entries.length === 0) return;

    const meta = res.subjects_meta || {};
    const metaInfo = (data.subjectId && meta[data.subjectId]) || (data.subject && meta[data.subject]) || {};
    const teacherName = metaInfo.teacher || "";

    let total = 0, totalWeight = 0;
    let lockedTotal = 0;
    let remWeight = 0;

    data.entries.forEach((e) => {
      const pct = e.max > 0 ? (e.current / e.max) * 100 : 0;
      total += pct * e.weight;
      totalWeight += e.weight;

      if (e.current === 0) {
        remWeight += e.weight;
      } else {
        lockedTotal += pct * e.weight;
      }
    });

    const rating = totalWeight > 0 ? total / totalWeight : 0;
    const maxPotential = totalWeight > 0 ? (lockedTotal + remWeight * 100) / totalWeight : rating;

    const isDark = isSiteDarkTheme();
    const grade = getAcademicGradeInline(rating);

    // Сохраняем в историю без мусора в названии
    const cleanName = getCleanSubjectName();
    if (cleanName && cleanName !== "Без названия") {
      chrome.storage.local.get("semester_subjects", (subRes) => {
        const list = subRes.semester_subjects || {};
        list[cleanName] = {
          name: cleanName,
          teacher: teacherName,
          subjectId: data.subjectId || null,
          rating: parseFloat(rating.toFixed(2)),
          updatedAt: Date.now()
        };
        chrome.storage.local.set({ semester_subjects: list });
      });
    }

    // Фоновая синхронизация с Supabase
    if (typeof SusuSupabase !== "undefined" && data.subjectId && cleanName && data.entries.length > 0) {
      SusuSupabase.syncSubjectData(data.subjectId, cleanName, teacherName, data.entries).catch(() => {});
    }

    injectInlineStyles();

    let widget = document.getElementById("susu-rating-inline-widget");
    if (!widget) {
      widget = document.createElement("div");
      widget.id = "susu-rating-inline-widget";
      widget.className = "susu-rating-card-widget";

      // Вставляем строго ПОСЛЕ названия предмета, а не внутрь него!
      const disciplineEl = document.querySelector(".discipline-name");
      if (disciplineEl) {
        disciplineEl.insertAdjacentElement("afterend", widget);
      } else {
        const targetHeader = document.querySelector("h2");
        if (targetHeader) {
          targetHeader.insertAdjacentElement("afterend", widget);
        } else {
          const table = document.querySelector("table.journal-table");
          if (table && table.parentNode) {
            table.parentNode.insertBefore(widget, table);
          }
        }
      }
    }

    // Подсказка до следующей цели
    let goalText = "";
    if (rating < 59.01) {
      goalText = `До зачёта (3): <span>+${(59.01 - rating).toFixed(1)}%</span>`;
    } else if (rating < 74.01) {
      goalText = `До четвёрки (4): <span>+${(74.01 - rating).toFixed(1)}%</span>`;
    } else if (rating < 84.01) {
      goalText = `До пятёрки (5): <span>+${(84.01 - rating).toFixed(1)}%</span>`;
    } else {
      goalText = `<span>Пятёрка обеспечена!</span>`;
    }

    const pillBg = isDark ? grade.badgeBg : grade.lightBg;
    const pillColor = isDark ? grade.badgeText : grade.lightText;
    const teacherHtml = teacherName ? `<span class="susu-widget-teacher-tag">👨‍🏫 ${teacherName}</span>` : "";

    widget.innerHTML = `
      <div class="susu-widget-left">
        <span class="susu-widget-title-tag">⚡ БРС Калькулятор:</span>
        ${teacherHtml}
        <span class="susu-stat-item">Текущий: <strong>${rating.toFixed(2)}%</strong></span>
        <span class="susu-grade-pill-tag" style="background:${pillBg} !important; color:${pillColor} !important;">
          ${grade.label}
        </span>
        <span class="susu-stat-item">Потенциал: <strong class="highlight-green">${maxPotential.toFixed(1)}%</strong></span>
        <span class="susu-goal-hint-tag">${goalText}</span>
      </div>
    `;
  });
}

// Запуск при загрузке страницы
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => {
    if (isSubjectPage()) setTimeout(renderInlineWidget, 500);
    else setTimeout(scanOverviewPage, 500);
  });
} else {
  if (isSubjectPage()) setTimeout(renderInlineWidget, 500);
  else setTimeout(scanOverviewPage, 500);
}

// Отслеживание изменений DOM (для SPA-навигации)
const observer = new MutationObserver(() => {
  if (isSubjectPage()) {
    if (!document.getElementById("susu-rating-inline-widget")) {
      const table = document.querySelector("table.journal-table");
      if (table) renderInlineWidget();
    }
  } else {
    scanOverviewPage();
  }
});
observer.observe(document.body, { childList: true, subtree: true });

// Слушатель сообщений от popup
if (!window.__susuRatingHelperInjected) {
  window.__susuRatingHelperInjected = true;

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (msg === "getData") {
      waitForJournal().then((data) => {
        chrome.storage.local.get("subjects_meta", (res) => {
          const meta = res.subjects_meta || {};
          const info = (data.subjectId && meta[data.subjectId]) || (data.subject && meta[data.subject]) || {};
          data.teacher = info.teacher || "";

          // Привязываем ID предмета и название
          if (data.subjectId && data.subject) {
            meta[data.subject] = {
              ...(meta[data.subject] || {}),
              subjectId: data.subjectId,
              subjectName: data.subject,
              ...(data.teacher ? { teacher: data.teacher } : {})
            };
            meta[data.subjectId] = meta[data.subject];
            chrome.storage.local.set({ subjects_meta: meta });
          }

          renderInlineWidget();
          sendResponse(data);
        });
      });
      return true;
    }
  });
}