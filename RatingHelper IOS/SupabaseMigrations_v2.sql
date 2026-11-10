-- =========================================================================
-- Rating Helper v2.1: Исправленная и устойчивая SQL-миграция (100% совместимость типов)
-- Выполнить в Supabase Dashboard -> SQL Editor.
-- Все сравнения UUID и TEXT приведены явно к TEXT (ошибка 42883 устранена).
-- =========================================================================

-- 1. РАСШИРЕНИЕ ПРОФИЛЯ ПОЛЬЗОВАТЕЛЕЙ (app_users)
-- Привязка к постоянному идентификатору ЮУрГУ и расширенным данным обучения
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS external_user_id text,
  ADD COLUMN IF NOT EXISTS external_identity text,
  ADD COLUMN IF NOT EXISTS username text,
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS susu_email text,
  ADD COLUMN IF NOT EXISTS group_id text,
  ADD COLUMN IF NOT EXISTS group_name text,
  ADD COLUMN IF NOT EXISTS speciality_code text,
  ADD COLUMN IF NOT EXISTS speciality_name text,
  ADD COLUMN IF NOT EXISTS unit_name text,
  ADD COLUMN IF NOT EXISTS education_level text,
  ADD COLUMN IF NOT EXISTS education_form text,
  ADD COLUMN IF NOT EXISTS study_years text,
  ADD COLUMN IF NOT EXISTS ban_reason text,
  ADD COLUMN IF NOT EXISTS banned_at timestamptz,
  ADD COLUMN IF NOT EXISTS banned_by text,
  ADD COLUMN IF NOT EXISTS app_version text;

CREATE INDEX IF NOT EXISTS app_users_external_user_id_idx ON public.app_users (external_user_id);
CREATE INDEX IF NOT EXISTS app_users_username_idx ON public.app_users (username);

-- 2. ЖУРНАЛ АДМИНИСТРАТИВНЫХ ДЕЙСТВИЙ (admin_audit_log)
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id text NOT NULL,
  target_user_id text NOT NULL,
  action text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_audit_log_target_idx ON public.admin_audit_log (target_user_id, created_at DESC);
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public select audit log for admins" ON public.admin_audit_log;
CREATE POLICY "Public select audit log for admins" ON public.admin_audit_log
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.app_users u 
    WHERE u.user_id::text = admin_audit_log.admin_user_id::text 
      AND coalesce(u.is_admin, false) = true
  ));

-- 3. РАСШИРЕНИЕ ИСТОРИИ РЕЙТИНГА ДЛЯ ОТДЕЛЬНЫХ ДИСЦИПЛИН
-- Используем text для subject_id во избежание конфликтов типов и ошибок внешних ключей
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rating_history' AND column_name = 'subject_id'
  ) THEN
    ALTER TABLE public.rating_history ADD COLUMN subject_id text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS rating_history_user_subject_date_idx
  ON public.rating_history (user_id, subject_id, recorded_at DESC);

-- 4. RPC ДЛЯ РАЗРЕШЕНИЯ / РЕГИСТРАЦИИ ПОЛЬЗОВАТЕЛЯ ПО ПОСТОЯННОМУ ID ЮУрГУ
CREATE OR REPLACE FUNCTION public.resolve_or_register_user(
  p_external_user_id text,
  p_external_identity text DEFAULT NULL,
  p_username text DEFAULT NULL,
  p_full_name text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_susu_email text DEFAULT NULL,
  p_group_id text DEFAULT NULL,
  p_group_name text DEFAULT NULL,
  p_speciality_code text DEFAULT NULL,
  p_speciality_name text DEFAULT NULL,
  p_unit_name text DEFAULT NULL,
  p_education_level text DEFAULT NULL,
  p_education_form text DEFAULT NULL,
  p_study_years text DEFAULT NULL,
  p_app_version text DEFAULT NULL,
  p_device_info text DEFAULT NULL
)
RETURNS TABLE (
  user_id text,
  is_banned boolean,
  ban_reason text,
  can_view_materials boolean,
  is_admin boolean,
  full_name text,
  group_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user record;
  v_is_uuid_col boolean;
BEGIN
  IF p_external_user_id IS NULL OR trim(p_external_user_id) = '' THEN
    RAISE EXCEPTION 'external_user_id is required' USING ERRCODE = '22023';
  END IF;

  -- 1. Поиск по постоянному external_user_id
  SELECT * INTO v_user
  FROM public.app_users u
  WHERE u.external_user_id = trim(p_external_user_id)
  LIMIT 1;

  -- 2. Если не найден по external_user_id, пробуем сопоставить по username
  IF v_user.user_id IS NULL AND p_username IS NOT NULL AND trim(p_username) <> '' THEN
    SELECT * INTO v_user
    FROM public.app_users u
    WHERE u.username = trim(p_username)
    LIMIT 1;
  END IF;

  IF v_user.user_id IS NOT NULL THEN
    -- Обновляем профиль и активность (сравнение user_id::text)
    UPDATE public.app_users
    SET
      external_user_id = coalesce(v_user.external_user_id, trim(p_external_user_id)),
      external_identity = coalesce(p_external_identity, external_identity),
      username = coalesce(trim(p_username), username),
      full_name = coalesce(trim(p_full_name), full_name),
      email = coalesce(trim(p_email), email),
      susu_email = coalesce(trim(p_susu_email), susu_email),
      group_id = coalesce(trim(p_group_id), group_id),
      group_name = coalesce(trim(p_group_name), group_name),
      speciality_code = coalesce(trim(p_speciality_code), speciality_code),
      speciality_name = coalesce(trim(p_speciality_name), speciality_name),
      unit_name = coalesce(trim(p_unit_name), unit_name),
      education_level = coalesce(trim(p_education_level), education_level),
      education_form = coalesce(trim(p_education_form), education_form),
      study_years = coalesce(trim(p_study_years), study_years),
      app_version = coalesce(p_app_version, app_version),
      device_info = coalesce(p_device_info, device_info),
      last_active = now()
    WHERE public.app_users.user_id::text = v_user.user_id::text
    RETURNING * INTO v_user;

    RETURN QUERY SELECT
      v_user.user_id::text,
      coalesce(v_user.is_banned, false),
      v_user.ban_reason,
      coalesce(v_user.can_view_materials, true),
      coalesce(v_user.is_admin, false),
      v_user.full_name,
      v_user.group_name;
    RETURN;
  END IF;

  -- 3. Создание нового постоянного пользователя с учётом типа user_id в схеме
  SELECT (data_type = 'uuid') INTO v_is_uuid_col
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'app_users' AND column_name = 'user_id';

  IF coalesce(v_is_uuid_col, false) THEN
    EXECUTE 'INSERT INTO public.app_users (
      user_id, external_user_id, external_identity, username, full_name, email, susu_email,
      group_id, group_name, speciality_code, speciality_name, unit_name, education_level,
      education_form, study_years, app_version, device_info, is_banned, can_view_materials,
      is_admin, created_at, last_active
    ) VALUES (
      gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, false, true, false, now(), now()
    ) RETURNING *'
    INTO v_user
    USING trim(p_external_user_id), p_external_identity, trim(p_username), trim(p_full_name),
          trim(p_email), trim(p_susu_email), trim(p_group_id), trim(p_group_name),
          trim(p_speciality_code), trim(p_speciality_name), trim(p_unit_name),
          trim(p_education_level), trim(p_education_form), trim(p_study_years),
          p_app_version, coalesce(p_device_info, 'iOS Native App');
  ELSE
    EXECUTE 'INSERT INTO public.app_users (
      user_id, external_user_id, external_identity, username, full_name, email, susu_email,
      group_id, group_name, speciality_code, speciality_name, unit_name, education_level,
      education_form, study_years, app_version, device_info, is_banned, can_view_materials,
      is_admin, created_at, last_active
    ) VALUES (
      gen_random_uuid()::text, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, false, true, false, now(), now()
    ) RETURNING *'
    INTO v_user
    USING trim(p_external_user_id), p_external_identity, trim(p_username), trim(p_full_name),
          trim(p_email), trim(p_susu_email), trim(p_group_id), trim(p_group_name),
          trim(p_speciality_code), trim(p_speciality_name), trim(p_unit_name),
          trim(p_education_level), trim(p_education_form), trim(p_study_years),
          p_app_version, coalesce(p_device_info, 'iOS Native App');
  END IF;

  RETURN QUERY SELECT
    v_user.user_id::text,
    coalesce(v_user.is_banned, false),
    v_user.ban_reason,
    coalesce(v_user.can_view_materials, true),
    coalesce(v_user.is_admin, false),
    v_user.full_name,
    v_user.group_name;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_or_register_user FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_or_register_user TO anon, authenticated;

-- 5. RPC ДЛЯ ПОЛУЧЕНИЯ МАТЕРИАЛОВ С ПРОВЕРКОЙ БАНА И ПРАВ can_view_materials
CREATE OR REPLACE FUNCTION public.get_accessible_materials(
  p_user_id text,
  p_checkpoint_id uuid
)
RETURNS SETOF public.materials
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user record;
BEGIN
  IF p_user_id IS NULL OR trim(p_user_id) = '' THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT is_banned, can_view_materials INTO v_user
  FROM public.app_users
  WHERE user_id::text = trim(p_user_id);

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'User not found' USING ERRCODE = '42501';
  END IF;

  IF coalesce(v_user.is_banned, false) THEN
    RAISE EXCEPTION 'User account is suspended' USING ERRCODE = '42501';
  END IF;

  IF NOT coalesce(v_user.can_view_materials, true) THEN
    -- Возвращаем пустой набор данных, если просмотр материалов закрыт
    RETURN;
  END IF;

  RETURN QUERY
    SELECT m.*
    FROM public.materials m
    WHERE m.checkpoint_id::text = p_checkpoint_id::text
    ORDER BY (m.upvotes - m.downvotes) DESC, m.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_accessible_materials(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_accessible_materials(text, uuid) TO anon, authenticated;

-- 6. RPC ДЛЯ АДМИНИСТРАТИВНОГО ИЗМЕНЕНИЯ СТАТУСА (С АУДИТ-ЛОГОМ)
CREATE OR REPLACE FUNCTION public.admin_set_user_status(
  p_admin_user_id text,
  p_target_user_id text,
  p_is_banned boolean DEFAULT NULL,
  p_ban_reason text DEFAULT NULL,
  p_can_view_materials boolean DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin record;
  v_target record;
  v_changes jsonb := '{}'::jsonb;
BEGIN
  -- 1. Проверка прав администратора
  SELECT is_admin INTO v_admin
  FROM public.app_users
  WHERE user_id::text = trim(p_admin_user_id);

  IF v_admin IS NULL OR NOT coalesce(v_admin.is_admin, false) THEN
    RAISE EXCEPTION 'Access denied: caller is not an administrator' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_target
  FROM public.app_users
  WHERE user_id::text = trim(p_target_user_id);

  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Target user not found' USING ERRCODE = '22023';
  END IF;

  -- 2. Применение изменений
  IF p_is_banned IS NOT NULL THEN
    v_changes := v_changes || jsonb_build_object('is_banned', p_is_banned, 'ban_reason', p_ban_reason);
    UPDATE public.app_users
    SET
      is_banned = p_is_banned,
      ban_reason = CASE WHEN p_is_banned THEN coalesce(p_ban_reason, 'Заблокирован администратором') ELSE NULL END,
      banned_at = CASE WHEN p_is_banned THEN now() ELSE NULL END,
      banned_by = CASE WHEN p_is_banned THEN p_admin_user_id ELSE NULL END
    WHERE user_id::text = trim(p_target_user_id);
  END IF;

  IF p_can_view_materials IS NOT NULL THEN
    v_changes := v_changes || jsonb_build_object('can_view_materials', p_can_view_materials);
    UPDATE public.app_users
    SET can_view_materials = p_can_view_materials
    WHERE user_id::text = trim(p_target_user_id);
  END IF;

  -- 3. Запись в журнал аудита
  INSERT INTO public.admin_audit_log (
    admin_user_id,
    target_user_id,
    action,
    details
  ) VALUES (
    trim(p_admin_user_id),
    trim(p_target_user_id),
    'UPDATE_USER_STATUS',
    v_changes
  );

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_status FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status TO anon, authenticated;

-- 7. РАСШИРЯЕМАЯ РЕЛЯЦИОННАЯ ОСНОВА ДЛЯ МОДУЛЯ ПРЕПОДАВАТЕЛЕЙ
CREATE TABLE IF NOT EXISTS public.teachers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL UNIQUE,
  department text,
  photo_url text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.teacher_disciplines (
  teacher_id uuid REFERENCES public.teachers(id) ON DELETE CASCADE,
  subject_id uuid,
  PRIMARY KEY (teacher_id, subject_id)
);

CREATE TABLE IF NOT EXISTS public.review_criteria (
  id text PRIMARY KEY,
  title text NOT NULL,
  description text
);

CREATE TABLE IF NOT EXISTS public.review_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid,
  reporter_user_id text NOT NULL,
  reason text NOT NULL,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_disciplines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_criteria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public select teachers" ON public.teachers;
CREATE POLICY "Public select teachers" ON public.teachers FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public select teacher_disciplines" ON public.teacher_disciplines;
CREATE POLICY "Public select teacher_disciplines" ON public.teacher_disciplines FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public select review_criteria" ON public.review_criteria;
CREATE POLICY "Public select review_criteria" ON public.review_criteria FOR SELECT TO anon, authenticated USING (true);
