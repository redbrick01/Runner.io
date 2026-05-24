# Git 업로드 전 체크리스트

작성일: 2026-05-24

## 1. 저장소 상태

- 현재 `/Users/yw0410/Desktop/Project/runner_flutter`에는 `.git` 디렉터리가 없다.
- 새 저장소로 올릴 경우:

```bash
git init
git status --short
git add .
git status --short
```

`git add .` 후 `ios/Pods`, `macos/Pods`, `.gradle`, `.kotlin`, `.DS_Store`, `local.properties`, `xcuserdata`가 staging 되지 않는지 확인한다.

## 2. 반드시 확인할 민감 정보

다음 값은 현재 코드에 직접 포함되어 있다.

- Supabase project URL
- Supabase anon key
- Android Google Maps API key는 `android/local.properties` 또는 환경변수로만 관리
- iOS Google Maps API key는 Xcode build setting 또는 로컬 xcconfig로만 관리

anon key와 모바일 지도 키는 클라이언트 앱에 포함될 수 있지만, 공개 저장소에서는 아래 제한이 중요하다.

- Supabase RLS 정책과 Edge Function 인증 검증이 안전한지 확인
- Supabase service role key가 절대 클라이언트 코드나 Git에 포함되지 않는지 확인
- Google Maps API key에 Android package/SHA-1, iOS bundle id, HTTP referrer 등 플랫폼별 제한 적용
- 테스트/개발/운영 프로젝트를 분리할 계획이 있으면 상수 분리 또는 빌드 환경값 주입으로 이전

## 3. Git에 올리면 안 되는 파일/폴더

`.gitignore`에 반영된 주요 제외 대상:

- Flutter/Dart: `.dart_tool/`, `.flutter-plugins-dependencies`, `build/`, `coverage/`
- Android: `android/.gradle/`, `android/.kotlin/`, `android/local.properties`, app build output
- iOS/macOS: `Pods/`, `.symlinks/`, `Flutter/ephemeral/`, `xcuserdata/`
- Supabase: `supabase/.temp/`
- OS/IDE: `.DS_Store`, `.idea/`, `*.iml`

이미 로컬에 있는 파일은 삭제하지 않았고, Git 초기화/추가 시 무시되도록 했다.

## 4. 정리 완료 및 남은 확인 후보

| 대상 | 현재 상태 | 권장 조치 |
|---|---|---|
| `new.dart` | 앱 진입점에서 사용되지 않는 별도 `MainPage` 실험 코드 | 삭제 완료 |
| `res/` | `.DS_Store` 외 실제 리소스 없음 | 삭제 완료 |
| `docs/*복사본.docx` | 중간보고서 복사본 파일 | 삭제 완료 |
| `.DS_Store` | macOS 생성 파일 | 삭제 완료, `.gitignore` 반영 |
| `lib/main/mainlist_page.dart` | 현재 앱 흐름에서 import되지 않는 과거 지도/목록 화면 | 삭제 완료 |
| `macos/`, `linux/`, `windows/` | Flutter desktop 타깃 포함 | 모바일 앱만 배포한다면 유지 필요성 결정 |

## 5. 업로드 전 검증 명령

```bash
flutter pub get
flutter analyze
flutter test
```

원격 Supabase까지 확인하려면:

```bash
flutter test integration_test/runner_api_e2e_test.dart \
  --dart-define=RUNNER_E2E_EMAIL="$RUNNER_E2E_EMAIL" \
  --dart-define=RUNNER_E2E_PASSWORD="$RUNNER_E2E_PASSWORD"
```

Android 네이티브 Kotlin 컴파일 확인:

```bash
./gradlew :app:compileDebugKotlin
```

## 6. README 확인 항목

- 프로젝트 목적이 첫 문단에 드러나는가
- Flutter/Supabase/Native 역할이 구분되어 있는가
- 실행 명령이 최신인가
- 테스트 명령과 E2E 주의사항이 있는가
- 공개 저장소에 올릴 때 key 제한 관련 안내가 있는가
