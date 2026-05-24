# Development Process Guidelines

이 문서는 runner_flutter에서 기능을 설계, 구현, 검증, 문서화할 때 따르는 개발 프로세스 규칙입니다.

기준 사례(원본 MONEYFY 프로젝트 작업 흐름):

- `docs/investment_performance_report_plan.md`
- `docs/new_features/investment_performance/tmp_development_report.md`
- `docs/investment_performance_verification_test_plan.md`
- `docs/investment_performance_test_report_20260524.md`

## Goals

이 프로세스의 목적은 다음과 같습니다.

- 기능 개발 전에 목적, 범위, 위험을 명확히 합니다.
- 구현 중 임시 계획을 사용하되 최종 산출물은 정리합니다.
- 계산, 데이터, UI 변경을 테스트로 고정합니다.
- 검증 결과를 문서로 남겨 후속 작업자가 같은 맥락을 이어받을 수 있게 합니다.
- 릴리스 전 자동 테스트와 수동 QA의 경계를 분명히 합니다.

## When To Use

다음 중 하나에 해당하면 이 프로세스를 사용합니다.

- 새 사용자 기능을 추가할 때
- 기존 핵심 화면을 제품급으로 고도화할 때
- DB, 원장, sync, snapshot, market data처럼 계산 신뢰도가 중요한 영역을 바꿀 때
- 여러 파일과 테스트를 함께 수정해야 할 때
- 후속 QA나 릴리스 판단이 필요한 변경일 때

단순 문구 수정, 작은 스타일 수정, 명확한 버그 1건 수정에는 전체 프로세스를 생략할 수 있습니다. 다만 테스트와 변경 요약은 남깁니다.

## Artifact Rules

### Permanent Documents

영구 문서는 기능의 제품 방향, 검증 기준, 최종 결과를 남길 때 사용합니다.

| 문서 유형 | 파일명 예시 | 목적 |
| --- | --- | --- |
| Feature plan | `docs/new_features/<feature>/plan.md` | 목표, 범위, UX, 데이터/API, 단계별 개발 계획 |
| Verification test plan | `docs/new_features/<feature>/verification_test_plan.md` | 자동 테스트, 수동 QA, acceptance criteria |
| Test report | `docs/new_features/<feature>/test_report_YYYYMMDD.md` | 실제 실행한 테스트와 결과 |
| Implementation report | `docs/new_features/<feature>/implementation_report_YYYYMMDD.md` | 배포/운영/데이터 보정까지 포함한 최종 보고 |

영구 문서를 추가하면 `docs/README.md`에 링크를 추가합니다.

### Temporary Documents

임시 문서는 작업 중 판단과 실행 순서를 관리하기 위한 문서입니다.

| 문서 유형 | 파일명 예시 | 삭제 시점 |
| --- | --- | --- |
| Execution plan | `docs/new_features/<feature>/tmp_execution_plan.md` | 구현 완료 후 |
| Development report | `docs/new_features/<feature>/tmp_development_report.md` | 최종 implementation report로 승격하거나 릴리스 후 정리 |
| Investigation notes | `docs/new_features/<feature>/tmp_investigation.md` | 결론이 영구 문서에 반영된 후 |

임시 문서는 `tmp_` prefix를 붙입니다. `docs/README.md`에는 연결하지 않습니다.

## Required Process

### Stage 1. Discovery

목표: 현재 코드와 문서가 말하는 제품/기술 맥락을 파악합니다.

작업:

1. `README.md`, `docs/README.md`, 관련 feature 문서를 확인합니다.
2. 관련 화면, service, DB, test 파일을 찾습니다.
3. 기존 테스트와 현재 git 상태를 확인합니다.
4. 변경 전 baseline test가 필요한지 판단합니다.

완료 기준:

- 기존 구현과 변경 지점이 파악됩니다.
- 영향을 받을 파일과 테스트 후보가 정리됩니다.

규칙:

- 검색은 우선 `rg` 또는 `rg --files`를 사용합니다.
- 이미 있는 패턴과 설계를 우선합니다.
- 사용자 변경으로 보이는 dirty worktree는 되돌리지 않습니다.

### Stage 2. Feature Plan

목표: 무엇을 만들지 제품과 기술 양쪽에서 합의 가능한 수준으로 씁니다.

필수 내용:

- Product goal
- Current baseline
- Success criteria
- Metric/data definitions
- Proposed UX
- Data/API changes
- Development phases
- MVP scope
- Test plan
- Risks and decisions
- Open questions

파일명:

```text
docs/new_features/<feature>/plan.md
```

완료 기준:

- 구현 범위와 제외 범위가 분명합니다.
- 계산식이나 데이터 기준이 문서에 남습니다.
- `docs/README.md`에 링크가 추가됩니다.

### Stage 3. Feasibility Feedback

목표: 계획을 비판적으로 검토하고, 바로 할 일과 나중에 할 일을 나눕니다.

검토 항목:

- 기존 구조와의 궁합
- 구현 난이도
- 사용자 체감 효과
- 데이터 정확도 리스크
- UI 복잡도
- 테스트 가능성
- 후속 기능과의 연결성

문서화 위치:

- feature plan 하단에 `Feasibility And Feedback` 섹션을 추가합니다.

완료 기준:

- 장점과 단점이 모두 기록됩니다.
- MVP에 넣지 않을 항목이 명시됩니다.
- 첫 개발 batch가 정해집니다.

### Stage 4. Temporary Execution Plan

목표: 구현을 실제 작업 순서로 쪼갭니다.

파일명:

```text
docs/new_features/<feature>/tmp_execution_plan.md
```

필수 내용:

- Execution scope
- Development principles
- Stage별 작업 목록
- Stage별 완료 기준
- Verification command
- Cleanup rule
- First/second/third implementation batch

완료 기준:

- 구현 중 체크리스트처럼 사용할 수 있습니다.
- 개발 완료 후 삭제할 문서임이 명시됩니다.

규칙:

- 임시 실행 계획서는 `docs/README.md`에 연결하지 않습니다.
- 구현이 끝나면 삭제합니다.

### Stage 5. Staged Implementation

목표: 작은 단위로 구현하고 각 단계마다 검증합니다.

권장 순서:

1. Baseline check
2. Calculation/data contract tests
3. Data/API changes
4. Screen state/data loading changes
5. UI changes
6. Drill-down or extension API
7. Targeted tests
8. Full verification
9. Cleanup

규칙:

- 계산 로직은 UI보다 먼저 테스트로 고정합니다.
- 기존 호출부와 호환되는 API 변경을 우선합니다.
- DB schema 변경이 필요하면 migration, sync, generated file 영향을 함께 봅니다.
- UI는 기존 design system과 component를 우선 사용합니다.
- 큰 리팩터는 기능 목표와 직접 관련된 경우에만 수행합니다.

완료 기준:

- 각 stage가 독립적으로 설명 가능합니다.
- 최소 targeted test가 통과합니다.
- 전체 검증으로 넘어갈 수 있습니다.

### Stage 6. Temporary Development Report

목표: 구현 결과를 검증 계획 수립용으로 요약합니다.

파일명:

```text
docs/new_features/<feature>/tmp_development_report.md
```

필수 내용:

- Summary
- Implemented stages
- Changed files
- Data layer changes
- UI changes
- Tests added or updated
- Verification results
- Known limitations
- Risk notes
- Follow-up items

완료 기준:

- 테스트 계획을 만들기에 충분한 변경 정보가 있습니다.
- 실제 구현과 문서 내용이 모순되지 않습니다.

규칙:

- 임시 개발 리포트는 `docs/README.md`에 연결하지 않습니다.
- 릴리스 문서가 필요하면 최종 implementation report로 승격하거나 별도 영구 문서를 작성합니다.

### Stage 7. Verification Test Plan

목표: 변경을 어떻게 검증할지 자동 테스트와 수동 QA로 나눕니다.

파일명:

```text
docs/new_features/<feature>/verification_test_plan.md
```

필수 내용:

- Scope
- Quality goals
- Automated test plan
- Manual QA plan
- Responsive checklist
- Regression test commands
- Acceptance criteria
- Release risk matrix
- Future test expansion

완료 기준:

- 어떤 테스트를 실행해야 하는지 명령어로 알 수 있습니다.
- 자동 테스트로 커버되지 않는 수동 확인 항목이 분명합니다.
- `docs/README.md`에 링크가 추가됩니다.

### Stage 8. Verification Run

목표: 테스트 계획서에 맞게 실제 검증을 수행합니다.

기본 명령:

```bash
flutter analyze
flutter test
```

집중 테스트 예시:

```bash
flutter test test/transaction_flow_test.dart
flutter test test/page_walkthrough_test.dart
flutter test test/ui_component_smoke_test.dart
```

규칙:

- 실패가 나오면 원인을 분류합니다.
  - 기능 회귀
  - 테스트 기대값 노후화
  - 환경 문제
  - 범위 밖 기존 실패
- 기능 회귀는 수정 후 같은 테스트를 다시 실행합니다.
- 테스트 기대값 노후화는 제품 문구/동작 변경이 타당한지 확인한 뒤 수정합니다.
- 모든 자동 테스트 결과는 보고서에 남깁니다.

완료 기준:

- 정적 분석과 관련 테스트가 통과하거나, 실패 이유가 문서화됩니다.
- 미수행 수동 QA 항목이 별도로 남습니다.

### Stage 9. Test Report

목표: 실제 검증 결과를 영구 문서로 남깁니다.

파일명:

```text
docs/new_features/<feature>/test_report_YYYYMMDD.md
```

필수 내용:

- Summary
- Test environment
- Commands run
- Command results
- Verification against plan
- Manual QA status
- Responsive QA status
- Acceptance criteria result
- Risk assessment after testing
- Follow-up recommendations
- Final result

완료 기준:

- 실행한 명령과 결과가 명확합니다.
- 자동 검증과 미수행 수동 QA가 분리되어 있습니다.
- `docs/README.md`에 링크가 추가됩니다.

### Stage 10. Cleanup

목표: 임시 산출물과 영구 산출물을 정리합니다.

작업:

1. 임시 실행 계획서를 삭제합니다.
2. 임시 개발 리포트를 유지할지, 최종 보고서로 승격할지 결정합니다.
3. `docs/README.md` 링크가 영구 문서만 가리키는지 확인합니다.
4. 테스트 결과와 known limitations가 최신인지 확인합니다.
5. `git status --short`로 변경 파일을 확인합니다.

완료 기준:

- 임시 문서의 처리 방침이 분명합니다.
- 영구 문서와 구현이 모순되지 않습니다.
- 최종 응답에 변경 내용과 검증 결과가 포함됩니다.

## Testing Rules

### Required Before Final Response

기능 구현이 있었으면 최소한 다음을 실행합니다.

```bash
flutter analyze
```

변경 범위에 따라 다음을 추가합니다.

| 변경 범위 | 필수 테스트 |
| --- | --- |
| 거래/원장/DB 계산 | `flutter test test/transaction_flow_test.dart` |
| 화면 진입/내비게이션 | `flutter test test/page_walkthrough_test.dart` |
| 공통 UI component | `flutter test test/ui_component_smoke_test.dart` |
| 서비스 parsing | 관련 service test |
| 넓은 영향 범위 | `flutter test` |

### Test Design Rules

- 계산 규칙은 작은 fixture로 직접 검증합니다.
- 날짜, 통화, 삭제 row, 숨김 row, source 제외 조건은 회귀 테스트로 고정합니다.
- UI 문구가 제품적으로 바뀌면 walkthrough 기대값을 함께 갱신합니다.
- 단순 smoke test와 계산 정확도 test를 구분합니다.
- 자동 테스트로 확인하지 못한 항목은 test report의 manual QA status에 남깁니다.

## Documentation Rules

- 새 영구 문서를 만들면 `docs/README.md`에 링크를 추가합니다.
- 임시 문서는 `tmp_` prefix를 사용하고 `docs/README.md`에 링크하지 않습니다.
- 실행 가능한 절차는 명령어 블록으로 남깁니다.
- 키, 토큰, 개인 계정 정보는 문서에 쓰지 않습니다.
- 오래된 설계는 삭제보다 archived note 또는 후속 문서에서 맥락을 남깁니다.
- 문서에는 실제로 실행한 테스트와 실행하지 않은 테스트를 구분해서 씁니다.

## Naming Conventions

| 목적 | 파일명 |
| --- | --- |
| 기능 계획 | `docs/new_features/<feature>/plan.md` |
| 임시 실행 계획 | `docs/new_features/<feature>/tmp_execution_plan.md` |
| 임시 개발 리포트 | `docs/new_features/<feature>/tmp_development_report.md` |
| 검증/테스트 계획 | `docs/new_features/<feature>/verification_test_plan.md` |
| 테스트 보고서 | `docs/new_features/<feature>/test_report_YYYYMMDD.md` |
| 구현 보고서 | `docs/new_features/<feature>/implementation_report_YYYYMMDD.md` |

`<feature>`는 snake_case를 사용합니다.

## Final Response Rules

기능 개발 완료 응답에는 다음을 포함합니다.

- 변경 요약
- 주요 파일 링크
- 실행한 테스트와 결과
- 미수행 검증이나 남은 위험
- 삭제한 임시 문서가 있으면 그 사실

예시:

```text
구현 완료했습니다.

- 기간 필터 API 추가
- 투자성과 화면 stateful 전환
- 현금흐름 분리 표시

검증:
- flutter analyze: passed
- flutter test: passed, 80 tests

수동 반응형 QA는 아직 수행하지 않았습니다.
```

