# Merge report

Дата: 2026-11-07

Целевой проект: `C:\Users\Иван\Downloads\RatingHelper`.
Источник: `C:\Users\Иван\Downloads\RatingHelper_Rating`.

Содержимое `RatingHelper` использовано как базовая версия. Исходная папка `RatingHelper_Rating` не изменялась.

## Перенесено

- Добавлен `Sources/RatingHelper/UI/Screens/Dashboard/RatingHistoryView.swift` с фильтрами периода и графиком истории общего рейтинга.
- В `SemesterDashboardView` добавлен блок истории рейтинга.
- В `SupabaseService` добавлены `RatingHistoryPoint`, чтение истории и идемпотентная запись новых точек рейтинга.
- В `AppState.loadJournal` добавлен расчёт среднего рейтинга выбранного семестра и запись точки истории.
- В `Subject` добавлена категория `Практика`; разбор типа аттестации расширен для `assessmentType`, `attestationType`, snake_case полей и строковых числовых идентификаторов.
- В `SubjectsView` добавлена группировка дисциплин по категории аттестации.
- В `CreateTaskSheet` сохранена UUID контрольной точки при создании и редактировании задачи; выбор контрольной точки обновляет UUID.
- В `CheckpointItem` сохранён безопасный `backendId` основной копии и добавлен совместимый alias `checkpointId` для функций задач.
- В `SupabaseMigrations.sql` добавлена таблица `rating_history`, индекс, RLS и порядок выдачи прав.

## Намеренно не перенесено целиком

- `SupabaseService.swift`, `AppState.swift`, `Checkpoint.swift`, `GoogleDriveService.swift`, `UploadMaterialSheet.swift` и миграции не заменялись файлами из источника. В них сохранены исправления первого агента: RPC синхронизации метаданных, UUID-проверки, защита загрузки, идемпотентность отзывов и кэширование файлов.
- `Googlescript.txt` оставлен из основной копии, включая проверку Base64.
- `Package.swift`, `xtool.yml`, `update.sh`, `update.ps1`, ресурсы и Bundle Identifier не менялись.

## Полное сравнение

В сравнении исходников обнаружены: один файл только в источнике (`RatingHistoryView.swift`), один файл только в основной копии (`CALENDAR_API_RESEARCH.md`) и десять общих изменённых файлов. Все изменения второго агента из этих десяти файлов либо объединены вручную, либо намеренно отклонены в пользу исправлений основной копии с записью причины в `MERGE_CONFLICTS.md`.

## Матрица изменённых общих файлов

| Файл | Изменение источника | Решение |
|---|---|---|
| `AppState.swift` | запись среднего рейтинга; UUID контрольной точки | объединено с RPC и `backendId` основной копии |
| `GoogleDriveService.swift` | удаление кэша загрузок | отклонено; кэш первой копии сохранён |
| `Checkpoint.swift` | поле `checkpointId` | объединено как alias к `backendId` |
| `Subject.swift` | `Практика`, расширенный разбор API | перенесено вручную |
| `SupabaseService.swift` | `rating_history`, прямые upsert-запросы | перенесена только история; RPC основной копии сохранён |
| `SemesterDashboardView.swift` | блок графика истории | перенесено вручную |
| `UploadMaterialSheet.swift` | удаление UUID-проверок | отклонено; проверки первой копии сохранены |
| `SubjectsView.swift` | группировка по аттестации | перенесено вручную |
| `CreateTaskSheet.swift` | сохранение checkpoint UUID в задаче | перенесено с адаптацией к `backendId` |
| `SupabaseMigrations.sql` | `rating_history` и небезопасные публичные политики | добавлен только безопасно согласованный блок истории |
| `Googlescript.txt` | версия без валидации Base64 основной копии | оставлена основная копия |
