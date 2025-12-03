DECLARE
  ln geometry := in_geom;
  ln_closed geometry;
  poly geometry;
BEGIN
  IF ln IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1) 라인 닫기 (시작점으로 되돌아오게)
  IF NOT ST_IsClosed(ln) THEN
    ln_closed := ST_AddPoint(ln, ST_StartPoint(ln));
  ELSE
    ln_closed := ln;
  END IF;

  ------------------------------------------------------------------
  -- 2) ★ 우선 ST_UnaryUnion + ST_BuildArea로
  --    자가 교차 포함 전체 면을 봉합해서 만들어 보기
  ------------------------------------------------------------------
  BEGIN
    poly := ST_BuildArea(ST_UnaryUnion(ln_closed));
  EXCEPTION WHEN OTHERS THEN
    poly := NULL;
  END;

  ------------------------------------------------------------------
  -- 3) 위 방법이 실패했거나(예외) 결과가 비어 있으면
  --    기존처럼 ST_MakePolygon으로 한 번 더 시도
  ------------------------------------------------------------------
  IF poly IS NULL OR ST_IsEmpty(poly) THEN
    BEGIN
      poly := ST_MakePolygon(ln_closed);
    EXCEPTION WHEN OTHERS THEN
      poly := NULL;
    END;
  END IF;

  ------------------------------------------------------------------
  -- 4) 그래도 폴리곤이 없으면 ConvexHull로 최후 fallback
  ------------------------------------------------------------------
  IF poly IS NULL OR ST_IsEmpty(poly) THEN
    poly := ST_ConvexHull(ln_closed);

    -- ConvexHull 결과가 LINESTRING이면 다시 닫아서 폴리곤 생성
    IF GeometryType(poly) = 'LINESTRING' THEN
      poly := ST_MakePolygon(ST_AddPoint(poly, ST_StartPoint(poly)));
    END IF;
  END IF;

  ------------------------------------------------------------------
  -- 5) 유효성 검사 및 보정
  ------------------------------------------------------------------
  IF poly IS NULL THEN
    RETURN NULL;
  END IF;

  IF NOT ST_IsValid(poly) THEN
    poly := ST_MakeValid(poly);
  END IF;

  -- 최종 검증: POLYGON / MULTIPOLYGON만 허용
  IF poly IS NULL
     OR NOT (GeometryType(poly) = 'POLYGON'
             OR GeometryType(poly) = 'MULTIPOLYGON') THEN
    RETURN NULL;
  END IF;

  RETURN poly;
END;