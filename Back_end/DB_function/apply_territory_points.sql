BEGIN
  WITH t AS (
    SELECT
      user_id,
      base_point,
      get_territory_weight(updated_at) AS weight,
      (base_point * get_territory_weight(updated_at)) AS points_delta,
      (updated_at + interval '30 minutes') AS next_process_at
    FROM public.territories
  ),
  -- Update profiles and capture affected rows for history insertion
  updated AS (
    UPDATE public.profiles p
    SET
      total_points = p.total_points + t.points_delta,
      updated_at = now(),
      next_process_at = t.next_process_at
    FROM t
    WHERE p.user_id = t.user_id
    RETURNING p.user_id, t.points_delta
  )
  -- Insert history for each updated row
  INSERT INTO public.point_history (event_type, points_delta, user_id, created_at)
  SELECT 'territory_maintenance', u.points_delta, u.user_id, now()
  FROM updated u;
END;