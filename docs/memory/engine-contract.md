# 실행 엔진 계약 (레시피 저작 시 필수 참조)

> 카탈로그(builtin-recipes.json)나 커스텀 레시피를 작성·수정할 때 이 계약을 벗어나면 안 된다.
> 원 출처: PRD §9·§10.1·§16.1. 구현: `app/LazyEnvironment/Sources/Engine/`.

## 셸 실행 2경로

- **기본(비인터랙티브)**: `/bin/zsh -c '<script>'` + **클린 env**: `PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`, HOME, USER, SHELL, LANG, TMPDIR, `TERM=dumb`, `DEV_HOME=<확장된 값>`, + 레시피 envVars(사전 확장). node/cargo 등은 PATH에 없음 → 바이너리는 env 경로(`"$CARGO_HOME/bin/rustup"`) 또는 절대경로로 참조.
- **인터랙티브(`requiresInteractiveShell: true`)**: `/bin/zsh -ic` + 프로세스 env 상속 + 레시피 envVars. **셸 함수 도구(nvm, sdkman)에만** 사용. 사용자 rc가 NVM_DIR/SDKMAN_DIR을 덮어쓰므로 **명령에 `export VAR=... &&` 명시 + init 파일 explicit source** 필수.
- **관리자(`adminActions` / 후보 `uninstallRequiresAdmin`)**: `/usr/bin/osascript -e 'do shell script "..." with administrator privileges'` → 시스템 비밀번호 프롬프트. root의 `$HOME=/var/root`이므로 **스크립트는 절대경로만**(엔진이 $HOME/$DEV_HOME을 사전 확장하긴 함). 출력은 완료 후 일괄(스트리밍 안 됨).

## 토큰 (유일한 템플릿)

| 토큰 | 해석 |
|------|------|
| `{{latestTag}}` / `{{latestVersion}}` | sourcePinning으로 해석(github-latest-tag→releases/latest tag_name, go-dev-json→첫 version, pinned→그 값). stable-url은 해석 불가 |
| `{{version}}` | 사용자 핀 우선, 없으면 latest |

토큰 있는 명령은 해석 가능한 sourcePinning 필수(핀만으로도 {{version}}은 동작). 카탈로그 불변식 테스트가 강제함.

## 감지 규칙

- `detectCommand` exit 0 = 설치됨. 관리 감지 실패 시 `externalCandidates` 순서대로 폴백 → `설치됨 (외부)`.
- `currentVersionCommand` stdout에서 비인터랙티브=첫 비공백 줄, **인터랙티브=마지막 비공백 줄**(rc 배너 오염 대응).
- 외부 후보 명령은 레시피 envVars에 의존 금지($HOME/절대경로만). 후보 uninstall이 없으면 제거 버튼 미노출(관리 경로 fallback 안 함 — 빈 삭제 오해 방지).
- 시스템 파이썬 스텁(/usr/bin/python3)을 감지 대상으로 삼지 말 것(PRD §9.6). PATH 기반 `command -v`는 클린 PATH에 /usr/bin이 포함됨을 유의.

## 안전 규칙

- `rm -rf`는 반드시 `"${VAR:?}"` 가드. sudo 직접 호출 금지(관리자 플래그 사용). TTY 프롬프트 금지(비대화식 플래그·auto-answer 사용).
- $HOME 밖 쓰기 금지 예외: /Applications(Docker.app), /opt/homebrew(공식 스크립트), 관리자 플래그 명령의 /usr/local 등.
- 디스크 경로는 레시피 간 부모/자식 중복 선언 금지(중복 합산 방지 — 캐시는 경로 문자열 단위 dedupe).

## 스키마 요약 (PRD §10.1 + 확장)

필수: id, displayName, category(language|runtime|mobile|editor|ai-agent|custom). 선택: summary, detect/currentVersion/install/update/uninstallCommand, envVars, diskUsagePaths, requiresInteractiveShell, brewFallbackRisk, supportsVersionPin, sourcePinning, lastVerified, manualSteps, installActionTitle/updateActionTitle(예: Prepare/Relocate/Clean Up), externalCandidates[{label, detectCommand, currentVersionCommand?, uninstallCommand?, uninstallRequiresAdmin?, diskUsagePaths}], adminActions([install|update|uninstall]), parentId(계층).

## 관리 디렉토리 레이아웃 (일관성 필수)

js: `$DEV_HOME/js/{nvm,pnpm,bun}` · java: `$DEV_HOME/java/{sdkman,gradle(GRADLE_USER_HOME, android와 공유)}` · rust: `$DEV_HOME/rust/{rustup,cargo}` · go: `$DEV_HOME/go/{toolchain,gopath}` · python(uv): `$DEV_HOME/python/uv/{bin,cache,tools,tool-bin}` + pythons(=python 레시피 소유) · ruby: `$DEV_HOME/ruby/{rbenv,cocoapods}` · android: `$DEV_HOME/android/sdk` · tools: `$DEV_HOME/tools/neovim` · ai: `$DEV_HOME/ai/{claude,codex}` · xcode: `$DEV_HOME/xcode/*`
