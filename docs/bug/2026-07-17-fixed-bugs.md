# 수정된 버그 (2026-07-17 세션 — 릴리즈 앱 사용자 리포트 3건)

> 형식: 증상 / 원인 / 해결. 재발 시 이 해법을 먼저 적용.
> 3건 모두 사용자가 `/Applications`의 릴리즈 앱(v0.0.1)에서 발견. 상태 파일의 `lastRun` 로그와 실제 디렉토리 실측으로 원인 확정.

## 1. 앱을 다시 실행해도 메인 창이 안 뜸
- 증상: `startInMenuBar: true` 상태에서 앱을 켜면 메뉴바에만 상주(의도된 동작)하는데, Finder/Launchpad에서 **다시 열어도** 리스트 창이 나타나지 않음.
- 원인: `AppDelegate`에 `applicationShouldHandleReopen` 미구현 + `StatusBarController.openMainWindow`가 가시성 검사 없이 `canBecomeMain`만 보고 **오프스크린 메뉴바 크롬 창**(2560×30 등, isVisible=true·화면 밖 좌표)을 메인 창으로 오인해 `makeKeyAndOrderFront`만 하고 종료. 폴백(NSWorkspace.openApplication)은 reopen 이벤트를 다시 쏘는 구조라 무한 순환 위험도 있었음.
- 해결: (1) `applicationShouldHandleReopen` 구현 — 보이는 창이 없으면 `openMainWindow()` 호출. (2) `openMainWindow` 필터를 `isMiniaturized || (isVisible && canBecomeMain)`로 — **최소화 중엔 `canBecomeMain=false`** 라 `(isVisible || isMiniaturized) && canBecomeMain` 꼴은 최소화 창을 놓쳐 중복 창을 만든다(적대적 리뷰가 프로브로 실증). SwiftUI Settings 창(`com_apple_SwiftUI_Settings_window`, canBecomeMain=true)도 제외. (3) 폴백을 NSWorkspace 재실행 대신 **File▸New Window(⌘N) 메뉴 항목 `performActionForItem`** 으로 교체(설정 창 여는 기존 패턴과 동일 기법 — SwiftUI가 suppressed WindowGroup 창을 새로 생성). ⌘N 항목이 없으면(사용자 App Shortcuts 재할당 등) accessory로 복귀해 창 없는 Dock 앱으로 남지 않게 함. (4) 창 닫힘 250ms 지연 accessory 전환과 reopen의 레이스는 `reopenRequestIsRecent`(1초) 가드로 차단, 같은 판정을 `isMainWindowCandidate` 헬퍼로 공유(최소화 창 존재 시 accessory 전환 안 함). 검증: 창 없는 실행 중 상태에서 `open` 재실행 → 새 창 onscreen 확인.
- 교훈: `kCGWindowIsOnscreen`은 winid.swift 출력에서 `true/false`가 아니라 `0/1`로 찍힐 수 있음 — `grep 'onscreen=true'`는 거짓 음성. 직접 실행 시 `print`는 파일 리다이렉트에서 전부 버퍼링됨 → 계측은 stderr(`fputs`)로.

## 2. Python 설치 버튼이 아무것도 설치하지 못함
- 증상: python 레시피 Install 클릭 → 즉시 실패. 상태 파일 로그: `exit 127, no such file or directory: .../python/uv/bin/uv`.
- 원인: python(부모)의 installCommand가 `"$UV_INSTALL_DIR/uv" python install`로 **자식 레시피(uv)가 먼저 설치돼 있어야만 동작하는 역의존**. manualSteps로만 "uv 먼저"라고 안내하고 명령은 가드가 없었음.
- 해결: installCommand/updateCommand를 `[ -x "$UV_INSTALL_DIR/uv" ] || (mkdir -p "$UV_INSTALL_DIR" && curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh) && "$UV_INSTALL_DIR/uv" python install`로 — uv 없으면 자동 부트스트랩(설치 스크립트는 `UV_INSTALL_DIR` env 존중, 스크립트 1236행 확인). `UV_NO_MODIFY_PATH=1`은 부트스트랩이 사용자 rc(~/.zshrc·~/.zshenv·~/.profile)를 조용히 수정하는 걸 차단(적대적 리뷰 지적 — 앱의 "export 구문 복사" 철학과 충돌. `UV_UNMANAGED_INSTALL`은 `uv self update`를 깨므로 쓰지 말 것). `UV_CACHE_DIR`도 envVars에 추가해 다운로드 캐시까지 `$DEV_HOME/python/uv/cache`로 재배치. manualSteps[0] 문구 교체(+xcstrings ko/ja 동기). 검증: 클린 env 샌드박스 E2E — uv 부트스트랩(rc 0바이트 유지 확인) → CPython 3.14.6 설치 → detect/currentVersion 모두 exit 0.

## 3. pnpm 설치가 성공해도 "미설치"로 표시
- 증상: Install 실행은 exit 0(로그에 "Done in 2.3s using pnpm v11.13.1")인데 재감지 후에도 미설치 상태.
- 원인: pnpm v11 공식 install.sh는 `pnpm setup --force` 경유로 실행 파일을 **`$PNPM_HOME/bin/pnpm`** 에 넣는데(설치 스크립트가 ~/.zshrc에 쓰는 PATH도 `$PNPM_HOME/bin`), 레시피 감지 명령은 구 레이아웃 `$PNPM_HOME/pnpm`을 봄 — 경로 불일치. quarantine 가설은 실측으로 기각(바이너리 직접 실행 정상).
- 해결: detect/currentVersionCommand를 `"$PNPM_HOME/bin/pnpm" --version 2>/dev/null || "$PNPM_HOME/pnpm" --version` 이중 경로로(구 레이아웃 폴백 유지). 외부 후보 `~/Library/pnpm`도 동일 처리. manualSteps[0]의 PATH 안내를 `$PNPM_HOME/bin`으로 교체(+xcstrings ko/ja 동기). 검증: 실제 설치본에서 새 감지 명령 `11.13.1`/exit 0, 레거시 레이아웃 모의 폴백 exit 0, 앱 화면에서 pnpm "Installed 11.13.1" 확인. 참고: 스크립트 주석의 "~/.pnpm 기본값"은 macOS에선 사실이 아님 — PNPM_HOME 미설정 샌드박스 실측 결과 기본 위치는 `~/Library/pnpm/bin/pnpm`(기존 외부 후보 위치 유지가 정답).

## 4. Java(SDKMAN) 설치 실패 — Bash 3.2 (v0.0.2 이후 사용자 리포트)
- 증상: Install 클릭 → exit 1. 로그: "SDKMAN requires Bash 4 or higher, but you are running Bash 3.2.57".
- 원인: 레시피 검증(07-14) 이후 SDKMAN 업스트림이 설치 스크립트에 **Bash 4+ 요구**를 추가. `curl | bash`가 macOS 기본 `/bin/bash`(3.2.57)로 실행되어 설치가 시작 전에 중단. 런타임 `sdk` 함수는 zsh 지원이라 설치 스크립트만 문제.
- 해결: installCommand를 `([ -x /opt/homebrew/bin/bash ] || /opt/homebrew/bin/brew install bash) && curl -s https://get.sdkman.io | /opt/homebrew/bin/bash`로 — Homebrew bash를 절대경로로 사용, 없으면 자동 설치(Homebrew 미설치면 명확히 실패 → manualSteps에 Homebrew 선행 안내 추가, xcstrings ko/ja 동기, 286키). updateCommand는 설치 스크립트를 안 돌리므로 무변경. 검증: 샌드박스 E2E(설치→detect `sdk version` exit 0→`sdk current java` exit 0) + 실 DEV_HOME 설치(Java 25.0.3-tem) + 앱 화면 "Installed" 확인.
- 교훈: `lastVerified` 이후에도 업스트림 설치 스크립트는 언제든 계약을 바꾼다 — 설치 실패 재현 시 state.json의 `lastRun.logText`부터 볼 것(원인이 그대로 찍혀 있음).

## 5. 서버 게스트 카탈로그 드리프트 (경로 감사 중 발견)
- 증상: 라이브 서버(`/api/catalog`)가 이날 수정 전의 깨진 레시피(구 sdkman `| bash`, 구 pnpm `$PNPM_HOME/pnpm` 감지, uv 부트스트랩 없는 python)를 서빙.
- 원인: 카탈로그가 `app/.../builtin-recipes.json`과 `server/data/catalog.json` **2곳에 사본**으로 존재 — 앱 쪽만 수정하면 서버가 구버전을 계속 서빙.
- 해결: 서버 사본을 앱 카탈로그로 복사(diff IDENTICAL 확인) + 서버 tsc·31 테스트 그린. 재발 방지 규칙을 PROCESS 알려진 제약에 명문화(앱 카탈로그 수정 시 서버 사본 동시 복사, 후속: SSOT화/CI 체크).
