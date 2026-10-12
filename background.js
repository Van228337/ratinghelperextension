// background.js

// Внедряем contentScript во все уже открытые вкладки журнала при установке или обновлении расширения
chrome.runtime.onInstalled.addListener(async () => {
  try {
    const tabs = await chrome.tabs.query({ url: "https://online.susu.ru/*" });
    for (const tab of tabs) {
      if (tab.id) {
        chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: ["supabase.js", "contentScript.js"],
        }).catch(() => {});
      }
    }
  } catch (e) {
    console.error("Ошибка при инициализации существующих вкладок:", e);
  }
});

// Дополнительно страхуем SPA-навигацию (смена URL без полной перезагрузки страницы)
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.url && changeInfo.url.includes("online.susu.ru")) {
    chrome.scripting.executeScript({
      target: { tabId },
      files: ["supabase.js", "contentScript.js"],
    }).catch(() => {});
  }
});
