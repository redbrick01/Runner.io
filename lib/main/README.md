# `lib/main/`

## 역할

`lib/main/`은 Runner.io의 실제 사용자 기능 화면과 러닝 계산 엔진을 포함하는 핵심 폴더입니다. 메인 지도, 러닝 세션, 결과 리포트, 기록, 포인트, 랭킹, 영토 상세, 마이페이지, 프로필 수정 흐름이 이 폴더에 모여 있습니다.

## 주요 파일

| 파일 | 설명 |
|---|---|
| `running_map_page.dart` | 앱의 중심 화면. Google Maps, 위치 권한, 실시간 경로, 영토 overlay, 러닝 제어 버튼, 사용자 요약 정보를 연결 |
| `run_session_engine.dart` | UI와 분리된 러닝 계산 엔진. 위치 샘플 필터링, 거리/속도/페이스/split/고도, 일시정지/재개 상태 계산 |
| `run_result_page.dart` | 러닝 종료 후 결과 리포트 화면. 경로 지도, 거리, 시간, 페이스, 포인트, 칼로리, 상승고도, split 표시 |
| `run_history_page.dart` | 저장된 러닝 기록 조회 및 상세 결과 화면 이동 |
| `point_history_page.dart` | 기간별 포인트 이벤트 이력 조회 및 관련 러닝 결과 연결 |
| `ranking_page.dart` | 일/주/월/년/전체 기준 랭킹 및 내 주변 순위 표시 |
| `territory_detail_page.dart` | 영토 상세 정보, 기여 기록, 지도 기반 상세 표시 |
| `my_page.dart` | 내 프로필 요약, 누적 포인트/순위/영토 정보, 메뉴, 로그아웃, TTS 테스트 |
| `profile_edit_page.dart` | 닉네임, 색상, 키, 몸무게, 비밀번호 수정 |

## 동작 흐름

```text
RunningMapPage
-> 위치 권한 확인 및 현재 위치 표시
-> 주변 영토/사용자 요약 조회
-> 러닝 시작
-> RunSessionEngine으로 위치 샘플 처리
-> 러닝 종료
-> RunService.createRun 호출
-> RunResultPage 표시
-> 기록/포인트/랭킹/영토 화면에서 결과 재조회
```

러닝 계산 자체는 `RunSessionEngine`에 모여 있어 화면과 독립적으로 테스트할 수 있습니다. 지도 화면은 위치 stream, 지도 overlay, 백엔드 서비스 호출, Android/iOS 네이티브 bridge를 조합하는 역할을 맡습니다.

## 관련 기능

- 실시간 러닝 기록
- GPS 오차 완화를 위한 샘플 필터링
- 지도 기반 경로/영토 시각화
- 러닝 결과 분석
- 기록/포인트/랭킹/프로필 조회와 수정
- Android foreground service 및 iOS Live Activity와의 MethodChannel 연동

## 참고 사항

- 러닝 계산 규칙 변경 시 `test/run_session_engine_test.dart`를 우선 확인해야 합니다.
- 지도, 위치 권한, 백그라운드 동작은 widget test만으로 충분히 검증하기 어렵기 때문에 실제 기기 테스트가 필요합니다.
- Edge Function 응답 형식이 바뀌면 이 폴더의 화면과 `lib/services/` 계층을 함께 수정해야 합니다.
- 보고서에서 언급된 AI 챗봇 분석 기능은 현재 이 폴더에서 구현된 화면으로 확인되지 않습니다.
