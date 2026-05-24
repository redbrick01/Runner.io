# `docs/`

## 역할

`docs/`는 Runner.io 졸업작품의 프로젝트 구조, 개발 가이드라인, 기능별 설계/검증 기록, 테스트 결과, 오류 리포트, 제출 보고서를 보관하는 문서 폴더입니다.

앞으로 새 기능 문서는 `docs/features/<feature>/` 아래에 모아 둡니다. `docs/` 루트에는 프로젝트 전체에 적용되는 공통 문서만 둡니다.

## 폴더 구조

| 경로 | 목적 |
|---|---|
| `features/` | 기능별 계획, 검증 계획, 테스트 보고서, 구현 보고서 |
| `guidelines/` | 개발 프로세스, 기능 완료 문서화, 버그 수정 문서화 가이드 |
| `error_reports/` | 이슈별 원인 분석, 수정 내용, 검증 결과 |
| `research/` | 기능 조사, 기술 조사, 사전 리서치 |
| 루트 | 프로젝트 구조, 전체 테스트 계획, 공개 전 체크리스트, 제출 보고서 |

## 주요 문서

### 프로젝트 공통

| 문서 | 목적 |
|---|---|
| `PROJECT_STRUCTURE.md` | 실제 저장소 폴더 구조, 앱/백엔드/네이티브 구성, 주요 데이터 흐름 설명 |
| `PRE_GIT_CHECKLIST.md` | GitHub 공개 전 제외 파일, 민감 정보, 검증 명령 체크리스트 |
| `test_plan_and_results.md` | 전체 테스트 계획, 자동/수동 검증 항목, E2E 테스트 결과 |

### 가이드라인

| 문서 | 목적 |
|---|---|
| `guidelines/development_process.md` | 기능 설계, 단계별 구현, 검증 계획, 테스트 보고서 작성을 정규화한 개발 프로세스 가이드 |
| `guidelines/feature_completion_documentation.md` | 기능 개발 완료 후 변경 기록, 테스트 결과, 구조 문서, README 갱신 기준 |
| `guidelines/bugfix_documentation.md` | 오류 수정 완료 후 재현 절차, 원인 분석, 수정 범위, 검증 결과 작성 기준 |

### 기능 문서

| 문서 | 목적 |
|---|---|
| `features/ai_running_similarity_analysis/plan.md` | Supabase embedding, PostGIS/수치 유사도 검색, 서버 LLM 비교 리포트 개발 계획 |
| `features/ai_running_similarity_analysis/verification_test_plan.md` | AI 러닝 유사도 분석 기능의 자동 테스트, 수동 QA, acceptance criteria |
| `features/ai_running_similarity_analysis/test_report_20260524.md` | AI 러닝 유사도 분석 기능의 2026-05-24 검증 결과 |
| `features/ai_running_similarity_analysis/implementation_report_20260524.md` | AI 러닝 유사도 분석 기능의 구현 범위, 변경 파일, 검증 결과 |
| `features/running_analysis/feature_update.md` | 분석 화면 추가, 하단 바 역할 변경, iOS release 서명 보정 변경 기록 |
| `features/design_md_application/plan.md` | design.md 적용 계획 |
| `features/design_md_application/feature_update.md` | design.md 적용 변경 기록 |

### 오류 리포트

| 문서 | 목적 |
|---|---|
| `error_reports/dashboard_resume_error_report.md` | 앱 백그라운드 복귀 후 메인 대시보드 데이터 미표시 이슈 |
| `error_reports/ios_locked_split_tts_issue_report.md` | iOS 화면 잠금 중 킬로미터당 페이스 TTS 미출력 이슈 |

### 리서치

| 문서 | 목적 |
|---|---|
| `research/ai_feature_research_report.md` | AI 기능 구현 전 기술/제품 조사 |

### 제출 보고서

| 문서 | 목적 |
|---|---|
| `졸작_중간보고서.docx` | 졸업작품 중간보고서 |
| `final_midterm_report_en.docx` | 중간보고서 영문 번역본 |
| `final_midterm_report_en.txt` | 영문 번역본 텍스트 확인용 파일 |

## 문서 작성 규칙

- 새 기능 문서는 `docs/features/<feature>/` 아래에 작성합니다.
- 기능 폴더 안에서는 `plan.md`, `verification_test_plan.md`, `test_report_YYYYMMDD.md`, `implementation_report_YYYYMMDD.md` 이름을 사용합니다.
- 임시 실행 계획은 `docs/features/<feature>/tmp_execution_plan.md`처럼 `tmp_` prefix를 붙이고 완료 후 삭제합니다.
- 새 영구 문서를 만들면 이 README의 해당 섹션에 링크를 추가합니다.
- 프로젝트 전체 규칙은 `guidelines/`에 둡니다.
- 이슈 수정 보고서는 `error_reports/`에 둡니다.

## 추천 읽기 순서

```text
README.md
-> docs/README.md
-> docs/PROJECT_STRUCTURE.md
-> docs/test_plan_and_results.md
-> docs/guidelines/development_process.md
-> docs/features/<feature>/plan.md
-> docs/features/<feature>/verification_test_plan.md
-> docs/features/<feature>/test_report_YYYYMMDD.md
-> docs/features/<feature>/implementation_report_YYYYMMDD.md
```

## 참고 사항

- 테스트 결과나 구현 범위가 바뀌면 루트 README와 이 문서를 함께 갱신합니다.
- 보고서와 코드가 다르게 표현하는 함수 이름이 일부 있습니다. 예를 들어 보고서의 `update_profile`은 실제 Edge Function 경로 기준 `update-profile`입니다.
