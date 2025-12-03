DECLARE
  other_rec RECORD;
  other_geom geometry;
  updated_geom geometry;
  area_m2_var double precision;
  base_point_var double precision;
  geom_srid integer := 4326;    -- 고정
BEGIN
  IF target_geom IS NULL THEN
    RETURN;
  END IF;

  FOR other_rec IN
    SELECT user_id, geom FROM public.territories
    WHERE user_id IS DISTINCT FROM exclude_user_id
  LOOP
    other_geom := other_rec.geom;
    IF other_geom IS NULL THEN
      CONTINUE;
    END IF;

    -- SRID 맞추기
    IF ST_SRID(other_geom) <> geom_srid THEN
      BEGIN
        other_geom := ST_Transform(other_geom, geom_srid);
      EXCEPTION WHEN OTHERS THEN
        other_geom := other_rec.geom;
      END;
    END IF;

    -- 교차 여부 검사
    IF NOT ST_Intersects(other_geom, target_geom) THEN
      CONTINUE;
    END IF;

    -- 차집합 시도
    BEGIN
      updated_geom := ST_Difference(other_geom, target_geom);
      IF updated_geom IS NULL OR ST_IsEmpty(updated_geom) THEN
        updated_geom := NULL;
      ELSE
        updated_geom := ST_MakeValid(updated_geom);
        updated_geom := ST_SetSRID(updated_geom, geom_srid);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      updated_geom := other_geom;
    END;

    -- 분리된 보조함수로 면적 및 base_point 계산
    SELECT area_m2, base_point INTO area_m2_var, base_point_var
    FROM public.compute_area_and_base(updated_geom);

    -- geom, area, base_point만 갱신
    UPDATE public.territories
    SET geom = updated_geom,
        area = area_m2_var,
        base_point = base_point_var
    WHERE user_id = other_rec.user_id;
  END LOOP;
END;