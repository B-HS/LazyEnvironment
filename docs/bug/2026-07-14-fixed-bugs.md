# 수정된 버그 (2026-07-14 세션)

> 형식: 증상 / 원인 / 해결. 재발 시 이 해법을 먼저 적용.

## 1. 인터랙티브 셸 버전 오염 ("bun add v1.3.0")
- 증상: nvm·codex 등 인터랙티브 레시피의 버전이 rc 배너 문자열로 표시.
- 원인: `zsh -ic` 실행 시 사용자 rc 출력이 stdout 첫 줄을 차지.
- 해결: `RecipeEngine` — 인터랙티브 레시피는 **마지막** 비공백 줄, 비인터랙티브는 첫 줄 파싱.

## 2. nvm/sdkman 관리 설치 오탐
- 증상: 관리 경로(~/development/js/nvm)가 비었는데 "설치됨(관리)"로 표시.
- 원인: 사용자 rc가 NVM_DIR을 자기 경로(~/.nvm)로 재수출 → 감지 명령의 `$NVM_DIR` 참조가 rc 값으로 평가.
- 해결: 카탈로그 명령에 `export NVM_DIR="$DEV_HOME/js/nvm" &&` 명시 + `[ -s "$DEV_HOME/..." ]` 직접 검사.

## 3. ShellRunner stderr 간헐 유실 (플레이크)
- 증상: 테스트에서 stderr가 드물게 빈 문자열.
- 원인: terminationHandler와 파이프 readabilityHandler 경쟁 — 종료 시점에 핸들러를 nil로 만들고 readToEnd하는 방식의 레이스.
- 해결: **파이프 EOF(빈 availableData)를 완료 신호로** 삼고, stdout EOF+stderr EOF+종료코드 3조건이 모두 모였을 때만 스트림 종료(`RunCompletion` 락). 5회 연속 통과 확인.

## 4. Settings가 메인 창을 여는 버그
- 증상: 메뉴바 Settings/기어 → 설정 대신 리스트 창.
- 원인: macOS 15 SwiftUI 앱에서 `showSettingsWindow:` 셀렉터 무동작 → 앱 활성화만 발생.
- 해결: 앱 메뉴에서 keyEquivalent `,`(Cmd) 항목을 찾아 `performActionForItem` 실행(폴백으로 구 셀렉터 유지).

## 5. 메뉴바 팝오버 세로 늘어짐/패딩 이상
- 원인: NSHostingController 기본 사이징이 SwiftUI 고유 크기를 안 따름.
- 해결: `hostingController.sizingOptions = [.preferredContentSize]`.

## 6. DiskUsageScanner의 cooperative pool 블로킹
- 원인: actor 메서드 안에서 `waitUntilExit`/`readDataToEndOfFile` 동기 블로킹 → Swift concurrency 스레드 점유.
- 해결: `withCheckedContinuation` + `DispatchQueue.global(qos: .utility)`로 블로킹 격리(타입도 struct화).

## 7. (설계 결함 예방 기록) 디스크 중복 합산
- python 레시피 신설 때 uv가 `$DEV_HOME/python/uv` 전체를, python이 하위 `pythons`를 선언하면 이중 합산 — uv 경로를 bin/cache/tools/tool-bin으로 좁혀 회피. 부모/자식 경로 동시 선언 금지 규칙화(project-map §불변 규칙 6).
