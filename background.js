chrome.runtime.onInstalled.addListener(() => {
  chrome.tabs.query({ url: "https://online.susu.ru/study-activity/journal/*/term/*" }, (tabs) => {
    for (let tab of tabs) {
      chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ["contentScript.js"]
      }).catch(err => console.log("Ошибка внедрения скрипта: ", err));
    }
  });
});