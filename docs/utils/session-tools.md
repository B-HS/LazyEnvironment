# 세션 도구·재사용 자산 (2026-07-14 세션)

> 이 세션(AI 주도 구축)에서 만들었거나 확립한 도구·패턴. 다음 세션에서 그대로 재사용.

## 앱 검증 도구 (클릭 자동화 불가 환경용)

### 창 ID 찾기 + 창 단위 캡처

접근성 권한 없이 앱 화면을 검증하는 표준 절차:

```bash
# 1) 창 나열 (스크립트는 세션 스크래치에 있었음 — 아래 내용으로 재생성)
swift winid.swift            # → id=NNNNN layer=0 onscreen=true bounds=...
# 2) 캡처 (메인 창=layer 0, 메뉴바 아이템=layer 25 38x24, 팝오버=layer 25 ~360폭)
screencapture -x -o -l<ID> out.png
```

winid.swift (CGWindowListCopyWindowInfo로 앱 소유 창 나열 — **오너명은 "Lazy Environment" 공백 포함**):

```swift
import CoreGraphics
import Foundation
guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else { exit(1) }
for window in list {
    guard let owner = window["kCGWindowOwnerName"] as? String, owner.lowercased().contains("lazy") else { continue }
    print("id=\(window["kCGWindowNumber"] ?? 0) layer=\(window["kCGWindowLayer"] ?? 0) onscreen=\(window["kCGWindowIsOnscreen"] ?? false) bounds=\(window["kCGWindowBounds"] ?? [:])")
}
```

### QA 런치 인자 (앱에 영구 내장)

`-force-dark`(다크 강제) · `-debug-show-popover`(2초 후 팝오버) · `-debug-open-settings`(2초 후 설정 창) · `-debug-open-main`(2초 후 메인 창 열기) · `-debug-close-windows`(3초 후 메인 창 전부 닫기 — 창 없는 상주 상태 재현). 새 시트/창 검증이 필요하면 같은 패턴으로 AppDelegate에 인자 추가.

### 창 검증 주의 (2026-07-17 확립)

- winid.swift의 `onscreen`은 `true/false`가 아니라 `1/0`으로 출력될 수 있음 — `grep 'onscreen=true'` 금지, 값 자체를 눈으로 확인.
- 앱 바이너리 직접 실행 시 `print`(stdout)는 파일 리다이렉트에서 전부 버퍼링되어 유실됨 — 계측 출력은 `fputs(..., stderr)`.
- reopen 이벤트 검증: 실행 중 앱에 `open <번들>` 재호출. 창 없는 상태는 `-debug-close-windows`로 재현(Saved Application State 삭제 불필요).

### 로케일 강제

`~/Library/Application Support/LazyEnvironment/settings.json`의 `language`를 바꾸고 재실행(검증 후 원복 — 사용자는 ko 사용 중).

### 다크모드 검증 주의

`defaults write -g AppleInterfaceStyle` / per-app 동명 키는 **동작 안 함** — `-force-dark` 인자를 쓸 것. osascript 시스템 이벤트는 접근성 권한 타임아웃.

## 카탈로그·i18n 편집 패턴

- xcstrings/builtin-recipes.json은 **python3 json 편집**이 표준(들여쓰기 2, ensure_ascii=False). 검증: `plutil -convert json -o /dev/null`(이 머신 plutil -lint는 JSON 거부).
- 카탈로그 대수술은 스크립트 작성→실행(예: 계층화 패치 — python/pip/npm 신설+re-parent를 멱등 스크립트로).
- **콘텐츠 문자열 수정 시 xcstrings 키 동기 필수** — 검증 스니펫: 각 recipe의 summary/manualSteps/label이 xcstrings에 키로 존재하는지 python으로 대조(0 miss 확인).

## 멀티에이전트 패턴 (실사용·재사용 가능)

> 사용자 규칙: 서브에이전트는 Opus + effort max, 지휘·핵심은 메인 모델 직접.

- **catalog-and-tests 워크플로** (가장 재사용 가치 높음): 그룹별 작성(schema 강제 출력) → 레시피별 적대적 검증(WebFetch로 URL 실검증 포함) → 이슈만 수정 → 메인이 취합·통합. 스크립트는 세션 디렉토리에 저장됐었음 — 새 세션에서는 패턴만 재현하면 됨(프롬프트에 engine-contract.md + PRD §9 참조 지시). API 스톨로 일부 그룹 실패 시 **resumeFromRunId 재실행이 캐시로 나머지를 재사용**함.
- **콘텐츠 보강 에이전트**: 원문 백업→필드 diff로 "지정 필드만 변경" 증명→번역 커버리지 0-miss 검증까지 에이전트가 자체 수행하게 지시.
- **번역 에이전트**: 키 byte-identical 유지, 포맷 지정자 개수 대조, 빌드+lproj 엔트리 수 검증을 프롬프트에 명시. **파일 단독 소유**(다른 작업과 xcstrings 동시 편집 금지 — 충돌).
- **서버 빌드 에이전트**: 컨벤션 문서 경로 + **고정 API 계약**을 프롬프트에 동결시켜 클라이언트와 병렬 개발. 이후 backend-convention-reviewer로 교차 검증(리뷰 결과는 맹신 금지 — getDbCredentials 오탐 사례).
- **병렬 빌드 시 derivedDataPath 분리**(-derivedDataPath .build/DerivedData-<이름>).

## 서버 검증 스니펫

```bash
cd server && NODE_ENV=development JWT_SECRET=dev TURSO_DATABASE_URL=file:e2e.db PORT=25299 bun src/index.ts &
curl -s localhost:25299/api/health
TOKEN=$(curl -s -X POST localhost:25299/api/auth/dev -H 'Content-Type: application/json' -d '{"login":"e2e"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['token'])")
curl -s localhost:25299/api/profile -H "Authorization: Bearer $TOKEN"   # PUT/GET 왕복으로 LWW 확인
pkill -f "bun src/index.ts"; rm -f e2e.db*
```
