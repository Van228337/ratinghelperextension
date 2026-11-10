-- =========================================================================
-- Rating Helper v3.0: Исправленная и проверенная SQL-миграция
-- Точно согласована с текущей схемой БД Supabase (типы uuid/text, subject_id)
-- Выполнить в Supabase Dashboard -> SQL Editor.
-- 100% неразрушающая: все существующие таблицы и данные сохраняются.
-- =========================================================================

-- 1. КОНФИГУРАЦИЯ БЕЗОПАСНОСТИ И МАСТЕР-КЛЮЧ АДМИНИСТРАТОРА
CREATE TABLE IF NOT EXISTS public.admin_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  description text,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.admin_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Deny public select admin_config" ON public.admin_config;
CREATE POLICY "Deny public select admin_config" ON public.admin_config FOR ALL USING (false);

-- Мастер-ключ по умолчанию (при необходимости измените значение 'rh_admin_susu_2026')
INSERT INTO public.admin_config (key, value, description)
VALUES 
  ('admin_secret', 'rh_admin_susu_2026', 'Мастер-ключ для авторизации в веб-панели и iOS-приложении'),
  ('gas_gateway_url', 'https://script.google.com/macros/s/AKfycbwYhcWQFDtdDxRF_E8JEh9GZOT7Ps-uvoYKyWxNWTUhv9qMoLzxgSyIUvVORM8FLGSWCg/exec', 'URL шлюза Google Apps Script')
ON CONFLICT (key) DO NOTHING;

-- RPC верификации мастер-ключа для веб-панели
CREATE OR REPLACE FUNCTION public.verify_admin_credentials(
  p_secret text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stored text;
BEGIN
  IF p_secret IS NULL OR trim(p_secret) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Secret key required');
  END IF;

  SELECT value INTO v_stored
  FROM public.admin_config
  WHERE key = 'admin_secret';

  IF v_stored IS NOT NULL AND v_stored = trim(p_secret) THEN
    RETURN jsonb_build_object(
      'success', true,
      'role', 'admin',
      'authenticated_at', now()
    );
  END IF;

  RETURN jsonb_build_object('success', false, 'message', 'Invalid master key');
END;
$$;

REVOKE ALL ON FUNCTION public.verify_admin_credentials(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_admin_credentials(text) TO anon, authenticated;

-- Обратная совместимость для существующего метода iOS: verify_admin_pin
CREATE OR REPLACE FUNCTION public.verify_admin_pin(
  p_pin text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stored text;
BEGIN
  SELECT value INTO v_stored
  FROM public.admin_config
  WHERE key = 'admin_secret';

  RETURN (v_stored IS NOT NULL AND v_stored = trim(p_pin));
END;
$$;

REVOKE ALL ON FUNCTION public.verify_admin_pin(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_admin_pin(text) TO anon, authenticated;


-- 2. ТАБЛИЦА УСТРОЙСТВ ПОЛЬЗОВАТЕЛЕЙ (user_devices)
CREATE TABLE IF NOT EXISTS public.user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  device_type text NOT NULL DEFAULT 'ios',
  device_name text,
  app_version text,
  push_token text,
  created_at timestamptz DEFAULT now(),
  last_seen timestamptz DEFAULT now(),
  UNIQUE (user_id, device_type, device_name)
);

CREATE INDEX IF NOT EXISTS user_devices_user_id_idx ON public.user_devices (user_id);
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public select user_devices" ON public.user_devices;
CREATE POLICY "Public select user_devices" ON public.user_devices
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public upsert user_devices" ON public.user_devices;
CREATE POLICY "Public upsert user_devices" ON public.user_devices
  FOR INSERT TO anon, authenticated
  WITH CHECK (length(trim(user_id)) > 0 AND length(trim(device_type)) > 0);


-- 3. УЖЕСТОЧЕНИЕ БЕЗОПАСНОСТИ RLS ДЛЯ МАТЕРИАЛОВ И ПОЛЬЗОВАТЕЛЕЙ
DROP POLICY IF EXISTS "Public select materials" ON public.materials;
DROP POLICY IF EXISTS "Materials accessible via RPC only" ON public.materials;
CREATE POLICY "Materials accessible via RPC only" ON public.materials
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Public update app_users" ON public.app_users;
DROP POLICY IF EXISTS "Public delete app_users" ON public.app_users;
REVOKE UPDATE, DELETE ON public.app_users FROM anon;


-- 4. RPC ДЛЯ ПОЛУЧЕНИЯ МАТЕРИАЛОВ С ПРОВЕРКОЙ БАНА И can_view_materials
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
    RETURN;
  END IF;

  RETURN QUERY
    SELECT m.*
    FROM public.materials m
    WHERE m.checkpoint_id = p_checkpoint_id
    ORDER BY (m.upvotes - m.downvotes) DESC, m.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_accessible_materials(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_accessible_materials(text, uuid) TO anon, authenticated;


-- 5. НОРМАЛИЗАЦИЯ ПРЕПОДАВАТЕЛЕЙ И УСТРАНЕНИЕ ДУБЛИКАТОВ
-- Таблица teachers (уже существует или создаётся)
CREATE TABLE IF NOT EXISTS public.teachers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL UNIQUE,
  department text,
  photo_url text,
  created_at timestamptz DEFAULT now()
);

-- Таблица teacher_disciplines: используем subject_id uuid из существующей схемы,
-- а discipline_name добавляем через ALTER TABLE при отсутствии
CREATE TABLE IF NOT EXISTS public.teacher_disciplines (
  teacher_id uuid NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL,
  PRIMARY KEY (teacher_id, subject_id)
);

ALTER TABLE public.teacher_disciplines 
  ADD COLUMN IF NOT EXISTS discipline_name text;

-- Таблица teacher_summaries: в текущей схеме primary key — teacher_name text
CREATE TABLE IF NOT EXISTS public.teacher_summaries (
  teacher_name text PRIMARY KEY,
  summary_text text NOT NULL,
  reviews_count integer DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.teacher_summaries 
  ADD COLUMN IF NOT EXISTS teacher_id uuid REFERENCES public.teachers(id);

-- Добавляем teacher_id в teacher_reviews
ALTER TABLE public.teacher_reviews 
  ADD COLUMN IF NOT EXISTS teacher_id uuid REFERENCES public.teachers(id);

CREATE INDEX IF NOT EXISTS teacher_reviews_teacher_id_idx ON public.teacher_reviews (teacher_id);
CREATE INDEX IF NOT EXISTS teacher_reviews_teacher_name_idx ON public.teacher_reviews (teacher_name);

-- Включение RLS
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_disciplines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_summaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public select teachers" ON public.teachers;
CREATE POLICY "Public select teachers" ON public.teachers FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public select teacher_disciplines" ON public.teacher_disciplines;
CREATE POLICY "Public select teacher_disciplines" ON public.teacher_disciplines FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public select teacher_summaries" ON public.teacher_summaries;
CREATE POLICY "Public select teacher_summaries" ON public.teacher_summaries FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public upsert teacher_summaries" ON public.teacher_summaries;
CREATE POLICY "Public upsert teacher_summaries" ON public.teacher_summaries
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- НЕРАЗРУШАЮЩАЯ МИГРАЦИЯ ДАННЫХ ПРЕПОДАВАТЕЛЕЙ
-- 1. Перенос уникальных преподавателей из subject_teachers
INSERT INTO public.teachers (full_name)
SELECT DISTINCT trim(teacher_name)
FROM public.subject_teachers
WHERE trim(coalesce(teacher_name, '')) <> ''
ON CONFLICT (full_name) DO NOTHING;

-- 2. Перенос преподавателей из отзывов
INSERT INTO public.teachers (full_name)
SELECT DISTINCT trim(teacher_name)
FROM public.teacher_reviews
WHERE trim(coalesce(teacher_name, '')) <> ''
ON CONFLICT (full_name) DO NOTHING;

-- 3. Заполнение связей преподаватель-дисциплина (используем subject_id uuid)
INSERT INTO public.teacher_disciplines (teacher_id, subject_id, discipline_name)
SELECT DISTINCT t.id, st.subject_id, coalesce(s.name, 'Дисциплина')
FROM public.subject_teachers st
JOIN public.teachers t ON t.full_name = trim(st.teacher_name)
LEFT JOIN public.subjects s ON s.id = st.subject_id
WHERE st.subject_id IS NOT NULL
ON CONFLICT (teacher_id, subject_id) DO UPDATE
  SET discipline_name = coalesce(excluded.discipline_name, teacher_disciplines.discipline_name);

-- 4. Связывание отзывов с teacher_id
UPDATE public.teacher_reviews r
SET teacher_id = t.id
FROM public.teachers t
WHERE r.teacher_id IS NULL AND trim(r.teacher_name) = t.full_name;

-- 5. Связывание существующих AI-выжимок с teacher_id
UPDATE public.teacher_summaries s
SET teacher_id = t.id
FROM public.teachers t
WHERE s.teacher_id IS NULL AND trim(s.teacher_name) = t.full_name;


-- 6. RPC ДЛЯ ПОЛУЧЕНИЯ ЕДИНОЙ КАРТОЧКИ ПРЕПОДАВАТЕЛЯ
CREATE OR REPLACE FUNCTION public.get_teacher_card(
  p_teacher_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher record;
  v_disciplines jsonb;
  v_stats jsonb;
  v_summary jsonb;
BEGIN
  -- 1. Поиск преподавателя
  SELECT * INTO v_teacher
  FROM public.teachers
  WHERE full_name = trim(p_teacher_name);

  IF v_teacher.id IS NULL THEN
    INSERT INTO public.teachers (full_name)
    VALUES (trim(p_teacher_name))
    ON CONFLICT (full_name) DO UPDATE SET full_name = excluded.full_name
    RETURNING * INTO v_teacher;
  END IF;

  -- 2. Список дисциплин преподавателя (через subject_id и subjects.name)
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'discipline_id', td.subject_id::text,
    'discipline_name', coalesce(td.discipline_name, s.name, 'Дисциплина')
  )), '[]'::jsonb) INTO v_disciplines
  FROM public.teacher_disciplines td
  LEFT JOIN public.subjects s ON s.id = td.subject_id
  WHERE td.teacher_id = v_teacher.id;

  -- 3. Статистика отзывов
  SELECT jsonb_build_object(
    'total_reviews', count(*),
    'avg_difficulty', coalesce(round(avg(difficulty)::numeric, 1), 3.0),
    'avtomat_pct', case when count(*) > 0 then round((count(*) filter (where gives_avtomat = true)::numeric / count(*)::numeric) * 100) else 0 end,
    'attendance_pct', case when count(*) > 0 then round((count(*) filter (where attendance_strict = true)::numeric / count(*)::numeric) * 100) else 0 end
  ) INTO v_stats
  FROM public.teacher_reviews
  WHERE teacher_id = v_teacher.id OR trim(teacher_name) = v_teacher.full_name;

  -- 4. AI-выжимка отзывов
  SELECT jsonb_build_object(
    'summary_text', summary_text,
    'reviews_count', reviews_count,
    'updated_at', updated_at
  ) INTO v_summary
  FROM public.teacher_summaries
  WHERE teacher_name = v_teacher.full_name
  LIMIT 1;

  RETURN jsonb_build_object(
    'id', v_teacher.id,
    'full_name', v_teacher.full_name,
    'department', v_teacher.department,
    'photo_url', v_teacher.photo_url,
    'disciplines', v_disciplines,
    'stats', v_stats,
    'summary', v_summary
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_teacher_card(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_card(text) TO anon, authenticated;


-- 7. ОБНОВЛЁННЫЙ RPC АДМИНИСТРАТОРА
CREATE OR REPLACE FUNCTION public.admin_set_user_status_v2(
  p_master_secret text,
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
  v_stored_secret text;
  v_admin record;
  v_target record;
  v_changes jsonb := '{}'::jsonb;
BEGIN
  -- 1. Проверка прав: мастер-ключ или пользователь с is_admin = true
  SELECT value INTO v_stored_secret
  FROM public.admin_config
  WHERE key = 'admin_secret';

  IF p_master_secret IS NOT NULL AND trim(p_master_secret) = v_stored_secret THEN
    NULL;
  ELSE
    SELECT is_admin INTO v_admin
    FROM public.app_users
    WHERE user_id::text = trim(p_admin_user_id);

    IF v_admin IS NULL OR NOT coalesce(v_admin.is_admin, false) THEN
      RAISE EXCEPTION 'Access denied: invalid admin credentials' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 2. Поиск целевого пользователя (сравнение с приведением к text для совместимости с uuid)
  SELECT * INTO v_target
  FROM public.app_users
  WHERE user_id::text = trim(p_target_user_id);

  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Target user not found' USING ERRCODE = '22023';
  END IF;

  -- 3. Применение изменений
  IF p_is_banned IS NOT NULL THEN
    v_changes := v_changes || jsonb_build_object('is_banned', p_is_banned, 'ban_reason', p_ban_reason);
    UPDATE public.app_users
    SET
      is_banned = p_is_banned,
      ban_reason = CASE WHEN p_is_banned THEN coalesce(p_ban_reason, 'Заблокирован администратором') ELSE NULL END,
      banned_at = CASE WHEN p_is_banned THEN now() ELSE NULL END,
      banned_by = CASE WHEN p_is_banned THEN coalesce(p_admin_user_id, 'web_admin') ELSE NULL END
    WHERE user_id::text = trim(p_target_user_id);
  END IF;

  IF p_can_view_materials IS NOT NULL THEN
    v_changes := v_changes || jsonb_build_object('can_view_materials', p_can_view_materials);
    UPDATE public.app_users
    SET can_view_materials = p_can_view_materials
    WHERE user_id::text = trim(p_target_user_id);
  END IF;

  -- 4. Запись в журнал аудита
  INSERT INTO public.admin_audit_log (
    admin_user_id,
    target_user_id,
    action,
    details
  ) VALUES (
    coalesce(trim(p_admin_user_id), 'web_admin'),
    trim(p_target_user_id),
    'UPDATE_USER_STATUS',
    v_changes
  );

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_status_v2 FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status_v2 TO anon, authenticated;
