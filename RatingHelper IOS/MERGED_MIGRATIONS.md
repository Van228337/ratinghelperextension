# Merged migrations

SQL автоматически не применялся.

Порядок применения в Supabase SQL Editor:

1. Выполнить актуальный `SupabaseMigrations.sql` целиком из основной папки.
2. Проверить, что создана функция `public.sync_subject_metadata(uuid, text, text, jsonb)` и ей выданы права `anon, authenticated`.
3. Проверить наличие `public.rating_history` и индекса `rating_history_user_term_date_idx`.
4. В Supabase Dashboard проверить RLS-политики для `rating_history` и фактические типы `user_id`, `term`, `rating`, `recorded_at`.
5. После ручной проверки выполнить загрузочный тест журнала и убедиться, что новые точки истории появляются только при изменении округлённого рейтинга.

Добавленный блок истории:

- таблица `rating_history` с UUID первичным ключом;
- `user_id text`, `term integer`, `rating numeric(7,2)`, `recorded_at timestamptz`;
- индекс по пользователю, семестру и дате;
- RLS включён;
- разрешены только SELECT и INSERT для `anon/authenticated` с проверками формата.

Ограничение текущей архитектуры: приложение использует UUID из Keychain, а не `auth.uid()` Supabase. Поэтому политика истории проверяет формат пользовательского UUID, но не может связать его с Supabase Auth без миграции авторизации. После перехода на Supabase Auth SELECT/INSERT-политики нужно ужесточить через `auth.uid()`.

Существующие миграции первого агента для RLS, RPC, отзывов, материалов и метаданных сохранены.
