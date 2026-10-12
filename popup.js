// popup.js

// === DOM Элементы ===
const mainView = document.getElementById("main-view");
const settingsView = document.getElementById("settings-view");
const dashboardView = document.getElementById("dashboard-view");
const infoView = document.getElementById("info-view");
const materialsView = document.getElementById("materials-view");
const reviewsView = document.getElementById("reviews-view");
const adminView = document.getElementById("admin-view");

const subjectEl = document.getElementById("subject");
const subjectTeacherEl = document.getElementById("subject-teacher");
const teacherReviewsBtn = document.getElementById("teacher-reviews-btn");
const teacherReviewsCount = document.getElementById("teacher-reviews-count");
const pointsContainer = document.getElementById("points-container");
const resultEl = document.getElementById("result");
const bonusSection = document.getElementById("bonus-section");
const bonusInput = document.getElementById("bonus-input");

// Кнопки в шапке
const adminBtn = document.getElementById("admin-btn");
const dashboardBtn = document.getElementById("dashboard-btn");
const settingsBtn = document.getElementById("settings-btn");
const infoBtn = document.getElementById("info-btn");
const themeToggle = document.getElementById("theme-toggle");

// Кнопки возврата
const backBtn = document.getElementById("back-btn");
const backFromSettingsBtn = document.getElementById("back-from-settings-btn");
const backFromDashboardBtn = document.getElementById("back-from-dashboard-btn");
const backFromMaterialsBtn = document.getElementById("back-from-materials-btn");
const backFromReviewsBtn = document.getElementById("back-from-reviews-btn");
const backFromAdminBtn = document.getElementById("back-from-admin-btn");
const adminRefreshBtn = document.getElementById("admin-refresh-btn");

// Админка
const adminTabBtns = document.querySelectorAll(".admin-tab-btn");
const adminTabUsers = document.getElementById("admin-tab-users");
const adminTabReviews = document.getElementById("admin-tab-reviews");
const adminTabMaterials = document.getElementById("admin-tab-materials");
const adminUsersList = document.getElementById("admin-users-list");
const adminReviewsList = document.getElementById("admin-reviews-list");
const adminMaterialsList = document.getElementById("admin-materials-list");

// Секретный диалог
const secretAdminModal = document.getElementById("secret-admin-modal");
const adminMyUuid = document.getElementById("admin-my-uuid");
const secretAdminInput = document.getElementById("secret-admin-input");
const secretAdminStatus = document.getElementById("secret-admin-status");
const secretAdminSubmitBtn = document.getElementById("secret-admin-submit-btn");
const secretAdminCancelBtn = document.getElementById("secret-admin-cancel-btn");
const appVersionBadge = document.getElementById("app-version-badge");

// AI-Сводка
const aiSummaryCard = document.getElementById("ai-summary-card");
const aiSummaryCountBadge = document.getElementById("ai-summary-count-badge");
const aiSummaryText = document.getElementById("ai-summary-text");

// Материалы
const materialsCheckpointTitle = document.getElementById("materials-checkpoint-title");
const materialsCheckpointSub = document.getElementById("materials-checkpoint-sub");
const materialsTotalCount = document.getElementById("materials-total-count");
const materialsList = document.getElementById("materials-list");
const matTitleInput = document.getElementById("mat-title-input");
const matYearInput = document.getElementById("mat-year-input");
const matFileInput = document.getElementById("mat-file-input");
const matFileSelectBtn = document.getElementById("mat-file-select-btn");
const matFileName = document.getElementById("mat-file-name");
const matUrlInput = document.getElementById("mat-url-input");
const matSubmitBtn = document.getElementById("mat-submit-btn");
const matStatusMsg = document.getElementById("mat-status-msg");

// Отзывы
const reviewsTeacherName = document.getElementById("reviews-teacher-name");
const reviewsSubjectName = document.getElementById("reviews-subject-name");
const reviewsStatsCard = document.getElementById("reviews-stats-card");
const statAvtomatPct = document.getElementById("stat-avtomat-pct");
const statDiffVal = document.getElementById("stat-diff-val");
const statAttPct = document.getElementById("stat-att-pct");
const reviewsTotalCount = document.getElementById("reviews-total-count");
const reviewsList = document.getElementById("reviews-list");
const revTextInput = document.getElementById("rev-text-input");
const revDiffSelect = document.getElementById("rev-diff-select");
const revYearInput = document.getElementById("rev-year-input");
const revAvtomatChk = document.getElementById("rev-avtomat-chk");
const revStrictChk = document.getElementById("rev-strict-chk");
const revSubmitBtn = document.getElementById("rev-submit-btn");
const revStatusMsg = document.getElementById("rev-status-msg");

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
  targetCalc: true,          // 1. Калькулятор целей
  rangeForecast: true,       // 2. Прогноз диапазона
  quickActions: true,        // 3. Быстрые действия
  academicGrade: true,       // 4. Оценка по шкале БРС
  examMode: true,            // 5. Учет экзамена
  inlineWidget: true,        // 6. Виджет на странице
  semesterDashboard: true,   // 7. Сводка семестра
  saveDrafts: true,          // 8. Сохранение плана
  communityMaterials: true,  // 9. База студенческих работ и методичек
  teacherReviews: true       // 10. Сводка и отзывы о преподавателях
};

let currentSettings = { ...DEFAULT_SETTINGS };
let originalData = null;
let currentScores = [];
let activeTarget = null;
let currentTabId = null;

// Переменные для Supabase
let currentCheckpoints = [];
let checkpointMaterialsCount = {};
let selectedFile = null;
let currentActiveEntry = null;
let currentActiveCheckpointId = null;

// Пользователь, права и сессия
let myUserId = null;
let myUserProfile = { is_admin: false, is_banned: false, can_view_materials: true };
let versionClickCount = 0;
let versionClickTimeout = null;

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
  if (backFromMaterialsBtn?.querySelector("img")) {
    backFromMaterialsBtn.querySelector("img").src = path + "arrow-left.svg";
  }
  if (backFromReviewsBtn?.querySelector("img")) {
    backFromReviewsBtn.querySelector("img").src = path + "arrow-left.svg";
  }
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
  materialsView.style.display = "none";
  reviewsView.style.display = "none";
  adminView.style.display = "none";
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
backFromMaterialsBtn?.addEventListener("click", () => showView(mainView));
backFromReviewsBtn?.addEventListener("click", () => showView(mainView));
backFromAdminBtn?.addEventListener("click", () => showView(mainView));

teacherReviewsBtn?.addEventListener("click", () => openReviewsScreen());
adminBtn?.addEventListener("click", () => openAdminScreen());

adminRefreshBtn?.addEventListener("click", () => {
  const activeTab = document.querySelector(".admin-tab-btn.active")?.dataset.tab || "users";
  switchAdminTab(activeTab);
});

// Секретный вход по 5 кликам по версии
const versionFooter = document.querySelector(".version-footer");

function handleSecretVersionClick() {
  versionClickCount++;
  clearTimeout(versionClickTimeout);
  versionClickTimeout = setTimeout(() => {
    versionClickCount = 0;
  }, 3500);

  if (versionClickCount >= 5) {
    versionClickCount = 0;
    if (adminMyUuid) adminMyUuid.textContent = myUserId || "не определен";
    if (secretAdminInput) {
      secretAdminInput.value = "";
      setTimeout(() => secretAdminInput.focus(), 60);
    }
    if (secretAdminStatus) {
      secretAdminStatus.textContent = "";
      secretAdminStatus.className = "action-status-msg";
    }
    if (secretAdminModal) {
      secretAdminModal.style.display = "flex";
    }
  }
}

appVersionBadge?.addEventListener("click", handleSecretVersionClick);
versionFooter?.addEventListener("click", (e) => {
  if (e.target !== appVersionBadge) {
    handleSecretVersionClick();
  }
});

secretAdminCancelBtn?.addEventListener("click", () => {
  if (secretAdminModal) secretAdminModal.style.display = "none";
});

secretAdminModal?.addEventListener("click", (e) => {
  if (e.target === secretAdminModal) {
    secretAdminModal.style.display = "none";
  }
});

secretAdminInput?.addEventListener("keydown", (e) => {
  if (e.key === "Enter") {
    secretAdminSubmitBtn?.click();
  }
});

async function computeSHA256(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Хэш мастер-ключа (пароль не хранится в открытом виде)
const ADMIN_KEY_SHA256 = "699f403c4b12dbe271f50eb54f75e7febcb38a5341e482e93fcc6c90a4290741";

secretAdminSubmitBtn?.addEventListener("click", async () => {
  const pin = secretAdminInput.value.trim();
  if (!pin) return;

  secretAdminSubmitBtn.disabled = true;
  secretAdminSubmitBtn.textContent = "⏳ Проверка...";
  secretAdminStatus.textContent = "";

  let isValid = false;

  // 1. Приоритет: серверная проверка через Supabase RPC (пароль не хранится на клиенте)
  if (typeof SusuSupabase !== "undefined" && typeof SusuSupabase.verifyAdminPin === "function") {
    try {
      isValid = await SusuSupabase.verifyAdminPin(pin);
    } catch (e) {
      console.warn("RPC verification failed, using fallback:", e);
    }
  }

  // 2. Резервная оффлайн-проверка (если нет связи с Supabase)
  if (!isValid) {
    const hashedInput = await computeSHA256(pin);
    isValid = (hashedInput === ADMIN_KEY_SHA256);
  }

  secretAdminSubmitBtn.disabled = false;
  secretAdminSubmitBtn.textContent = "Подтвердить";

  if (isValid) {
    secretAdminStatus.className = "action-status-msg success";
    secretAdminStatus.textContent = "✅ Вы назначены Администратором!";

    myUserProfile.is_admin = true;
    myUserProfile.can_view_materials = true;
    chrome.storage.local.set({ is_admin: true });

    if (typeof SusuSupabase !== "undefined" && myUserId) {
      SusuSupabase.updateUser(myUserId, { is_admin: true, can_view_materials: true }).catch(() => {});
    }

    applySettingsToUI();

    setTimeout(() => {
      if (secretAdminModal) secretAdminModal.style.display = "none";
      openAdminScreen();
    }, 600);
  } else {
    secretAdminStatus.className = "action-status-msg error";
    secretAdminStatus.textContent = "❌ Неверный ключ доступа.";
  }
});

const externalLinkBtn = document.getElementById("external-link-btn");
externalLinkBtn?.addEventListener("click", () => {
  chrome.tabs.create({ url: "https://online.susu.ru" });
});

// === СЕССИЯ ПОЛЬЗОВАТЕЛЯ И ПРАВА ДОСТУПА ===
async function initUserSession() {
  return new Promise((resolve) => {
    chrome.storage.local.get(["user_id", "is_admin"], async (res) => {
      if (res && res.user_id) {
        myUserId = res.user_id;
      } else {
        myUserId = crypto.randomUUID();
        chrome.storage.local.set({ user_id: myUserId });
      }

      const localIsAdmin = !!(res && res.is_admin);

      try {
        if (typeof SusuSupabase !== "undefined") {
          const profile = await SusuSupabase.getUserProfile(myUserId);
          myUserProfile = {
            ...profile,
            is_admin: profile.is_admin || localIsAdmin
          };
          if (profile.is_admin || localIsAdmin) {
            chrome.storage.local.set({ is_admin: true });
          }
        }
      } catch (err) {
        myUserProfile = {
          user_id: myUserId,
          is_banned: false,
          can_view_materials: true,
          is_admin: localIsAdmin
        };
      }

      applySettingsToUI();
      resolve(myUserProfile);
    });
  });
}

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
    if (originalData?.entries) render();
  });
}

function applySettingsToUI() {
  const hasData = originalData && originalData.entries && originalData.entries.length > 0;

  // Контроль видимости базы материалов для конкретных пользователей
  if (!myUserProfile.can_view_materials) {
    currentSettings.communityMaterials = false;
  }

  const matSettingItem = settingsView.querySelector("input[data-setting='communityMaterials']")?.closest(".setting-item");
  if (matSettingItem) {
    matSettingItem.style.display = myUserProfile.can_view_materials ? "flex" : "none";
  }

  // Кнопка панели администратора в шапке (СТРОГО скрыта от всех, кроме админа)
  if (adminBtn) {
    adminBtn.style.display = myUserProfile.is_admin ? "inline-flex" : "none";
  }

  gradeCard.style.display = (hasData && currentSettings.academicGrade) ? "block" : "none";
  rangeCard.style.display = (hasData && currentSettings.rangeForecast) ? "flex" : "none";
  targetCard.style.display = (hasData && currentSettings.targetCalc) ? "block" : "none";
  quickActionsBar.style.display = (hasData && currentSettings.quickActions) ? "flex" : "none";
  examSection.style.display = (hasData && currentSettings.examMode) ? "block" : "none";
  planFooter.style.display = (hasData && currentSettings.saveDrafts) ? "block" : "none";
  dashboardBtn.style.display = currentSettings.semesterDashboard ? "flex" : "none";

  if (!hasData || !currentSettings.teacherReviews || !originalData?.teacher) {
    if (teacherReviewsBtn) teacherReviewsBtn.style.display = "none";
  } else {
    if (teacherReviewsBtn) teacherReviewsBtn.style.display = "inline-flex";
  }

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
  await initUserSession();
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
      subjectEl.textContent = "⚠️ Откройте страницу журнала";
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

      // Обновляем бейдж отзывов о преподавателе
      if (response.teacher && currentSettings.teacherReviews && typeof SusuSupabase !== "undefined") {
        teacherReviewsBtn.style.display = "inline-flex";
        SusuSupabase.getTeacherReviews(response.teacher).then(({ reviews }) => {
          if (reviews && reviews.length > 0) {
            teacherReviewsCount.textContent = reviews.length;
            teacherReviewsCount.style.display = "inline-block";
          } else {
            teacherReviewsCount.style.display = "none";
          }
        }).catch(() => {});
      } else if (teacherReviewsBtn) {
        teacherReviewsBtn.style.display = "none";
      }

      currentScores = originalData.entries.map((e) => e.current);
      bonusSection.style.display = "flex";
      applySettingsToUI();
      render();
      checkExistingDraft(originalData.subject);

      // Фоновая синхронизация с базой Supabase
      if (response.subjectId && currentSettings.communityMaterials && typeof SusuSupabase !== "undefined") {
        SusuSupabase.syncSubjectData(
          response.subjectId,
          response.subject,
          response.teacher,
          response.entries
        ).then(async (checkpoints) => {
          currentCheckpoints = checkpoints || [];
          const countMap = await SusuSupabase.getMaterialsCountForSubject(response.subjectId);
          checkpointMaterialsCount = {};
          currentCheckpoints.forEach((cp) => {
            if (countMap[cp.id]) {
              checkpointMaterialsCount[cp.title] = countMap[cp.id];
            }
          });
          render();
        }).catch((err) => console.warn("Supabase background sync:", err));
      }
    } else if (response && response.notInSubject) {
      if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
      if (teacherReviewsBtn) teacherReviewsBtn.style.display = "none";
      subjectEl.textContent = "Выберите предмет";
      resultEl.textContent = "Перейдите в журнал предмета";
      pointsContainer.innerHTML = "";
      applySettingsToUI();
    } else if (response && response.subject && response.subject !== "Без названия") {
      if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
      if (teacherReviewsBtn) teacherReviewsBtn.style.display = "none";
      subjectEl.textContent = cleanSubjectName(response.subject);
      resultEl.textContent = "Контрольные точки не найдены";
      pointsContainer.innerHTML = "";
      applySettingsToUI();
    } else {
      if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
      if (teacherReviewsBtn) teacherReviewsBtn.style.display = "none";
      subjectEl.textContent = "Выберите предмет";
      resultEl.textContent = "Перейдите в журнал предмета";
      pointsContainer.innerHTML = "";
      applySettingsToUI();
    }
  } catch (error) {
    console.error("Ошибка при получении данных:", error);
    if (subjectTeacherEl) subjectTeacherEl.style.display = "none";
    if (teacherReviewsBtn) teacherReviewsBtn.style.display = "none";
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

    const rightWrap = document.createElement("div");
    rightWrap.className = "work-actions";

    // Скрепка для базы материалов (Фича 9)
    if (currentSettings.communityMaterials) {
      const clipBtn = document.createElement("button");
      clipBtn.className = "work-clip-btn";
      const count = checkpointMaterialsCount[entry.title] || 0;
      clipBtn.innerHTML = count > 0 
        ? `📎 <span class="clip-counter">${count}</span>` 
        : `📎`;
      if (count > 0) clipBtn.classList.add("has-materials");
      clipBtn.title = count > 0 ? `Материалы к работе (${count})` : "Прикрепить работу / методичку";
      clipBtn.addEventListener("click", () => {
        openMaterialsScreen(entry);
      });
      rightWrap.appendChild(clipBtn);
    }

    rightWrap.appendChild(scoreDisplay);
    div.append(title, rightWrap);
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

// === ЭКРАН МАТЕРИАЛОВ К КОНТРОЛЬНОЙ ТОЧКЕ (ФИЧА 9) ===
async function openMaterialsScreen(entry) {
  currentActiveEntry = entry;
  materialsCheckpointTitle.textContent = entry.title;
  materialsCheckpointSub.textContent = `${cleanSubjectName(originalData?.subject)} • Максимум: ${entry.max} б.`;
  matStatusMsg.textContent = "";
  matStatusMsg.className = "action-status-msg";
  matTitleInput.value = "";
  matUrlInput.value = "";
  matFileInput.value = "";
  selectedFile = null;
  matFileName.textContent = "Файл не выбран";

  showView(materialsView);

  let cp = currentCheckpoints.find((c) => c.title === entry.title);
  if (!cp && originalData?.subjectId && typeof SusuSupabase !== "undefined") {
    currentCheckpoints = await SusuSupabase.getCheckpoints(originalData.subjectId);
    cp = currentCheckpoints.find((c) => c.title === entry.title);
  }

  currentActiveCheckpointId = cp ? cp.id : null;
  if (currentActiveCheckpointId) {
    await loadMaterialsList(currentActiveCheckpointId);
  } else {
    materialsList.innerHTML = `<div class="empty-state">Синхронизация контрольной точки с базой...</div>`;
    if (originalData?.subjectId && typeof SusuSupabase !== "undefined") {
      currentCheckpoints = await SusuSupabase.syncSubjectData(
        originalData.subjectId,
        originalData.subject,
        originalData.teacher,
        originalData.entries
      );
      const reFound = currentCheckpoints.find((c) => c.title === entry.title);
      if (reFound) {
        currentActiveCheckpointId = reFound.id;
        await loadMaterialsList(currentActiveCheckpointId);
      } else {
        materialsList.innerHTML = `<div class="empty-state">Пока нет загруженных материалов. Будьте первым!</div>`;
      }
    }
  }
}

async function loadMaterialsList(checkpointId) {
  if (!checkpointId || typeof SusuSupabase === "undefined") return;
  materialsList.innerHTML = `<div class="empty-state">Загрузка материалов...</div>`;
  try {
    const list = await SusuSupabase.getMaterialsForCheckpoint(checkpointId);
    materialsTotalCount.textContent = list.length;
    materialsList.innerHTML = "";

    if (!list || list.length === 0) {
      materialsList.innerHTML = `<div class="empty-state">К этой работе пока нет материалов. Загрузите свою работу первым! 🚀</div>`;
      return;
    }

    list.forEach((item) => {
      const card = document.createElement("div");
      card.className = "material-card";

      const header = document.createElement("div");
      header.className = "material-header";

      const titleEl = document.createElement("div");
      titleEl.className = "material-title";
      titleEl.textContent = item.title;

      header.appendChild(titleEl);

      const meta = document.createElement("div");
      meta.className = "material-meta";
      meta.innerHTML = `<span>📅 ${item.year} г.</span>`;
      if (item.isFresh) {
        meta.innerHTML += `<span class="freshness-badge">🔥 Свежая</span>`;
      }
      if (item.teacher_name) {
        meta.innerHTML += `<span>👨‍🏫 ${item.teacher_name}</span>`;
      }

      const footer = document.createElement("div");
      footer.className = "material-footer";

      const dlLink = document.createElement("a");
      dlLink.className = "download-link-btn";
      dlLink.href = item.file_url;
      dlLink.target = "_blank";
      dlLink.innerHTML = "⬇ Открыть / Скачать";

      const voteGroup = document.createElement("div");
      voteGroup.className = "vote-group";

      const upBtn = document.createElement("button");
      upBtn.className = "vote-btn";
      upBtn.textContent = `▲ ${item.upvotes || 0}`;
      upBtn.addEventListener("click", async () => {
        await SusuSupabase.voteMaterial(item.id, true);
        item.upvotes = (item.upvotes || 0) + 1;
        upBtn.textContent = `▲ ${item.upvotes}`;
      });

      const downBtn = document.createElement("button");
      downBtn.className = "vote-btn";
      downBtn.textContent = `▼ ${item.downvotes || 0}`;
      downBtn.addEventListener("click", async () => {
        await SusuSupabase.voteMaterial(item.id, false);
        item.downvotes = (item.downvotes || 0) + 1;
        downBtn.textContent = `▼ ${item.downvotes}`;
      });

      voteGroup.append(upBtn, downBtn);
      footer.append(dlLink, voteGroup);

      card.append(header, meta, footer);
      materialsList.appendChild(card);
    });
  } catch (e) {
    materialsList.innerHTML = `<div class="empty-state">Ошибка загрузки: ${e.message}</div>`;
  }
}

// Загрузка файла в материалах (проверка формата и размера)
const ALLOWED_EXTENSIONS = [
  "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
  "txt", "rtf", "odt", "zip", "rar", "7z", "png", "jpg", "jpeg"
];
const MAX_FILE_SIZE = 20 * 1024 * 1024; // 20 MB

matFileSelectBtn?.addEventListener("click", () => matFileInput.click());
matFileInput?.addEventListener("change", () => {
  if (matFileInput.files && matFileInput.files[0]) {
    const file = matFileInput.files[0];
    const ext = (file.name.split(".").pop() || "").toLowerCase();

    if (!ALLOWED_EXTENSIONS.includes(ext)) {
      matStatusMsg.className = "action-status-msg error";
      matStatusMsg.textContent = "❌ Запрещенный формат! Разрешены только PDF, Office, архивы (ZIP/RAR) и изображения.";
      matFileInput.value = "";
      selectedFile = null;
      matFileName.textContent = "Файл не выбран";
      return;
    }

    if (file.size > MAX_FILE_SIZE) {
      matStatusMsg.className = "action-status-msg error";
      matStatusMsg.textContent = `❌ Файл слишком большой (${(file.size / 1024 / 1024).toFixed(1)} MB). Лимит: 20 MB.`;
      matFileInput.value = "";
      selectedFile = null;
      matFileName.textContent = "Файл не выбран";
      return;
    }

    selectedFile = file;
    const sizeMb = (selectedFile.size / 1024 / 1024).toFixed(2);
    matStatusMsg.textContent = "";
    matFileName.textContent = `${selectedFile.name} (${sizeMb} MB)`;
  } else {
    selectedFile = null;
    matFileName.textContent = "Файл не выбран";
  }
});

matSubmitBtn?.addEventListener("click", async () => {
  if (!currentActiveCheckpointId && currentActiveEntry) {
    const found = currentCheckpoints.find((c) => c.title === currentActiveEntry.title);
    if (found) currentActiveCheckpointId = found.id;
  }

  if (!currentActiveCheckpointId) {
    matStatusMsg.className = "action-status-msg error";
    matStatusMsg.textContent = "Ошибка: контрольная точка не синхронизирована.";
    return;
  }

  const title = matTitleInput.value.trim();
  const externalUrl = matUrlInput.value.trim();
  const year = parseInt(matYearInput.value, 10) || new Date().getFullYear();

  if (!selectedFile && !externalUrl) {
    matStatusMsg.className = "action-status-msg error";
    matStatusMsg.textContent = "Выберите файл или укажите ссылку на материал!";
    return;
  }

  matSubmitBtn.disabled = true;
  matSubmitBtn.textContent = "⏳ Загрузка в базу...";
  matStatusMsg.className = "action-status-msg";
  matStatusMsg.textContent = "";

  try {
    await SusuSupabase.uploadMaterial({
      checkpointId: currentActiveCheckpointId,
      subjectId: originalData?.subjectId,
      teacherName: originalData?.teacher,
      title: title || (selectedFile ? selectedFile.name : "Материал"),
      file: selectedFile,
      externalUrl: externalUrl || null,
      year
    });

    matStatusMsg.className = "action-status-msg success";
    matStatusMsg.textContent = "✅ Работа успешно добавлена!";
    matTitleInput.value = "";
    matUrlInput.value = "";
    matFileInput.value = "";
    selectedFile = null;
    matFileName.textContent = "Файл не выбран";

    await loadMaterialsList(currentActiveCheckpointId);

    // Обновляем бейдж скрепки
    if (currentActiveEntry) {
      checkpointMaterialsCount[currentActiveEntry.title] = (checkpointMaterialsCount[currentActiveEntry.title] || 0) + 1;
      render();
    }
  } catch (err) {
    matStatusMsg.className = "action-status-msg error";
    matStatusMsg.textContent = `Ошибка: ${err.message || "Не удалось загрузить"}`;
  } finally {
    matSubmitBtn.disabled = false;
    matSubmitBtn.textContent = "📤 Опубликовать в базу";
  }
});

// === ЭКРАН СВОДКИ И ОТЗЫВОВ О ПРЕПОДАВАТЕЛЕ (ФИЧА 10) ===
async function openReviewsScreen() {
  reviewsTeacherName.textContent = `👨‍🏫 ${originalData?.teacher || "Преподаватель"}`;
  reviewsSubjectName.textContent = cleanSubjectName(originalData?.subject);
  revStatusMsg.textContent = "";
  revStatusMsg.className = "action-status-msg";
  revTextInput.value = "";

  showView(reviewsView);
  if (originalData?.teacher) {
    await loadTeacherReviewsList(originalData.teacher);
  }
}

async function loadTeacherReviewsList(teacherName) {
  if (!teacherName || typeof SusuSupabase === "undefined") return;
  reviewsList.innerHTML = `<div class="empty-state">Загрузка отзывов...</div>`;
  try {
    const { reviews, stats } = await SusuSupabase.getTeacherReviews(teacherName);
    reviewsTotalCount.textContent = reviews ? reviews.length : 0;
    reviewsList.innerHTML = "";

    // 1. Подтягиваем или автогенерируем AI-выжимку
    const summary = await SusuSupabase.getTeacherSummary(teacherName);
    if (summary && summary.summary_text && aiSummaryCard) {
      aiSummaryCard.style.display = "block";
      aiSummaryCountBadge.textContent = `на основе ${summary.reviews_count || (reviews ? reviews.length : 1)} отзывов`;
      aiSummaryText.textContent = summary.summary_text;
    } else if (reviews && reviews.length > 0 && typeof SusuGroq !== "undefined" && aiSummaryCard) {
      // Отзывы есть, а выжимки еще нет — генерируем на лету и сохраняем!
      aiSummaryCard.style.display = "block";
      aiSummaryCountBadge.textContent = "✨ Генерация нейросетью...";
      aiSummaryText.textContent = "Анализирую отзывы студентов и составляю выжимку...";

      SusuGroq.generateTeacherSummary(teacherName, reviews).then(async (newSummary) => {
        if (newSummary && newSummary.trim()) {
          aiSummaryCountBadge.textContent = `на основе ${reviews.length} отзывов`;
          aiSummaryText.textContent = newSummary.trim();
          await SusuSupabase.saveTeacherSummary(teacherName, newSummary.trim(), reviews.length);
        } else {
          aiSummaryCard.style.display = "none";
        }
      }).catch((e) => {
        console.warn("AI summary error:", e);
        if (aiSummaryCard) aiSummaryCard.style.display = "none";
      });
    } else if (aiSummaryCard) {
      aiSummaryCard.style.display = "none";
    }

    if (stats) {
      reviewsStatsCard.style.display = "block";
      statAvtomatPct.textContent = `${stats.avtomatPct}%`;
      statDiffVal.textContent = `${stats.avgDifficulty} / 5`;
      statAttPct.textContent = `${stats.attendancePct}%`;
    } else {
      reviewsStatsCard.style.display = "none";
    }

    if (!reviews || reviews.length === 0) {
      reviewsList.innerHTML = `<div class="empty-state">Об этом преподавателе пока нет отзывов. Напишите первый совет! 💡</div>`;
      return;
    }

    reviews.forEach((item) => {
      const card = document.createElement("div");
      card.className = "review-card";

      const header = document.createElement("div");
      header.className = "review-header";
      header.style.fontSize = "12px";
      header.style.lineHeight = "1.35";
      header.textContent = item.text;

      const meta = document.createElement("div");
      meta.className = "review-meta";
      meta.innerHTML = `<span>📅 ${item.year} г.</span><span>⚡ Сложность: ${item.difficulty}/5</span>`;
      if (item.gives_avtomat) {
        meta.innerHTML += `<span class="freshness-badge">🎯 Автомат</span>`;
      }
      if (item.attendance_strict) {
        meta.innerHTML += `<span>📝 Строго посещения</span>`;
      }

      const footer = document.createElement("div");
      footer.className = "review-footer";

      const likeBtn = document.createElement("button");
      likeBtn.className = "vote-btn";
      likeBtn.textContent = `👍 Полезно (${item.likes || 0})`;
      likeBtn.addEventListener("click", async () => {
        await SusuSupabase.likeReview(item.id);
        item.likes = (item.likes || 0) + 1;
        likeBtn.textContent = `👍 Полезно (${item.likes})`;
      });

      footer.appendChild(likeBtn);
      card.append(header, meta, footer);
      reviewsList.appendChild(card);
    });
  } catch (e) {
    reviewsList.innerHTML = `<div class="empty-state">Ошибка загрузки отзывов: ${e.message}</div>`;
  }
}

revSubmitBtn?.addEventListener("click", async () => {
  if (myUserProfile.is_banned) {
    revStatusMsg.className = "action-status-msg error";
    revStatusMsg.textContent = "Ваш аккаунт заблокирован администратором.";
    return;
  }

  const text = revTextInput.value.trim();
  if (!text) {
    revStatusMsg.className = "action-status-msg error";
    revStatusMsg.textContent = "Пожалуйста, напишите текст отзыва или совета!";
    return;
  }

  // Защита от спама и исчерпания лимитов (таймаут 30 секунд между отправками)
  const now = Date.now();
  const lastReviewTime = parseInt(localStorage.getItem("last_review_submit_time") || "0", 10);
  const cooldownMs = 30000;
  if (now - lastReviewTime < cooldownMs) {
    const waitSec = Math.ceil((cooldownMs - (now - lastReviewTime)) / 1000);
    revStatusMsg.className = "action-status-msg error";
    revStatusMsg.textContent = `⏳ Пожалуйста, подождите ${waitSec} сек. перед отправкой следующего отзыва.`;
    return;
  }

  revSubmitBtn.disabled = true;
  revSubmitBtn.textContent = "⏳ Проверка нейросетью...";
  revStatusMsg.className = "action-status-msg";
  revStatusMsg.textContent = "";

  try {
    // 1. Модерация через Groq (Llama / Qwen)
    if (typeof SusuGroq !== "undefined") {
      const modResult = await SusuGroq.moderateReview(text);
      if (!modResult.allowed) {
        revSubmitBtn.disabled = false;
        revSubmitBtn.textContent = "💬 Опубликовать совет";
        revStatusMsg.className = "action-status-msg error";
        revStatusMsg.textContent = `❌ Модерация не пройдена: ${modResult.reason}`;
        return;
      }
    }

    revSubmitBtn.textContent = "⏳ Сохранение в базу...";

    // 2. Добавление отзыва в Supabase
    await SusuSupabase.addTeacherReview({
      teacherName: originalData?.teacher,
      subjectId: originalData?.subjectId,
      subjectName: originalData?.subject,
      text,
      difficulty: parseInt(revDiffSelect.value, 10) || 3,
      givesAvtomat: revAvtomatChk.checked,
      attendanceStrict: revStrictChk.checked,
      year: parseInt(revYearInput.value, 10) || new Date().getFullYear()
    });

    revStatusMsg.className = "action-status-msg success";
    revStatusMsg.textContent = "✅ Спасибо! Ваш совет опубликован.";
    revTextInput.value = "";
    localStorage.setItem("last_review_submit_time", Date.now().toString());

    // 3. Проверка необходимости обновления AI-выжимки (1-й отзыв или каждый 5-й)
    const { reviews } = await SusuSupabase.getTeacherReviews(originalData?.teacher);
    const count = reviews ? reviews.length : 1;

    if (typeof SusuGroq !== "undefined" && (count === 1 || count % 5 === 0)) {
      revSubmitBtn.textContent = "✨ Генерация AI-выжимки...";
      try {
        const newSummary = await SusuGroq.generateTeacherSummary(originalData?.teacher, reviews);
        if (newSummary && newSummary.trim()) {
          await SusuSupabase.saveTeacherSummary(originalData?.teacher, newSummary.trim(), count);
        }
      } catch (sumErr) {
        console.warn("Summary generation error:", sumErr);
      }
    }

    await loadTeacherReviewsList(originalData?.teacher);

    // Обновляем бейдж счетчика в шапке
    const headerCount = parseInt(teacherReviewsCount.textContent, 10) || 0;
    teacherReviewsCount.textContent = headerCount + 1;
    teacherReviewsCount.style.display = "inline-block";
  } catch (err) {
    revStatusMsg.className = "action-status-msg error";
    revStatusMsg.textContent = `Ошибка: ${err.message || "Не удалось сохранить"}`;
  } finally {
    revSubmitBtn.disabled = false;
    revSubmitBtn.textContent = "💬 Опубликовать совет";
  }
});

// === АДМИН-ПАНЕЛЬ (ФУНКЦИОНАЛ ДЛЯ ВАЙТЛИСТА) ===
async function openAdminScreen() {
  if (!myUserProfile.is_admin) return;
  showView(adminView);
  const activeTab = document.querySelector(".admin-tab-btn.active")?.dataset.tab || "users";
  switchAdminTab(activeTab);
}

adminTabBtns.forEach((btn) => {
  btn.addEventListener("click", () => {
    adminTabBtns.forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    switchAdminTab(btn.dataset.tab);
  });
});

function switchAdminTab(tabName) {
  if (adminTabUsers) adminTabUsers.style.display = tabName === "users" ? "block" : "none";
  if (adminTabReviews) adminTabReviews.style.display = tabName === "reviews" ? "block" : "none";
  if (adminTabMaterials) adminTabMaterials.style.display = tabName === "materials" ? "block" : "none";

  if (tabName === "users") renderAdminUsers();
  else if (tabName === "reviews") renderAdminReviews();
  else if (tabName === "materials") renderAdminMaterials();
}

async function renderAdminUsers() {
  if (!adminUsersList) return;
  adminUsersList.innerHTML = `<div class="empty-state">Загрузка пользователей...</div>`;
  try {
    const users = await SusuSupabase.getAllUsers();
    adminUsersList.innerHTML = "";
    if (users.length === 0) {
      adminUsersList.innerHTML = `<div class="empty-state">Пользователи еще не зарегистрированы в базе.</div>`;
      return;
    }

    users.forEach((u) => {
      const card = document.createElement("div");
      card.className = "admin-card";

      const isMe = u.user_id === myUserId;
      const header = document.createElement("div");
      header.className = "admin-card-header";
      header.innerHTML = `<span>👤 Студент ${isMe ? '<strong style="color:#22c55e;">(Вы)</strong>' : ''}</span><span style="font-size:10px; opacity:0.6;">${new Date(u.last_active).toLocaleDateString()}</span>`;

      const uuidDiv = document.createElement("div");
      uuidDiv.className = "admin-uuid-text";
      uuidDiv.textContent = u.user_id;

      const actions = document.createElement("div");
      actions.className = "admin-actions-row";

      // 1. Тумблер видимости материалов для студента
      const matBtn = document.createElement("button");
      matBtn.className = `admin-mini-btn ${u.can_view_materials ? 'active' : 'danger'}`;
      matBtn.textContent = u.can_view_materials ? "👀 Работы: ВКЛ" : "🙈 Работы: СКРЫТЫ";
      matBtn.title = "Включить/скрыть доступ к базе работ и скрепкам для этого UUID";
      matBtn.addEventListener("click", async () => {
        try {
          const newVal = !u.can_view_materials;
          matBtn.disabled = true;
          await SusuSupabase.updateUser(u.user_id, { can_view_materials: newVal });
          u.can_view_materials = newVal;
          matBtn.className = `admin-mini-btn ${u.can_view_materials ? 'active' : 'danger'}`;
          matBtn.textContent = u.can_view_materials ? "👀 Работы: ВКЛ" : "🙈 Работы: СКРЫТЫ";
        } catch (err) {
          alert("Не удалось изменить статус доступа: " + (err.message || err));
        } finally {
          matBtn.disabled = false;
        }
      });

      // 2. Тумблер бана
      const banBtn = document.createElement("button");
      banBtn.className = `admin-mini-btn ${u.is_banned ? 'danger' : ''}`;
      banBtn.textContent = u.is_banned ? "🚫 Забанен" : "✅ Активен";
      banBtn.addEventListener("click", async () => {
        try {
          const newVal = !u.is_banned;
          banBtn.disabled = true;
          await SusuSupabase.updateUser(u.user_id, { is_banned: newVal });
          u.is_banned = newVal;
          banBtn.className = `admin-mini-btn ${u.is_banned ? 'danger' : ''}`;
          banBtn.textContent = u.is_banned ? "🚫 Забанен" : "✅ Активен";
        } catch (err) {
          alert("Не удалось изменить статус бана: " + (err.message || err));
        } finally {
          banBtn.disabled = false;
        }
      });

      // 3. Тумблер админа
      const admBtn = document.createElement("button");
      admBtn.className = `admin-mini-btn ${u.is_admin ? 'active' : ''}`;
      admBtn.textContent = u.is_admin ? "👑 Админ" : "Юзер";
      admBtn.title = "Выдать или отозвать права администратора";
      admBtn.addEventListener("click", async () => {
        try {
          const newVal = !u.is_admin;
          admBtn.disabled = true;
          await SusuSupabase.updateUser(u.user_id, { is_admin: newVal });
          u.is_admin = newVal;
          admBtn.className = `admin-mini-btn ${u.is_admin ? 'active' : ''}`;
          admBtn.textContent = u.is_admin ? "👑 Админ" : "Юзер";
        } catch (err) {
          alert("Не удалось изменить права админа: " + (err.message || err));
        } finally {
          admBtn.disabled = false;
        }
      });

      actions.append(matBtn, banBtn, admBtn);
      card.append(header, uuidDiv, actions);
      adminUsersList.appendChild(card);
    });
  } catch (e) {
    adminUsersList.innerHTML = `<div class="empty-state">Ошибка: ${e.message}</div>`;
  }
}

async function renderAdminReviews() {
  if (!adminReviewsList) return;
  adminReviewsList.innerHTML = `<div class="empty-state">Загрузка отзывов...</div>`;
  try {
    const reviews = await SusuSupabase.getAllReviews();
    adminReviewsList.innerHTML = "";
    if (reviews.length === 0) {
      adminReviewsList.innerHTML = `<div class="empty-state">Отзывов пока нет.</div>`;
      return;
    }

    reviews.forEach((r) => {
      const card = document.createElement("div");
      card.className = "admin-card";

      const header = document.createElement("div");
      header.className = "admin-card-header";
      header.innerHTML = `<span>👨‍🏫 ${r.teacher_name}</span><span style="font-size:10px; opacity:0.6;">${r.year} г.</span>`;

      const body = document.createElement("div");
      body.style.fontSize = "11px";
      body.style.lineHeight = "1.35";
      body.textContent = r.text;

      const actions = document.createElement("div");
      actions.className = "admin-actions-row";

      const delBtn = document.createElement("button");
      delBtn.className = "admin-mini-btn danger";
      delBtn.textContent = "🗑️ Удалить";
      delBtn.addEventListener("click", async () => {
        if (!confirm("Удалить этот отзыв навсегда?")) return;
        try {
          delBtn.disabled = true;
          delBtn.textContent = "⏳...";
          await SusuSupabase.deleteReview(r.id);
          card.remove();
        } catch (err) {
          alert("Ошибка удаления отзыва (проверьте SQL-политики в Supabase): " + (err.message || err));
          delBtn.disabled = false;
          delBtn.textContent = "🗑️ Удалить";
        }
      });

      actions.append(delBtn);
      card.append(header, body, actions);
      adminReviewsList.appendChild(card);
    });
  } catch (e) {
    adminReviewsList.innerHTML = `<div class="empty-state">Ошибка: ${e.message}</div>`;
  }
}

async function renderAdminMaterials() {
  if (!adminMaterialsList) return;
  adminMaterialsList.innerHTML = `<div class="empty-state">Загрузка материалов...</div>`;
  try {
    const list = await SusuSupabase.getAllMaterials();
    adminMaterialsList.innerHTML = "";
    if (list.length === 0) {
      adminMaterialsList.innerHTML = `<div class="empty-state">Материалов пока нет.</div>`;
      return;
    }

    list.forEach((m) => {
      const card = document.createElement("div");
      card.className = "admin-card";

      const header = document.createElement("div");
      header.className = "admin-card-header";
      header.innerHTML = `<span>📄 ${m.title}</span><span style="font-size:10px; opacity:0.6;">${m.year} г.</span>`;

      const meta = document.createElement("div");
      meta.style.fontSize = "10px";
      meta.style.opacity = "0.7";
      meta.textContent = `${m.file_name} • ${m.teacher_name || 'Без препода'}`;

      const actions = document.createElement("div");
      actions.className = "admin-actions-row";

      const openLink = document.createElement("a");
      openLink.className = "admin-mini-btn";
      openLink.href = m.file_url;
      openLink.target = "_blank";
      openLink.textContent = "⬇ Открыть";

      const delBtn = document.createElement("button");
      delBtn.className = "admin-mini-btn danger";
      delBtn.textContent = "🗑️ Удалить файл";
      delBtn.addEventListener("click", async () => {
        if (!confirm(`Удалить файл «${m.title}» из базы и хранилища?`)) return;
        try {
          delBtn.disabled = true;
          delBtn.textContent = "⏳...";
          await SusuSupabase.deleteMaterial(m.id, m.file_url);
          card.remove();
        } catch (err) {
          alert("Ошибка удаления файла: " + (err.message || err));
          delBtn.disabled = false;
          delBtn.textContent = "🗑️ Удалить файл";
        }
      });

      actions.append(openLink, delBtn);
      card.append(header, meta, actions);
      adminMaterialsList.appendChild(card);
    });
  } catch (e) {
    adminMaterialsList.innerHTML = `<div class="empty-state">Ошибка: ${e.message}</div>`;
  }
}