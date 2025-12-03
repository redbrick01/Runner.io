DECLARE
  -- 내부 고정값
  p_geom_srid integer := 4326;
  p_area_srid integer := 3857;

  user_exist boolean;
  existing_geom geometry;
  merged_geom geometry;
  area_m2_var double precision;
  base_point_var double precision;
BEGIN
  IF p_out_geom IS NULL OR p_user_id IS NULL THEN
    RETURN;
  END IF;

  -- 존재 여부 확인
  SELECT EXISTS(SELECT 1 FROM public.territories WHERE user_id = p_user_id)
  INTO user_exist;

  IF user_exist THEN
    -- 기존 레코드 잠금 후 geom 로드
    SELECT geom INTO existing_geom
    FROM public.territories
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF existing_geom IS NULL THEN
      merged_geom := p_out_geom;
    ELSE
      -- SRID 맞추기
      IF ST_SRID(existing_geom) <> p_geom_srid THEN
        BEGIN
          existing_geom := ST_Transform(existing_geom, p_geom_srid);
        EXCEPTION WHEN OTHERS THEN
          existing_geom := existing_geom; -- 실패 시 원본 유지
        END;
      END IF;

      BEGIN
        merged_geom := ST_Union(existing_geom, p_out_geom);
        merged_geom := ST_MakeValid(merged_geom);
      EXCEPTION WHEN OTHERS THEN
        merged_geom := ST_ConvexHull(ST_Collect(existing_geom, p_out_geom));
      END;
    END IF;

    -- 면적 및 base_point 계산 (보조함수 재사용)
    SELECT area_m2, base_point INTO area_m2_var, base_point_var
    FROM public.compute_area_and_base(merged_geom);

    -- 업데이트 (updated_at 갱신)
    UPDATE public.territories
    SET geom = ST_SetSRID(merged_geom, p_geom_srid),
        area = area_m2_var,
        base_point = base_point_var,
        updated_at = now()
    WHERE user_id = p_user_id;

  ELSE
    -- 신규 삽입 시에도 면적 계산
    SELECT area_m2, base_point INTO area_m2_var, base_point_var
    FROM public.compute_area_and_base(ST_SetSRID(p_out_geom, p_geom_srid));

    INSERT INTO public.territories(user_id, geom, area, base_point, created_at, updated_at)
    VALUES (p_user_id, ST_SetSRID(p_out_geom, p_geom_srid), area_m2_var, base_point_var, now(), now());
  END IF;
END;
