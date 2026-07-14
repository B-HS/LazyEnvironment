# 2026-07-14 — 초기 스택·범위 합의

## v2 결정 (2026-07-14, 사용자 지시)

- **서버 스택: Bun + Hono + Turso(libSQL, Drizzle ORM)** — PRD의 bun:sqlite 대신 Turso로 변경(사용자 지정). 자격증명은 사용자 Vercel 프로젝트 env(TURSO_DATABASE_URL/TURSO_AUTH_TOKEN)에 보관 — `server/`에서 `vercel link && vercel env pull .env`로 주입(AI는 .env를 읽지 않음). 미설정 시 `file:local.db` 폴백으로 제로 설정 로컬 개발.
- **셀프 호스트 1급 지원**: 앱 설정에서 동기화 서버 URL 커스터마이즈 가능. 서버는 요청 origin(또는 SERVER_BASE_URL)에서 OAuth redirect_uri 유도 — 고정 origin 가정 금지. 셀프 호스트 체크리스트는 server/docs/server.md.
- **PORT 기본 25252** — 사용자가 env.ts 직접 수정. 앱 기본 URL도 `http://127.0.0.1:25252`로 정렬.
- **i18n 3개 언어(ko/en/ja) + 언어팩 확장성**: 번역은 전부 단일 Localizable.xcstrings — 새 언어 추가 = 각 키에 stringUnit 추가(커뮤니티 PR 병합 흐름). 레시피 콘텐츠(summary/manualSteps/후보 라벨/액션 타이틀)도 `Text(LocalizedStringKey(...))` 경유로 같은 카탈로그에서 번역.
- **계층 카탈로그(일관 적용)**: Node.js(nvm) 아래 npm·pnpm·bun, Python 아래 uv·pip(`parentId`). relocate 미구현 재확인 — "삭제 제대로 + 설치 경로 지정"으로 대체. 자동 디스크 재검사 삭제(디스크 수명), 수동 스캔만.
- **온라인/오프라인 모드 + 연결 상태(8차 지시)**: 설정에 동기화 모드 세그먼트(오프라인이면 로그인·동기화·연결 확인 전부 비활성), 연결 테스트 버튼 + 결과 알럿 팝업, 상태 점(미확인/온라인/오프라인)과 마지막 확인 시각. sync는 실행 전 자동 헬스체크.
- **README 한 줄**: 사용자가 만든 `README.md`의 `{여기에 한줄}` 자리에 영어 태그라인 기입(명시 지시 — README 금지 규칙의 예외 발동). 이외 README 수정은 여전히 금지.
- **폴더명 리네임**: `lazy-enviroment` → `lazy-environment`(사용자 지시). 참조 정리 후 앱 47·서버 31 테스트 재통과.

## 사용자 결정 (AskUserQuestion)

| 항목 | 결정 |
|------|------|
| 시작 범위 | **v0+v1 통합** — Recipe 스키마 기반 + 커스텀 레시피 추가/편집 UI(JSON 에디터 포함)까지. v2(백엔드·OAuth·동기화)는 이후 |
| 프로젝트 구성 | **XcodeGen** (project.yml 커밋, .xcodeproj gitignore) |
| git·레포 구조 | init + **모노레포** — `app/`(Swift), `server/`(v2 자리), `docs/` |
| UI 언어 | **시스템 로케일 + 인앱 언어 선택 가능한 i18n** (String Catalog ko/en) |

## 기본값 (질문 없이 진행, 이의 없었음)

- 최소 타깃 macOS 15, 번들 ID `com.hyunseokbyun.LazyEnvironment`
- 로컬 저장 JSON (PRD §12 권장), 위치 `~/Library/Application Support/LazyEnvironment/`
- 폴더명 오타(`lazy-environment`)는 초기엔 유지했다가 사용자 지시(2026-07-14)로 `lazy-environment`로 리네임 완료

## 구현 중 내린 설계 결정

- **PRD §14 열린 질문 "실행 전 명령 확인" 채택**: 레시피별 최초 실행 시 CommandPreviewSheet 강제 + 설정으로 "매번 확인" 옵션.
- **Recipe 스키마 확장 필드**: PRD §10.1 대비 `summary`, `supportsVersionPin`, `manualSteps`, `installActionTitle`/`updateActionTitle`(재배치·정리 레시피의 버튼 라벨), `category` 추가. `{{latestVersion}}`/`{{version}}` 토큰 추가({{version}}=핀 우선).
- **디스크 중복 계산 방지**: 사용량 캐시를 recipe 단위가 아닌 **확장된 경로(path) 단위**로 저장 → GRADLE_USER_HOME처럼 공유되는 경로는 전역 합계에서 1회만 계산, detail 뷰에 "Shared with X" 표시.
- **인터랙티브 셸 레시피**(nvm/sdkman)는 `zsh -ic` + **명시적 source** 병행(사용자 rc 내용에 의존하지 않도록).
- **비인터랙티브 실행 환경은 클린 env** (base PATH + HOME/USER/LANG/TMPDIR/TERM=dumb + DEV_HOME + 레시피 envVars). 레시피 detect는 env 경로/절대경로로 바이너리 참조.
- **DiskUsageScanner는 GCD로 blocking 격리** (cooperative pool 점유 방지).
- **envVars의 셸 반영은 v1에서 수동**: detail 뷰 "Copy export lines" 버튼 제공. rc 파일 자동 수정은 하지 않음(PRD 미요구, 파괴적).
- 서브에이전트 운용: 카탈로그 작성·검증·테스트 작성은 Opus+max 위임, 코어 계약·UI 정본은 메인(Fable) 직접.
- **(사용자 지시, 2026-07-14 세션 중) 기존 설치 감지·매칭**: 관리 경로(~/development)만 감지하지 말고 표준 위치(~/.nvm, ~/.bun, ~/.rustup, /usr/local/go, ~/Library/Android/sdk 등)의 기존 설치를 감지해 레시피에 매칭. 구현: `externalCandidates` 스키마 + 엔진 폴백 감지 + `설치됨 (외부)` 상태(청록) + 실경로·용량 표시. 외부 설치 시 Update는 숨기고 Install(관리 사본 구성, 기존 설치 무손상)만 노출.
- **(사용자 결정, 2026-07-14) relocate 기능은 만들지 않는다**: move+symlink(B) vs env 재지정(A) 트레이드오프 제시했으나 사용자가 방향 변경 — "삭제 기능을 제대로 + 설치할 때 경로 지정을 제대로"로 확정. 구현:
  - **외부 설치 제거**: `ExternalInstallCandidate.uninstallCommand` — 감지된 위치 전용 제거 명령(도구 네이티브 우선: `rustup self uninstall -y`, brew 후보는 `brew uninstall <formula>`; 경로 삭제는 전부 `${HOME:?}` 가드). 후보에 제거 명령이 없으면 제거 버튼 자체를 숨김(관리 경로 fallback 금지 — 빈 삭제 오해 방지). 제거는 항상 명령 확인 시트 경유.
  - **레시피별 설치 경로 오버라이드**: `RecipePersistedState.customDevHome` — 상세 뷰 "설치 위치" 섹션(직접 입력+폴더 선택+실경로 미리보기). 해당 레시피의 설치·감지·디스크 스캔·env 표시·export 복사 전부가 그 경로 기준으로 동작. 비우면 전역 DEV_HOME 복귀.
  - cocoapods/neovim/claude의 PATH 기반 후보는 설치 관리자를 특정할 수 없어 제거 명령 의도적 미제공. go `/usr/local/go`는 sudo 필요라 자동 제거 제외.
