// contentScript.js

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

    // Универсально пропускаем всё без нормального веса
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

function waitForJournal(timeout = 10000) {
  return new Promise((resolve) => {
    const start = Date.now();

    const check = () => {
      const data = parsePage();

      if (data.entries.length > 0) {
        resolve(data);
        return;
      }

      if (Date.now() - start > timeout) {
        resolve(data);
        return;
      }

      setTimeout(check, 300);
    };

    check();
  });
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg === "getData") {
    waitForJournal().then(sendResponse);
    return true;
  }
});