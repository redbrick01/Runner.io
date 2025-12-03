## 1. Edge Function

---

### 1.1 update_profile

- 로그인된 유저의  프로필 ( 닉네임, 색상 ), 비밀번호 업데이트
- 엔드포인트 : `POST /functions/v1/update-profile`
- 요청 Body (JSON)
    - `password` (선택, string) : 새 비밀번호, 최소 8자
    - `nick_name` (선택, string) : 닉네임
    - `color_hex` (선택, string) : 프로필 컬러 (HEX)
- 응답
    - 성공: 200 OK, JSON 형태로 업데이트된 정보 반환
    - 실패: 400/401/405/500 상태 코드와 에러 메시지
- 인증 : Bearer 토큰 필요

---

### 1.2 run_create

- 러닝 기록 생성 API
- 로그인된 유저의 러닝기록을 생성하고 DB의 `runs` 테이블에 저장
- 엔드포인트 : `POST /functions/v1/run-create`
- 요청 Body (JSON)
    - `start_at` (필수, timestampz) : 러닝 시작 시간
    - `ended_at` (필수, timestampz) : 러닝 종료 시간
    - `duration` (필수, float) : 러닝 소요 시간 (분)
    - `distance` (필수, float) : 러닝 코스 거리 (m)
    - `point` (필수, float) : 러닝 포인트
    - `path_geom` (필수, WKT) : 러닝 코스 데이터 (좌표)
- 응답
    - 성공: 201 Created, JSON 형태로 업데이트된 정보 반환
    - 실패: 400/401/405/500 상태 코드와 에러 메시지
- 인증 : Bearer 토큰 필요

---

### 1.3 profile_leaderboard

- 리더보드 조회 API
- 전체 상위 유저 또는 특정 유저 주변 랭킹 조회 가능
- 엔드포인트: `GET /functions/v1/profile-leaderboard?mode=<top|context>&user_id=<optional>`
- 요청 파라미터
    - `mode` (선택, string) : 조회 모드, `top`(기본) 또는 `context`
    - `user_id` (선택, string) : `context` 모드일 때 사용자 ID
- 응답
    - 성공: 200 OK, JSON 형태로 리더보드 결과 반환
        - `top` 모드: 상위 10명
        - `context` 모드: 특정 유저 주변 랭킹 (위 50명, 아래 50명 포함)
    - 실패: 400/404/500 상태 코드와 에러 메시지
- 인증: 불필요 (ANON 키 사용, 읽기 전용)

---

### 1.4 territory_geojson

- 영역(territory) 조회 API
- `territories` 테이블의 영역 데이터를 GeoJSON 형식으로 반환
- 프로필 정보(`nick_name`, `color_hex`)와 함께 제공
- 엔드포인트: `GET /functions/v1/territory-geojson`
- 요청 쿼리 파라미터
    - `bbox` (선택, string) : 조회 영역, 형식 `minX,minY,maxX,maxY`
    - `srid` (선택, integer) : 반환 좌표계, 기본 4326
    - `limit` (선택, integer) : 최대 반환 개수, 기본 1000, 최대 5000
- 응답
    - 성공: 200 OK, GeoJSON FeatureCollection
    - 실패: 400/500 상태 코드와 에러 메시지
        - 400: 잘못된 bbox 형식
        - 500: DB 조회 오류 등
- 인증: 불필요 (ANON 키 사용, 읽기 전용)

---

### 1.5 point_history_list

- 포인트 내역 조회 API
- 로그인된 유저의 `point_history` 테이블 데이터를 페이징 처리하여 반환
- 엔드포인트: `GET /functions/v1/point-history-list`
- 요청 쿼리 파라미터 (선택)
    - `limit` (integer) : 최대 조회 건수, 기본 100, 최대 500
    - `offset` (integer) : 조회 시작 위치, 기본 0
- 응답
    - 성공: 200 OK, JSON 형태
    - 실패: 401/500 상태 코드와 에러 메시지
        - 401: 토큰 누락 또는 유효하지 않은 토큰
        - 500: DB 조회 오류, 서버 오류 등
- 인증: Bearer 토큰 필요 (로그인된 사용자만 접근 가능)
