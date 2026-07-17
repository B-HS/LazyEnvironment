# 명령 모음

## 앱 (app/)

```bash
./start.sh                      # 루트에서: xcodegen + 빌드 + 재실행 (인자는 앱으로 전달)
cd app && xcodegen generate     # 파일 추가/project.yml 변경 후 필수
xcodebuild -project LazyEnvironment.xcodeproj -scheme LazyEnvironment \
  -configuration Debug -derivedDataPath .build/DerivedData build -quiet   # 빌드
xcodebuild ... test             # 47 tests (같은 인자에 build 대신 test)
```

- 빌드 산출물: `app/.build/DerivedData/Build/Products/Debug/LazyEnvironment.app`
- **에이전트 병렬 빌드 시 derivedDataPath를 분리**할 것(예: `.build/DerivedData-<name>`) — 동시 빌드 충돌 방지.

### QA 런치 인자 (open ... --args <인자>)

| 인자 | 효과 |
|------|------|
| `-force-dark` | 다크모드 강제(스킴 오버라이드) |
| `-debug-show-popover` | 실행 2초 후 메뉴바 팝오버 자동 표시(클릭 불가 환경 캡처용) |
| `-debug-open-settings` | 실행 2초 후 설정 창 자동 오픈 |
| `-debug-open-main` | 실행 2초 후 `openMainWindow()` 호출(메인 창 표시 경로 검증) |
| `-debug-close-windows` | 실행 3초 후 메인 창 전부 닫기(창 없는 상주 상태 재현) |

## 서버 (server/)

```bash
bun install
bun run dev                     # file:local.db 로 제로 설정 기동 (PORT 25252)
bun test                        # 31 tests
bunx tsc --noEmit               # 타입체크
vercel link && vercel env pull .env   # 실제 Turso 자격증명 주입(비밀값 비노출 흐름)
```

- 스크래치 기동(로컬 검증): `NODE_ENV=development JWT_SECRET=dev TURSO_DATABASE_URL=file:tmp.db PORT=25299 bun src/index.ts`
- dev 로그인: `curl -X POST localhost:25252/api/auth/dev -H 'Content-Type: application/json' -d '{"login":"me"}'`

## 앱 로컬 데이터

- `~/Library/Application Support/LazyEnvironment/{settings,state,custom-recipes}.json`
- 언어 강제(테스트용): settings.json의 `language`를 `"ko"|"en"|"ja"|"system"`으로 바꾸고 앱 재시작
