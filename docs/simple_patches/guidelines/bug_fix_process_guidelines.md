# 버그 픽스 프로세스 가이드라인

작성일: 2026-05-24

이 문서는 Runner.io 프로젝트에서 버그, 장애, 회귀, 실기기 이슈, API/DB 데이터 불일치, 빌드/배포 실패를 수정할 때 따르는 프로세스 규칙입니다.

## Goals

버그 픽스 프로세스의 목적은 다음과 같습니다.

- 증상, 재현 조건, 원인을 분리해 수정 방향을 명확히 합니다.
- 재현 방지 테스트 또는 검증 절차를 남깁니다.
- 수정 범위를 최소화하면서 주변 기능 회귀를 확인합니다.
- 실기기, 백그라운드, 권한, 원격 DB처럼 자동 테스트가 어려운 조건을 문서에 남깁니다.
- 같은 문제가 다시 발생했을 때 추적 가능한 기록을 `docs/bug_fixes/`에 보관합니다.

## When To Use

다음 중 하나에 해당하면 이 프로세스를 사용합니다.

- 사용자가 관찰한 오류나 비정상 동작을 수정할 때
- 기존 테스트, 빌드, 배포, 정적 분석 실패를 수정할 때
- 앱 생명주기, 권한, 네트워크, 백그라운드, TTS, 지도, 위치 같은 환경 의존 문제를 다룰 때
- Supabase Edge Function, DB schema, RPC, RLS, 원격 데이터 불일치를 수정할 때
- 회귀 가능성이 있어 재현 절차와 검증 결과가 필요한 변경일 때

다음에 해당하면 다른 프로세스로 전환합니다.

| 상황 | 사용할 프로세스 |
|---|---|
| 새 사용자 기능 또는 기능 확장까지 포함됨 | `docs/simple_patches/guidelines/development_process.md` |
| 오류가 아니라 문서/경로/설정 정리만 수행함 | `docs/simple_patches/guidelines/patch_process_guidelines.md` |
| 원인 분석 결과 제품 동작을 새로 설계해야 함 | 기능 개발 프로세스로 승격 |

## Artifact Rules

### Permanent Documents

주요 버그 수정은 영구 리포트를 작성합니다.

| 문서 유형 | 파일명 예시 | 목적 |
|---|---|---|
| Bug fix report | `docs/bug_fixes/<issue_name>_error_report.md` | 증상, 재현, 원인, 수정, 검증, 재발 방지 |
| Issue report | `docs/bug_fixes/<issue_name>_issue_report.md` | 원인 미확정 이슈의 조사 및 방어 조치 |
| Test plan update | `docs/simple_patches/test_plan_and_results.md` | 새 테스트 또는 넓어진 검증 범위 기록 |
| Project structure update | `docs/simple_patches/PROJECT_STRUCTURE.md` | 구조, 데이터 흐름, 서비스 책임 변경 기록 |

새 영구 리포트를 추가하면 `docs/README.md`에 링크를 추가합니다.

### Temporary Documents

조사가 길어지는 경우에만 임시 문서를 사용합니다.

```text
docs/bug_fixes/tmp_<issue_name>_investigation.md
docs/bug_fixes/tmp_<issue_name>_reproduction_notes.md
```

임시 문서는 최종 리포트에 결론을 반영한 뒤 삭제합니다.

## Required Process

### Stage 1. Intake And Triage

목표: 이슈의 실제 증상과 우선순위를 파악합니다.

작업:

1. 사용자가 본 증상, 발생 조건, 기대 동작을 분리합니다.
2. 영향 범위를 사용자 화면, 데이터/API, 저장/동기화, 네이티브/권한, 테스트/빌드로 나눕니다.
3. 심각도를 판단합니다.
4. 현재 `git status --short`를 확인하고 기존 사용자 변경을 구분합니다.

완료 기준:

- 무엇이 깨졌는지 한 문단으로 설명할 수 있습니다.
- 재현 또는 확인에 필요한 환경이 정리됩니다.

### Stage 2. Reproduction

목표: 수정 전 상태에서 문제를 확인하거나, 재현 불가라면 그 사실을 기록합니다.

작업:

1. 재현 절차를 최소 단계로 정리합니다.
2. 로그, 에러 메시지, 화면 상태, API 응답을 확인합니다.
3. 가능하면 실패하는 테스트나 명령을 찾습니다.
4. 재현이 어려우면 가능한 조건과 불가능한 조건을 구분합니다.

완료 기준:

- 재현 가능한 경우: 같은 절차로 다시 실패를 볼 수 있습니다.
- 재현 불가인 경우: 확인한 범위와 남은 가설이 분명합니다.

규칙:

- 재현 없이 바로 수정하지 않습니다. 단, 명백한 컴파일 오류처럼 실패 원인이 고정된 경우에는 명령 결과를 재현 근거로 사용합니다.
- 실기기 이슈는 기기, OS, 앱 상태, 권한, 백그라운드 조건을 기록합니다.

### Stage 3. Impact And Root Cause Analysis

목표: 증상과 원인을 분리하고, 수정할 지점을 좁힙니다.

작업:

1. 관련 코드와 데이터 흐름을 추적합니다.
2. 원인 후보를 2개 이상 고려하되 확인된 사실과 추측을 구분합니다.
3. 기존 테스트가 왜 잡지 못했는지 확인합니다.
4. 수정 범위와 회귀 위험을 판단합니다.

분석 항목:

- 화면 state와 lifecycle
- service/API 호출 경로
- Supabase Edge Function, migration, RPC, RLS
- Android/iOS 네이티브 bridge와 권한
- 캐시, 비동기 호출, race condition
- 테스트 expectation 노후화

완료 기준:

- 최종 원인 또는 가장 가능성 높은 원인이 정리됩니다.
- 수정 대상 파일과 검증 후보가 정해집니다.

### Stage 4. Fix Plan

목표: 작은 수정 단위와 검증 방법을 정합니다.

필수 내용:

- Root cause summary
- Files to change
- Safety checks
- Regression areas
- Targeted tests
- Manual QA need
- Documentation updates

문서화:

- 간단한 버그는 작업 중 메모로 충분합니다.
- 실기기, 원격 DB, 배포, 데이터 보정이 포함되면 `docs/bug_fixes/<issue_name>_error_report.md` 초안을 먼저 만들 수 있습니다.

완료 기준:

- 수정 범위가 원인과 직접 연결됩니다.
- 변경 후 어떤 명령이나 절차로 고쳤다고 말할지 정해집니다.

### Stage 5. Minimal Fix Implementation

목표: 원인을 해결하는 데 필요한 만큼만 수정합니다.

규칙:

- 버그 수정과 무관한 리팩터를 섞지 않습니다.
- 기존 public API나 DB 계약을 바꿀 때는 호출부와 테스트를 함께 확인합니다.
- 방어 코드만 추가할 때도 왜 필요한지 리포트에 남깁니다.
- 회귀 테스트가 가능한 원인은 테스트를 먼저 추가하거나 수정 직후 추가합니다.
- 사용자 변경으로 보이는 dirty worktree는 되돌리지 않습니다.

완료 기준:

- 재현 원인을 직접 막는 코드 변경이 들어갔습니다.
- 주변 동작 변경이 있으면 의도와 영향이 설명 가능합니다.

### Stage 6. Verification Run

목표: 재현 케이스가 사라졌고 주변 기능이 유지되는지 확인합니다.

기본 명령:

```bash
flutter analyze
flutter test
```

변경 범위별 검증:

| 변경 범위 | 권장 검증 |
|---|---|
| Dart service/model | 관련 unit test, parsing test |
| Flutter 화면 state | 관련 widget test, page test |
| 앱 생명주기/백그라운드 | 실기기 또는 시뮬레이터 수동 QA |
| 위치/TTS/지도/권한 | 실기기 수동 QA 필수 여부 기록 |
| Supabase Edge Function | `deno fmt`, `deno check`, 원격/로컬 function 호출 |
| DB migration/RPC/RLS | migration apply, SQL/RPC 직접 검증, E2E test |
| 빌드/배포 실패 | 실패했던 build/deploy 명령 재실행 |

완료 기준:

- 원래 재현 절차가 더 이상 실패하지 않습니다.
- 관련 자동 테스트가 통과하거나 실패 이유가 분류됩니다.
- 자동 테스트로 대체할 수 없는 수동 확인 항목이 기록됩니다.

### Stage 7. Regression Check

목표: 수정 주변의 정상 흐름이 유지되는지 확인합니다.

작업:

1. 같은 화면의 정상 상태를 확인합니다.
2. 같은 service/API의 성공, 빈 상태, 실패 상태를 확인합니다.
3. 기존 테스트 중 관련성이 높은 테스트를 실행합니다.
4. 변경 범위가 넓으면 `flutter test` 전체 실행을 검토합니다.

완료 기준:

- 직접 수정한 영역의 정상 흐름이 유지됩니다.
- 회귀 위험이 남으면 리포트의 남은 확인 사항에 기록됩니다.

### Stage 8. Bug Fix Report

목표: 재현, 원인, 수정, 검증, 재발 방지를 영구 기록으로 남깁니다.

파일명:

```text
docs/bug_fixes/<issue_name>_error_report.md
```

필수 내용:

- Issue summary
- Reproduction steps
- Expected behavior
- Actual behavior
- Impact scope
- Related code and data flow
- Root cause analysis
- Final root cause
- Fix details
- Verification results
- Remaining checks
- Prevention
- Conclusion

완료 기준:

- 다른 사람이 같은 리포트로 문제의 맥락과 수정 이유를 이해할 수 있습니다.
- 실행한 테스트와 실행하지 않은 테스트가 구분되어 있습니다.
- `docs/README.md`에 링크가 추가됩니다.

### Stage 9. Documentation And Cleanup

목표: 버그 수정 후 문서와 임시 산출물을 정리합니다.

작업:

1. `docs/README.md`에 새 리포트를 추가합니다.
2. 새 테스트나 검증 범위가 있으면 `docs/simple_patches/test_plan_and_results.md`를 갱신합니다.
3. 구조나 데이터 흐름이 바뀌면 `docs/simple_patches/PROJECT_STRUCTURE.md`를 갱신합니다.
4. 임시 조사 문서를 삭제하거나 유지 이유를 기록합니다.
5. `git status --short`로 변경 범위를 확인합니다.

완료 기준:

- 버그 리포트와 실제 수정 내용이 모순되지 않습니다.
- 오래된 임시 문서가 남지 않습니다.
- 최종 응답에 원인, 수정, 검증, 남은 확인 사항이 포함됩니다.

## Testing Rules

버그 픽스에서는 "재현 방지"가 핵심입니다.

필수:

- 재현 케이스가 수정 후 사라졌는지 확인
- 같은 영역의 정상 케이스 유지 확인
- 관련 정적 분석 또는 테스트 실행
- 자동화가 어려운 경우 수동 QA 절차와 미수행 사유 기록

가능하면 추가:

- 원인 로직 단위 테스트
- 화면 상태 widget test
- API/DB 통합 테스트
- 실기기 조건 수동 테스트

실패 분류:

| 분류 | 처리 |
|---|---|
| 실제 회귀 | 수정 후 같은 테스트 재실행 |
| 테스트 기대값 노후화 | 제품 동작이 맞는지 확인 후 테스트 갱신 |
| 환경 문제 | 로그와 재시도 여부 기록 |
| 범위 밖 기존 실패 | 최종 응답과 리포트에 분리 기록 |

## Documentation Rules

- 주요 버그 수정은 `docs/bug_fixes/`에 리포트를 남깁니다.
- 새 리포트를 만들면 `docs/README.md`에 링크를 추가합니다.
- 테스트 범위가 바뀌면 `docs/simple_patches/test_plan_and_results.md`를 갱신합니다.
- 구조나 데이터 흐름이 바뀌면 `docs/simple_patches/PROJECT_STRUCTURE.md`를 갱신합니다.
- 운영 DB 데이터 보정이 포함되면 보정 범위, 기준, 검증 방법을 별도 섹션으로 남깁니다.
- 민감 정보, access token, service role key, 개인 계정 정보는 문서에 쓰지 않습니다.

## Naming Conventions

| 목적 | 파일명 |
|---|---|
| 오류 수정 보고서 | `docs/bug_fixes/<issue_name>_error_report.md` |
| 이슈 분석 보고서 | `docs/bug_fixes/<issue_name>_issue_report.md` |
| 임시 조사 노트 | `docs/bug_fixes/tmp_<issue_name>_investigation.md` |
| 임시 재현 노트 | `docs/bug_fixes/tmp_<issue_name>_reproduction_notes.md` |

`<issue_name>`은 snake_case를 사용합니다.

## Final Response Rules

버그 픽스 완료 응답에는 다음을 포함합니다.

- 핵심 원인
- 수정 요약
- 주요 파일 링크
- 실행한 테스트와 결과
- 실기기/운영 데이터/수동 QA 등 남은 확인 사항

예시:

```text
오류 수정 완료했습니다.

원인:
- 앱 복귀 시 캐시가 비어 있는 상태에서 대시보드 값을 덮어썼습니다.

수정:
- resumed 흐름에서 기존 정상 값을 유지하고 force reload 실패 시 fallback하도록 보정했습니다.

검증:
- flutter analyze: passed
- 관련 widget test: passed

남은 확인:
- 실제 iPhone 백그라운드 복귀 수동 확인이 필요합니다.
```
