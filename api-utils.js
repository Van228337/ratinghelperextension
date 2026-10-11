/**
 * API утилиты для работы с бэкендом Rating Helper
 */

const API_BASE_URL = 'http://localhost:3000/api';

/**
 * Помощник для выполнения API запросов
 */
async function apiCall(endpoint, method = 'GET', data = null) {
  const options = {
    method,
    headers: {
      'Content-Type': 'application/json',
    },
  };

  if (data && (method === 'POST' || method === 'PUT' || method === 'DELETE')) {
    options.body = JSON.stringify(data);
  }

  try {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, options);
    const result = await response.json();

    if (!response.ok) {
      console.error(`API Ошибка [${method} ${endpoint}]:`, result);
      return { success: false, error: result.error || 'API ошибка' };
    }

    return result;
  } catch (error) {
    console.error(`Ошибка запроса [${method} ${endpoint}]:`, error);
    return { success: false, error: error.message };
  }
}

/**
 * === ПОЛЬЗОВАТЕЛИ ===
 */

async function getUserIdFromStorage() {
  return new Promise((resolve) => {
    chrome.storage.local.get(['userId'], (result) => {
      resolve(result.userId);
    });
  });
}

async function saveUserIdToStorage(userId) {
  return new Promise((resolve) => {
    chrome.storage.local.set({ userId }, resolve);
  });
}

async function getOrCreateUser() {
  const existingUserId = await getUserIdFromStorage();

  if (existingUserId) {
    return { success: true, userId: existingUserId };
  }

  const result = await apiCall('/users/get-or-create', 'POST');

  if (result.success) {
    await saveUserIdToStorage(result.userId);
  }

  return result;
}

/**
 * === ПРЕДМЕТЫ ===
 */

async function getOrCreateSubject(name, teacherName = null) {
  return apiCall('/subjects', 'POST', {
    name,
    teacherName,
  });
}

async function getSubject(subjectId) {
  return apiCall(`/subjects/${subjectId}`);
}

/**
 * === ОТЗЫВЫ ===
 */

async function createReview(userId, subjectId, content, rating = null, difficulty = null) {
  return apiCall('/reviews', 'POST', {
    userId,
    subjectId,
    content,
    rating,
    difficulty,
  });
}

async function getReviewsBySubject(subjectId, limit = 20, offset = 0) {
  return apiCall(`/reviews/subject/${subjectId}?limit=${limit}&offset=${offset}`);
}

async function voteReview(reviewId, userId, voteType) {
  // voteType: 'like' или 'dislike'
  return apiCall(`/reviews/${reviewId}/vote`, 'POST', {
    userId,
    voteType,
  });
}

async function deleteReview(reviewId, userId) {
  return apiCall(`/reviews/${reviewId}`, 'DELETE', {
    userId,
  });
}

/**
 * === ОЦЕНКИ ===
 */

async function addGrade(userId, subjectId, rating) {
  return apiCall('/grades', 'POST', {
    userId,
    subjectId,
    rating,
  });
}

async function getUserGrades(userId) {
  return apiCall(`/grades/user/${userId}`);
}

async function getSubjectStats(subjectId) {
  return apiCall(`/grades/subject/${subjectId}/stats`);
}

async function addMultipleGrades(userId, grades) {
  /**
   * grades: Array<{subjectId, rating}>
   */
  const promises = grades.map(g => addGrade(userId, g.subjectId, g.rating));
  return Promise.all(promises);
}

// Экспорт для использования в popup.js и contentScript.js
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    apiCall,
    getOrCreateUser,
    getUserIdFromStorage,
    saveUserIdToStorage,
    getOrCreateSubject,
    getSubject,
    createReview,
    getReviewsBySubject,
    voteReview,
    deleteReview,
    addGrade,
    getUserGrades,
    getSubjectStats,
    addMultipleGrades,
  };
}
