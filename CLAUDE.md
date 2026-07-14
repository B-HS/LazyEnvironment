# lazy-environment

macOS 개발 도구체인 관리 앱(SwiftUI) + 동기화 백엔드(Bun/Hono/Turso) 모노레포.

## 새 세션 시작 시

1. **`docs/PROCESS.md`를 먼저 읽는다** — 현재 상태·체크리스트·미확인 항목·재개 가이드.
2. 아키텍처는 `docs/memory/project-map.md`, 명령은 `docs/memory/commands.md`.
3. 스펙 정본은 `docs/PRD.md`(§16 개정 포함).

## 도메인 규칙

- `app/`(Swift)은 **웹 코드 컨벤션(arrow fn·enum 금지 등)을 적용하지 않는다** — Swift 표준 관례. `server/`(TS)는 `~/.claude/convention/backend.md` 전면 적용.
- 공통: 코드 주석 금지(영어 doc comment만), 매직넘버 금지, Conventional Commits(작성자 단독·Co-Authored-By 금지·요청 시에만 커밋).

## 하드 규칙 (깨지기 쉬움)

- `app/LazyEnvironment.xcodeproj`는 생성물 — 항상 `xcodegen generate`. 파일 추가 후 재생성 필수.
- **builtin-recipes.json의 사용자 노출 문자열을 바꾸면 Localizable.xcstrings의 동일 영문 키를 함께 갱신**(ko/ja). 상세: `docs/memory/i18n.md`.
- 레시피 명령은 `docs/memory/engine-contract.md` 계약 준수(클린 env, `"${VAR:?}"` 가드, 인터랙티브는 export 명시, admin은 절대경로).
- 서버-클라이언트 API는 `docs/memory/sync-protocol.md`에 고정 — 한쪽만 바꾸지 말 것.
- `server/.env`는 읽지도 쓰지도 않는다(자격증명은 `vercel env pull`, 예시는 `.env.example`).

## 빌드·검증 (종료 전 필수)

- 앱: `cd app && xcodegen generate && xcodebuild -project LazyEnvironment.xcodeproj -scheme LazyEnvironment -configuration Debug -derivedDataPath .build/DerivedData test`
- 서버: `cd server && bunx tsc --noEmit && bun test`
- 실행: 루트 `./start.sh` (QA 인자: `-force-dark`, `-debug-show-popover`, `-debug-open-settings`)
- UI 변경은 실행 화면 확인까지(캡처 절차: `docs/utils/session-tools.md`).
