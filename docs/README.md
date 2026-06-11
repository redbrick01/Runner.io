# `docs/`

## 역할

`docs/`는 Runner.io 졸업작품의 개발 기록을 변경 성격별로 보관하는 문서 폴더입니다.

문서는 아래 3가지 기준으로 분리합니다.

| 경로 | 분류 기준 |
|---|---|
| `new_features/` | 새 기능 개발, 기존 핵심 기능의 큰 확장, 기능별 계획/구현/검증/리서치 |
| `simple_patches/` | 문서 정리, 체크리스트, 프로젝트 구조, 제출 보고서, 가이드라인, 작은 정비 기록 |
| `bug_fixes/` | 오류 재현, 원인 분석, 수정 범위, 검증 결과, 재발 방지 기록 |

`docs/` 루트에는 이 분류 인덱스인 `README.md`만 둡니다.

## 분류 규칙

- 새 사용자 기능을 만들거나 기능 단위 검증이 필요한 변경은 `docs/new_features/<feature>/`에 저장합니다.
- 기능 구현 전 조사 문서는 기능 개발의 준비 산출물이므로 `docs/new_features/research/`에 저장합니다.
- 단순 문구/문서/구조/체크리스트 정리처럼 기능 단위가 아닌 변경은 `docs/simple_patches/`에 저장합니다.
- 개발 프로세스와 문서화 규칙은 작업 가이드 성격이므로 `docs/simple_patches/guidelines/`에 저장합니다.
- 버그, 장애, 회귀, 실기기 이슈, API/DB 데이터 불일치, 빌드/배포 실패는 `docs/bug_fixes/`에 저장합니다.

## 주요 문서

### 새로운 기능 개발

| 문서 | 목적 |
|---|---|
| `new_features/ai_running_similarity_analysis/plan.md` | Supabase embedding, PostGIS/수치 유사도 검색, 서버 LLM 비교 리포트 개발 계획 |
| `new_features/ai_running_similarity_analysis/live_voice_coaching_plan.md` | 1km 페이스 알림에 과거 유사 구간 벡터 검색 기반 AI 음성 코칭을 결합하는 확장 계획 |
| `new_features/ai_running_similarity_analysis/live_voice_coaching_implementation_report_20260528.md` | AI 유사 구간 기반 실시간 음성 코칭 MVP 구현 범위, 변경 파일, 검증 결과 |
| `new_features/ai_running_similarity_analysis/verification_test_plan.md` | AI 러닝 유사도 분석 기능의 자동 테스트, 수동 QA, acceptance criteria |
| `new_features/ai_running_similarity_analysis/test_report_20260524.md` | AI 러닝 유사도 분석 기능의 2026-05-24 검증 결과 |
| `new_features/ai_running_similarity_analysis/implementation_report_20260524.md` | AI 러닝 유사도 분석 기능의 구현 범위, 변경 파일, 검증 결과 |
| `new_features/running_analysis/feature_update.md` | 분석 화면 추가, 하단 바 역할 변경, iOS release 서명 보정 변경 기록 |
| `new_features/design_md_application/plan.md` | design.md 적용 계획 |
| `new_features/design_md_application/feature_update.md` | design.md 적용 변경 기록 |
| `new_features/research/ai_feature_research_report.md` | AI 기능 구현 전 기술/제품 조사 |

### 단순 패치

| 문서 | 목적 |
|---|---|
| `simple_patches/PROJECT_STRUCTURE.md` | 실제 저장소 폴더 구조, 앱/백엔드/네이티브 구성, 주요 데이터 흐름 설명 |
| `simple_patches/PRE_GIT_CHECKLIST.md` | GitHub 공개 전 제외 파일, 민감 정보, 검증 명령 체크리스트 |
| `simple_patches/test_plan_and_results.md` | 전체 테스트 계획, 자동/수동 검증 항목, E2E 테스트 결과 |
| `simple_patches/guidelines/development_process.md` | 기능 설계, 단계별 구현, 검증 계획, 테스트 보고서 작성 프로세스 가이드 |
| `simple_patches/guidelines/patch_process_guidelines.md` | 단순 패치의 범위 판단, 최소 변경, 검증, 문서 갱신 프로세스 가이드 |
| `simple_patches/guidelines/bug_fix_process_guidelines.md` | 버그 픽스의 재현, 원인 분석, 수정, 회귀 검증, 리포트 작성 프로세스 가이드 |
| `simple_patches/guidelines/feature_completion_documentation.md` | 기능 개발 완료 후 변경 기록, 테스트 결과, 구조 문서, README 갱신 기준 |
| `simple_patches/guidelines/bugfix_documentation.md` | 오류 수정 완료 후 재현 절차, 원인 분석, 수정 범위, 검증 결과 작성 기준 |
| `simple_patches/졸작_중간보고서.docx` | 졸업작품 중간보고서 |
| `simple_patches/final_midterm_report_en.docx` | 중간보고서 영문 번역본 |
| `simple_patches/final_midterm_report_en.txt` | 영문 번역본 텍스트 확인용 파일 |

### 버그 픽스

| 문서 | 목적 |
|---|---|
| `bug_fixes/dashboard_resume_error_report.md` | 앱 백그라운드 복귀 후 메인 대시보드 데이터 미표시 이슈 |
| `bug_fixes/ios_locked_split_tts_issue_report.md` | iOS 화면 잠금 중 킬로미터당 페이스 TTS 미출력 이슈 |
| `bug_fixes/supabase_security_advisor_error_report.md` | Supabase DB lint/advisor 오류와 RLS/RPC 권한 수정 이슈 |

## 문서 작성 규칙

- 새 기능 문서는 `docs/new_features/<feature>/` 아래에 작성합니다.
- 기능 폴더 안에서는 `plan.md`, `verification_test_plan.md`, `test_report_YYYYMMDD.md`, `implementation_report_YYYYMMDD.md` 이름을 사용합니다.
- 임시 실행 계획은 `docs/new_features/<feature>/tmp_execution_plan.md`처럼 `tmp_` prefix를 붙이고 완료 후 삭제합니다.
- 단순 패치 문서는 `docs/simple_patches/` 또는 성격에 맞는 하위 폴더에 저장합니다.
- 이슈 수정 보고서는 `docs/bug_fixes/`에 저장합니다.
- 새 영구 문서를 만들면 이 README의 해당 섹션에 링크를 추가합니다.

## 추천 읽기 순서

```text
README.md
-> docs/README.md
-> docs/simple_patches/PROJECT_STRUCTURE.md
-> docs/simple_patches/test_plan_and_results.md
-> docs/simple_patches/guidelines/development_process.md
-> docs/simple_patches/guidelines/patch_process_guidelines.md
-> docs/simple_patches/guidelines/bug_fix_process_guidelines.md
-> docs/new_features/<feature>/plan.md
-> docs/new_features/<feature>/verification_test_plan.md
-> docs/new_features/<feature>/test_report_YYYYMMDD.md
-> docs/new_features/<feature>/implementation_report_YYYYMMDD.md
```

## 참고 사항

- 테스트 결과나 구현 범위가 바뀌면 루트 README와 이 문서를 함께 갱신합니다.
- 보고서와 코드가 다르게 표현하는 함수 이름이 일부 있습니다. 예를 들어 보고서의 `update_profile`은 실제 Edge Function 경로 기준 `update-profile`입니다.
