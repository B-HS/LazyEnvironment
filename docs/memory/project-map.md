# 프로젝트 지도 (아키텍처·핵심 파일)

## 레포 구조

```
lazy-environment/
├── CLAUDE.md               # 프로젝트 룰(새 세션 진입점 중 하나)
├── start.sh                # 빌드+실행 스크립트 (./start.sh [앱 인자...])
├── app/                    # macOS SwiftUI 앱
│   ├── project.yml         # XcodeGen 정의(.xcodeproj는 gitignore — 항상 xcodegen generate)
│   ├── LazyEnvironment/Sources/
│   │   ├── App/            # LazyEnvironmentApp(+AppDelegate: 메뉴바 설치·wake·창닫힘 관찰·QA 인자), AppState(중앙 @Observable 싱글턴), StatusBarController
│   │   ├── Models/         # Recipe(+ExternalInstallCandidate·SourcePinning·parentId·adminActions), RecipeState(상태·런로그·PersistedState), AppSettings(+SyncMode)
│   │   ├── Engine/         # CommandResolver(토큰·클린 env), ShellRunner(zsh 2경로·osascript admin·EOF 완료), RecipeEngine(관리→외부 폴백 감지), DiskUsageScanner(du·GCD), LatestVersionResolver(GitHub/go.dev), PathExpander
│   │   ├── Store/          # LocalStore(JSON 3파일)
│   │   ├── Catalog/        # BuiltinCatalog(번들 JSON 로드)
│   │   ├── Sync/           # KeychainStore, SyncModels(API 봉투), SyncClient, SyncEngine(로그인·충돌·LWW·연결상태)
│   │   └── UI/             # MainView(계층 리스트), RecipeRow/Detail, CommandPreviewSheet, CustomRecipeEditor, Settings, MenuBarSummary, ConflictResolutionSheet, LogView, Formatters(타일·필)
│   ├── LazyEnvironment/Resources/
│   │   ├── builtin-recipes.json    # 내장 카탈로그 23종 — 수정 시 xcstrings 동기 필수(아래 참조)
│   │   ├── Localizable.xcstrings   # ko/en/ja 285키 — UI 크롬 + 레시피 콘텐츠 번역
│   │   └── Assets.xcassets/AppIcon.appiconset/
│   └── Tests/LazyEnvironmentTests/ # 47 tests / 9 suites (Swift Testing)
├── server/                 # Bun+Hono+Turso 동기화 백엔드 (운영 문서: server/docs/server.md)
│   └── src/ {index,app,db,dto,lib,middleware,route,service,compose} + tests/ (31 tests)
└── docs/                   # 이 문서군 (PROCESS.md가 진입점)
```

## 데이터 흐름 (앱)

- `AppState.shared`(@MainActor @Observable)가 전부 소유: settings, 카탈로그(내장+커스텀), statuses, externalMatches, runs(라이브 로그), PersistedState.
- 감지: `RecipeEngine.detect` — 관리 경로 감지 성공 → `.installed`; 실패 시 `externalCandidates` 순회 → `.installedExternally` + 매칭 인덱스. 레시피별 `effectiveSettings`(customDevHome 오버라이드) 사용.
- 실행: UI → (최초 실행이면 CommandPreviewSheet 강제) → `AppState.run` → resolver(토큰·env)→ShellRunner 스트림→RunRecord 영속→재감지→해당 레시피 디스크 재스캔.
- 디스크: **수동 트리거만**(툴바 새로고침/상세 다시 검사/팝오버). 캐시는 확장된 경로 문자열 키 → 공유 경로(GRADLE_USER_HOME 등) 전역 합계 1회 계산.
- 동기화: `SyncEngine.shared` — Keychain JWT, sync()=헬스체크→pull→충돌 계산(레시피 단위)→(충돌 시 시트)→push(LWW는 서버가 행 단위 타임스탬프). 오프라인 모드면 전부 가드.

## 계층 카탈로그

- `Recipe.parentId` — MainView.rowEntries가 부모 뒤에 자식 들여쓰기 배치(보이는 집합 안에서만 계층화).
- 현재: node-nvm ▸ npm·pnpm·bun / python ▸ uv·pip. 카테고리 카운트는 자식 포함.

## 불변 규칙 (깨면 안 됨)

1. **builtin-recipes.json의 사용자 노출 문자열(summary/manualSteps/externalCandidates[].label/액션 타이틀)을 바꾸면 Localizable.xcstrings에서 그 영문 원문 키를 찾아 함께 갱신**(키=영문 원문 byte-identical). `Text(LocalizedStringKey(...))` 렌더라 키가 어긋나면 영어 폴백만 되고 크래시는 없음.
2. 새 소스/테스트 파일 추가 후 반드시 `xcodegen generate`(sources가 폴더 글롭).
3. admin 플래그 명령은 절대경로만($HOME 의존 금지 — 엔진이 사전 확장하지만 카탈로그도 절대경로 원칙). rm -rf는 `"${VAR:?}"` 가드.
4. 인터랙티브(nvm/sdkman) 명령은 `export NVM_DIR=...` 명시(사용자 rc 오버라이드 차단) + init 파일 explicit source.
5. 서버 API 계약은 [sync-protocol.md](./sync-protocol.md)에 고정 — 클라이언트·서버 동시 변경 필요.
6. 디스크 경로 중복 계산 금지 — 부모/자식 경로를 서로 다른 레시피에 declare하지 말 것(uv=bin·cache·tools·tool-bin, python=pythons로 분리해 둔 이유).
