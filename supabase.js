// supabase.js - Модуль взаимодействия с базой знаний и материалами Supabase

const SusuSupabase = {
  url: "https://ysrkzvqzlvpoeyxmywdd.supabase.co",
  key: "sb_publishable_zmYaWaMZW0hEkDeb9R_N8Q_BPJXNG_F",

  async request(endpoint, options = {}) {
    const url = `${this.url}/rest/v1/${endpoint}`;
    const headers = {
      "apikey": this.key,
      "Authorization": `Bearer ${this.key}`,
      "Content-Type": "application/json",
      ...(options.headers || {})
    };
    try {
      const res = await fetch(url, { ...options, headers });
      if (!res.ok) {
        const text = await res.text();
        throw new Error(`Supabase error ${res.status}: ${text}`);
      }
      const contentType = res.headers.get("content-type");
      if (contentType && contentType.includes("application/json")) {
        return await res.json();
      }
      return null;
    } catch (e) {
      console.warn("SusuSupabase request failed:", e);
      throw e;
    }
  },

  // 1. Фоновая синхронизация метаданных предмета, преподавателя и контрольных точек
  async syncSubjectData(subjectId, subjectName, teacherName, entries) {
    if (!subjectId || !subjectName) return [];
    try {
      // Upsert дисциплины
      await this.request("subjects?on_conflict=id", {
        method: "POST",
        headers: { "Prefer": "resolution=merge-duplicates" },
        body: JSON.stringify([{ id: subjectId, name: subjectName }])
      });

      // Upsert преподавателя
      if (teacherName && teacherName.trim()) {
        await this.request("subject_teachers?on_conflict=subject_id,teacher_name", {
          method: "POST",
          headers: { "Prefer": "resolution=merge-duplicates" },
          body: JSON.stringify([{ subject_id: subjectId, teacher_name: teacherName.trim() }])
        });
      }

      // Upsert контрольных точек
      if (Array.isArray(entries) && entries.length > 0) {
        const rows = entries.map((e) => ({
          subject_id: subjectId,
          title: e.title,
          max_score: e.max || 0,
          weight: e.weight || 1
        }));
        await this.request("checkpoints?on_conflict=subject_id,title", {
          method: "POST",
          headers: { "Prefer": "resolution=merge-duplicates" },
          body: JSON.stringify(rows)
        });
      }

      return await this.getCheckpoints(subjectId);
    } catch (err) {
      console.warn("syncSubjectData warning:", err);
      return [];
    }
  },

  // 2. Получить список контрольных точек предмета
  async getCheckpoints(subjectId) {
    try {
      const list = await this.request(`checkpoints?subject_id=eq.${subjectId}&select=*`);
      return Array.isArray(list) ? list : [];
    } catch (e) {
      return [];
    }
  },

  // 3. Получить счетчики материалов для контрольных точек
  async getMaterialsCountForSubject(subjectId) {
    try {
      const materials = await this.request(`materials?subject_id=eq.${subjectId}&select=checkpoint_id`);
      const map = {};
      if (Array.isArray(materials)) {
        materials.forEach((m) => {
          if (m.checkpoint_id) {
            map[m.checkpoint_id] = (map[m.checkpoint_id] || 0) + 1;
          }
        });
      }
      return map;
    } catch (e) {
      return {};
    }
  },

  // 4. Получить материалы конкретной контрольной точки (с расчетом актуальности)
  async getMaterialsForCheckpoint(checkpointId) {
    try {
      const data = await this.request(`materials?checkpoint_id=eq.${checkpointId}&select=*`);
      if (!Array.isArray(data)) return [];

      const currentYear = new Date().getFullYear();
      // Формула актуальности:
      // Свежесть (макс 10 баллов): 10 - (currentYear - year) * 2
      // Рейтинг от оценок студентов: (upvotes - downvotes) * 3
      return data
        .map((item) => {
          const age = Math.max(0, currentYear - (item.year || currentYear));
          const freshnessScore = Math.max(0, 10 - age * 2);
          const voteScore = ((item.upvotes || 0) - (item.downvotes || 0)) * 3;
          const totalScore = freshnessScore + voteScore;
          return {
            ...item,
            relevanceScore: totalScore,
            isFresh: age <= 1
          };
        })
        .sort((a, b) => b.relevanceScore - a.relevanceScore);
    } catch (e) {
      return [];
    }
  },

  // 5. Загрузка файла в Supabase Storage и создание записи в materials
  async uploadMaterial({ checkpointId, subjectId, teacherName, title, file, externalUrl, year }) {
    let fileUrl = externalUrl ? externalUrl.trim() : null;
    let fileName = file ? file.name : (fileUrl ? "Внешний ресурс" : "Материал");

    if (file) {
      const sanitizedName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
      const storagePath = `${subjectId}/${checkpointId}/${Date.now()}_${sanitizedName}`;

      const storageUrl = `${this.url}/storage/v1/object/materials/${storagePath}`;
      const uploadRes = await fetch(storageUrl, {
        method: "POST",
        headers: {
          "apikey": this.key,
          "Authorization": `Bearer ${this.key}`,
          "Content-Type": file.type || "application/octet-stream"
        },
        body: file
      });

      if (!uploadRes.ok) {
        const errText = await uploadRes.text();
        throw new Error(`Ошибка загрузки файла в хранилище: ${errText}`);
      }

      fileUrl = `${this.url}/storage/v1/object/public/materials/${storagePath}`;
      fileName = file.name;
    }

    if (!fileUrl) throw new Error("Укажите файл или ссылку на материал");

    const newMaterial = {
      checkpoint_id: checkpointId,
      subject_id: subjectId,
      teacher_name: teacherName || null,
      title: title && title.trim() ? title.trim() : fileName,
      file_url: fileUrl,
      file_name: fileName,
      year: parseInt(year, 10) || new Date().getFullYear(),
      upvotes: 1,
      downvotes: 0
    };

    const res = await this.request("materials", {
      method: "POST",
      headers: { "Prefer": "return=representation" },
      body: JSON.stringify([newMaterial])
    });

    return Array.isArray(res) ? res[0] : res;
  },

  // 6. Голосование за материал (+1 / -1)
  async voteMaterial(materialId, isUpvote) {
    const col = isUpvote ? "upvotes" : "downvotes";
    const cur = await this.request(`materials?id=eq.${materialId}&select=upvotes,downvotes`);
    if (!cur || cur.length === 0) return;
    const currentVal = cur[0][col] || 0;

    await this.request(`materials?id=eq.${materialId}`, {
      method: "PATCH",
      headers: { "Prefer": "return=minimal" },
      body: JSON.stringify({ [col]: currentVal + 1 })
    });
  },

  // 7. Получить отзывы о преподавателе и сводную статистику
  async getTeacherReviews(teacherName) {
    if (!teacherName) return { reviews: [], stats: null };
    try {
      const query = `teacher_reviews?teacher_name=eq.${encodeURIComponent(teacherName)}&order=created_at.desc`;
      const reviews = await this.request(query);
      if (!Array.isArray(reviews)) return { reviews: [], stats: null };

      if (reviews.length === 0) {
        return { reviews: [], stats: null };
      }

      let totalDiff = 0;
      let avtomatCount = 0;
      let strictAttendanceCount = 0;

      reviews.forEach((r) => {
        totalDiff += (r.difficulty || 3);
        if (r.gives_avtomat) avtomatCount++;
        if (r.attendance_strict) strictAttendanceCount++;
      });

      const stats = {
        totalReviews: reviews.length,
        avgDifficulty: (totalDiff / reviews.length).toFixed(1),
        avtomatPct: Math.round((avtomatCount / reviews.length) * 100),
        attendancePct: Math.round((strictAttendanceCount / reviews.length) * 100)
      };

      return { reviews, stats };
    } catch (e) {
      return { reviews: [], stats: null };
    }
  },

  // 8. Добавить отзыв о преподавателе
  async addTeacherReview(data) {
    const newReview = {
      teacher_name: data.teacherName,
      subject_id: data.subjectId || null,
      subject_name: data.subjectName || null,
      text: data.text,
      difficulty: parseInt(data.difficulty, 10) || 3,
      gives_avtomat: !!data.givesAvtomat,
      attendance_strict: !!data.attendanceStrict,
      year: parseInt(data.year, 10) || new Date().getFullYear(),
      likes: 0
    };

    const res = await this.request("teacher_reviews", {
      method: "POST",
      headers: { "Prefer": "return=representation" },
      body: JSON.stringify([newReview])
    });

    return Array.isArray(res) ? res[0] : res;
  },

  // 9. Поставить лайк отзыву
  async likeReview(reviewId) {
    const cur = await this.request(`teacher_reviews?id=eq.${reviewId}&select=likes`);
    if (!cur || cur.length === 0) return;
    const currentLikes = cur[0].likes || 0;

    await this.request(`teacher_reviews?id=eq.${reviewId}`, {
      method: "PATCH",
      headers: { "Prefer": "return=minimal" },
      body: JSON.stringify({ likes: currentLikes + 1 })
    });
  },

  // 10. AI-сводка о преподавателе (кэш в Supabase)
  async getTeacherSummary(teacherName) {
    if (!teacherName) return null;
    try {
      const res = await this.request(`teacher_summaries?teacher_name=eq.${encodeURIComponent(teacherName)}&select=*`);
      return Array.isArray(res) && res.length > 0 ? res[0] : null;
    } catch (e) {
      return null;
    }
  },

  async saveTeacherSummary(teacherName, summaryText, reviewsCount) {
    if (!teacherName || !summaryText) return;
    try {
      await this.request("teacher_summaries?on_conflict=teacher_name", {
        method: "POST",
        headers: { "Prefer": "resolution=merge-duplicates" },
        body: JSON.stringify([
          {
            teacher_name: teacherName,
            summary_text: summaryText,
            reviews_count: reviewsCount || 0,
            updated_at: new Date().toISOString()
          }
        ])
      });
    } catch (e) {
      console.warn("Save teacher summary warning:", e);
    }
  },

  // 11. Система пользователей и прав (UUID)
  async getUserProfile(userId) {
    if (!userId) return { user_id: null, is_banned: false, can_view_materials: true, is_admin: false };
    try {
      const existing = await this.request(`app_users?user_id=eq.${userId}&select=*`);
      if (Array.isArray(existing) && existing.length > 0) {
        // Обновляем время последней активности
        this.request(`app_users?user_id=eq.${userId}`, {
          method: "PATCH",
          headers: { "Prefer": "return=minimal" },
          body: JSON.stringify({ last_active: new Date().toISOString() })
        }).catch(() => {});
        return existing[0];
      }

      // Регистрируем нового пользователя
      const newUser = {
        user_id: userId,
        device_info: "Chrome Extension",
        is_banned: false,
        can_view_materials: true,
        is_admin: false,
        created_at: new Date().toISOString(),
        last_active: new Date().toISOString()
      };

      await this.request("app_users?on_conflict=user_id", {
        method: "POST",
        headers: { "Prefer": "resolution=merge-duplicates" },
        body: JSON.stringify([newUser])
      });

      return newUser;
    } catch (e) {
      console.warn("getUserProfile fallback:", e);
      return { user_id: userId, is_banned: false, can_view_materials: true, is_admin: false };
    }
  },

  async updateUser(userId, updates) {
    if (!userId) return;
    return await this.request(`app_users?user_id=eq.${userId}`, {
      method: "PATCH",
      headers: { "Prefer": "return=representation" },
      body: JSON.stringify(updates)
    });
  },

  // 12. Админские методы
  async getAllUsers() {
    try {
      const res = await this.request("app_users?order=last_active.desc");
      return Array.isArray(res) ? res : [];
    } catch (e) {
      return [];
    }
  },

  async getAllReviews() {
    try {
      const res = await this.request("teacher_reviews?order=created_at.desc");
      return Array.isArray(res) ? res : [];
    } catch (e) {
      return [];
    }
  },

  async deleteReview(reviewId) {
    return await this.request(`teacher_reviews?id=eq.${reviewId}`, {
      method: "DELETE",
      headers: { "Prefer": "return=representation" }
    });
  },

  async getAllMaterials() {
    try {
      const res = await this.request("materials?order=created_at.desc");
      return Array.isArray(res) ? res : [];
    } catch (e) {
      return [];
    }
  },

  async deleteMaterial(materialId, fileUrl) {
    // 1. Удаляем запись из БД
    const res = await this.request(`materials?id=eq.${materialId}`, {
      method: "DELETE",
      headers: { "Prefer": "return=representation" }
    });

    // 2. Если файл хранился в Supabase Storage, удаляем его из хранилища
    if (fileUrl && fileUrl.includes("/storage/v1/object/public/materials/")) {
      try {
        const path = fileUrl.split("/storage/v1/object/public/materials/")[1];
        if (path) {
          await fetch(`${this.url}/storage/v1/object/materials/${path}`, {
            method: "DELETE",
            headers: {
              "apikey": this.key,
              "Authorization": `Bearer ${this.key}`
            }
          });
        }
      } catch (storageErr) {
        console.warn("Failed to delete file from storage:", storageErr);
      }
    }
  },

  // 10. Глобальные настройки приложения и API-ключи (app_config)
  async getConfig(key) {
    try {
      const res = await this.request(`app_config?key=eq.${encodeURIComponent(key)}&select=value`);
      return res && res.length > 0 ? res[0].value : null;
    } catch {
      return null;
    }
  },

  async saveConfig(key, value) {
    return await this.request("app_config?on_conflict=key", {
      method: "POST",
      headers: { "Prefer": "resolution=merge-duplicates" },
      body: JSON.stringify([{ key, value }])
    });
  },

  // 11. Безопасная серверная проверка мастер-ключа через Supabase RPC
  async verifyAdminPin(pin) {
    try {
      const res = await this.request("rpc/verify_admin_pin", {
        method: "POST",
        body: JSON.stringify({ p_pin: pin })
      });
      return res === true;
    } catch {
      return false;
    }
  }
};

if (typeof window !== "undefined") {
  window.SusuSupabase = SusuSupabase;
}
if (typeof module !== "undefined" && module.exports) {
  module.exports = SusuSupabase;
}
