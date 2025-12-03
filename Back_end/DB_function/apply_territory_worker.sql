
DECLARE
  v_user_ids uuid[];
  -- 하드코딩된 설정값
  v_limit integer := 100;
  v_lock_interval interval := '00:30:00'::interval;
BEGIN
  -- 1) 만료된 user_id 추출 (중복 제거), 배치 크기 적용
  WITH expired AS (
    SELECT DISTINCT user_id
    FROM public.territories
    WHERE next_process_at <= now()
    LIMIT v_limit
  )
  SELECT array_agg(user_id) INTO v_user_ids FROM expired;

  -- 2) 아무 대상이 없으면 종료
  IF v_user_ids IS NULL OR array_length(v_user_ids,1) = 0 THEN
    RETURN;
  END IF;

  -- 3) 선택된 user_id들에 대해 next_process_at를 밀어 잠금(다른 워커 중복 방지)
  UPDATE public.territories
  SET next_process_at = now() + v_lock_interval
  WHERE user_id = ANY (v_user_ids)
    AND next_process_at <= now(); -- 안전장치: 만료 상태인 것만 업데이트

  -- 4) 실제 포인트 적용 호출
  PERFORM public.apply_territory_points(v_user_ids);

  -- 끝
END;
