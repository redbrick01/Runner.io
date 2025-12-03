DECLARE
    geom_srid integer;
    ln geometry;
    poly geometry;
    out_geom geometry;
BEGIN
    -- path_geom이 없으면 아무 작업도 하지 않음
    IF NEW.path_geom IS NULL THEN
        RETURN NEW;
    END IF;

    -- SRID 보정 (NULL 또는 0이면 4326으로 설정)
    geom_srid := ST_SRID(NEW.path_geom);
    IF geom_srid IS NULL OR geom_srid = 0 THEN
        geom_srid := 4326;
        NEW.path_geom := ST_SetSRID(NEW.path_geom, geom_srid);
    END IF;
		
    -- 단순화 / 라인정리 함수 호출
    ln := public.clean_geom(NEW.path_geom);

    -- ln 검증: NULL 또는 유효한 포인트 수가 아니면 중단
    IF ln IS NULL THEN
        RETURN NEW;
    END IF;
    IF ST_NPoints(ln) < 2 THEN
        RETURN NEW;
    END IF;

    -- 시작점 ↔ 끝점 거리 체크 (10m 기준)
    IF ST_Distance(ST_StartPoint(ln), ST_EndPoint(ln)) > 10 THEN
        RETURN NEW;
    END IF;

    -- 폴리곤 생성 함수
    poly := public.geom_to_polygon(ln);

    IF poly IS NULL OR ST_IsEmpty(poly) THEN
        NEW.loop_geom := NULL;
        RETURN NEW;
    END IF;

    -- SRID를 명시적으로 설정 (좌표 변환이 필요하면 ST_Transform 사용 권장)
    out_geom := ST_SetSRID(poly, geom_srid);
    NEW.loop_geom := out_geom;

    -- 현재 사용자 Territory 병합 / 신규 삽입 함수 호출 (void 반환이므로 PERFORM 사용)
    PERFORM public.subtract_territory_and_update(out_geom, NEW.user_id);
    PERFORM public.upsert_or_merge_territory(out_geom, NEW.user_id);

    RETURN NEW;
END;