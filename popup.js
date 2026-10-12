// popup.js

// === DOM Элементы ===
const mainView = document.getElementById("main-view");
const settingsView = document.getElementById("settings-view");
const dashboardView = document.getElementById("dashboard-view");
const infoView = document.getElementById("info-view");

const subjectEl = document.getElementById("subject");
const subjectTeacherEl = document.getElementById("subject-teacher");
const pointsContainer = document.getElementById("points-container");
const resultEl = document.getElementById("result");
const bonusSection = document.getElementById("bonus-section");
const bonusInput = document.getElementById("bonus-input");

// Кнопки в шапке
const dashboardBtn = document.getElementById("dashboard-btn");
const settingsBtn = document.getElementById("settings-btn");
const infoBtn = document.getElementById("info-btn");
const themeToggle = document.getElementById("theme-toggle");

// Кнопки возврата
const backBtn = document.getElementById("back-btn");
const backFromSettingsBtn = document.getElementById("back-from-settings-btn");
const backFromDashboardBtn = document.getElementById("back-from-dashboard-btn");

// Карточки фич
const gradeCard = document.getElementById("grade-card");
const gradeBadge = document.getElementById("grade-badge");
const ratingVal = document.getElementById("rating-val");
const progressFill = document.getElementById("progress-fill");
const gradeSubtext = document.getElementById("grade-subtext");

const rangeCard = document.getElementById("range-card");
const rangeMin = document.getElementById("range-min");
const rangeCurr = document.getElementById("range-curr");
const rangeMax = document.getElementById("range-max");

const targetCard = document.getElementById("target-card");
const targetHint = document.getElementById("target-hint");
const targetChips = document.querySelectorAll(".target-chip");

const quickActionsBar = document.getElementById("quick-actions-bar");
const quickRemMaxBtn = document.getElementById("quick-rem-max-btn");
const quickAllMaxBtn = document.getElementById("quick-all-max-btn");
const quickResetBtn = document.getElementById("quick-reset-btn");

const examSection = document.getElementById("exam-section");
const examToggle = document.getElementById("exam-toggle");
const examInputWrap = document.getElementById("exam-input-wrap");
const examInput = document.getElementById("exam-input");
const examFormulaTip = document.getElementById("exam-formula-tip");

const draftBanner = document.getElementById("draft-banner");
const revertDraftBtn = document.getElementById("revert-draft-btn");
const planFooter = document.getElementById("plan-footer");
const savePlanBtn = document.getElementById("save-plan-btn");

const resetSettingsBtn = document.getElementById("reset-settings-btn");
const clearDashboardBtn = document.getElementById("clear-dashboard-btn");

// === Настройки по умолчанию ===
const DEFAULT_SETTINGS = {
  targetCalc: true,        // 1. Калькулятор целей
  rangeForecast: true,     // 2. Прогноз диапазона
  quickActions: true,      // 3. Быстрые действия
  academicGrade: true,     // 4. Оценка по шкале БРС
  examMode: true,          // 5. Учет экзамена
  inlineWidget: true,      // 6. Виджет на странице
  semesterDashboard: true, // 7. Сводка семестра
  saveDrafts: true,        // 8. Сохранение плана
};

let currentSettings = { ...DEFAULT_SETTINGS };
let originalData = null;
let currentScores = [];
let activeTarget = null;
let currentTabId = null;

// Очистка названия предмета от случайных артефактов
function cleanSubjectName(name) {
  if (!name) return "";
  return name.replace(/[🎓⚡].*$/, "").replace(/Рейтинг:.*$/, "").trim();
}

// === ТЕМА И ИКОНКИ ===
function getIconPath(isDark) {
  return isDark ? "icons-dark/" : "icons-light/";
}

function loadIcons(isDark) {
  const path = getIconPath(isDark);
  dashboardBtn.querySelector("img").src = path + "dashboard.svg";
  settingsBtn.querySelector("img").src = path + "settings.svg";
  infoBtn.querySelector("img").src = path + "info.svg";
  themeToggle.querySelector("img").src = path + (isDark ? "moon.svg" : "sun.svg");
  backBtn.querySelector("img").src = path + "arrow-left.svg";
  backFromSettingsBtn.querySelector("img").src = path + "arrow-left.svg";
  backFromDashboardBtn.querySelector("img").src = path + "arrow-left.svg";
}

const isDark = localStorage.getItem("theme") === "dark";
if (isDark) document.body.classList.add("dark");
loadIcons(isDark);

themeToggle.addEventListener("click", () => {
  document.body.classList.toggle("dark");
  const isNowDark = document.body.classList.contains("dark");
  localStorage.setItem("theme", isNowDark ? "dark" : "light");
  loadIcons(isNowDark);
});

// === НАВИГАЦИЯ МЕЖДУ ЭКРАНАМИ ===
function showView(view) {
  mainView.style.display = "none";
  settingsView.style.display = "none";
  dashboardView.style.display = "none";
  infoView.style.display = "none";
  view.style.display = "block";
}

settingsBtn.addEventListener("click", () => {
  renderSettingsScreen();
  showView(settingsView);
});

dashboardBtn.addEventListener("click", () => {
  renderDashboardScreen();
  showView(dashboardView);
});

infoBtn.addEventListener("click", () => showView(infoView));
backBtn.addEventListener("click", () => showView(mainView));
backFromSettingsBtn.addEventListener("click", () => showView(mainView));
backFromDashboardBtn.addEventListener("click", () => showView(mainView));

const externalLinkBtn = document.getElementById("external-link-btn");
externalLinkBtn?.addEventListener("click", () => {
  chrome.tabs.create({ url: "https://online.susu.ru" });
});

// === УПРАВЛЕНИЕ НАСТРОЙКАМИ ===
function loadSettings() {
  return new Promise((resolve) => {
    chrome.storage.local.get("settings", (data) => {
      if (data && data.settings) {
        currentSettings = { ...DEFAULT_SETTINGS, ...data.settings };
      }
      applySettingsToUI();
      resolve(currentSettings);
    });
  });
}

function saveSettings() {
  chrome.storage.local.set({ settings: currentSettings }, () => {
    applySettingsToUI();
  });
}

function applySettingsToUI() {
  const hasData = originalData && originalData.entries && originalData.entries.length > 0;

  gradeCard.style.display = (hasData && currentSettings.academicGrade) ? "block" : "none";
  rangeCard.style.display = (hasData && currentSettings.rangeForecast) ? "flex" : "none";
  targetCard.style.display = (hasData && currentSettings.targetCalc) ? "block" : "none";
  quickActionsBar.style.display = (hasData && currentSettings.quickActions) ? "flex" : "none";
  examSection.style.display = (hasData && currentSettings.examMode) ? "block" : "none";
  planFooter.style.display = (hasData && currentSettings.saveDrafts) ? "block" : "none";
  dashboardBtn.style.display = currentSettings.semesterDashboard ? "flex" : "none";

  if (!hasData) {
    draftBanner.style.display = "none";
  }
}

function renderSettingsScreen() {
  const switches = settingsView.querySelectorAll("input[data-setting]");
  switches.forEach((sw) => {
    const key = sw.dataset.setting;
    sw.checked = !!currentSettings[key];
    sw.onchange = () => {
      currentSettings[key] = sw.checked;
      saveSettings();
    };
  });
}

resetSettingsBtn.addEventListener("click", () => {
  currentSettings = { ...DEFAULT_SETTINGS };
  saveSettings();
  renderSettingsScreen();
});

// === ОПРЕДЕЛЕНИЕ ОЦЕНКИ ПО ШКАЛЕ БРС (ФИЧА 4) ===
// 59.01% - уже 3 или зачтено, 74.01% - четверка, 84.01% - пятерка
function getAcademicGrade(pct) {
  if (pct >= 84.01) {
    return {
      grade: 5,
      label: "Отлично (5)",
      badgeClass: "green",
      subtext: "Отличный результат по БРС! Сдача обеспечена.",
      threshold: 84.01
    };
  } else if (pct >= 74.01) {
    const toNext = (84.01 - pct).toFixed(2);
    return {
      grade: 4,
      label: "Хорошо (4)",
      badgeClass: "blue",
      subtext: `До «Отлично (5)» не хватает ${toNext}%`,
      threshold: 74.01
    };
  } else if (pct >= 59.01) {
    const toNext = (74.01 - pct).toFixed(2);
    return {
      grade: 3,
      label: "Удовлетворительно (3)",
      badgeClass: "orange",
      subtext: `До «Хорошо (4)» не хватает ${toNext}%`,
      threshold: 59.01
    };
  } else {
    const toNext = (59.01 - pct).toFixed(2);
    return {
      grade: 2,
      label: "Незачёт / Долг (2)",
      badgeClass: "red",
      subtext: `До зачёта / тройки не хватает ${toNext}%`,
      threshold: 0
    };
  }
}

// === БЫСТРЫЕ ДЕЙСТВИЯ (ФИЧА 3) ===
quickRemMaxBtn.addEventListener("click", () => {
  if (!originalData?.entries) return;
  originalData.entries.forEach((e, idx) => {
    if (e.current === 0 || currentScores[idx] === 0) {
      currentScores[idx] = e.max;
    }
  });
  render();
});

quickAllMaxBtn.addEventListener("click", () => {
  if (!originalData?.entries) return;
  originalData.entries.forEach((e, idx) => {
    currentScores[idx] = e.max;
  });
  render();
});

quickResetBtn.addEventListener("click", () => {
  if (!originalData?.entries) return;
  currentScores = originalData.entries.map((e) => e.current);
  bonusInput.value = 0;
  examInput.value = 0;
  examToggle.checked = false;
  examInputWrap.style.display = "none";
  examFormulaTip.style.display = "none";
  render();
});

// === РЕЖИМ ЭКЗАМЕНА (ФИЧА 5) ===
examToggle.addEventListener("change", () => {
  const isExam = examToggle.checked;
  examInputWrap.style.display = isExam ? "flex" : "none";
  examFormulaTip.style.display = isExam ? "block" : "none";
  updateRating();
});

examInput.addEventListener("keydown", (e) => {
  if (e.key === "-" || e.key === "+" || e.key === "e" || e.key === "E") e.preventDefault();
});

examInput.addEventListener("input", () => {
  let val = parseFloat(examInput.value);
  if (!isNaN(val)) {
    if (val > 100) examInput.value = 100;
    else if (val < 0) examInput.value = 0;
  }
  updateRating();
});

// === ПОЛЕ БОНУСА ===
bonusInput.addEventListener("keydown", (e) => {
  if (e.key === "-" || e.key === "+" || e.key === "e" || e.key === "E") e.preventDefault();
});

bonusInput.addEventListener("input", () => {
  let val = parseFloat(bonusInput.value);
  if (!isNaN(val)) {
    if (val > 100) bonusInput.value = 100;
    else if (val < 0) bonusInput.value = 0;
  }
  updateRating();
});

// === ЦЕЛЕВОЙ КАЛЬКУЛЯТОР (ФИЧА 1) ===
targetChips.forEach((chip) => {
  chip.addEventListener("click", () => {
    const targetVal = parseFloat(chip.dataset.target);
    targetChips.forEach((c) => c.classList.remove("active"));
    chip.classList.add("active");
    activeTarget = targetVal;
    calculateTargetGoal(targetVal);
  });
});

function calculateTargetGoal(target) {
  if (!originalData?.entries) return;

  const bonus = parseFloat(bonusInput.value) || 0;
  const isExam = examToggle.checked;

  let totalWeight = 0;
  originalData.entries.forEach((e) => (totalWeight += e.weight));
  if (totalWeight <= 0) return;

  if (isExam) {
    let currentTotal = 0;
    originalData.entries.forEach((entry, idx) => {
      const pct = entry.max > 0 ? (currentScores[idx] / entry.max) * 100 : 0;
      currentTotal += pct * entry.weight;
    });
    const currentControl = currentTotal / totalWeight;

    const neededExam = (target - bonus - currentControl * 0.6) / 0.4;

    if (neededExam <= 0) {
      targetHint.innerHTML = `✅ <strong>Цель уже достигнута!</strong> Порог преодолён даже с 0% за экзамен.`;
    } else if (neededExam > 100) {
      targetHint.innerHTML = `❌ <strong>Недостижимо:</strong> даже сдав экзамен на 100%, вы наберёте максимум ${(currentControl * 0.6 + 40 + bonus).toFixed(1)}%.`;
    } else {
      targetHint.innerHTML = `📝 При текущем контроле <strong>${currentControl.toFixed(1)}%</strong>, на экзамене нужно набрать не менее <strong>${neededExam.toFixed(1)}%</strong>. <button id="apply-target-exam-btn" class="mini-btn" style="margin-left:6px;">Поставить балл</button>`;
      document.getElementById("apply-target-exam-btn")?.addEventListener("click", () => {
        examInput.value = Math.ceil(neededExam);
        updateRating();
      });
    }
    return;
  }

  let lockedWeighted = 0;
  let remainingWeight = 0;
  let remainingIndices = [];

  originalData.entries.forEach((entry, idx) => {
    if (entry.current === 0) {
      remainingWeight += entry.weight;
      remainingIndices.push(idx);
    } else {
      const pct = entry.max > 0 ? (currentScores[idx] / entry.max) * 100 : 0;
      lockedWeighted += pct * entry.weight;
    }
  });

  const maxPossible = (lockedWeighted + remainingWeight * 100) / totalWeight + bonus;
  let currTotal = 0;
  originalData.entries.forEach((e, idx) => {
    currTotal += e.max > 0 ? (currentScores[idx] / e.max) * 100 * e.weight : 0;
  });
  const currentRating = currTotal / totalWeight + bonus;

  if (currentRating >= target) {
    targetHint.innerHTML = `✅ <strong>Цель уже достигнута!</strong> Текущий рейтинг: <strong>${currentRating.toFixed(2)}%</strong>.`;
    return;
  }

  if (target > maxPossible) {
    targetHint.innerHTML = `❌ <strong>Недостижимо:</strong> максимально возможный рейтинг с учетом уже сданного — <strong>${maxPossible.toFixed(1)}%</strong>.`;
    return;
  }

  if (remainingIndices.length === 0) {
    targetHint.innerHTML = `ℹ️ Все работы уже сданы. Для изменения рейтинга скорректируйте баллы в строках выше.`;
    return;
  }

  const neededWeighted = (target - bonus) * totalWeight - lockedWeighted;
  const neededAvgPct = neededWeighted / remainingWeight;

  targetHint.innerHTML = `🎯 Оставшиеся <strong>${remainingIndices.length}</strong> работ нужно сдать в среднем на <strong>${neededAvgPct.toFixed(1)}%</strong>. <button id="apply-target-scores-btn" class="mini-btn" style="margin-left:6px;">Заполнить баллы</button>`;

  document.getElementById("apply-target-scores-btn")?.addEventListener("click", () => {
    remainingIndices.forEach((idx) => {
      const entry = originalData.entries[idx];
      const rec = Math.min(entry.max, Math.round((entry.max * (neededAvgPct / 100)) * 10) / 10);
      currentScores[idx] = rec;
    });
    render();
  });
}

// === ПРОГНОЗ ДИАПАЗОНА (ФИЧА 2) ===
function updateRangeForecast(totalWeight, bonus) {
  if (!originalData?.entries || totalWeight <= 0) return;

  let lockedWeighted = 0;
  let remainingWeight = 0;

  originalData.entries.forEach((entry, idx) => {
    if (entry.current === 0) {
      remainingWeight += entry.weight;
    } else {
      const pct = entry.max > 0 ? (entry.current / entry.max) * 100 : 0;
      lockedWeighted += pct * entry.weight;
    }
  });

  const minRating = (lockedWeighted / totalWeight) + bonus;
  const maxRating = ((lockedWeighted + remainingWeight * 100) / totalWeight) + bonus;

  rangeMin.textContent = `${minRating.toFixed(1)}%`;
  rangeMax.textContent = `${maxRating.toFixed(1)}%`;
}

// === СОХРАНЕНИЕ ПЛАНА / ЧЕРНОВИКА (ФИЧА 8) ===
savePlanBtn.addEventListener("click", () => {
  const cleanName = cleanSubjectName(originalData?.subject);
  if (!cleanName) return;
  const key = `draft_${cleanName}`;
  const planData = {
    scores: currentScores,
    bonus: bonusInput.value,
    isExam: examToggle.checked,
    examScore: examInput.value,
    savedAt: Date.now()
  };
  chrome.storage.local.set({ [key]: planData }, () => {
    savePlanBtn.textContent = "✅ План сохранён!";
    draftBanner.style.display = "flex";
    setTimeout(() => {
      savePlanBtn.textContent = "💾 Сохранить расчёт как план";
    }, 2000);
  });
});

revertDraftBtn.addEventListener("click", () => {
  const cleanName = cleanSubjectName(originalData?.subject);
  if (!cleanName) return;
  const key = `draft_${cleanName}`;
  chrome.storage.local.remove(key, () => {
    draftBanner.style.display = "none";
    currentScores = originalData.entries.map((e) => e.current);
    bonusInput.value = 0;
    examToggle.checked = false;
    examInput.value = 0;
    examInputWrap.style.display = "none";
    examFormulaTip.style.display = "none";
    render();
  });
});

function checkExistingDraft(subjectName) {
  if (!currentSettings.saveDrafts) return;
  const cleanName = cleanSubjectName(subjectName);
  const key = `draft_${cleanName}`;
  chrome.storage.local.get(key, (res) => {
    if (res && res[key]) {
      const draft = res[key];
      if (Array.isArray(draft.scores) && draft.scores.length === originalData.entries.length) {
        currentScores = draft.scores;
        if (draft.bonus !== undefined) bonusInput.value = draft.bonus;
        if (draft.isExam) {
          examToggle.checked = true;
          examInputWrap.style.display = "flex";
          examFormulaTip.style.display = "block";
          examInput.value = draft.examScore || 0;
        }
        draftBanner.style.display = "flex";
        render();
      }
    }
  });
}

// Сохраняем предмет в общую историю для дашборда семестра (Фича 7)
function saveSubjectToSemesterHistory(subjectName, rating, teacher, subjectId) {
  const clean = cleanSubjectName(subjectName);
  if (!clean || clean === "Без названия") return;
  chrome.storage.local.get("semester_subjects", (res) => {
    const list = res.semester_subjects || {};
    list[clean] = {
      name: clean,
      teacher: teacher || list[clean]?.teacher || "",
      subjectId: subjectId || list[clean]?.subjectId || null,
      rating: parseFloat(rating.toFixed(2)),
      updatedAt: Date.now()
    };
    chrome.storage.local.set({ semester_subjects: list });
  });
}

// === ЭКРАН ДАШБОРДА СЕМЕСТРА С ТОЧЕЧНЫМ УДАЛЕНИЕМ (ФИЧА 7) ===
function renderDashboardScreen() {
  const avgValEl = document.getElementById("dashboard-avg-val");
  const avgBadgeEl = document.getElementById("dashboard-avg-badge");
  const statsEl = document.getElementById("dashboard-stats");
  const listEl = document.getElementById("dashboard-subjects-list");

  chrome.storage.local.get("semester_subjects", (res) => {
    const rawMap = res.semester_subjects || {};
    // Очищаем и дедуплицируем записи
    const cleanMap = {};
    Object.values(rawMap).forEach((s) => {
      const clean = cleanSubjectName(s.name);
      if (!clean || clean === "Без названия") return;
      if (!cleanMap[clean] || (s.updatedAt || 0) >= (cleanMap[clean].updatedAt || 0)) {
        cleanMap[clean] = {
          name: clean,
          teacher: s.teacher || "",
          subjectId: s.subjectId || null,
          rating: s.rating,
          updatedAt: s.updatedAt || Date.now()
        };
      }
    });

    // Сохраняем очищенный список без дублей
    if (Object.keys(cleanMap).length !== Object.keys(rawMap).length || Object.keys(rawMap).some((k) => k !== cleanSubjectName(k))) {
      chrome.storage.local.set({ semester_subjects: cleanMap });
    }

    const subjects = Object.values(cleanMap);
    listEl.innerHTML = "";

    if (subjects.length === 0) {
      avgValEl.textContent = "0.0%";
      avgBadgeEl.textContent = "Нет данных";
      avgBadgeEl.className = "grade-badge";
      statsEl.textContent = "Открывайте предметы в журнале, чтобы они появились здесь.";
      return;
    }

    let sum = 0;
    let debts = 0;
    subjects.forEach((s) => {
      sum += s.rating;
      if (s.rating < 59.01) debts++;
    });

    const avg = sum / subjects.length;
    avgValEl.textContent = `${avg.toFixed(2)}%`;

    const gradeInfo = getAcademicGrade(avg);
    avgBadgeEl.textContent = gradeInfo.label;
    avgBadgeEl.className = `grade-badge ${gradeInfo.badgeClass}`;

    statsEl.textContent = `Учтено дисциплин: ${subjects.length} • Задолженностей: ${debts}`;

    subjects.forEach((s) => {
      const item = document.createElement("div");
      item.className = "dashboard-subject-item";

      const nameEl = document.createElement("div");
      nameEl.className = "dashboard-sub-name";
      nameEl.innerHTML = `<div>${s.name}</div>${s.teacher ? `<div class="dashboard-sub-teacher">👨‍🏫 ${s.teacher}</div>` : ""}`;

      const rightEl = document.createElement("div");
      rightEl.className = "dashboard-sub-right";

      const g = getAcademicGrade(s.rating);
      const b = document.createElement("span");
      b.className = `grade-badge ${g.badgeClass}`;
      b.textContent = `${s.rating}%`;

      // Кнопка точечного удаления предмета из истории
      const delBtn = document.createElement("button");
      delBtn.className = "delete-sub-btn";
      delBtn.title = `Удалить «${s.name}» из истории`;
      delBtn.textContent = "✕";
      delBtn.addEventListener("click", () => {
        delete cleanMap[s.name];
        chrome.storage.local.set({ semester_subjects: cleanMap }, () => {
          renderDashboardScreen();
        });
      });

      rightEl.append(b, delBtn);
      item.append(nameEl, rightEl);
      listEl.appendChild(item);
    });
  });
}

clearDashboardBtn.addEventListener("click", () => {
  chrome.storage.local.remove("semester_subjects", () => {
    renderDashboardScreen();
  });
});

// === ПРОВЕРКА URL ЖУРНАЛА ===
function isSubjectPageUrl(urlStr) {
  try {
    const url = new URL(urlStr);
    const parts = url.pathname.split("/").filter(Boolean);
    return (
      parts[0] === "study-activity" &&
      parts[1] === "journal" &&
      parts.length >= 3 &&
      parts[2] !== "term"
    );
  } catch (e) {
    return false;
  }
}

// === ЗАГРУЗКА ДАННЫХ ===
async function loadData() {
  await loadSettings();

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id) {
      subjectEl.textContent = "❌ Вкладка не найдена";
      resultEl.textContent = "";
      applySettingsToUI();
      return;
    }

    currentTabId = tab.id;

    if (!tab.url || !tab.url.includes("online.susu.ru")) {
      subjectEl.textContent = "⚠️ Откройте журнал ЮУрГУ";
      resultEl.textContent = "online.susu.ru";
      applySettingsToUI();
      return;
    }

    if (!isSubjectPageUrl(tab.url)) {
      subjectEl.textContent = "Выберите предмет";
      resultEl.textContent = "Перейдите в журнал предмета";
      pointsContainer.innerHTML = "";
      applySettingsToUI();
      if (currentSettings.semesterDashboard) {
        showView(dashboardView);
        renderDashboardScreen();
      }
      return;
    }

    subjectEl.textContent = "Загрузка...";
    resultEl.textContent = "Получение данных...";
    applySettingsToUI();

    const sendGetData = () =>
      new Promise((resolve, reject) => {
        chrome.tabs.sendMessage(tab.id, "getData", (response) => {
          if (chrome.runtime.lastError) {
            reject(chrome.runtime.lastError);
          } else {
            resolve(response);
          }
        });
      });

    let response = null;

    try {
      response = await sendGetData();
    } catch (err) {
      try {
        await chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: ["contentScript.js"],
        });
        response = await sendGetData();
      } catch (injectErr) {
        console.error("Ошибка при динамическом внедрении скрипта:", injectErr);
      }
    }

    if (response && response.entries && response.entries.length > 0) {
      response.subject = cleanSubjectName(response.subject);
      originalData = response;
      if (response.teacher && subjectTeacherEl) {
        subjectTeacherEl.textContent = `👨‍🏫 ${response.teacher}`;
        subjectTeacherEl.style.display = "block";
      } else if (subjectTeacherEl) {
        subjectTeacherEl.style.display = "none";
      }
      currentScores = originalData.entries.map((e) => e.current);
      bonusSection.style.display = "flex";
      applySettingsToUI();
      render();
      checkExistingDraft(originalData.subject);
    } else if (response && response.notInSubject) {
      if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
      subjectEl.textContent = "Выберите предмет";
      resultEl.textContent = "Перейдите в журнал предмета";
      pointsContainer.innerHTML = "";
      applySettingsToUI();
    } else if (response && response.subject && response.subject !== "Без названия") {
      if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
      subjectEl.textContent = cleanSubjectName(response.subject);
      resultEl.textContent = "Контрольные точки не найдены";
      pointsContainer.innerHTML = "";
      applySettingsToUI();
    } else {
      if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
      subjectEl.textContent = "Выберите предмет";
      resultEl.textContent = "Перейдите в журнал предмета";
      pointsContainer.innerHTML = "";
      applySettingsToUI();
    }
  } catch (error) {
    console.error("Ошибка при получении данных:", error);
    if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
    subjectEl.textContent = "❌ Ошибка";
    applySettingsToUI();
  }
}

loadData();

// === РЕНДЕР СПИСКА РАБОТ ===
function render() {
  subjectEl.textContent = cleanSubjectName(originalData.subject) || "Без названия";
  pointsContainer.innerHTML = "";

  originalData.entries.forEach((entry, idx) => {
    const div = document.createElement("div");
    div.className = "work-item";

    const title = document.createElement("div");
    title.className = "work-title";
    title.textContent = entry.title;

    const scoreValue = document.createElement("div");
    scoreValue.className = "score-value";
    const pct = entry.max > 0 ? (entry.current / entry.max) * 100 : 0;
    if (pct < 33.33) scoreValue.classList.add("red");
    else if (pct < 66.66) scoreValue.classList.add("orange");
    else scoreValue.classList.add("green");
    scoreValue.textContent = currentScores[idx];

    const maxLabel = document.createElement("div");
    maxLabel.className = "max-label";
    maxLabel.textContent = `/ ${entry.max}`;

    const scoreDisplay = document.createElement("div");
    scoreDisplay.className = "score-display";
    scoreDisplay.append(scoreValue, maxLabel);

    scoreValue.addEventListener("click", () => {
      const input = document.createElement("input");
      input.type = "number";
      input.min = "0";
      input.max = String(entry.max);
      const isDecimal = !Number.isInteger(entry.max) || !Number.isInteger(entry.current);
      input.step = isDecimal ? "0.5" : "1";
      input.value = currentScores[idx];
      input.style.width = "48px";
      input.style.textAlign = "right";
      input.style.padding = "2px 4px";
      input.style.border = "1px solid #555";
      input.style.borderRadius = "4px";
      input.style.background = "var(--input-bg)";
      input.style.color = "var(--text)";
      input.style.fontSize = "13px";

      input.addEventListener("keydown", (e) => {
        if (e.key === "-" || e.key === "+" || e.key === "e" || e.key === "E") e.preventDefault();
      });

      input.addEventListener("input", () => {
        if (input.value === "") return;
        const num = parseFloat(input.value);
        if (!isNaN(num)) {
          if (num > entry.max) input.value = entry.max;
          else if (num < 0) input.value = 0;
        }
      });

      scoreValue.replaceWith(input);
      input.focus();
      input.select();

      let finished = false;
      const finish = () => {
        if (finished) return;
        finished = true;

        let val = parseFloat(input.value);
        if (isNaN(val) || val < 0) {
          val = currentScores[idx];
        } else if (val > entry.max) {
          val = entry.max;
        }

        currentScores[idx] = val;
        updateRating();

        scoreValue.textContent = val;
        const newPct = entry.max > 0 ? (val / entry.max) * 100 : 0;
        scoreValue.className = "score-value";
        if (newPct < 33.33) scoreValue.classList.add("red");
        else if (newPct < 66.66) scoreValue.classList.add("orange");
        else scoreValue.classList.add("green");

        input.replaceWith(scoreValue);
      };

      input.addEventListener("blur", finish);
      input.addEventListener("keydown", (e) => {
        if (e.key === "Enter") finish();
        else if (e.key === "Escape") {
          finished = true;
          input.replaceWith(scoreValue);
        }
      });
    });

    div.append(title, scoreDisplay);
    pointsContainer.appendChild(div);
  });

  updateRating();
}

// === РАСЧЁТ ИТОГОВОГО РЕЙТИНГА ===
function updateRating() {
  if (!originalData?.entries) return;

  let total = 0, totalWeight = 0;
  originalData.entries.forEach((entry, idx) => {
    const pct = entry.max > 0 ? (currentScores[idx] / entry.max) * 100 : 0;
    total += pct * entry.weight;
    totalWeight += entry.weight;
  });

  const currentControlRating = totalWeight > 0 ? total / totalWeight : 0;
  const bonus = parseFloat(bonusInput.value) || 0;
  const isExam = examToggle.checked;

  let finalRating = 0;
  if (isExam) {
    const examScore = parseFloat(examInput.value) || 0;
    finalRating = currentControlRating * 0.6 + examScore * 0.4 + bonus;
    resultEl.textContent = `Итоговый рейтинг (с экзаменом): ${finalRating.toFixed(2)}%`;
  } else {
    finalRating = currentControlRating + bonus;
    // Убираем слово "автомат", просто "Итоговый рейтинг"
    resultEl.textContent = `Итоговый рейтинг: ${finalRating.toFixed(2)}%`;
  }

  // Обновляем оценку (Фича 4)
  const gradeInfo = getAcademicGrade(finalRating);
  ratingVal.textContent = `${finalRating.toFixed(2)}%`;
  gradeBadge.textContent = gradeInfo.label;
  gradeBadge.className = `grade-badge ${gradeInfo.badgeClass}`;
  gradeSubtext.textContent = gradeInfo.subtext;

  // Прогресс-бар
  const fillPct = Math.min(100, Math.max(0, finalRating));
  progressFill.style.width = `${fillPct}%`;

  // Диапазон (Фича 2)
  rangeCurr.textContent = `${finalRating.toFixed(1)}%`;
  updateRangeForecast(totalWeight, bonus);

  // Калькулятор целей (Фича 1)
  if (activeTarget) {
    calculateTargetGoal(activeTarget);
  }

  // Сохраняем чистый предмет в историю семестра (Фича 7)
  saveSubjectToSemesterHistory(
    originalData.subject,
    finalRating,
    originalData.teacher,
    originalData.subjectId
  );
}