# 2026-07-14 — v0+v1 초기 구축 (로컬 전용 전체)

## 결과물

- `app/` — SwiftUI macOS 앱 (XcodeGen, Swift 6, macOS 15+, strict concurrency)
  - Models: `Recipe`(PRD §10.1 + summary/supportsVersionPin/manualSteps/액션라벨/externalCandidates 확장), `SourcePinning`(github-latest-tag/stable-url/pinned/go-dev-json), 상태·런로그·설정
  - Engine: `CommandResolver`(토큰 `{{latestTag}}`/`{{latestVersion}}`/`{{version}}`, 클린 env 합성), `ShellRunner`(zsh -c / zsh -ic 2경로, 라이브 스트리밍), `RecipeEngine`(관리 감지 → 외부 후보 폴백, 인터랙티브 셸 rc 노이즈 대응 버전 파싱), `DiskUsageScanner`(du, GCD 격리), `LatestVersionResolver`(GitHub/go.dev, 세션 캐시)
  - Store: JSON 3파일(settings/state/custom-recipes), `~/Library/Application Support/LazyEnvironment/`
  - UI: 3열 메인 패널, 상세(경로·env·핀·로그·수동단계·외부설치 노트·export 복사), 명령 확인 시트(최초 실행 강제), 커스텀 레시피 폼+JSON 에디터, 설정. `-force-dark` QA 인자
  - i18n: Localizable.xcstrings 125키 en/ko
  - 카탈로그: 내장 레시피 20종(워크플로 3그룹 작성 → 레시피별 적대적 검증 → 자동 수정) + 외부 설치 후보 12종
- 테스트: 40 tests / 8 suites (모델 디코드, 경로 확장, 명령 해석, 셸 러너, 디스크 스캐너, 로컬 스토어, 카탈로그 불변식, 외부 감지)

## 검증

- `xcodebuild test` 전체 통과. 앱 라이브 실행: 라이트/다크/한국어 렌더 캡처 확인
- 실머신 감지 확인: Homebrew 6.0.10, Docker 4.39.0(30.5GB), Claude Code 2.1.208, LunarVim 1.4.0, 시뮬레이터 8.96GB + 외부 매칭(nvm ~/.nvm v22.14.0, bun ~/.bun 32.3GB, rustup, go1.24.1 /usr/local/go, uv, rbenv 3.3.0(brew), neovim v0.12.2, cocoapods 1.16.2), 관리 합계 86.2GB

## 세션 중 잡은 버그

1. 인터랙티브 셸 버전 오염 — 사용자 rc 배너("bun add v1.3.0")가 첫 줄로 잡힘 → 인터랙티브 레시피는 마지막 비공백 줄 사용
2. nvm/sdkman 관리 감지 오탐 — rc가 NVM_DIR/SDKMAN_DIR을 덮어써 관리 설치로 오인 → 명령에 export 명시로 차단
3. DiskUsageScanner가 actor 안에서 blocking(waitUntilExit) → GCD 격리로 cooperative pool 보호

## 2차 확장 (같은 날, 사용자 지시)

- **기존 설치 감지·매칭**: `externalCandidates`(표준 위치 후보 12종) + 엔진 폴백 감지 + "설치됨 (외부)" 상태 + 실경로·용량. relocate는 검토 후 사용자 결정으로 폐기 → "제거 + 설치 경로 지정"으로 대체.
- **외부 설치 제거**: 후보별 `uninstallCommand`(도구 네이티브 우선), 제거 명령 없으면 버튼 숨김. 항상 확인 시트.
- **레시피별 설치 경로**: `customDevHome` 오버라이드(상세 뷰 "설치 위치" 섹션) — 설치·감지·디스크·env 전부 반영.
- **관리자 권한 실행**: `adminActions`/`uninstallRequiresAdmin` → osascript 관리자 프롬프트, admin 스크립트 $HOME 사전 확장, 확인 시트 배지. PRD §16 개정.
- **메뉴바 상주 + 자동 시작 + 아이콘**: NSStatusItem(요약 팝오버/우클릭 메뉴), SMAppService 로그인 시작, "메뉴 막대로 시작"(suppressed launch + accessory policy), 앱 아이콘 에셋(에이전트 생성).
- **UI 향상**: 카테고리 컬러 타일·상태 필·사이드바 컬러 아이콘·상세 헤더 개편.
- 최종 44 tests / 8 suites 통과. i18n 141키.

## 3차 (사용자 피드백: Dock·팝오버·wake)

- 창이 하나도 없으면 Dock 아이콘 자동 숨김(accessory) — willClose 중앙 관찰로 메인/설정 창 모두 커버.
- 잠자기→wake 시 didWakeNotification으로 상태·디스크 자동 재갱신.
- 팝오버 전면 재디자인: 헤더(아이콘+설정 기어), 상태 칩 3개, 디스크 카드(총량+상위 4개 카테고리 컬러 바+스캔 시각), 푸터(새로고침·모두 업데이트·자세히 보기). NSHostingController `sizingOptions=.preferredContentSize`로 세로 늘어짐 해결. `-debug-show-popover` QA 인자 추가.
- ShellRunner 간헐 stderr 유실 근본 수정(EOF 기반 완료 신호). 44 tests 통과 + ShellRunnerTests 5연속 통과.

## 4차 (콘텐츠·계층·v2 서버/동기화·i18n 3개 언어)

- 버튼 눈 아이콘 제거, 수동 단계 줄바꿈·로컬라이즈 렌더링(레시피 콘텐츠도 xcstrings 경유), 레시피 설명 전면 보강(요약 20종 재작성 + 수동 단계 54개).
- 일관 계층 카탈로그(`parentId`): Node.js(nvm) 아래 npm(신설)·pnpm·bun / Python(신설) 아래 uv·pip(신설) — 총 23 레시피. 사용자 pyenv가 Python 외부 설치로 감지되는 것 확인.
- **v2**: `server/` Bun+Hono+**Turso**(Drizzle) — GitHub OAuth(요청 origin 기반 redirect_uri, 셀프 호스트 1급), JWT, 공개 카탈로그, 프로필 CRUD(레시피 단위 LWW), dev 로그인(개발 모드 한정). 31 bun tests + tsc + 라이브 curl E2E. 컨벤션 리뷰 반영(프로덕션 판정 DI 동기화, 프로필 교체 원자화). PORT 25252(사용자 지정), Turso 자격증명은 Vercel env→`vercel env pull`.
- **v2 클라이언트**: Keychain, SyncClient, ASWebAuthenticationSession GitHub 로그인(`lazyenvironment://`), SyncEngine(레시피별 충돌·LWW), 설정 "계정 및 동기화"(서버 URL 커스터마이즈), 충돌 해소 시트(PRD §11.4). 서버 실응답 픽스처 디코딩 테스트 포함 47 tests.
- **i18n**: ko/en/ja 3개 언어, 273키 전체(레시피 콘텐츠 포함). ja 라이브 렌더 확인. 언어팩 = xcstrings 키별 stringUnit 추가(PR 병합 방식).

## 5차 (연결 상태·오프라인 모드·docs 전면 정비·리네임)

- 설정 "계정 및 동기화": 동기화 모드(온라인/오프라인), 연결 테스트+결과 팝업(알럿), 상태 점+마지막 확인 시각. sync 전 자동 헬스체크. 오프라인 모드는 로그인·동기화 전면 가드. i18n 285키(ko/ja 동시 추가).
- 레포 폴더명 오타 수정: `lazy-enviroment` → `lazy-environment`(참조 정리, 앱 47·서버 31 테스트 재통과, 앱 재실행).
- README `{여기에 한줄}` 태그라인 기입(명시 지시).
- docs/ 전수검사·재구성: PROCESS(재개 가이드), memory(project-map·commands·engine-contract·sync-protocol·i18n), utils(session-tools), bug, feedback, quality-assurance(resume-checklist), 루트 CLAUDE.md 신설.

## 미완 / 다음 단계 (2026-07-14 세션 종료 시점)

- 사용자 입회 확인 목록: docs/quality-assurance/resume-checklist.md "사용자 입회 필요" 절
- GitHub OAuth 앱 생성(사용자) 후 실로그인 검증, 서버 배포(Vercel/Turso 연결), 게스트 공개 카탈로그 병합 UI(PRD §6.3)
- 커밋 미실행(사용자 지시 대기), personal-llm 기록 여부 답변 대기
- git 커밋 없음(지시 대기)
