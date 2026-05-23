CREATE OR REPLACE FUNCTION public.handle_run_points() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 1) point_history 기록
  INSERT INTO public.point_history (event_type, points_delta, created_at, user_id)
  VALUES ('run_created', COALESCE(NEW.point, 0), now(), NEW.user_id);

  -- 2) profiles.total_points 누적
  UPDATE public.profiles
  SET total_points = COALESCE(total_points, 0) + COALESCE(NEW.point, 0)
  WHERE user_id = NEW.user_id;

  -- 3) user_point_daily (KST 기준 일자) 누적 upsert
  INSERT INTO public.user_point_daily (
    user_id,
    day_kst,
    run_points,
    total_points
  )
  VALUES (
    NEW.user_id,
    (now() AT TIME ZONE 'Asia/Seoul')::date,
    COALESCE(NEW.point, 0),
    COALESCE(NEW.point, 0)
  )
  ON CONFLICT (user_id, day_kst)
  DO UPDATE
  SET
    run_points = COALESCE(user_point_daily.run_points, 0) + EXCLUDED.run_points,
    total_points = COALESCE(user_point_daily.total_points, 0) + EXCLUDED.total_points;

  RETURN NEW;
END;
$$;

WITH run_daily AS (
  SELECT
    user_id,
    (created_at AT TIME ZONE 'Asia/Seoul')::date AS day_kst,
    SUM(COALESCE(points_delta, 0)) AS run_points
  FROM public.point_history
  WHERE event_type = 'run_created'
    AND user_id IS NOT NULL
  GROUP BY user_id, (created_at AT TIME ZONE 'Asia/Seoul')::date
)
INSERT INTO public.user_point_daily (
  user_id,
  day_kst,
  run_points,
  total_points
)
SELECT
  user_id,
  day_kst,
  run_points,
  run_points
FROM run_daily
ON CONFLICT (user_id, day_kst)
DO UPDATE
SET run_points = EXCLUDED.run_points;
