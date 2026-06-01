CREATE UNIQUE INDEX IF NOT EXISTS crews_active_name_key
  ON public.crews (lower(name))
  WHERE deleted_at IS NULL;
