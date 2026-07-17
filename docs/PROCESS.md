# PROCESS — lazy-environment

> **새 세션은 이 문서부터 읽는다.** 기준 문서: [PRD.md](./PRD.md)(§16 개정 포함), `~/.claude/convention/*`, `~/personal-llm/*`, 레포 루트 `CLAUDE.md`.
> Swift(비-웹 도메인)는 웹 코드 컨벤션(arrow fn 등)을 적용하지 않고 Swift 표준 관례를 따른다. 공통 적용: 주석 금지(영어 doc comment만), Conventional Commits·author 단독·co-author 금지·요청 시에만 커밋, 시크릿/.env 접근 금지, 종료 전 검증.

## 세션 재개 가이드 (2026-07-17 기준 현황)

| 항목 | 상태 |
|------|------|
| 앱 (`app/`) | v0+v1+v2 클라이언트 완성. Swift 6 / SwiftUI / macOS 15+ / XcodeGen. **47 tests / 9 suites 그린** |
| 서버 (`server/`) | v2 완성. Bun + Hono + Turso(libSQL·Drizzle). **31 tests + tsc 그린**, 컨벤션 리뷰 반영 완료 |
| i18n | ko/en/ja 3언어, xcstrings 285키(레시피 콘텐츠 포함). ko·ja 라이브 렌더 확인 |
| 카탈로그 | 내장 레시피 23종(계층: node-nvm▸npm·pnpm·bun / python▸uv·pip), 외부 설치 감지 12+종 |
| git | prod 브랜치 커밋 10개(..d6269b2, 버그 수정 ac 포함 — v0.0.2 릴리즈됨). **커밋은 여전히 사용자 지시 시에만** |
| CI/릴리즈 | `.github/workflows/{ci,release-app}.yml` — push마다 서명·공증 자동 릴리즈(md 전용 제외, 직렬화, 버전 4-스킵 자동 증가). 태그 v0.0.1 공증 통과, 사용자가 `/Applications`에 설치해 사용 중 |
| 서버 배포 | Vercel 배포 계약 반영(자가 번들 함수·public 디렉토리·카탈로그 정적 import 폴백). 사용자 settings의 서버 URL `https://lazy.seok.dev` |
| 앱 언어 설정 | 사용자 머신에서 ko로 사용 중, `startInMenuBar: true` (`~/Library/Application Support/LazyEnvironment/settings.json`) |
| 워킹트리 | ac는 커밋·푸시·릴리즈 완료(v0.0.2). ad(Java SDKMAN Bash4 수정)는 미커밋 |

빌드·실행·검증 명령: [memory/commands.md](./memory/commands.md). 아키텍처 지도: [memory/project-map.md](./memory/project-map.md). 세션 도구·재사용 자산: [utils/session-tools.md](./utils/session-tools.md). 검증 절차: [quality-assurance/resume-checklist.md](./quality-assurance/resume-checklist.md).

## 합의된 스택·범위

- v0+v1+v2 전부 구현됨(당초 v2는 후순위였으나 사용자 지시로 당김). 상세 결정: [acknowledge/2026-07-14-initial-stack.md](./acknowledge/2026-07-14-initial-stack.md)
- 앱: XcodeGen(project.yml 커밋, .xcodeproj 미커밋), 번들 `com.hyunseokbyun.LazyEnvironment`, 최소 macOS 15
- 서버: Bun+Hono+Turso(Drizzle), PORT 25252, 셀프 호스트 1급, Turso 자격증명은 Vercel env(`vercel env pull`)
- 로컬 저장: JSON 3파일(`settings/state/custom-recipes`) @ `~/Library/Application Support/LazyEnvironment/`

## 체크리스트 (완료 이력)

- [x] a. 스캐폴딩 — git init, 모노레포(app/server/docs), XcodeGen, 빌드 그린
- [x] b~e. 코어 — Recipe 스키마(Codable)·토큰 해석 / 실행 엔진(클린 env `zsh -c` · 인터랙티브 `zsh -ic` 2경로, 라이브 로그, 명령 프리뷰 FR8) / du 디스크 스캐너(경로 단위 캐시, 공유 경로 중복 방지) / JSON 로컬 저장
- [x] f. 내장 카탈로그 — 워크플로(3그룹 작성→레시피별 적대적 검증→자동수정), 외부 설치 후보 포함
- [x] g~h. 메인 UI(3열, 상태 필, 카테고리 타일)·상세 뷰·커스텀 레시피 폼+JSON 에디터·명령 확인 시트(최초 실행 강제)
- [x] i. i18n — ko/en(이후 ja 추가), 시스템 로케일 + 인앱 언어 선택
- [x] j~k. 테스트·docs
- [x] l. 외부(기존) 설치 감지·매칭 — `externalCandidates` + `설치됨 (외부)` 상태 + 실경로·용량
- [x] m. 관리자 권한 실행 — `adminActions`/`uninstallRequiresAdmin` → osascript 관리자 프롬프트(스크립트 $HOME 사전 확장), PRD §16.1
- [x] n. 메뉴바 상주(NSStatusItem, 좌클릭 팝오버/우클릭 메뉴) + 로그인 자동 시작(SMAppService) + 메뉴바 시작(suppressed+accessory) + 앱 아이콘
- [x] o~p. UI 향상(아이콘 타일·필) + 팝오버 재디자인(상태 칩·디스크 상위 바·sizingOptions 수정)
- [x] q. 창 없으면 Dock 숨김(willClose 중앙 관찰) + wake 시 상태 재감지
- [x] r. ShellRunner 플레이크 근본 수정(EOF+종료코드 3조건 완료)
- [x] s. 자동 디스크 재검사 전면 삭제(디스크 수명) — 수동 스캔만, 측정 시각 저장·표시
- [x] t. Settings 열기 버그 수정(macOS 15 셀렉터 무동작 → 앱 메뉴 항목 performActionForItem)
- [x] u. 레시피 설명 전면 보강(요약 20종 재작성+수동 단계 54개) + 로컬라이즈 렌더링 + 눈 아이콘 제거
- [x] v. 일관 계층 카탈로그(`parentId`) — node-nvm▸npm·pnpm·bun / python▸uv·pip (23종)
- [x] w. v2 서버 — 상세: [memory/sync-protocol.md](./memory/sync-protocol.md), `server/docs/server.md`
- [x] x. v2 클라이언트 — Keychain·GitHub 로그인(ASWebAuthenticationSession)·SyncEngine(레시피별 LWW·충돌)·충돌 해소 시트(PRD §11.4)·서버 URL 커스터마이즈
- [x] y. ja 번역 285키 전체(빌드·lproj·라이브 렌더 검증)
- [x] z. 서버 컨벤션 리뷰 반영(프로덕션 판정 DI 동기화·프로필 교체 원자화·사각 코드 제거. `getDbCredentials` 삭제 제안은 오탐 — drizzle.config가 사용)
- [x] aa. (사용자 지시 8차) 서버 연결 상태 — 연결 테스트 버튼+결과 팝업(알럿), 상태 점(온라인/오프라인/미확인)+마지막 확인 시각, **동기화 모드(온라인/오프라인)** 설정(오프라인 시 로그인·동기화·연결 확인 비활성), sync 전 자동 헬스체크
- [x] ab. 레포 리네임 `lazy-enviroment`→`lazy-environment`(오타 수정, 사용자 지시) + README `{여기에 한줄}` 태그라인 기입 + docs 전면 정비(memory/utils/bug/feedback/QA/루트 CLAUDE.md) — 리네임 후 앱 47·서버 31 테스트 재통과
- [x] ac. (사용자 지시 9차, 2026-07-17) 릴리즈 앱 버그 3건 수정 — (1) 메뉴바 시작 시 앱 재실행해도 창 안 뜸 → `applicationShouldHandleReopen` + `openMainWindow` 가시성 필터(+File▸New Window ⌘N 폴백), (2) python 설치 실패(uv 역의존, exit 127) → installCommand/updateCommand가 uv 자동 부트스트랩 + `UV_CACHE_DIR` env, (3) pnpm 설치 성공인데 미설치 표시 → pnpm v11 `$PNPM_HOME/bin` 레이아웃 반영(관리+외부 후보 이중 경로, 레거시 폴백). xcstrings 2키 교체(ko/ja), QA 인자 `-debug-open-main`/`-debug-close-windows` 추가. 적대적 리뷰(3에이전트, 프로브 실증) 반영: 최소화 창 `canBecomeMain=false` 중복 창 블로커, Settings 창 제외, ⌘N 부재 시 accessory 복귀, accessory 전환 레이스 가드, `UV_NO_MODIFY_PATH=1`(rc 무수정). 검증: 47 테스트 그린 + 샌드박스 E2E(uv 부트스트랩→CPython 3.14.6, rc 0바이트) + 실행 화면 캡처(pnpm Installed 11.13.1, reopen 창 표시). 상세: [bug/2026-07-17-fixed-bugs.md](./bug/2026-07-17-fixed-bugs.md) — 커밋 6fcb7ed·d6269b2, **v0.0.2 릴리즈**(CI 서명·공증 통과)
- [x] ad. (사용자 지시 10차) Java(SDKMAN) 설치 실패 수정 — SDKMAN 설치 스크립트의 Bash 4+ 요구 vs macOS 기본 Bash 3.2. installCommand가 Homebrew bash 절대경로로 파이프(없으면 `brew install bash` 자동), manualSteps에 Homebrew 선행 안내 추가(xcstrings 286키, ko/ja). 검증: 샌드박스 E2E + 실 DEV_HOME 설치(Java 25.0.3-tem) + 앱 "Installed" 캡처 + 47 테스트 그린. 상세: [bug/2026-07-17-fixed-bugs.md](./bug/2026-07-17-fixed-bugs.md) §4
- [x] ae. (사용자 지시 11차) 전체 경로 감사 + 동기화 확인 — 23종 레시피 엔진 동일 env 프로브: 설치 12종 전부 정상 감지·경로 정합, 겹침은 의도된 gradle 공유뿐(npm `~/.npm`·pip `~/Library/Caches/pip`는 설계상 캐시 추적 경로). 동기화: 프로드 서버 정상(health·게이팅·401·카탈로그), **서버 카탈로그 드리프트 발견→동기화**(server/data/catalog.json ← 앱 카탈로그, 서버 31 테스트 그린), OAuth 미구성(503)은 사용자 액션 대기

## 미확인 항목 (사용자 직접 확인 필요 — 클릭/자격증명 필요)

- [ ] 메뉴바 팝오버·우클릭 메뉴·자동 시작 토글 실클릭 (QA 인자로 팝오버 표시는 확인됨)
- [ ] 관리자 비밀번호 프롬프트 실동작 (go `/usr/local/go` 외부 제거 시)
- [ ] GitHub OAuth 실로그인 — 서버 측 구성은 **완료**(2026-07-18: 사용자가 Vercel env `GITHUB_CLIENT_ID`/`GITHUB_CLIENT_SECRET` 등록 — 최초 `GITHUB_SECRET` 오기를 정정 — 후 `vercel redeploy`로 반영, `/auth/github` 302→github.com 확인). 남은 것: **앱에서 실클릭 로그인**(설정→GitHub 로그인→브라우저 인증→`lazyenvironment://` 콜백) 후 동기화 왕복 확인. GitHub OAuth 앱 콜백 URL은 `https://lazy.seok.dev/auth/github/callback`이어야 함
- [ ] 충돌 해소 시트 실사용(두 기기 또는 로컬 상태 변경 후 재동기화)
- [ ] 실제 설치 E2E(파괴적 — 입회 권장)
- [ ] 커스텀 레시피 에디터 시트 상호작용

## 알려진 제약 / 후속 후보

- 실행 중 설치 로그는 스트리밍되지만 **관리자(osascript) 실행은 완료 후 일괄 출력**(do shell script 특성)
- 레시피 콘텐츠 번역은 xcstrings 키=영문 원문 방식 — **builtin-recipes.json의 summary/manualSteps/라벨을 수정하면 xcstrings의 해당 키도 함께 갱신**해야 함(안 하면 해당 문자열만 영어 폴백). 검증법은 QA 체크리스트 참조
- 서버 배포는 Vercel 계약 반영 완료(31ef17a·38da3f2·0c01ee3), 로컬 검증은 여전히 `bun run dev`. Turso 연결은 `vercel env pull`
- `/Applications`의 릴리즈 앱은 v0.0.1(수정 전) — 버그 3건 수정은 다음 push→자동 릴리즈에 포함되어야 반영됨. 그 전까지는 로컬 Debug 빌드(`./start.sh`)로 사용
- uv 레시피의 uninstall(`rm -rf $DEV_HOME/python/uv`)이 python 레시피 소유 `pythons/`까지 제거 — 후속 후보(감지됨, 미수정)
- uv 레시피 자체 installCommand는 여전히 rc 파일을 수정함(python 부트스트랩만 `UV_NO_MODIFY_PATH=1` 적용) — 통일 여부는 후속 판단
- **카탈로그 사본이 2곳**(`app/LazyEnvironment/Resources/builtin-recipes.json` ↔ `server/data/catalog.json`) — 앱 쪽만 고치면 서버 게스트 카탈로그가 구버전을 서빙(2026-07-17 드리프트 실발생·동기화함). **앱 카탈로그 수정 시 서버 사본도 함께 복사** 필수. 후속 후보: 단일 SSOT화 또는 CI 드리프트 체크
- Vercel 함수는 부팅 마이그레이션이 없음 — DB 마이그레이션은 `vercel-build`의 `bun run db:migrate`가 배포마다 실행(멱등). 스키마 변경 시 `drizzle-kit generate`로 마이그레이션 파일 커밋만 하면 됨. Sensitive env는 `vercel env pull`로 실값 조회 불가(빌드/런타임에만 주입)
- 공개 카탈로그를 앱이 가져와 병합하는 게스트 모드(PRD §6.3 첫 항목)는 서버 API만 존재, 앱 쪽 병합 UI 미구현
- Homebrew 최초 부트스트랩은 sudo/TTY 필요 → 수동 단계로 안내(레시피에 반영됨)

## 진행 메모 (시간순 요약)

- (2026-07-14) 스캐폴딩→코어→UI→카탈로그 워크플로(1차 15종 검증, 그룹B 스톨 재실행으로 20종)→i18n ko→외부 감지→관리자 실행→메뉴바/자동시작/아이콘→자동 재검사 삭제→Settings 버그→콘텐츠 보강(20 요약+54 단계)→계층화(23종)→v2 서버+클라이언트+E2E→ja→연결 상태/오프라인 모드→docs 전면 정비. 상세: [history/2026-07-14-v0v1-initial-build.md](./history/2026-07-14-v0v1-initial-build.md), 버그: [bug/2026-07-14-fixed-bugs.md](./bug/2026-07-14-fixed-bugs.md), 피드백: [feedback/2026-07-14-session-feedback.md](./feedback/2026-07-14-session-feedback.md)
- (2026-07-15/16, 세션 외) 사용자 주도 커밋 8개 — 초기 스캐폴딩 커밋, Vercel 배포 계약, CI+서명 릴리즈 워크플로(버전 4-스킵), 공증 거절 해결(get-task-allow 주입 차단), push 자동 릴리즈. 태그 v0.0.1 배포
- (2026-07-17) 릴리즈 앱 사용자 버그 3건 수정(체크리스트 ac) — 창 reopen / python uv 부트스트랩 / pnpm bin 경로. 버그: [bug/2026-07-17-fixed-bugs.md](./bug/2026-07-17-fixed-bugs.md)
