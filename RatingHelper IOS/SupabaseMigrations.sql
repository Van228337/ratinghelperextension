-- Rating Helper: безопасная миграция после диагностики 07 Nov 2026
-- Выполнить в Supabase SQL Editor. Данные не удаляются, RLS не отключается.

-- Логи: 42501/401 возникали из-за прямых POST метаданных под publishable key;
-- 22P02 — в checkpoint_id передавалось локальное имя работы вместо UUID;
-- 42601 — старый опубликованный SQL содержал синтаксическую ошибку.

ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

ALTER TABLE public.checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject_teachers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public select checkpoints" ON public.checkpoints;
CREATE POLICY "Public select checkpoints" ON public.checkpoints
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public select subjects" ON public.subjects;
CREATE POLICY "Public select subjects" ON public.subjects
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public select subject_teachers" ON public.subject_teachers;
CREATE POLICY "Public select subject_teachers" ON public.subject_teachers
  FOR SELECT TO anon, authenticated USING (true);

-- Единственная запись метаданных — узкий RPC с проверками входных данных.
CREATE OR REPLACE FUNCTION public.sync_subject_metadata(
  p_subject_id uuid,
  p_subject_name text,
  p_teacher_name text DEFAULT NULL,
  p_checkpoints jsonb DEFAULT '[]'::jsonb
)
RETURNS SETOF public.checkpoints
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item jsonb;
  checkpoint_title text;
  checkpoint_max numeric;
  checkpoint_weight numeric;
BEGIN
  IF p_subject_id IS NULL OR length(trim(coalesce(p_subject_name, ''))) NOT BETWEEN 1 AND 240 THEN
    RAISE EXCEPTION 'Invalid subject metadata' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(coalesce(p_checkpoints, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Checkpoints must be a JSON array' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.subjects (id, name)
  VALUES (p_subject_id, trim(p_subject_name))
  ON CONFLICT (id) DO UPDATE SET name = excluded.name;

  IF length(trim(coalesce(p_teacher_name, ''))) > 0 THEN
    INSERT INTO public.subject_teachers (subject_id, teacher_name)
    VALUES (p_subject_id, left(trim(p_teacher_name), 240))
    ON CONFLICT (subject_id, teacher_name) DO NOTHING;
  END IF;

  FOR item IN SELECT value FROM jsonb_array_elements(p_checkpoints) LOOP
    checkpoint_title := left(trim(coalesce(item->>'title', '')), 240);
    checkpoint_max := (item->>'max_score')::numeric;
    checkpoint_weight := (item->>'weight')::numeric;
    IF checkpoint_title <> ''
       AND checkpoint_max IS NOT NULL AND checkpoint_max >= 0 AND checkpoint_max <= 100000
       AND checkpoint_weight IS NOT NULL AND checkpoint_weight >= 0 AND checkpoint_weight <= 100000 THEN
      INSERT INTO public.checkpoints (subject_id, title, max_score, weight)
      VALUES (p_subject_id, checkpoint_title, checkpoint_max, checkpoint_weight)
      ON CONFLICT (subject_id, title) DO UPDATE SET
        max_score = excluded.max_score,
        weight = excluded.weight;
    END IF;
  END LOOP;

  RETURN QUERY
    SELECT c.* FROM public.checkpoints c
    WHERE c.subject_id = p_subject_id
    ORDER BY c.title;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_subject_metadata(uuid, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_subject_metadata(uuid, text, text, jsonb) TO anon, authenticated;

ALTER TABLE public.teacher_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public select teacher_reviews" ON public.teacher_reviews;
CREATE POLICY "Public select teacher_reviews" ON public.teacher_reviews
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public select materials" ON public.materials;
CREATE POLICY "Public select materials" ON public.materials
  FOR SELECT TO anon, authenticated USING (true);

-- Вставка пользовательских данных с базовыми ограничениями. Админские таблицы
-- этими политиками не открываются; UPDATE/DELETE остаются закрытыми.
DROP POLICY IF EXISTS "Public insert teacher_reviews" ON public.teacher_reviews;
CREATE POLICY "Public insert teacher_reviews" ON public.teacher_reviews
  FOR INSERT TO anon, authenticated
  WITH CHECK (length(trim(coalesce(text, ''))) BETWEEN 15 AND 1200
              AND difficulty BETWEEN 1 AND 5
              AND year BETWEEN 2000 AND 2100);
DROP POLICY IF EXISTS "Public insert materials" ON public.materials;
CREATE POLICY "Public insert materials" ON public.materials
  FOR INSERT TO anon, authenticated
  WITH CHECK (checkpoint_id IS NOT NULL AND subject_id IS NOT NULL
             AND length(trim(coalesce(file_url, ''))) > 0);

-- verify_admin_pin с захардкоженным PIN намеренно не создаётся заново.

-- История общего рейтинга по пользователю и семестру.
-- Приложение использует собственный UUID из Keychain, а не Supabase Auth JWT,
-- поэтому политики ниже ограничивают формат данных, но не используют auth.uid().
-- После перехода на Supabase Auth замените SELECT-политику на auth.uid() = user_id.
CREATE TABLE IF NOT EXISTS public.rating_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  term integer NOT NULL CHECK (term > 0),
  rating numeric(7,2) NOT NULL CHECK (rating >= 0 AND rating <= 100),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS rating_history_user_term_date_idx
  ON public.rating_history (user_id, term, recorded_at);

ALTER TABLE public.rating_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public select rating_history" ON public.rating_history;
CREATE POLICY "Public select rating_history" ON public.rating_history
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public insert rating_history" ON public.rating_history;
CREATE POLICY "Public insert rating_history" ON public.rating_history
  FOR INSERT TO anon, authenticated
  WITH CHECK (length(trim(user_id)) BETWEEN 1 AND 128 AND term > 0 AND rating BETWEEN 0 AND 100);
GRANT SELECT, INSERT ON public.rating_history TO anon, authenticated;
