// === DOM элементы ===
const subjectEl = document.getElementById("subject");
const pointsContainer = document.getElementById("points-container");
const resultEl = document.getElementById("result");
const themeToggle = document.getElementById("theme-toggle");
const infoBtn = document.getElementById("info-btn");
const backBtn = document.getElementById("back-btn");
const bonusInput = document.getElementById("bonus-input");
const mainView = document.getElementById("main-view");
const infoView = document.getElementById("info-view");
const externalLinkBtn = document.getElementById("external-link-btn");

// Вкладки
const tabBtns = document.querySelectorAll(".tab-btn");
const tabContents = document.querySelectorAll(".tab-content");

// Отзывы
const addReviewBtn = document.getElementById("add-review-btn");
const reviewModal = document.getElementById("review-modal");
const reviewText = document.getElementById("review-text");
const reviewRating = document.getElementById("review-rating");
const reviewDifficulty = document.getElementById("review-difficulty");
const submitReviewBtn = document.getElementById("submit-review-btn");
const cancelReviewBtn = document.getElementById("cancel-review-btn");
const modalClose = document.querySelector(".modal-close");
const reviewsList = document.getElementById("reviews-list");

// Статистика
const fetchAllGradesBtn = document.getElementById("fetch-all-grades-btn");
const parseStatus = document.getElementById("parse-status");
const subjectStatsEl = document.getElementById("subject-stats");

let originalData = null;
let currentScores = [];
let currentSubjectId = null;
let currentUserId = null;

// === Определяем путь к иконкам в зависимости от темы ===
function getIconPath(isDark) {
  return isDark ? "icons-dark/" : "icons-light/";
}

// === Загружаем иконки в кнопки ===
function loadIcons(isDark) {
  const path = getIconPath(isDark);
  const infoImg = infoBtn.querySelector("img");
  const themeImg = themeToggle.querySelector("img");
  const backImg = backBtn.querySelector("img");

  if (infoImg) infoImg.src = path + "info.svg";
  if (themeImg) themeImg.src = path + (isDark ? "moon.svg" : "sun.svg");
  if (backImg) backImg.src = path + "arrow-left.svg";
}

// === Инициализация темы ===
const isDark = localStorage.getItem("theme") === "dark";
if (isDark) {
  document.body.classList.add("dark");
}
loadIcons(isDark);

themeToggle.addEventListener("click", () => {
  document.body.classList.toggle("dark");
  const isNowDark = document.body.classList.contains("dark");
  localStorage.setItem("theme", isNowDark ? "dark" : "light");
  loadIcons(isNowDark);
});

infoBtn.addEventListener("click", () => {
  mainView.style.display = "none";
  infoView.style.display = "block";
});

backBtn.addEventListener("click", () => {
  infoView.style.display = "none";
  mainView.style.display = "block";
});

externalLinkBtn?.addEventListener("click", () => {
  chrome.tabs.create({ url: "https://online.susu.ru" });
});

bonusInput.addEventListener("input", updateRating);

// === Управление вкладками ===
tabBtns.forEach(btn => {
  btn.addEventListener("click", () => {
    const tabName = btn.getAttribute("data-tab");
    
    tabBtns.forEach(b => b.classList.remove("active"));
    tabContents.forEach(tc => tc.style.display = "none");
    
    btn.classList.add("active");
    document.getElementById(`${tabName}-tab`).style.display = "block";

    // Загрузить содержимое вкладки
    if (tabName === "reviews") {
      loadReviews();
    } else if (tabName === "stats") {
      loadStats();
    }
  });
});

// === ОТЗЫВЫ ===

addReviewBtn?.addEventListener("click", () => {
  reviewText.value = "";
  reviewRating.value = "";
  reviewDifficulty.value = "";
  reviewModal.style.display = "flex";
});

modalClose?.addEventListener("click", () => {
  reviewModal.style.display = "none";
});

cancelReviewBtn?.addEventListener("click", () => {
  reviewModal.style.display = "none";
});

submitReviewBtn?.addEventListener("click", async () => {
  const content = reviewText.value.trim();
  const rating = reviewRating.value ? parseInt(reviewRating.value) : null;
  const difficulty = reviewDifficulty.value || null;

  if (!content) {
    alert("Пожалуйста, напишите отзыв");
    return;
  }

  if (!currentUserId || !currentSubjectId) {
    alert("Ошибка: не загружены данные пользователя или предмета");
    return;
  }

  try {
    submitReviewBtn.disabled = true;
    submitReviewBtn.textContent = "Отправка...";

    const result = await createReview(currentUserId, currentSubjectId, content, rating, difficulty);

    if (result.success) {
      alert("✅ Отзыв успешно добавлен!");
      reviewModal.style.display = "none";
      loadReviews();
    } else {
      alert("❌ Ошибка при добавлении отзыва: " + result.error);
    }
  } catch (error) {
    console.error("Ошибка:", error);
    alert("❌ Ошибка при добавлении отзыва");
  } finally {
    submitReviewBtn.disabled = false;
    submitReviewBtn.textContent = "Отправить";
  }
});

async function loadReviews() {
  if (!currentSubjectId) {
    reviewsList.innerHTML = "<p>⚠️ Предмет не загружен</p>";
    return;
  }

  reviewsList.innerHTML = "<p>⏳ Загрузка отзывов...</p>";

  try {
    const result = await getReviewsBySubject(currentSubjectId);

    if (!result.success) {
      reviewsList.innerHTML = `<p>❌ Ошибка: ${result.error}</p>`;
      return;
    }

    if (result.reviews.length === 0) {
      reviewsList.innerHTML = "<p>📝 Отзывов пока нет. Будьте первым!</p>";
      return;
    }

    reviewsList.innerHTML = result.reviews.map(review => `
      <div class="review-item">
        <div class="review-header">
          <span class="review-rating">⭐ ${review.rating || "—"}/5</span>
          <span class="review-difficulty difficulty-${review.difficulty || 'unknown'}">
            ${getDifficultyLabel(review.difficulty)}
          </span>
        </div>
        <p class="review-content">${escapeHtml(review.content)}</p>
        <div class="review-footer">
          <button class="vote-btn like-btn" data-review-id="${review.id}" data-vote="like">
            👍 ${review.likes || 0}
          </button>
          <button class="vote-btn dislike-btn" data-review-id="${review.id}" data-vote="dislike">
            👎 ${review.dislikes || 0}
          </button>
          <span class="review-date">${new Date(review.created_at).toLocaleDateString('ru-RU')}</span>
        </div>
      </div>
    `).join("");

    // Добавить обработчики для голосований
    document.querySelectorAll(".vote-btn").forEach(btn => {
      btn.addEventListener("click", handleVote);
    });

  } catch (error) {
    console.error("Ошибка загрузки отзывов:", error);
    reviewsList.innerHTML = "<p>❌ Ошибка при загрузке отзывов</p>";
  }
}

async function handleVote(e) {
  const reviewId = e.target.getAttribute("data-review-id");
  const voteType = e.target.getAttribute("data-vote");

  if (!currentUserId) {
    alert("Ошибка: не загружен ID пользователя");
    return;
  }

  try {
    const result = await voteReview(reviewId, currentUserId, voteType);

    if (result.success) {
      loadReviews();
    } else {
      alert("❌ Ошибка при голосовании: " + result.error);
    }
  } catch (error) {
    console.error("Ошибка голосования:", error);
    alert("❌ Ошибка при голосовании");
  }
}

function getDifficultyLabel(difficulty) {
  const labels = {
    'easy': '🟢 Легкий',
    'medium': '🟡 Средний',
    'hard': '🔴 Сложный',
  };
  return labels[difficulty] || '⚪ Неизвестно';
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// === СТАТИСТИКА ===

async function loadStats() {
  if (!currentSubjectId) {
    subjectStatsEl.innerHTML = "<p>⚠️ Предмет не загружен</p>";
    return;
  }

  subjectStatsEl.innerHTML = "<p>⏳ Загрузка статистики...</p>";

  try {
    const result = await getSubjectStats(currentSubjectId);

    if (!result.success) {
      subjectStatsEl.innerHTML = `<p>❌ Ошибка: ${result.error}</p>`;
      return;
    }

    const stats = result.stats;
    const difficulty = result.difficulty;

    subjectStatsEl.innerHTML = `
      <div class="stats-box">
        <h3>📊 Статистика по предмету</h3>
        <div class="stat-item">
          <span>Количество оценок:</span>
          <strong>${stats.totalGrades}</strong>
        </div>
        <div class="stat-item">
          <span>Средняя оценка:</span>
          <strong>${stats.averageRating ? stats.averageRating + '%' : 'Нет данных'}</strong>
        </div>
        <div class="stat-item">
          <span>Минимальная оценка:</span>
          <strong>${stats.minRating || '—'}</strong>
        </div>
        <div class="stat-item">
          <span>Максимальная оценка:</span>
          <strong>${stats.maxRating || '—'}</strong>
        </div>
        <div class="stat-item difficulty-indicator">
          <span>Сложность предмета:</span>
          <strong>${getDifficultyLabel(difficulty)}</strong>
        </div>
        <div class="difficulty-hint">
          ${getDifficultyHint(difficulty, stats.averageRating)}
        </div>
      </div>
    `;

  } catch (error) {
    console.error("Ошибка загрузки статистики:", error);
    subjectStatsEl.innerHTML = "<p>❌ Ошибка при загрузке статистики</p>";
  }
}

function getDifficultyHint(difficulty, avgRating) {
  const hints = {
    'easy': '✅ Этот предмет относительно легкий. Высокие оценки достаточно часто.',
    'medium': '⚖️ Предмет среднего уровня сложности. Требует обычного объема работы.',
    'hard': '⚠️ Этот предмет сложный. Требуется серьезная подготовка.',
    'unknown': 'ℹ️ Недостаточно данных для определения сложности.',
  };
  return hints[difficulty] || '';
}

// === ПАРСИНГ ВСЕХ ОЦЕНОК ===

fetchAllGradesBtn?.addEventListener("click", async () => {
  if (!currentUserId) {
    alert("❌ Ошибка: не загружен ID пользователя");
    return;
  }

  fetchAllGradesBtn.disabled = true;
  parseStatus.innerHTML = "⏳ Парсинг оценок...";

  try {
    // Отправляем команду на contentScript для парсинга всех предметов
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      chrome.tabs.sendMessage(tabs[0].id, "parseAllGrades", async (response) => {
        if (chrome.runtime.lastError || !response || !response.grades) {
          parseStatus.innerHTML = "❌ Ошибка при парсинге. Убедитесь, что вы на странице ЮУрГУ.";
          fetchAllGradesBtn.disabled = false;
          return;
        }

        try {
          // Добавляем все оценки на бэкенд
          const gradesToAdd = response.grades.map(g => ({
            subjectId: null, // Будет заполнено позже
            rating: g.rating,
            subjectName: g.subject,
          }));

          // Создаем предметы и добавляем оценки
          let addedCount = 0;
          for (const grade of response.grades) {
            const subjectResult = await getOrCreateSubject(grade.subject, grade.teacher || null);
            if (subjectResult.success) {
              const gradeResult = await addGrade(currentUserId, subjectResult.subjectId, grade.rating);
              if (gradeResult.success) {
                addedCount++;
              }
            }
          }

          parseStatus.innerHTML = `✅ Успешно добавлено ${addedCount}/${response.grades.length} оценок!`;
        } catch (error) {
          console.error("Ошибка добавления оценок:", error);
          parseStatus.innerHTML = `❌ Ошибка: ${error.message}`;
        } finally {
          fetchAllGradesBtn.disabled = false;
        }
      });
    });
  } catch (error) {
    console.error("Ошибка:", error);
    parseStatus.innerHTML = `❌ Ошибка: ${error.message}`;
    fetchAllGradesBtn.disabled = false;
  }
});

// === Проверка URL и управление отображением ===
function checkUrlAndLoad() {
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    const tab = tabs[0];
    if (!tab || !tab.url) return;

    const susuRegex = /^https:\/\/online\.susu\.ru\/study-activity\/journal\/.*\/term\/.*/;

    if (susuRegex.test(tab.url)) {
      mainView.style.display = "block";
      infoView.style.display = "none";
      backBtn.style.display = "flex";
      loadData();
    } else {
      mainView.style.display = "none";
      infoView.style.display = "block";
      backBtn.style.display = "none";
    }
  });
}

// === Инициализация пользователя и загрузка данных ===
async function initialize() {
  try {
    // Получить или создать ID пользователя
    const userResult = await getOrCreateUser();
    if (userResult.success) {
      currentUserId = userResult.userId;
      console.log("✅ ID пользователя:", currentUserId);
    } else {
      console.error("❌ Ошибка получения ID пользователя:", userResult.error);
    }
  } catch (error) {
    console.error("❌ Ошибка инициализации:", error);
  }

  checkUrlAndLoad();
}

// === Загрузка данных (работает только для правильного URL) ===
function loadData() {
  chrome.storage.local.get(["cachedRatingData"], (result) => {
    if (result.cachedRatingData && result.cachedRatingData.entries && result.cachedRatingData.entries.length > 0) {
      originalData = result.cachedRatingData;
      currentScores = originalData.entries.map(e => e.current);
      render();
      setupSubject();
    }

    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const tab = tabs[0];
      if (!tab?.id) return;

      chrome.tabs.sendMessage(tab.id, "getData", (response) => {
        if (chrome.runtime.lastError || !response || !response.entries || response.entries.length === 0) {
          if (!originalData) {
            subjectEl.textContent = "❌ Нет данных";
          }
          return;
        }

        chrome.storage.local.set({ "cachedRatingData": response });
        originalData = response;
        currentScores = originalData.entries.map(e => e.current);
        render();
        setupSubject();
      });
    });
  });
}

async function setupSubject() {
  if (!originalData || !originalData.subject) return;

  try {
    const result = await getOrCreateSubject(originalData.subject);
    if (result.success) {
      currentSubjectId = result.subjectId;
      console.log("✅ Предмет ID:", currentSubjectId);
    }
  } catch (error) {
    console.error("❌ Ошибка установки предмета:", error);
  }
}

// Запуск инициализации при открытии попапа
initialize();

// === Отображение списка ===
function render() {
  subjectEl.textContent = originalData.subject || "Без названия";
  pointsContainer.innerHTML = "";

  originalData.entries.forEach((entry, idx) => {
    const div = document.createElement("div");
    div.className = "work-item";

    const title = document.createElement("div");
    title.className = "work-title";
    title.textContent = entry.title;

    const scoreValue = document.createElement("div");
    scoreValue.className = "score-value";
    const pct = entry.max > 0 ? (entry.current / entry.max * 100) : 0;
    if (pct < 33.33) scoreValue.classList.add("red");
    else if (pct < 66.66) scoreValue.classList.add("orange");
    else scoreValue.classList.add("green");
    scoreValue.textContent = entry.current;

    const maxLabel = document.createElement("div");
    maxLabel.className = "max-label";
    maxLabel.textContent = `/ ${entry.max}`;

    const scoreDisplay = document.createElement("div");
    scoreDisplay.className = "score-display";
    scoreDisplay.append(scoreValue, maxLabel);

    scoreValue.addEventListener("click", () => {
      const input = document.createElement("input");
      input.type = "number";
      input.min = 0;
      input.max = entry.max;
      input.value = currentScores[idx];
      input.style.width = "40px";
      input.style.textAlign = "right";
      input.style.padding = "2px 4px";
      input.style.border = "1px solid #555";
      input.style.borderRadius = "4px";
      input.style.background = "var(--input-bg)";
      input.style.color = "var(--text)";
      input.style.fontSize = "13px";

      scoreValue.replaceWith(input);
      input.focus();
      input.select();

      const finish = () => {
        const val = Number(input.value);
        if (!isNaN(val) && val >= 0 && val <= entry.max) {
          currentScores[idx] = val;
          updateRating();
        }
        scoreValue.textContent = isNaN(val) ? entry.current : val;
        const newPct = (val / entry.max) * 100;
        scoreValue.className = "score-value";
        if (newPct < 33.33) scoreValue.classList.add("red");
        else if (newPct < 66.66) scoreValue.classList.add("orange");
        else scoreValue.classList.add("green");
        input.replaceWith(scoreValue);
      };

      input.addEventListener("blur", finish);
      input.addEventListener("keypress", (e) => {
        if (e.key === "Enter") finish();
      });
    });

    div.append(title, scoreDisplay);
    pointsContainer.appendChild(div);
  });

  updateRating();
}

function updateRating() {
  if (!originalData?.entries) return;

  let total = 0, totalWeight = 0;
  originalData.entries.forEach((entry, idx) => {
    const pct = entry.max > 0 ? (currentScores[idx] / entry.max) * 100 : 0;
    total += pct * entry.weight;
    totalWeight += entry.weight;
  });

  const currentRating = totalWeight > 0 ? total / totalWeight : 0;
  const bonus = parseFloat(bonusInput.value) || 0;
  const finalRating = currentRating + bonus;

  resultEl.textContent = `Итоговый рейтинг: ${finalRating.toFixed(2)}%`;
}