# Полный архитектурный и технический аудит системы Rating Helper

**Дата составления:** 7 ноября 2026 г.  
**Объект аудита:** Исходный код iOS-приложения (Swift/SwiftUI), браузерного расширения (Manifest V3), Google Apps Script (Web App Gateway), базы данных Supabase (PostgreSQL / RLS / RPC) и сопутствующей документации проекта Rating Helper.

---

## 1. Общая архитектура системы

Система **Rating Helper** представляет собой мультиплатформенный программный комплекс, предназначенный для академического мониторинга, расчёта и прогнозирования балльно-рейтинговой системы (БРС) студентов Южно-Уральского государственного университета (ЮУрГУ).

В состав системы входят 4 ключевых компонента:
1. **iOS-приложение (клиент)** — нативное приложение на Swift 6 / SwiftUI, собираемое с использованием легковесного кросс-компилятора `xtool` в окружении Windows + WSL Ubuntu 24.04 без Xcode. Выполняет роль основного клиентского интерфейса, локального планировщика задач и инструмента мониторинга успеваемости.
2. **Браузерное расширение (локальный помощник)** — расширение Chromium (Manifest V3), работающее на страницах личного кабинета `https://online.susu.ru`. Служит для локального считывания DOM журнала и встраивания инлайн-виджета БРС.
3. **Google Apps Script Gateway (серверный шлюз)** — серверный шлюз, скрывающий ключ `GROQ_API_KEY` для AI-модерации отзывов и выжимки через Groq AI, а также сохраняющий файлы учебных материалов на Google Диск.
4. **Supabase / PostgreSQL (облачная база данных)** — база данных PostgreSQL с механизмом Row Level Security (RLS) и хранимыми процедурами (RPC), хранящая метаданные дисциплин, контрольные точки, учебные материалы, отзывы и историю рейтинга.
5. **Внешние сервисы ЮУрГУ и Moodle**:
   - `online.susu.ru` Microgateway API — авторизация (`/api/auth/login`), обновление токенов (`/api/auth/UpdateToken`), перечень дисциплин (`/api/StudyActivity/Subjects`), журнал контрольных точек (`/api/StudyActivity/Journal`) и расписание занятий групп (`/api/Schedule/GetGroupSchedule/{groupId}`).
   - `edu.susu.ru` (Moodle) — календарь дедлайнов учебных заданий (`core_calendar_get_calendar_monthly_view`).

---

## 2. Назначение и фактическая реализация компонентов

### 2.1. Браузерное расширение
- **Фактическое состояние**:
  - Манифест (`manifest.json`): содержит права `activeTab`, `storage`, `scripting`, а также `host_permissions` на `online.susu.ru`, `supabase.co`, `api.groq.com`, `script.google.com`, `drive.google.com`.
  - Скрипты контента (`contentScript.js`): считывают структуру таблицы `.journal-table`, извлекают название предмета (`.discipline-name`), форму контроля (Зачёт / Экзамен / Диф. зачёт), контрольные точки (название, текущий балл, максимум, вес) и внедряют виджет `#susu-rating-inline-widget`.
  - **Критическое расхождение с концепцией**: В проект расширения были внедрены файлы `supabase.js` и `groq.js`. В `contentScript.js` (строка 423) при каждом открытии страницы дисциплины запускается сетевая синхронизация `SusuSupabase.syncSubjectData(...)`. В `popup.js` присутствуют формы модерации отзывов, загрузки файлов на Google Диск и ввода PIN-кода администратора. При этом расширение **не имеет** полноценной пользовательской сессии, не регистрирует устройства и не имеет механизма проверки блокировки.
  - **Вывод аудита**: В соответствии с разделом 1.1 технического задания, расширение должно оставаться надёжным локальным инструментом разбора DOM и калькулятором БРС, не требующим авторизации, регистрации устройств или проверок банов. Его локальная логика расчёта БРС, прогноза и внедрения виджета полностью автономна.

### 2.2. iOS-приложение (Swift / SwiftUI)
- **Архитектура**: SwiftUI с централизованным наблюдаемым объектом `AppState` (`@MainActor public final class AppState: ObservableObject`), синглтонами-акторами (`SusuAuthService`, `SusuJournalService`, `SupabaseService`, `GoogleDriveService`, `GroqModerationService`) и локальными хранилищами (`LocalStore`, `KeychainHelper`, `TaskManager`).
- **Сборка**: Проект описан в `Package.swift` и `xtool.yml`. Сборка выполняется в WSL2 Ubuntu-24.04 через `xtool dev build` без необходимости запуска macOS и Xcode.
- **Основные экраны**:
  - `LoginView` — форма входа в учётную запись ЮУрГУ.
  - `SubjectsView` — список дисциплин семестра с группировкой по типу аттестации.
  - `JournalView` — подробный журнал дисциплины с баллами БРС, симулятором и контрольными точками.
  - `TasksView` — планировщик учебных задач и дедлайнов с фильтрацией и календарным представлением.
  - `SemesterDashboardView` — сводный дашборд семестра со средним баллом и графиком `RatingHistoryView`.
  - `MaterialsView` / `UploadMaterialSheet` — просмотр и добавление учебных материалов к контрольным точкам.
  - `TeacherReviewsView` / `AddReviewSheet` — отзывы о преподавателях и сводка AI.
  - `SettingsView` / `AdminView` — настройки приложения, экспорт/импорт бэкапа и скрытая панель администратора.

### 2.3. Google Apps Script Web App (`Googlescript.txt`)
- Реализованы точки входа `doGet` и `doPost`.
- `action === "moderateReview"`: трехуровневая модерация текста (омоглифы, стоп-слова, вызов Groq API с системным промптом `ACADEMIC_MODERATION_PROMPT` и моделью `qwen/qwen3.8-27b`).
- `action === "generateSummary"`: агрегация до 15 отзывов и генерация структурированного резюме преподавателя через Groq.
- `action === "uploadMaterial"` (или наличие `fileData`): приём Base64-содержимого файла, декодирование, сохранение в папку `STUDENT_MATERIALS` на Google Диске и возврат публичной ссылки `https://drive.google.com/uc?export=download&id=...`.
- **Секреты**: `GROQ_API_KEY` получается из `PropertiesService.getScriptProperties().getProperty("GROQ_API_KEY")`.

### 2.4. Supabase / PostgreSQL
- **Таблицы**:
  - `app_users`: `user_id` (text, PK), `device_info` (text), `is_banned` (bool), `can_view_materials` (bool), `is_admin` (bool), `created_at`, `last_active`.
  - `subjects`: `id` (uuid, PK), `name` (text).
  - `subject_teachers`: `subject_id` (uuid, FK), `teacher_name` (text), PK(`subject_id`, `teacher_name`).
  - `checkpoints`: `id` (uuid, PK), `subject_id` (uuid, FK), `title` (text), `max_score` (numeric), `weight` (numeric), UNIQUE(`subject_id`, `title`).
  - `materials`: `id` (uuid, PK), `checkpoint_id` (uuid, FK), `subject_id` (uuid, FK), `teacher_name` (text), `title` (text), `file_url` (text), `file_name` (text), `year` (int), `upvotes` (int), `downvotes` (int), `created_at`.
  - `teacher_reviews`: `id` (uuid, PK), `teacher_name` (text), `subject_id` (uuid, nullable), `subject_name` (text), `text` (text), `difficulty` (int), `gives_avtomat` (bool), `attendance_strict` (bool), `year` (int), `likes` (int), `dislikes` (int), `created_at`.
  - `teacher_summaries`: `teacher_name` (text, PK), `summary_text` (text), `reviews_count` (int), `updated_at`.
  - `rating_history`: `id` (uuid, PK), `user_id` (text), `term` (int), `rating` (numeric(7,2)), `recorded_at` (timestamptz).
  - `app_config`: `key` (text, PK), `value` (text).
- **Хранимые процедуры (RPC)**:
  - `sync_subject_metadata(p_subject_id, p_subject_name, p_teacher_name, p_checkpoints)`: идемпотентная вставка дисциплины, преподавателя и контрольных точек с правами `SECURITY DEFINER`.

---

## 3. Анализ авторизации и постоянной идентификации пользователя

### 3.1. Фактический жизненный цикл в iOS
1. Метод `SusuAuthService.login(login:password:rememberMe:)` отправляет `POST https://online.susu.ru/microgateway/api/auth/login`.
2. В строке запроса и теле передаются:
   - `identity`: генерируется строкой `generateIdentity(length: 32)` случайным образом (`chars.randomElement()`).
   - `LoginForm[login]`
   - `LoginForm[password]`
3. **Обнаруженная проблема реализации**: Структура `LoginResponse` в `SusuAuthService.swift` считывает **только 3 поля**:
   ```swift
   public struct LoginResponse: Codable, Sendable {
       public let isLogged: Bool?
       public let accessToken: String?
       public let refreshToken: String?
   }
   ```
   Все остальные богатейшие данные ответа ЮУрГУ отбрасываются!

### 3.2. Фактические поля ответа ЮУрГУ (`online.susu.ru`)
Сервер ЮУрГУ при успешной авторизации возвращает расширенный JSON:
- `id` — постоянный целочисленный/строковый ID пользователя в информационной системе ЮУрГУ («Универис»).
- `userName` — логин студента (например, `ivanovii`).
- `email`, `susuEmail` — личный и корпоративный почтовые адреса.
- `firstName`, `middleName`, `lastName` — полное ФИО студента.
- `student` — **массив** объектов сведений об обучении:
  - `unitId`, `unitName`, `unitShortName` — факультет / высшая школа / институт (например, «Высшая школа электроники и компьютерных наук»).
  - `parentId`, `parentName` — головное подразделение.
  - `educationLevel` — уровень образования («Бакалавриат», «Магистратура», «Специалитет»).
  - `specialityCode`, `specialityName` — код и профиль направления подготовки.
  - `groupId` — **постоянный UUID студенческой группы** (критически необходим для API расписания!).
  - `groupName` — наименование группы (например, «КЭ-205»).
  - `studyYears` — годы обучения.
  - `educationForm` — форма обучения («Очная», «Заочная»).

### 3.3. Исследование параметра `identity` и сопоставление с `id`
- В веб-интерфейсе `online.susu.ru` параметр `identity` передаётся клиентом для привязки сессии/устройства. Если клиент генерирует его случайно при каждом новом входе (как сейчас делает `SusuAuthService.swift:35`), сервер всё равно принимает запрос, но привязывает refresh-токен к этому сгенерированному ключу.
- Поле `id` в ответе авторизации является истинным постоянным первичным ключом студента в базе ЮУрГУ. Оно не меняется при смене устройства, пароля или переустановке приложения.
- Логин `userName` также уникален и стабилен для каждого студента.
- Поле `student[].groupId` определяет академическую группу студента. При переходе на следующий курс или смене группы меняется `groupId`, поэтому в профиле необходимо сохранять массив учебных связей либо ссылку на активную программу.

### 3.4. Ошибка привязки пользователя в Supabase (`app_user_uuid`)
В `AppState.swift` (строки 65–70):
```swift
let userId = KeychainHelper.shared.readString(key: "app_user_uuid") ?? {
    let newId = UUID().uuidString
    _ = KeychainHelper.shared.saveString(key: "app_user_uuid", value: newId)
    return newId
}()
```
- Идентификатор пользователя генерировался на стороне клиента как случайный `UUID()` и сохранялся в Keychain устройства.
- При удалении приложения или сбросе Keychain генерировался **новый UUID**, что приводило к созданию дублирующей строки в `app_users`.
- Блокировка (`is_banned`), привязанная к старому `user_id`, мгновенно обходилась переустановкой приложения.

---

## 4. Детальный аудит выявленных проблем и уязвимостей

### Проблема 1. Фиктивная система блокировки (`is_banned`)
- **Где**: `SupabaseService.swift:22`, `AdminView.swift:123`, `SupabaseMigrations.sql`.
- **Суть**: Флаг `is_banned` хранится в таблице `app_users`, но:
  1. В `SupabaseService.swift` ни один рабочий метод (`getCheckpoints`, `getMaterialsForCheckpoint`, `addMaterialRecord`, `addTeacherReview`, `loadRatingHistory`, `recordOverallRating`) **не проверяет** `is_banned`.
  2. В `AppState.swift` при получении `appUser.isBanned == true` не происходит ни блокировки UI, ни завершения сессии, ни запрета сетевых операций.
  3. В Supabase RLS политики `materials`, `teacher_reviews`, `rating_history` не содержат проверки статуса блокировки пользователя (`USING (true)`).
  4. Заблокированный пользователь может беспрепятственно читать и отправлять отзывы, скачивать и загружать материалы, писать в историю рейтинга.

### Проблема 2. Обход ограничения доступа к материалам (`can_view_materials`)
- **Где**: `MaterialsListView.swift`, `SupabaseService.swift:232`, `Googlescript.txt:454`, `SupabaseMigrations.sql:90`.
- **Точная причина, почему материалы отображаются при `can_view_materials = false`**:
  1. Метод `SupabaseService.getMaterialsForCheckpoint(checkpointId:)` запрашивает:
     `GET /rest/v1/materials?checkpoint_id=eq.{id}&select=*`
     В этом запросе вообще не передаётся ID пользователя и не проверяется `can_view_materials`.
  2. RLS-политика `Public select materials` в Supabase имеет условие `USING (true)`, разрешая выборку всем клиентам с публичным anon-ключом.
  3. В `Googlescript.txt` строка 454: `file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW)`. Файлы публикуются с прямым доступом по URL вида `https://drive.google.com/uc?export=download&id={fileId}`.
  4. На клиенте в `MaterialsListView` отсутствует проверка `appState.appUser?.canViewMaterials`.
  5. В результате любой пользователь, независимо от флага в базе данных, видит полный список материалов и имеет прямые ссылки на их скачивание.

### Проблема 3. Небезопасная проверка прав администратора
- **Где**: `SettingsView.swift:191`, `SupabaseService.swift:512`, `AdminView.swift`.
- **Суть**: 
  1. Проверка прав администратора вызывается через диалог ввода мастер-ключа при 5-кратном нажатии на номер версии (`handleVersionTap`).
  2. В `SupabaseService.verifyAdminPin` вызывается RPC `verify_admin_pin(p_pin)`. В старой миграции пароль `'2026_ADMIN_PIN'` был захардкожен открытым текстом прямо в теле SQL-функции.
  3. При успешном ответе клиент просто локально устанавливает `appState.appUser?.isAdmin = true`.
  4. Все операции администратора в `SupabaseService.swift` (`getAllUsers`, `deleteReview`, `deleteMaterial`, `updateUser`) выполняются обычными REST-запросами `DELETE` и `PATCH` под публичным anon-ключом без серверной проверки, действительно ли вызывающий является администратором.
  5. В миграциях источника `RatingHelper_Rating` политика `Public delete materials` имела `USING (true)`, что позволяло любому желающему удалить всю базу материалов одной HTTP-командой.

### Проблема 4. Некорректное отображение формы аттестации «Зачёт»
- **Где**: `AcademicGrade.swift:54-80`, `Subject.swift:34-53`, `JournalView.swift`, `GradeBadgeView.swift`, `SimulatorCardView.swift`.
- **Суть**: 
  1. `AcademicGrade` строго привязан к 4-балльной шкале (2, 3, 4, 5).
  2. Если дисциплина имеет форму контроля «Зачёт» (`AssessmentType.zachet`), при наборе более 59.01% метод `AcademicGrade.from(percentage:)` возвращает `.satisfactory` («Удовлетворительно (3)»).
  3. Метод `AcademicGrade.subtext(for:)` выводит подсказку: «До «Хорошо (4)» не хватает X%».
  4. На экране журнала дисциплины вверху отображается бейдж «Зачёт», а чуть ниже в кольце и бейдже оценки крупно написано «Удовлетворительно (3)» и предлагается набрать баллы до четвёрки, что вводит студентов в заблуждение и противоречит регламенту ЮУрГУ.
  5. Логика оценки не учитывает тип аттестации: для «Зачёта» допустимы только состояния «Зачтено» ($\ge 59.01\%$) и «Не зачтено / Долг» ($< 59.01\%$), без шкал 4 и 5.

### Проблема 5. Ограниченность истории рейтинга
- **Где**: `rating_history` в `SupabaseMigrations.sql`, `SupabaseService.swift:121-156`, `RatingHistoryView.swift`.
- **Суть**:
  1. Таблица `rating_history` хранит только поля `user_id`, `term`, `rating`, `recorded_at`.
  2. В таблице отсутствует поле `subject_id`, из-за чего сохранение и построение истории по конкретным дисциплинам технически невозможно.
  3. График `RatingHistoryView` отображает исключительно средний рейтинг всего семестра.
  4. Запись в историю привязана к нестабильному `app_user_uuid` из Keychain.

### Проблема 6. Отсутствие модуля расписания занятий
- **Где**: `RatingHelper IOS/Sources/RatingHelper`.
- **Суть**: В приложении полностью отсутствует экран и сервис расписания, несмотря на наличие готового университетского API:
  `GET https://online.susu.ru/microgateway/api/Schedule/GetGroupSchedule/{groupId}`.
  Идентификатор `groupId` присутствует в ответе авторизации (`student[0].groupId`), но не извлекается клиентом.

### Проблема 7. Неполная интеграция задач с контрольными точками и дедлайнами Moodle
- **Где**: `StudyTask.swift:106-153`, `CreateTaskSheet.swift`, `TaskManager.swift`.
- **Суть**:
  1. В `StudyTask` есть только одно поле даты — `dueDate`.
  2. Отсутствует разделение на `source_deadline` (официальный срок сдачи из ЮУрГУ / Moodle) и `custom_deadline` (персональный срок, установленный студентом).
  3. Нет привязки к `termNumber` (семестру).
  4. Нет защиты от дублирования при повторной синхронизации или импорте задач из внешних календарей.
  5. Результаты исследования `CALENDAR_API_RESEARCH.md` по AJAX API календаря `edu.susu.ru` не воплощены в клиентский сервис.

---

## 5. Сводная матрица безопасности и архитектурных рисков

| Компонент / Endpoint | Уязвимость / Дефект | Уровень риска | Необходимое исправление |
|---|---|---|---|
| `POST /api/auth/login` | Игнорирование постоянного `id`, `userName` и массива `student[]` | Высокий | Расширить `LoginResponse`, сохранять постоянные идентификаторы ЮУрГУ и `groupId` |
| `KeychainHelper` (`app_user_uuid`) | Идентификатор пользователя привязан к случайному UUID устройства | Критический | Сопоставлять пользователя в Supabase по постоянному `external_user_id` / `external_identity` |
| `public.app_users` | Отсутствие RLS-защиты от модификации чужих данных и флагов бана | Критический | Закрыть прямой `UPDATE/INSERT` для `anon`; перевести регистрацию и профиль на защищённый RPC |
| `public.materials` | `SELECT` доступен всем (`USING (true)`), игнорируя `can_view_materials` и бан | Высокий | Защитить выборку через RLS / RPC с проверкой прав вызывающего пользователя |
| Google Drive Upload | Файлы расшариваются с `ANYONE_WITH_LINK` | Высокий | Хранить приватный ID файла; выдавать доступ только авторизованным через прокси/RPC |
| `verify_admin_pin` | Захардкоженный PIN в клиенте/SQL без аудита | Высокий | Серверная авторизация администраторов, ведение журнала `admin_audit_log` |
| `AcademicGrade.swift` | Отображение 3/4/5 для предметов с типом «Зачёт» | Средний | Добавить `AcademicEvaluation` с учётом `AssessmentType` (Зачёт / Экзамен / Дифзачёт) |
| `rating_history` | Отсутствие `subject_id` в схеме таблицы | Средний | Добавить миграцию с nullable `subject_id` (NULL = общий рейтинг, UUID = предмет) |
| Расписание | Отсутствие модуля расписания | Средний | Реализовать `SusuScheduleService`, модели, кэширование и UI вкладки `ScheduleView` |
