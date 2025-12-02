# Runner.io

주요 기능만 구현 - 실제 작동에 중점 / 세부적인 부분은 추후 개발 (점령전, 크루 시스템, 이벤트)

[제목 없음](https://www.notion.so/2bd34ca825b0804c9904c38eb2a5e88b?pvs=21)

### 3. 게임 로직

1. 새로운 구역 A(new)의 면적 계산 → 초기 포인트 지급
    
    ```python
    area_new := ST_Area(Anew::geography);
    ```
    
2. 기존 전체 영토 집합 X 중 A(new)와 겹치는 구역 찾기
    
    ```python
    SELECT * FROM territories
    WHERE ST_Intersects(geom, Anew);
    ```
    
3. 기존 구역 X에서 A(new)와의 교집합 부분 제거 (기존 영토 수정)
    
    ```python
    UPDATE territories
    SET geom = ST_Multi(ST_Difference(geom, Anew))
    WHERE ST_Intersects(geom, Anew);
    ```
    
4. 완전히 사라진 기존 영토 제거
    
    ```python
    DELETE FROM territories
    WHERE ST_IsEmpty(geom);
    ```
    
5. 유저 A가 새 구역 A(new)를 자신의 territory에 추가
    
    ```python
    INSERT INTO territories (owner_id, geom, area_m2, last_owner_change_at, last_maintained_at)
    VALUES (
        userA,
        ST_Multi(Anew),
        area_new,
        now(),
        now()
    );
    ```
    
6. 매 주기(ex:5분, 10분)마다 각 유저의 territory 면적을 기준으로 유지 포인트 지급

- 두 구역 교차 판정 **ST_Intersects(geomA, geomB)**
- 두 구역 교집합 추출 ST_Intersection(geomA, geomB)
- 두 구역 차집합 ST_Difference(geomA, geomB) → 기존 구역 업데이트
- 두 구역 합집합 **ST_Union(geomA, geomB) → 유저의 구역 추가**
- 구역 면적 계산 ST_Area(geom)
- 구역 포함 (완전 점령) ST_Contains(geomA, geomB), ST_IsEmpty(geom)
- 경계면 **ST_Touches(geomA, geomB)**
- 폴리곤 모양 검사 ST_IsValid(geom)
- 폴리곤 8자형 코스 - 멀티폴리곤화 **ST_MakeValid(geom)**
- 하나의 MultiPolygon을 **여러 Polygon 조각으로 분리**

1. `loop_geom` → geometry(POLYGON, 4326)로 변환
2. 기존 `territories.geom` 중 `ST_Intersects` 되는 것들 찾기
3. `ST_Difference`로 기존 영토 잘라내기
4. 완전히 사라진 영토 삭제(`ST_IsEmpty`)
5. 공격자 유저의 새 영토 insert
6. `ST_Area(loop_geom)`으로 면적 구해서
    - `point_events`에 capture 이벤트 기록
    - `profiles.total_points` 갱신

### 4. 점수 산정 방식

4.1. 초기 영토 생성 점수 

- 러닝 거리 + 러닝 속도 + 전체 소모 칼로리

$$
S_{\text{init}} = d \cdot \left(1 + k_v \cdot \frac{v}{v_{\text{ref}}}\right) \cdot 10
$$

- 속도 가중치 $k_v$ : 속도 영향력 가중치 (0.2~0.4)
- 기준속도 $v_{\text{ref}}$ : 일반 사용자 기준의 평균 속도 (10km/h)

- 예시 러닝 거리 5.3km, 소요 시간 25분, 면적 77,121제곱미터 ⇒ 초기 점수 66.5점

4.2 영토 유지 추가 점수

- 기준 시간(30분)당, 점령 영토 면적 적용
- 같은 러닝 거리를 뛰어도 방식에 따라 면적의 크기차이가 크다 → 상용로그 처리
- 2,000,000m^2 = 6.3점 , 50,000 = 4.69점
- 러닝게임의 목적에 맞게 점령 면적 포인트 비중 최소화
- 예시 면적 77,121제곱미터 ⇒ 4.88포인트/30분

$$
S_{\text{keep,30}} = \log_{10}(A)

$$

- 경쟁률이 저조한 영토 점령후 방치 문제 해결 (장기 점령)
- `get_territory_weight` 입력된 updated_at 시간으로부터 경과 시간을 계산해 가중치(double precision)를 반환
    - 점령후 0~4시간 100%
    - 점령후 4~8시간 70%
    - 점령후 8~12시간 30%
    - 점형 후 12시간 초과 10%
- `apply_territory_points` territories 테이블의 각 행을 기반으로 프로필에 포인트를 더하고 포인트 히스토리를 삽입
- `apply_territory_worker`- next_process_at 시간이 만료된 유저를 찾아 apply_territory_points 시실행
- `run_apply_territory_points_with_lock` pg_try_advisory_lock로 잠금을 시도하여 동시 실행을 방지
- `cron job` - 1분마다 apply-territory-worker 호출

territory의 update_at이 변경될 때 (유저가 영토를 새롭게 점령하거나 러닝을 했을 떄)

트리거 → **update_next_process_at(30분)**