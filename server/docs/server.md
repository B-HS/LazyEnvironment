# lazy-environment sync 백엔드 — 운영 문서

Bun + Hono + Turso/libSQL(drizzle-orm) 기반 동기화 백엔드. macOS 앱의 GitHub 로그인·프로필 동기화·공개 카탈로그 서빙만 담당한다. 설치 스크립트 실행은 전적으로 사용자 Mac에서 일어나며, 서버는 어떤 명령도 실행하지 않는다.

## 빠른 시작 (로컬, 계정 불요)

```bash
cd server
bun install
JWT_SECRET=dev-secret bun run dev
```

- `TURSO_DATABASE_URL` 미설정 시 로컬 파일 DB(`file:local.db`)를 사용한다.
- 서버는 부팅 시 `drizzle/`의 마이그레이션을 **자동 적용**(drizzle-orm/libsql 마이그레이터)하므로 별도 DB 준비가 필요 없다.
- GitHub 자격증명 없이도 `GET /api/catalog` 와 `POST /api/auth/dev`(development 전용)로 전체 흐름을 로컬에서 검증할 수 있다.

## 스크립트

| 스크립트 | 동작 |
|----------|------|
| `bun run dev` | `--watch` 개발 서버 |
| `bun run start` | 프로덕션 실행 |
| `bun run test` | bun:test 전체 |
| `bun run typecheck` | `tsc --noEmit` |
| `bun run db:generate` | 스키마 변경 시 `drizzle-kit generate` 로 새 마이그레이션 생성 |

## 환경 변수

`.env.example` 를 복사해 채운다. **실제 `.env` 는 절대 커밋하지 않는다**(`.gitignore` 에 이미 포함, `.env.example` 만 placeholder 로 유지).

| 변수 | 필수 | 기본값 | 설명 |
|------|:---:|--------|------|
| `TURSO_DATABASE_URL` | 아니오 | `file:local.db` | libSQL/Turso 접속 URL. 로컬은 `file:...`, 원격은 `libsql://<db>.turso.io` |
| `TURSO_AUTH_TOKEN` | 원격만 | — | 원격 Turso DB용 토큰. 로컬 파일 DB 에서는 불필요 |
| `JWT_SECRET` | **예** | — | 세션 JWT(HS256) 서명 시크릿. 길고 무작위인 문자열 |
| `GITHUB_CLIENT_ID` | 아니오 | — | GitHub OAuth 앱 client id. 없으면 `/auth/github*` 는 `SERVICE_NOT_CONFIGURED` 반환 |
| `GITHUB_CLIENT_SECRET` | 아니오 | — | GitHub OAuth 앱 client secret |
| `PORT` | 아니오 | `25252` | 리슨 포트 |
| `NODE_ENV` | 아니오 | `development` | `development`\|`production`\|`test`. `/api/auth/dev` 게이팅·에러 details 노출 여부 |
| `APP_CALLBACK_SCHEME` | 아니오 | `lazyenvironment` | 앱이 등록한 커스텀 URL 스킴(OAuth 콜백 리다이렉트 대상) |
| `SERVER_BASE_URL` | 아니오 | — | OAuth `redirect_uri` origin 강제 오버라이드. 미설정 시 요청 origin 에서 유도 |

## API 계약 (고정)

봉투: 성공 `{"success":true,"data":<payload>}`, 실패 `{"success":false,"error":{"code","message"}}` (`details` 는 비프로덕션에서만). 모든 응답은 JSON. 인증 실패 401(`UNAUTHORIZED`), 미존재 경로 404(`NOT_FOUND`).

| 메서드 · 경로 | 인증 | 설명 |
|---------------|:---:|------|
| `GET /api/health` | — | `{ status: "ok" }` |
| `GET /api/catalog` | — | `{ recipes: <data/catalog.json>, updatedAt: <파일 mtime ISO> }` |
| `GET /auth/github` | — | GitHub authorize 로 302. state 를 short-lived httpOnly 쿠키에 저장 |
| `GET /auth/github/callback?code&state` | — | state 검증 → code 교환 → 유저 upsert → JWT 발급 → `${APP_CALLBACK_SCHEME}://auth#token=<jwt>&login=<login>` 로 302. 실패 시 `...#error=<code>` |
| `POST /api/auth/dev` | — | **development 전용**. body `{ login }`. dev 유저(`dev_<login>`) 생성 후 `{ token, login }`. production 은 404 |
| `GET /api/profile` | Bearer JWT | `{ userId, updatedAt, environments[], customRecipes[] }` (타임스탬프 ISO) |
| `PUT /api/profile` | Bearer JWT | body `{ environments[], customRecipes[] }`. 유저 행 전체 교체(없는 행 삭제, 나머지 upsert). 내용이 바뀐 행만 `updated_at=now`, 안 바뀐 행은 기존 타임스탬프 보존. 반환은 GET 과 동일 형태 |

프로필 동기화 정책: push+pull, **recipe 단위 last-write-wins**. 서버는 병합하지 않고 클라이언트가 보낸 전체 상태로 교체하며, 변경된 행만 새 타임스탬프를 찍는다.

## 데이터 모델

- `users(id, login, created_at)` — `id` 는 GitHub 유저 id 문자열(dev 유저는 `dev_<login>`).
- `environments(user_id, recipe_id, pinned_version, custom_path, enabled, updated_at)` — 복합 PK `(user_id, recipe_id)`.
- `custom_recipes(user_id, recipe_id, recipe_json, updated_at)` — 복합 PK `(user_id, recipe_id)`. `recipe_json` 은 canonical(키 정렬) 직렬화로 저장해 변경 감지를 안정화한다.

카탈로그(`data/catalog.json`)는 앱의 `builtin-recipes.json`(레시피 23종) 사본이다. 갱신 시 이 파일을 교체하면 `GET /api/catalog` 가 새 `updatedAt`(파일 mtime)과 함께 서빙한다.

## GitHub OAuth 앱 설정

1. GitHub → Settings → Developer settings → OAuth Apps → **New OAuth App**.
2. **Authorization callback URL** 을 서버 origin 기준으로 지정한다.
   - 로컬 개발: `http://127.0.0.1:25252/auth/github/callback` (포트를 바꿨다면 그 포트로).
   - 배포: `https://<your-origin>/auth/github/callback`.
3. 발급된 Client ID/Secret 을 `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` 에 넣는다.
4. `redirect_uri` 는 들어온 요청 origin 에서 자동 유도된다(프록시 뒤에서 Host 가 다르면 `SERVER_BASE_URL` 로 오버라이드). GitHub 앱에 등록한 콜백 URL 과 반드시 일치해야 한다.
5. scope 는 `read:user` 만 요청한다.

## Turso(원격 DB)로 전환

로컬 파일 DB 대신 원격 Turso 를 쓰려면 두 변수만 채우면 된다(코드 변경 없음).

```bash
TURSO_DATABASE_URL=libsql://<db-name>-<org>.turso.io
TURSO_AUTH_TOKEN=<turso-token>
```

- 스키마는 서버 부팅 시 자동 마이그레이션된다.
- 이 프로젝트는 Vercel 프로젝트 env 에 Turso 자격증명을 보관한다. **시크릿을 노출하지 않고** 로컬로 가져오려면 `server/` 에서:
  ```bash
  vercel link          # 최초 1회, 이 디렉터리를 Vercel 프로젝트에 연결
  vercel env pull .env # 원격 env 를 로컬 .env 로 내려받음
  ```
  `.env` 는 `.gitignore` 되어 있으므로 커밋되지 않는다. `.env.example` 에는 placeholder 만 유지한다.

## 셀프 호스팅 체크리스트

누구나 자기 인스턴스를 띄우고 앱의 "서버 URL" 을 그 origin 으로 지정할 수 있다(단일 고정 origin 을 가정하지 않는다).

1. **GitHub OAuth 앱을 직접 만든다.** callback URL = `https://<your-origin>/auth/github/callback` (로컬은 `http://127.0.0.1:25252/auth/github/callback`).
2. `JWT_SECRET` 을 길고 무작위인 값으로 설정한다.
3. DB 선택: 간단히 `file:` 로컬 파일(단일 인스턴스), 또는 `TURSO_DATABASE_URL` + `TURSO_AUTH_TOKEN` 으로 원격 Turso.
4. 프록시 뒤라 서버가 보는 Host 가 공개 origin 과 다르면 `SERVER_BASE_URL=https://<your-origin>` 를 설정한다.
5. `bun install && bun run start` 로 기동한다(마이그레이션 자동 적용).
6. macOS 앱 설정에서 서버 URL 을 `https://<your-origin>` 으로 지정하면 로그인·동기화가 그 인스턴스로 향한다.

## 아키텍처 (backend.md 계층)

`route`(HTTP 경계·DTO 검증·에러 throw) → `service`(도메인 로직, HTTP/DB 모름) → `*ServiceDb`(compose 가 drizzle 로 인라인 구현). 의존성은 `compose/` 에서 조립하고, 라우터는 `route/index.ts` 의 `createRouter` 가 묶는다. 모든 핸들러는 `withErrorHandling` 으로 감싸고, 인증 라우트는 `withAuth` HOF 로 게이팅한다. 에러는 3-파일 체계(`lib/error-code.ts`·`lib/error-message.ts`·`lib/error.ts`)의 `createAppError` 로만 던진다. 환경 변수는 `getEnv()` 싱글톤(zod safeParse)로만 접근한다.
