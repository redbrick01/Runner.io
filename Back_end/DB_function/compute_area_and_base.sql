DECLARE
  area_srid integer := 5179; -- 고정
  computed_area double precision;
BEGIN
  -- 기본값
  area_m2 := 0;
  base_point := 0;

  IF geom IS NULL THEN
    -- geom이 NULL이면 0값을 반환하고 종료
    RETURN NEXT;
    RETURN;
  END IF;

  BEGIN
    computed_area := ST_Area(ST_Transform(geom, area_srid));
  EXCEPTION WHEN OTHERS THEN
    computed_area := 0;
  END;

  IF computed_area IS NULL OR computed_area <= 0 THEN
    area_m2 := 0;
    base_point := 0;
  ELSE
    area_m2 := computed_area;
    -- base_point 계산: ln(area_m2) / ln(10)
    BEGIN
      base_point := (LN(area_m2) / LN(10));
    EXCEPTION WHEN OTHERS THEN
      base_point := 0;
    END;
  END IF;

  -- OUT 변수 값을 한 행으로 반환
  RETURN NEXT;
  RETURN;
END;