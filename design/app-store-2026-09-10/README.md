# Scoor 앱스토어 제출용 스크린샷

2026-09-10 제작. 한국어 PNG 7장. 실제 Scoor 시뮬레이터 캡처를 사용한 편집 디자인입니다.

## 업로드 파일

`upload/ko-KR/` 아래 파일만 App Store Connect의 한국어 스크린샷에 등록합니다. 각 폴더에서 파일명 순서로 업로드하면 됩니다.

| 기기 | 크기 | 수량 | 순서 |
|---|---|---|---|
| iPhone 6.9인치 | 1320 × 2868 | 4장 | 점수 입력 → 기록 → 통계 → 달력 |
| iPad 13인치 | 2064 × 2752 | 3장 | 기록 → 통계 → 달력 |

PNG는 8비트 RGB, sRGB, 알파·투명도 없음으로 출력했습니다. `preview-*.png`는 검토용 전체 보기이므로 업로드하지 않습니다. 압축 파일에는 업로드 이미지와 이 안내서만 포함됩니다.

iPad 점수 입력 시트는 배경에 예시 커뮤니티 피드가 함께 나타나므로 제출 세트에서 제외했습니다. 개인 기록이 표시되는 전체 화면 3장을 사용했습니다.

## 디자인과 문구

브랜드 레드 `#CE3B22`, 차콜 `#0A0A0B`, 웜 화이트 `#FAF8F5`. 기존 Scoor 로고와 Pretendard를 사용했습니다. 한 장마다 두 줄 제목과 짧은 설명, 정면 기기 프레임을 배치했습니다. 화면 내 UI와 수치·문구는 캡처 그대로이며, AI로 재생성하거나 교체하지 않았습니다.

1. **오늘 하루, 몇 점인가요?** — 0부터 100까지, 나의 하루를 기록해요.
2. **점수와 한 줄로 남기는 오늘** — 그날의 점수와 이유를 함께 모아봐요.
3. **쌓인 기록에서 나를 발견해요** — 일별·주별·월별로 나의 흐름을 살펴요.
4. **하루하루 쌓이는 나만의 기록** — 달력에서 그날의 마음을 다시 만나보세요.

## 참고 자료

2026-09-10 한국 App Store의 iPhone 스크린샷을 직접 확인했습니다.

- [Threads](https://apps.apple.com/kr/app/threads/id6446901002): 검정 배경, 짧은 문구, 특정 단어 강조, 크게 배치한 앱 화면.
- [Instagram](https://apps.apple.com/kr/app/instagram/id389801252): 선명한 컬러 배경, 기능별 문구, 연속된 갤러리의 리듬.
- [X](https://apps.apple.com/kr/app/x/id333903271): 강한 명암 대비, 큰 제목과 기기 화면의 조합.
- [Apple 스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/): 기기별 허용 크기, 1~10장, PNG/JPEG 및 투명도 제한.

경쟁 앱의 로고·UI·사진·카피는 결과물에 넣지 않았습니다.

## 원본과 검증

- 원본: `raw/ko-KR/`. iPhone 17 Pro Max와 iPad Pro 13-inch (M5), iOS 26.5에서 각각 캡처했습니다.
- 기존 `ScoorAppStoreScreenshotsUITests/testKoreanScreenshots`를 실행했고 기기별 캡처 테스트가 통과했습니다.
- 앱의 DEBUG 전용 `-appstore-screenshot-fixture`에 있는 예시 개인 기록입니다. 실제 사용자 기록이나 실서비스의 활동 수치를 주장하지 않습니다.
- 첫 빌드는 Desktop 확장 속성 때문에 서명에 실패해 임시 빌드 경로로 옮겨 성공했습니다. iPad는 빌드를 재사용하고 병렬 테스트를 끈 상태에서 실행했습니다.
- 캡처 후 이번 작업에서 켠 두 시뮬레이터를 종료했습니다.
- `validation.json`에 출력 크기, PNG 형식, 투명도 및 파일 해시 검사 결과를 저장했습니다.
- 앱스토어 업로드·심사 제출은 실행하지 않았습니다. 이 산출물은 스크린샷 이미지 준비 범위입니다.

## 수정 및 재출력

`source/render.swift`에서 카피·색상·배치를 수정할 수 있습니다. macOS의 AppKit/Core Graphics로 한 장씩 순차 출력합니다. Pretendard가 설치되어 있지 않으면 시스템 폰트를 사용합니다. 저장소 루트에서 실행하세요.

```sh
swift -module-cache-path /tmp/scoor-artwork-module-cache design/app-store-2026-09-10/source/render.swift iphone-6.9
```

iPhone 출력이 끝난 뒤, iPad를 별도로 출력합니다.

```sh
swift -module-cache-path /tmp/scoor-artwork-module-cache design/app-store-2026-09-10/source/render.swift ipad-13
```

`source/extract.py`는 xcresult에서 내보낸 첨부 파일의 이름을 정리해 원본 폴더로 복사하는 도구입니다.
