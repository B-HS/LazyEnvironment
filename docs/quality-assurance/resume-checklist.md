# 검증 체크리스트 (세션 재개·릴리스 전)

> 각 항목: 확인 방법 → 기대 결과. 수행 여부를 체크박스로 갱신한다.

## 기본 그린 상태 (모든 작업 후 필수)

- [x] 앱 테스트: `cd app && xcodebuild -project LazyEnvironment.xcodeproj -scheme LazyEnvironment -configuration Debug -derivedDataPath .build/DerivedData test` → 47 tests / 9 suites SUCCEEDED (2026-07-14 리네임 후 통과)
- [x] 서버: `cd server && bunx tsc --noEmit && bun test` → clean + 31 pass (2026-07-14 통과)
- [x] 앱 실행: `./start.sh` → 리스트 렌더·감지 동작 (2026-07-14 통과)

## 카탈로그/i18n 변경 시

- [ ] 카탈로그 디코드·불변식: 앱 테스트의 BuiltinCatalogTests 포함 통과
- [ ] 콘텐츠-번역 동기: builtin-recipes.json의 summary/manualSteps/label 각각이 xcstrings 키로 존재(python 대조 0 miss)
- [ ] `plutil -convert json -o /dev/null app/LazyEnvironment/Resources/Localizable.xcstrings`
- [ ] 라이브 렌더: settings.json language를 ko/ja로 강제 → 창 캡처(utils/session-tools.md 절차) → 원복(사용자는 ko)

## UI 변경 시

- [ ] 라이트 + `-force-dark` 캡처
- [ ] 메뉴바: `-debug-show-popover` 캡처 / 설정: `-debug-open-settings` 캡처

## 동기화 변경 시

- [ ] 서버 계약 E2E(utils/session-tools.md 스니펫): health→catalog(23)→dev auth→PUT/GET 왕복(LWW: 무변경 행 updatedAt 보존)→401
- [ ] SyncModelsTests 픽스처가 실제 응답과 여전히 일치하는지(계약 변경 시 픽스처 재캡처)

## 사용자 입회 필요 (자동화 불가 — 미완)

- [ ] 메뉴바 좌/우클릭, 자동 시작 토글, 관리자 비밀번호 프롬프트(go /usr/local/go 제거)
- [ ] GitHub OAuth 실로그인(OAuth 앱 생성 후) 및 두 기기 충돌 시트
- [ ] 실제 레시피 설치 E2E(파괴적)
- [ ] 커스텀 레시피 에디터 시트 조작
