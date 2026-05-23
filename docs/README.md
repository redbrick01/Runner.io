# `docs/`

## 역할

`docs/`는 Runner.io 졸업작품의 보고서, 프로젝트 구조 설명, Git 공개 전 점검 자료, 테스트 계획 및 결과를 보관하는 문서 폴더입니다. 루트 README와 하위 폴더 README는 이 폴더의 보고서 내용과 실제 코드 구조를 함께 참고해 작성되었습니다.

## 문서 목록

| 문서 | 목적 |
|---|---|
| `졸작_중간보고서.docx` | 졸업작품 중간보고서. 프로젝트 배경, 목표, 기술 선택 이유, 구현 현황, 화면별 진행 내역, 개발 일정/역할 분담 정리 |
| `final_midterm_report_en.docx` | 중간보고서 영문 번역본 |
| `final_midterm_report_en.txt` | 영문 번역본을 텍스트로 확인하기 위한 파일 |
| `PROJECT_STRUCTURE.md` | 실제 저장소 폴더 구조, 앱/백엔드/네이티브 구성, 주요 데이터 흐름 설명 |
| `PRE_GIT_CHECKLIST.md` | GitHub 공개 전 제외 파일, 민감 정보, 검증 명령 체크리스트 |
| `test_plan_and_results.md` | 테스트 계획, 자동/수동 검증 항목, E2E 테스트 결과 정리 |

현재 `docs/`에서 확인되는 발표자료 또는 최종보고서 별도 파일은 없습니다. 중간보고서와 영문 번역본, 구조/테스트 문서를 기준으로 문서화를 진행했습니다.

## 주요 파일

- `졸작_중간보고서.docx`
  - 프로젝트명 `Runner.io 러닝 기반 영토 점령 게임 애플리케이션`
  - 러닝 앱의 단순 기록 중심 한계와 게임화 필요성 설명
  - Flutter, Supabase, PostGIS, Edge Function 선택 이유 설명
  - 로그인, 러닝 기록, 지도/영토, 결과 리포트, 이력/분석, 백그라운드 기능 구현 현황 정리
  - AI 챗봇 분석, 사용자 피드백 수집, 안정성 향상은 향후 개발 목표로 분류
- `PROJECT_STRUCTURE.md`
  - 실제 코드 기준 폴더별 책임과 데이터 흐름 정리
  - Flutter 앱, Supabase backend, Android/iOS native 연동 설명
- `test_plan_and_results.md`
  - 기능 테스트, 경계 상황, 회귀 검증 방식과 실행 결과 정리
- `PRE_GIT_CHECKLIST.md`
  - 공개 저장소 업로드 전 API key, build 산출물, 생성 파일 관리 기준 정리

## 동작 흐름

문서 흐름은 다음 순서로 읽으면 프로젝트 이해가 쉽습니다.

```text
README.md
-> docs/README.md
-> docs/PROJECT_STRUCTURE.md
-> docs/test_plan_and_results.md
-> docs/PRE_GIT_CHECKLIST.md
-> 중간보고서 docx/txt
```

기획/설계/구현/검증 관점에서는 다음처럼 연결됩니다.

```text
중간보고서
-> 프로젝트 배경과 목표 정의
-> 기술 스택 및 구현 범위 정리
PROJECT_STRUCTURE.md
-> 실제 코드 구조와 아키텍처 설명
test_plan_and_results.md
-> 구현 기능 검증 방법 정리
PRE_GIT_CHECKLIST.md
-> 공개 전 정리 기준 제공
```

## 중간보고서 핵심 내용 요약

- 러닝 인구 증가와 기존 기록형 앱의 지속 동기 부족을 문제로 정의했습니다.
- GPS 기반 실시간 경로 기록과 지도 시각화를 핵심 기반으로 삼았습니다.
- 사용자의 이동 경로를 영토 점령, 포인트, 랭킹과 연결해 게임화된 러닝 경험을 제공하는 것을 목표로 했습니다.
- 중간 단계 구현 범위는 인증, Flutter 주요 화면, Supabase DB/Edge Function 연동, 러닝 세션 상태 관리, 결과/기록/포인트/랭킹/영토 화면 구성입니다.
- Android는 foreground service 기반 백그라운드 러닝 보조, iOS는 Live Activity 기반 상태 표시를 구현 내용으로 정리했습니다.
- 이후 개발 목표로 AI 챗봇 API 기반 분석, 안정성 향상, 최종 데모 및 사용자 피드백 수집이 언급되었습니다.

## 관련 기능

- 졸업작품 제출 문서 관리
- GitHub 공개용 README 작성 근거
- 프로젝트 구조와 테스트 결과 공유
- 구현 완료 기능과 향후 계획 구분

## 참고 사항

- 문서상 계획으로 언급된 AI 챗봇 분석 기능은 현재 코드에서 구현 파일을 확인하지 못했습니다.
- 발표자료와 최종보고서 파일은 현재 `docs/` 폴더에서 확인되지 않았습니다.
- 보고서와 코드가 다르게 표현하는 함수 이름이 일부 있습니다. 예를 들어 보고서의 `update_profile`은 실제 Edge Function 경로 기준 `update-profile`입니다.
- 테스트 결과나 구현 범위가 바뀌면 루트 README와 이 문서를 함께 갱신해야 합니다.
