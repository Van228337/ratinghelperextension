# План реализации целевой архитектуры Rating Helper (v2.1)

**Дата:** 7 ноября 2026 г.  
**Среда разработки:** Windows + WSL Ubuntu 24.04 (Swift 6, `xtool` 1.24.0)  
**Целевой Bundle ID:** `org.ratinghelper.susu` (сохранён)  

---

## Этапы выполнения работ

### Этап 1. База данных и контракты безопасности Supabase
- **Задачи:**
  1. Разработать файл миграции `SupabaseMigrations_v2.sql` без деструктивных изменений существующих таблиц.
  2. Расширить таблицу `app_users` полями: `external_user_id`, `username`, `full_name`, `email`, `susu_email`, `group_name`, `speciality_name`, `unit_name`, `study_years`, `education_level`, `education_form`, `ban_reason`, `banned_at`, `banned_by`, `app_version`.
  3. Создать таблицу `admin_audit_log` для фиксации всех административных действий (бан, разбан, изменение прав).
  4. Расширить `rating_history` полем `subject_id uuid REFERENCES public.subjects(id)`.
  5. Создать `SECURITY DEFINER` RPC `public.resolve_or_register_user(...)` для идемпотентного сопоставления студентов по `external_user_id`.
  6. Создать RPC `public.get_accessible_materials(p_user_id, p_checkpoint_id)` с проверкой бана и флага `can_view_materials`.
  7. Создать RPC `public.admin_set_user_status(...)` для безопасного управления блокировками и доступом к материалам.
  8. Заложить реляционные таблицы для будущей базы преподавателей (`teachers`, `teacher_disciplines`, `review_criteria`, `review_reports`).
- **Зависимости:** Существующая схема `SupabaseMigrations.sql`.
- **Риски:** Миграции готовятся в виде готового SQL-файла; к production применяются только администратором.

---

### Этап 2. Авторизация ЮУрГУ и постоянная идентификация в iOS
- **Задачи:**
  1. Расширить `LoginResponse` в `SusuAuthService.swift`: поддержать `id`, `userName`, `email`, `susuEmail`, `firstName`, `middleName`, `lastName`, `student[]` (`groupId`, `groupName`, `specialityCode`, `specialityName`, `unitName`, etc.).
  2. Расширить `UserSession.swift` структурой `StudentProfile` и полями постоянной идентификации.
  3. В `AppState.loadUserProfile()` использовать постоянный `external_user_id` студента для вызова `resolve_or_register_user`, устранив генерацию случайного `app_user_uuid`.
  4. Реализовать обработку серверного бана: при `isBanned == true` немедленно блокировать доступ к рабочим экранам с выводом экрана причины блокировки.
- **Файлы:** `SusuAuthService.swift`, `UserSession.swift`, `AppState.swift`, `SupabaseService.swift`.

---

### Этап 3. Исправление типов аттестации и расчет рейтинга БРС
- **Задачи:**
  1. Создать структуру `AcademicEvaluation` в `AcademicGrade.swift`, учитывающую `AssessmentType`:
     - Для `AssessmentType.zachet`: статус «Зачтено» ($\ge 59.01\%$) либо «Не зачтено / Долг» ($< 59.01\%$), без шкал 3/4/5 и без подсказки «До четвёрки не хватает...».
     - Для `AssessmentType.exam` и `diffZachet`: полноценная 4-балльная шкала (2, 3, 4, 5) с расчётом дельты до следующего грейда.
     - Для курсовых и практик: шкалы дифференцированного зачёта / зачёта.
  2. Централизовать вычисление оценки в `RatingCalculator.swift` и обновить компоненты отображения (`JournalView.swift`, `SimulatorCardView.swift`, `GradeBadgeView.swift`, `ProgressRingView.swift`, `SemesterDashboardView.swift`).
- **Файлы:** `AcademicGrade.swift`, `RatingCalculator.swift`, `Subject.swift`, `JournalView.swift`, `SimulatorCardView.swift`, `GradeBadgeView.swift`.

---

### Этап 4. Расписание занятий через online.susu.ru
- **Задачи:**
  1. Создать сервис `SusuScheduleService.swift`:
     - Запрос `GET https://online.susu.ru/microgateway/api/Schedule/GetGroupSchedule/{groupId}` с Bearer-авторизацией.
     - Парсинг полей: `beginTime`, `endTime`, `subject`, `eventType`, `eventDate`, `instructors` (`name`, `roomId`, `location`), `isAllowedToOpen`.
     - Часовой пояс: `Asia/Yekaterinburg` (UTC+5).
     - Локальное кэширование в `LocalStore`.
  2. Создать модели `ScheduleLesson` и `ScheduleInstructor`.
  3. Разработать пользовательский интерфейс `ScheduleView.swift`:
     - Выбор дней текущей недели (горизонтальная полоса дат).
     - Кнопка перехода к «Сегодня».
     - Карточки занятий со временем, типом, предметом, преподавателем и аудиторией.
     - Корректная обработка пар без аудитории / преподавателя.
     - Сопоставление предмета с журналом дисциплины.
  4. Добавить вкладку «Расписание» в `RootTabView.swift`.
- **Файлы:** `APIEndpoints.swift`, `SusuScheduleService.swift`, `ScheduleLesson.swift`, `ScheduleView.swift`, `RootTabView.swift`.

---

### Этап 5. Расширение истории рейтинга (семестр и дисциплины)
- **Задачи:**
  1. Обновить `RatingHistoryPoint` для поддержки `subjectId: String?`.
  2. Добавить в `SupabaseService.swift` методы загрузки и сохранения истории по конкретной дисциплине.
  3. В `AppState.swift` сохранять фактические точки рейтинга как для семестра, так и для открытой дисциплины.
  4. Обновить `RatingHistoryView.swift`: переключатель «Семестр / Дисциплина», фильтры периодов, отображение текущего значения и дельты.
- **Файлы:** `SupabaseService.swift`, `AppState.swift`, `RatingHistoryView.swift`.

---

### Этап 6. Планировщик задач и интеграция дедлайнов Moodle
- **Задачи:**
  1. Расширить `StudyTask.swift`: `sourceDeadline`, `customDeadline`, `termNumber`, `externalSource`, `externalId`.
  2. В `CreateTaskSheet.swift` автоматически подставлять название, дисциплину, семестр и срок сдачи контрольной точки; сохранять пользовательские правки отдельно от исходного дедлайна.
  3. Создать `MoodleCalendarService.swift` на базе спецификации `CALENDAR_API_RESEARCH.md` для загрузки дедлайнов заданий (`mod_assign`) и тестов (`mod_quiz`).
  4. Предусмотреть создание задач из дедлайнов Moodle.
- **Файлы:** `StudyTask.swift`, `CreateTaskSheet.swift`, `TaskManager.swift`, `MoodleCalendarService.swift`.

---

### Этап 7. Защита материалов и исправление `can_view_materials`
- **Задачи:**
  1. В `MaterialsListView.swift` внедрить строгую клиентскую проверку `appState.appUser?.canViewMaterials == true`.
  2. При отключенном разрешении скрывать список файлов и отображать информационное предупреждение.
  3. Запретить вызов скачивания и открытие прямых ссылок при отсутствии прав.
- **Файлы:** `MaterialsListView.swift`, `SupabaseService.swift`.

---

### Этап 8. Полноценная административная панель
- **Задачи:**
  1. Обновить `AdminView.swift`: отображать полную карточку студента (ФИО, логин, email, группа, направление, форма обучения, годы обучения, версия приложения, дата регистрации, активность).
  2. Реализовать диалог блокировки с указанием причины бана.
  3. Реализовать управление доступом к материалам (`can_view_materials`).
  4. Подключить ведение журнала административных действий.
- **Файлы:** `AdminView.swift`, `SupabaseService.swift`.

---

### Этап 9. Браузерное расширение — сохранение локального парсера
- **Задачи:**
  1. Проверить, что локальный парсер DOM, расчёт БРС, симулятор и инлайн-виджет работают автономно без обязательной серверной связи.
  2. Не внедрять искусственную авторизацию, токены или проверки банов в расширение.
- **Файлы:** `contentScript.js`, `manifest.json`, `popup.js`.

---

### Этап 10. Сборка и верификация
- **Задачи:**
  1. Собрать проект через `xtool dev build` в WSL Ubuntu 24.04.
  2. Проверить отсутствие ошибок компиляции Swift.
  3. Проверить сохранность Bundle ID (`org.ratinghelper.susu`).
  4. Подготовить финальный отчёт аудита и реализации.
