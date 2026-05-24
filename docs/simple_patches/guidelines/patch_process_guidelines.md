# 단순 패치 프로세스 가이드라인

작성일: 2026-05-24

이 문서는 Runner.io 프로젝트에서 새 기능 개발이나 버그 픽스가 아닌 작은 정비 작업을 수행할 때 따르는 프로세스 규칙입니다.

## Goals

단순 패치 프로세스의 목적은 다음과 같습니다.

- 작은 변경을 빠르게 처리하되 범위가 커지는 순간을 놓치지 않습니다.
- 문서, 설정, 스타일, 문구, 구조 정리 변경의 영향을 명확히 확인합니다.
- 불필요한 기능 개발 산출물을 만들지 않고 필요한 검증만 수행합니다.
- 패치 후 경로, README, 체크리스트가 오래된 상태로 남지 않게 합니다.

## When To Use

다음 중 하나에 해당하면 이 프로세스를 사용합니다.

- 문서 경로, README, 체크리스트, 프로젝트 구조 문서를 정리할 때
- 작은 UI 문구, 오타, 라벨, 색상 토큰, spacing 같은 저위험 변경을 할 때
- 앱 동작을 바꾸지 않는 설정, 정리, 포맷, 파일 이동을 할 때
- 테스트 추가 없이 기존 테스트 실행만으로 충분한 변경일 때
- 새 사용자 기능이나 명확한 오류 수정으로 분류하기 어려운 유지보수 작업일 때

다음에 해당하면 다른 프로세스로 전환합니다.

| 상황 | 사용할 프로세스 |
|---|---|
| 새 화면, 새 서비스, 새 DB/API, 새 사용자 가치가 생김 | `docs/simple_patches/guidelines/development_process.md` |
| 재현 가능한 오류, 장애, 회귀, 빌드 실패를 수정함 | `docs/simple_patches/guidelines/bug_fix_process_guidelines.md` |
| 실기기, 운영 데이터, 원격 배포 검증이 필요함 | 기능 개발 또는 버그 픽스 프로세스로 승격 |

## Artifact Rules

### Permanent Documents

단순 패치는 별도 문서를 항상 만들지 않습니다. 아래 기준에 해당할 때만 영구 문서를 작성하거나 갱신합니다.

| 문서 유형 | 파일명 예시 | 목적 |
|---|---|---|
| Patch note | `docs/simple_patches/<patch_name>_patch_note_YYYYMMDD.md` | 변경 범위가 넓은 정리 작업의 이유, 변경 파일, 검증 결과 |
| Project structure update | `docs/simple_patches/PROJECT_STRUCTURE.md` | 폴더, 화면, 서비스, 데이터 흐름 설명 갱신 |
| Checklist update | `docs/simple_patches/PRE_GIT_CHECKLIST.md` | 공개 전 제외 파일, 민감 정보, 검증 명령 갱신 |
| Test plan update | `docs/simple_patches/test_plan_and_results.md` | 테스트 범위나 결과 기록 갱신 |
| Guideline update | `docs/simple_patches/guidelines/*.md` | 개발/패치/버그 픽스/문서화 규칙 갱신 |

새 영구 문서를 추가하면 `docs/README.md`에 링크를 추가합니다.

### Temporary Documents

단순 패치에서는 임시 문서를 기본적으로 만들지 않습니다.

범위가 커져 작업 순서가 필요하면 다음 이름을 사용하고 완료 후 삭제합니다.

```text
docs/simple_patches/tmp_<patch_name>_execution_plan.md
```

## Required Process

### Stage 1. Scope Check

목표: 이 작업이 정말 단순 패치인지 확인합니다.

작업:

1. 사용자 요청과 영향 범위를 한 문장으로 정리합니다.
2. 변경 대상 파일과 관련 문서를 찾습니다.
3. 새 기능 개발 또는 버그 픽스 프로세스로 승격해야 하는지 판단합니다.
4. 현재 `git status --short`를 확인하고 기존 사용자 변경을 구분합니다.

완료 기준:

- 패치 목적과 제외 범위가 분명합니다.
- 영향을 받을 파일 후보가 파악됩니다.
- 다른 프로세스로 전환할 필요가 없는지 확인됩니다.

### Stage 2. Baseline Review

목표: 기존 구조와 참조를 확인해 작은 변경이 끊긴 링크나 문서 불일치를 만들지 않게 합니다.

작업:

1. `rg` 또는 `rg --files`로 관련 경로, 이름, 문구를 검색합니다.
2. README, docs README, 관련 가이드 문서를 확인합니다.
3. 코드 변경이면 관련 화면, service, test 파일을 확인합니다.
4. 변경 전 테스트가 필요한지 판단합니다.

완료 기준:

- 변경해야 할 위치와 함께 갱신해야 할 참조가 정리됩니다.
- 삭제/이동/이름 변경 시 남을 수 있는 오래된 참조가 식별됩니다.

### Stage 3. Minimal Patch Plan

목표: 작은 작업이라도 실행 순서를 짧게 정합니다.

필수 내용:

- Patch scope
- Files to change
- References to update
- Verification command or inspection method
- Documentation update need

문서화:

- 보통 별도 파일로 저장하지 않고 작업 중 메모로 충분합니다.
- 파일 이동, 문서 재분류, 설정 변경처럼 범위가 넓으면 patch note를 작성할 수 있습니다.

완료 기준:

- 어떤 파일을 왜 바꾸는지 설명 가능합니다.
- 검증 방법이 정해져 있습니다.

### Stage 4. Patch Implementation

목표: 정해진 범위 안에서 변경합니다.

규칙:

- 기존 파일의 스타일과 명명 규칙을 유지합니다.
- 단순 패치 범위를 넘는 리팩터나 동작 변경을 섞지 않습니다.
- 파일 이동 후에는 남은 경로 참조를 반드시 검색합니다.
- 문서 변경에서는 실제 코드나 저장소 상태와 맞지 않는 내용을 쓰지 않습니다.
- 사용자 변경으로 보이는 dirty worktree는 되돌리지 않습니다.

완료 기준:

- 변경 범위가 Stage 3의 scope 안에 있습니다.
- 이동/삭제/이름 변경의 후속 참조가 갱신됩니다.

### Stage 5. Targeted Verification

목표: 패치 성격에 맞는 최소 검증을 수행합니다.

검증 기준:

| 변경 범위 | 권장 검증 |
|---|---|
| 문서 경로/파일 이동 | `rg`로 오래된 경로 참조 확인, `find docs`로 구조 확인 |
| README/문서 내용 | 관련 문서 직접 읽기, 링크 경로 확인 |
| Dart 코드 문구/스타일 | `flutter analyze`, 관련 widget/unit test |
| 설정 파일 | 해당 빌드/분석 명령 또는 설정 참조 검색 |
| 테스트 파일만 변경 | 해당 `flutter test ...` |

기본 명령 예시:

```bash
git status --short
rg -n "old_path_or_old_name" .
flutter analyze
```

완료 기준:

- 실행한 명령과 결과가 설명 가능합니다.
- 실행하지 않은 검증이 있으면 이유를 남깁니다.

### Stage 6. Documentation Update

목표: 패치 결과와 문서 목록이 서로 맞게 합니다.

갱신 판단:

| 변경 내용 | 갱신 문서 |
|---|---|
| 새 영구 문서 추가 | `docs/README.md` |
| 문서 분류/경로 변경 | `docs/README.md`, 루트 `README.md`의 참고 문서 |
| 프로젝트 구조 변경 | `docs/simple_patches/PROJECT_STRUCTURE.md` |
| 공개 전 주의사항 변경 | `docs/simple_patches/PRE_GIT_CHECKLIST.md` |
| 테스트 명령/결과 변경 | `docs/simple_patches/test_plan_and_results.md` |
| 프로세스 규칙 변경 | `docs/simple_patches/guidelines/*.md` |

완료 기준:

- 새 문서와 이동된 문서가 README에 반영됩니다.
- 오래된 경로 참조가 남지 않습니다.

### Stage 7. Cleanup And Final Check

목표: 패치가 작고 명확한 상태로 끝나게 합니다.

작업:

1. 임시 문서가 있으면 삭제하거나 유지 이유를 기록합니다.
2. `git status --short`로 변경 범위를 확인합니다.
3. 관련 diff를 확인해 의도하지 않은 변경이 없는지 봅니다.
4. 최종 응답에 변경 요약, 검증 결과, 미수행 검증을 포함합니다.

완료 기준:

- 변경 파일이 요청 범위와 맞습니다.
- 사용자에게 남은 리스크를 짧게 설명할 수 있습니다.

## Testing Rules

단순 패치는 변경 범위에 따라 검증을 줄일 수 있습니다.

| 패치 유형 | 최소 검증 |
|---|---|
| 문서만 변경 | 관련 문서 읽기, 경로 검색 |
| 파일 이동/이름 변경 | 전체 저장소에서 이전 경로 검색 |
| Dart 코드 변경 | `flutter analyze` |
| UI 표시 변경 | 관련 widget test 또는 수동 확인 필요 여부 기록 |
| 설정/빌드 변경 | 해당 플랫폼 build/analyze 명령 |

검증을 생략할 수 있는 경우:

- 순수 문서 문장 보정
- README의 링크/목록만 갱신
- 테스트 실행과 무관한 보고서 파일 이동

생략한 경우에도 최종 응답에 "코드 변경 없음" 또는 "문서 변경만 있어 테스트 미실행"처럼 이유를 남깁니다.

## Documentation Rules

- 단순 패치 문서는 `docs/simple_patches/` 아래에 둡니다.
- 가이드 문서는 `docs/simple_patches/guidelines/` 아래에 둡니다.
- 새 영구 문서를 만들면 `docs/README.md`에 링크를 추가합니다.
- 문서 경로를 바꾸면 루트 `README.md`의 참고 문서도 확인합니다.
- 실행한 검증과 실행하지 않은 검증을 구분합니다.
- 민감 정보, access token, service role key, 개인 계정 정보는 문서에 쓰지 않습니다.

## Naming Conventions

| 목적 | 파일명 |
|---|---|
| 패치 노트 | `docs/simple_patches/<patch_name>_patch_note_YYYYMMDD.md` |
| 임시 실행 계획 | `docs/simple_patches/tmp_<patch_name>_execution_plan.md` |
| 가이드라인 | `docs/simple_patches/guidelines/<topic>_guidelines.md` |

`<patch_name>`은 snake_case를 사용합니다.

## Final Response Rules

단순 패치 완료 응답에는 다음을 포함합니다.

- 변경 요약
- 주요 파일 링크
- 수행한 검증
- 테스트를 실행하지 않았다면 이유
- 건드리지 않은 기존 변경이 있으면 그 사실

예시:

```text
문서 경로 정리 완료했습니다.

- docs를 new_features, simple_patches, bug_fixes로 재분류
- docs/README.md와 루트 README 경로 갱신

검증:
- 이전 경로 참조 검색 완료
- 문서 변경만 있어 Flutter 테스트는 실행하지 않았습니다.
```
