# 동기화 프로토콜 (서버-클라이언트 고정 계약)

> 변경 시 서버(`server/src`)와 클라이언트(`app/.../Sync/`)를 함께 수정하고 양쪽 테스트를 모두 갱신한다.
> 서버 운영·셀프 호스트·OAuth 앱 생성 절차: `server/docs/server.md`.

## 봉투

- 성공 `{"success":true,"data":<payload>}` / 실패 `{"success":false,"error":{"code","message"}}` (details는 비프로덕션만)

## 엔드포인트

| 메서드/경로 | 인증 | 설명 |
|---|---|---|
| GET `/api/health` | - | `{status:"ok"}` — 앱 "연결 테스트"가 사용 |
| GET `/api/catalog` | - | `{recipes:[Recipe...], updatedAt}` — 게스트 공개 카탈로그(23종) |
| GET `/auth/github` | - | GitHub authorize로 302(state 쿠키). redirect_uri는 요청 origin(또는 SERVER_BASE_URL)에서 유도 — 셀프 호스트 지원 |
| GET `/auth/github/callback` | - | code 교환→users upsert→JWT(HS256, 30d)→`lazyenvironment://auth#token=<jwt>&login=<login>` 302 (실패 시 `#error=<code>`) |
| POST `/api/auth/dev` | - | **NODE_ENV=development 한정** `{login}` → `{token,login}` (프로덕션 404) |
| GET `/api/profile` | Bearer | `{userId, updatedAt, environments:[{recipeId,pinnedVersion,customPath,enabled,updatedAt}], customRecipes:[{recipeId,recipe,updatedAt}]}` |
| PUT `/api/profile` | Bearer | 전체 교체(단일 db.batch 원자적). **내용이 바뀐 행만 updated_at 갱신**(LWW), 빠진 행 삭제 |

## 클라이언트 매핑

- `customPath` ⇄ 앱의 `RecipePersistedState.customDevHome`, `pinnedVersion` ⇄ 버전 핀. enabled는 현재 항상 true로 push.
- JWT/login: Keychain(service `com.hyunseokbyun.LazyEnvironment`, account `session-token`/`session-login`).
- sync() 흐름: 오프라인 모드 가드 → 헬스체크 → GET profile → 충돌 계산(레시피 단위: 로컬 값 존재+상이 → 충돌, 원격만 → 자동 적용, 로컬만 → push 대상) → 충돌 있으면 시트(이 Mac/클라우드/[커스텀만]둘 다 유지(-cloud 사본)/삭제) → PUT → lastSyncedAt 기록(state.json).
- 연결 상태: `SyncEngine.connectionStatus`(unknown/online/offline) + 마지막 확인 시각, "연결 테스트"는 결과 알럿(팝업).

## 서버 구현 메모

- Drizzle(libSQL): `lazyenv_users` / `lazyenv_environments`(pk user+recipe) / `lazyenv_custom_recipes`(pk user+recipe), 저널은 `lazyenv_drizzle_migrations` — **공유 Turso DB 공존을 위한 lazyenv_ 프리픽스 네임스페이스**(2026-07-18 결정). 마이그레이션: 셀프 호스트는 부팅 시, Vercel은 빌드 단계(`scripts/migrate.ts`)에서 실행.
- env: TURSO_DATABASE_URL(기본 file:local.db), TURSO_AUTH_TOKEN, JWT_SECRET(필수), GITHUB_CLIENT_ID/SECRET(없으면 OAuth 503 stub), PORT(25252), APP_CALLBACK_SCHEME(lazyenvironment), SERVER_BASE_URL(선택).
- 프로덕션 판정은 compose 시 `configureEnvironmentMode(env.NODE_ENV)`로 주입 env와 동기화(에러 details 숨김).
- 미검증: GitHub OAuth 실플로우(자격증명 필요), Vercel 배포.
