DECLARE
  simplified_geom geometry;
  ln geometry;
  _area_srid integer := 5179;
  _geom_srid integer := 4326;
  _tol_meters double precision := 5.0;
BEGIN
  IF in_geom IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1) 입력을 area_srid로 변환
  simplified_geom := ST_Transform(in_geom, _area_srid);

  -- 2) 단순화 시도 (예외 발생 시 변환 결과로 복구)
  BEGIN
    simplified_geom := ST_SimplifyPreserveTopology(simplified_geom, _tol_meters);
  EXCEPTION WHEN OTHERS THEN
    simplified_geom := ST_Transform(in_geom, _area_srid);
  END;

  -- 3) 다시 목표 geom_srid로 변환
  simplified_geom := ST_Transform(simplified_geom, _geom_srid);

  -- 4) 라인 병합 및 MULTILINESTRING 처리
  ln := ST_LineMerge(simplified_geom);

  IF GeometryType(ln) = 'MULTILINESTRING' THEN
    ln := (
      SELECT (st).geom
      FROM (SELECT ST_Dump(ln) AS st) AS foo
      ORDER BY ST_Length((st).geom) DESC
      LIMIT 1
    );
  END IF;

  RETURN ln;

EXCEPTION WHEN OTHERS THEN
  -- 예외 발생 시 원본 지오메트리를 안전하게 반환
  RETURN in_geom;
END;