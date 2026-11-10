# Архитектурное проектирование целевой системы Rating Helper (v2.1)

**Дата:** 7 ноября 2026 г.  
**Статус:** Согласовано для реализации  
**Цель:** Создание целостной, безопасной, расширяемой и устойчивой архитектуры для Rating Helper (iOS, Web Extension, Supabase, Google Apps Script, ЮУрГУ API, Moodle).

---

## 1. Концептуальная архитектура и границы компонентов

```
+-----------------------------------------------------------------------------------+
|                              ПОЛЬЗОВАТЕЛЬСКИЕ КЛИЕНТЫ                             |
|                                                                                   |
|  +-------------------------------------+   +------------------------------------+  |
|  |           iOS ПРИЛОЖЕНИЕ            |   |       БРАУЗЕРНОЕ РАСШИРЕНИЕ        |  |
|  |     (Swift 6, SwiftUI, xtool)       |   |      (Manifest V3, Pure Local)     |  |
|  |                                     |   |                                    |  |
|  | * UI: Дисциплины, Журнал, Расписание|   | * Парсинг DOM online.susu.ru       |  |
|  |   План, Сводка, История, Настройки  |   | * Инлайн-виджет БРС на странице    |  |
|  | * Локальный кэш: LocalStore/Keychain|   | * Локальный калькулятор цели       |  |
|  | * Авторизация: online.susu.ru       |   | * Локальное хранение (storage)     |  |
|  | * Сетевой клиент: Supabase & Gateway|   | * БЕЗ авторизации, БЕЗ банов       |  |
|  +------------------+------------------+   +------------------------------------+  |
+---------------------|-------------------------------------------------------------+
                      |
                      +-----------------------------+-------------------------------+
                      |                             |                               |
                      v                             v                               v
    +--------------------------------+ +------------------------+ +-------------------------+
    |      СЕРВИСЫ ЮУрГУ И MOODLE    | |   SUPABASE / POSTGRES  | |   GOOGLE APPS SCRIPT    |
    |                                | |                        | |         GATEWAY         |
    | 1. Auth & UpdateToken          | | * users & profiles     | | * Скрытие GROQ_API_KEY  |
    |    (microgateway/api/auth)     | | * schedule cache/logs  | | * AI-модерация отзывов  |
    | 2. Subjects & Journal          | | * rating_history       | | * Выжимка отзывов (Groq)|
    |    (microgateway/api/Study...) | | * checkpoints/subjects | | * Загрузка файлов на    |
    | 3. Schedule API                | | * materials (RLS check)| |   Google Диск           |
    |    (microgateway/api/Schedule) | | * teacher_reviews      | +-------------------------+
    | 4. Moodle AJAX Calendar        | | * admin_audit_log      |
    |    (edu.susu.ru/lib/ajax)      | | * RPC: resolve_user,   |
    +--------------------------------+ |   sync_meta, get_mats  |
                                       +------------------------+
```

---

## 2. Модель идентификации и авторизации пользователя

### 2.1. Идентификаторы
1. `users.id` — внутренний неизменяемый первичный ключ (PostgreSQL `UUID`), генерируемый базой данных при первом подтверждённом входе студента.
2. `users.external_user_id` — стабильный уникальный идентификатор пользователя из системы «Универис» / ЮУрГУ (поле `id` в ответе `POST /microgateway/api/auth/login`).
3. `users.username` — логин ЮУрГУ (`userName`, например `ivanovii`).
4. `users.external_identity` — клиентский идентификатор сессии `identity`, передаваемый в `auth/login` и `auth/UpdateToken`. Сохраняется в Keychain устройства.

### 2.2. Алгоритм разрешения пользователя (`resolve_or_register_user`)
При каждом успешном входе или обновлении токена в iOS:
1. `SusuAuthService` парсит полный ответ `LoginResponse`, включая `id`, `userName`, `email`, `susuEmail`, `firstName`, `middleName`, `lastName` и массив `student[]`.
2. Из первого (или активного) элемента `student` извлекаются `groupId`, `groupName`, `specialityCode`, `specialityName`, `unitName`, `educationLevel`, `educationForm`, `studyYears`.
3. Вызывается RPC `public.resolve_or_register_user`:
   - Поиск по `external_user_id = p_external_user_id`.
   - Если найден: обновляются поля ФИО, группы, подразделения, версии приложения, `last_active = now()`. Возвращается существующий `id`, `is_banned`, `can_view_materials`, `is_admin`.
   - Если не найден: создаётся новая запись в `app_users` со статусом `is_banned = false`, `can_view_materials = true`, `is_admin = false`.
   - Внутренний `id` сохраняется в Keychain приложения (`rating_helper_user_uuid`).
4. **Реакция на бан**: Если сервер вернул `is_banned = true`, приложение немедленно прекращает выполнение защищённых запросов, очищает рабочий кэш и переключается на экран уведомления о блокировке с отображением причины.

---

## 3. Серверная система банов и прав доступа

### 3.1. Защита на уровне PostgreSQL (RLS и RPC)
1. Все запросы к материалам (`materials`), отзывам (`teacher_reviews`) и истории (`rating_history`) валидируются серверными политиками или через RPC:
   - Если пользователь помечен как `is_banned = true`, любые RPC добавления отзывов, материалов или записи истории вызывают `RAISE EXCEPTION 'User is suspended' USING ERRCODE = '42501'`.
2. Выборка материалов защищается RPC `public.get_accessible_materials(p_user_id, p_checkpoint_id)`:
   - Проверяется: пользователь существует, `is_banned = false`, `can_view_materials = true`.
   - Только при соблюдении всех условий возвращаются строки с `file_url`.
3. Прямые операции `UPDATE` и `DELETE` на таблицах `app_users`, `materials`, `teacher_reviews` запрещены для ролей `anon` и `authenticated`. Изменение статусов пользователей разрешено только через RPC `public.admin_set_user_status(...)`, проверяющий реальный статус `is_admin` вызывающего и фиксирующий операцию в `admin_audit_log`.

---

## 4. Расписание занятий (`Schedule`) через online.susu.ru

### 4.1. Спецификация API
- **Endpoint:** `GET https://online.susu.ru/microgateway/api/Schedule/GetGroupSchedule/{groupId}`
- **Параметры:** `{groupId}` — UUID учебной группы из `session.studentProfile.groupId`.
- **Заголовки:**
  - `Authorization: Bearer <accessToken>`
  - `Accept: application/json`
  - `User-Agent: RatingHelper-iOS/2.1`

### 4.2. Модель занятия (`ScheduleLesson`)
```swift
public struct ScheduleLesson: Identifiable, Codable, Hashable, Sendable {
    public let id: String                 // Детерминированный хэш (дата + время + предмет + аудитория)
    public let eventDate: String          // "2026-09-01"
    public let beginTime: String          // "09:45:00" -> форматируется "09:45"
    public let endTime: String            // "11:20:00" -> форматируется "11:20"
    public let subject: String            // "Хранилища данных"
    public let eventType: String          // "Лекции", "Практические занятия", "Лабораторные работы"
    public let instructors: [ScheduleInstructor]
    public let isAllowedToOpen: Bool?
    public var matchedSubjectId: String?  // UUID дисциплины из журнала при совпадении
}

public struct ScheduleInstructor: Codable, Hashable, Sendable {
    public let name: String?
    public let roomId: String?
    public let location: String?          // Название аудитории/корпуса, например "339/3б"
}
```

### 4.3. Синхронизация и локальный кэш
1. **Часовой пояс:** Строго `Asia/Yekaterinburg` (UTC+5). Текущий день определяется по местному времени университета.
2. **Кэширование:** При успешном запросе массив занятий сохраняется в `LocalStore` (`schedule_cache_{groupId}`).
3. **Обновление:** Фоновая проверка актуальности раз в 4 часа либо принудительно через `pull-to-refresh`.
4. **Интерфейс:** Вкладка «Расписание» (`ScheduleView`) в `RootTabView`:
   - Горизонтальная лента дней текущей недели с подсветкой сегодняшнего дня.
   - Быстрый переход «Сегодня».
   - Карточки пар с временем, типом занятия, предметом, аудиторией и преподавателем.
   - Корректная обработка пар без преподавателя / аудитории (военная кафедра, самостоятельная работа, дистанционные лекции).

---

## 5. Moodle Calendar — Дедлайны (`edu.susu.ru`)

### 5.1. Архитектурная модель интеграции
На основе исследования `CALENDAR_API_RESEARCH.md`:
1. Moodle Calendar работает через `POST https://edu.susu.ru/lib/ajax/service.php?sesskey=<SESSKEY>&info=core_calendar_get_calendar_monthly_view`.
2. Календарь Moodle изолирован от SSO ЮУрГУ и требует сессионную куку `MoodleSession` и CSRF-токен `sesskey`.
3. Для Rating Helper Moodle является **внешним источником событий**, а не единым источником истины.
4. В приложении проектируется сервис `MoodleCalendarService`, предоставляющий:
   - Проверку наличия активной сессии Moodle.
   - Безопасное сохранение MoodleSession/sesskey в Keychain.
   - Загрузку ежемесячных событий `mod_assign` (дедлайны заданий) и `mod_quiz` (закрытие тестов).
   - Преобразование любого события Moodle в пользовательскую задачу `StudyTask` одним нажатием.

---

## 6. Централизованная модель академической аттестации и БРС

### 6.1. Модель `AcademicEvaluation`
Вместо жесткой привязки к 4-балльной шкале (2, 3, 4, 5) создается единый модуль оценивания:

```swift
public struct AcademicEvaluation: Sendable {
    public let rating: Double
    public let assessmentType: AssessmentType
    
    // Результат
    public let statusTitle: String        // "Зачтено", "Отлично (5)", "Незачёт / Долг"
    public let shortLabel: String         // "Зачёт", "Отл (5)", "Долг"
    public let isPassed: Bool             // rating >= 59.01
    public let gradeValue: Int?           // 5, 4, 3, 2 для диф. оценок; nil для зачёта
    public let progressToNext: String?    // nil для зачёта! Подсказка только для оценок
    public let badgeColor: Color
    public let lightBackground: Color
}
```

### 6.2. Правила расчёта по типам аттестации
1. **Зачёт (`AssessmentType.zachet`)**:
   - $\text{Рейтинг} \ge 59.01\% \implies$ «Зачтено» (зелёный цвет, `isPassed = true`).
   - $\text{Рейтинг} < 59.01\% \implies$ «Не зачтено / Долг» (красный цвет, `isPassed = false`, прогресс: «До зачёта не хватает $X\%$»).
   - **Запрещено** отображать «3», «4», «5» и «До четвёрки не хватает...».
2. **Экзамен (`AssessmentType.exam`) и Диф. зачёт (`AssessmentType.diffZachet`)**:
   - $\ge 84.01\% \implies$ «Отлично (5)».
   - $74.01\% - 84.00\% \implies$ «Хорошо (4)». Прогресс до «Отлично (5)».
   - $59.01\% - 74.00\% \implies$ «Удовлетворительно (3)». Прогресс до «Хорошо (4)».
   - $< 59.01\% \implies$ «Неудовлетворительно / Долг (2)». Прогресс до «Удовлетворительно (3)».
3. **Курсовой проект / Курсовая работа**:
   - Оцениваются по 5-балльной шкале дифференцированного зачёта.
4. **Практика**:
   - Оценивается в соответствии с типом контроля практики (зачётная либо дифференцированная шкала).

---

## 7. История рейтинга: семестровая и по дисциплинам

### 7.1. Схема базы данных
Таблица `public.rating_history` расширяется полем `subject_id`:
```sql
ALTER TABLE public.rating_history 
  ADD COLUMN IF NOT EXISTS subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS rating_history_user_subject_date_idx
  ON public.rating_history (user_id, subject_id, recorded_at);
```
- Если `subject_id IS NULL` — точка отражает **средний рейтинг семестра**.
- Если `subject_id` заполнен — точка отражает **рейтинг конкретной дисциплины**.

### 7.2. Логика фиксации точек
- Идемпотентность: новая точка записывается только при изменении рейтинга более чем на $0.01\%$.
- Точки не дублируются при повторном открытии экрана.
- В интерфейсе `RatingHistoryView` добавляется выбор: «Общий за семестр» или конкретный предмет.

---

## 8. Планировщик задач (`StudyTask`)

### 8.1. Разделение дедлайнов
```swift
public struct StudyTask: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var disciplineId: String?
    public var disciplineName: String?
    public var checkpointId: String?
    public var checkpointTitle: String?
    public var termNumber: Int?
    
    // Раздельные сроки:
    public var sourceDeadline: Date?     // Исходный срок из ЮУрГУ или Moodle
    public var customDeadline: Date?     // Персональный срок студента
    public var effectiveDeadline: Date? { customDeadline ?? sourceDeadline }
    
    public var externalSource: TaskSourceType // .manual, .checkpoint, .moodle
    public var externalId: String?       // ID события для предотвращения дубликатов
    public var priority: TaskPriority
    public var status: TaskStatus
    public var reminderOptions: [TaskReminderOption]
    public var createdAt: Date
    public var completedAt: Date?
}
```

---

## 9. Административная панель и безопасность

### 9.1. Структура `app_users`
Включает расширенные поля профиля, актуализируемые при входе:
- `user_id` (PK), `external_user_id`, `username`, `full_name`, `email`, `group_name`, `speciality_name`, `unit_name`, `study_years`, `education_level`, `education_form`.
- `is_banned`, `ban_reason`, `banned_at`, `can_view_materials`, `is_admin`, `last_active`, `app_version`, `device_info`.

### 9.2. Журнал административных действий (`admin_audit_log`)
Каждая смена статуса бана или доступа к материалам фиксируется в таблице `admin_audit_log`:
- `id`, `admin_user_id`, `target_user_id`, `action`, `details`, `created_at`.
