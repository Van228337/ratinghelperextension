// popup.js

const subjectEl = document.getElementById("subject");
const pointsContainer = document.getElementById("points-container");
const resultEl = document.getElementById("result");
const themeToggle = document.getElementById("theme-toggle");
const infoBtn = document.getElementById("info-btn");
const backBtn = document.getElementById("back-btn");
const bonusInput = document.getElementById("bonus-input");
const mainView = document.getElementById("main-view");
const infoView = document.getElementById("info-view");

let originalData = null;
let currentScores = [];

// === Определяем путь к иконкам в зависимости от темы ===
function getIconPath(isDark) {
  return isDark ? "icons-dark/" : "icons-light/";
}

// === Загружаем иконки в кнопки ===
function loadIcons(isDark) {
  const path = getIconPath(isDark);
  infoBtn.querySelector("img").src = path + "info.svg";
  themeToggle.querySelector("img").src = path + (isDark ? "moon.svg" : "sun.svg");
  backBtn.querySelector("img").src = path + "arrow-left.svg";
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

const externalLinkBtn = document.getElementById("external-link-btn");
externalLinkBtn?.addEventListener("click", () => {
chrome.tabs.create({ url: "https://online.susu.ru" });
});

bonusInput.addEventListener("input", updateRating);

// === Загрузка данных ===
function loadData(retries = 10) {
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    const tab = tabs[0];
    if (!tab?.id) return;

    chrome.tabs.sendMessage(tab.id, "getData", (response) => {
      if (chrome.runtime.lastError || !response || !response.entries || response.entries.length === 0) {
        if (retries > 0) {
          setTimeout(() => loadData(retries - 1), 500);
        } else {
          subjectEl.textContent = "❌ Нет данных";
        }
        return;
      }

      originalData = response;
      currentScores = originalData.entries.map(e => e.current);
      render();
    });
  });
}

loadData();

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

    // === Редактирование прямо в строке ===
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
        // Восстанавливаем отображение
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

// === Расчёт с бонусом ===
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