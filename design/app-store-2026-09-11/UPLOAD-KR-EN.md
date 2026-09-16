# SCOOR App Store screenshots — Korean + English

2026-09-11 · iPhone 6.9-inch · 1320 × 2868 px · opaque RGB PNG

## 업로드 파일

| 대상 | App Store Connect 언어 | 폴더 | 수량 |
|---|---|---|---:|
| 국내용 | Korean | `upload/ko-KR/iphone-6.9/` | 5장 |
| 해외 영어 공용 | English (U.S.) | `upload/en-US/iphone-6.9/` | 5장 |

각 언어의 iPhone 6.9-inch 스크린샷 영역에 해당 폴더의 PNG를 01–05 순서로 업로드합니다. 미리보기 합본 이미지는 제출하지 않습니다.

App Store Connect는 스크린샷을 **언어별 현지화**로 관리합니다. 국가, 사용자 언어, 등록된 현지화, 기본 언어에 따라 표시 언어가 결정되므로, 한국어/영어 두 세트를 추가하는 것만으로 모든 해외 사용자에게 영어가 고정되는 것은 아닙니다. 해외 기본 화면도 영어로 운영하려면 현재 기본 언어와 기존 현지화를 확인해야 합니다. 이번 작업에서는 계정 설정 변경, 실제 업로드, 심사 제출을 실행하지 않았습니다.

Apple 안내: [현지화 관리](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/), [표시 언어 기준](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/), [스크린샷 업로드](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/).

## 5장 구성

| 순서 | 국내용 | 해외용 | 역할 |
|---:|---|---|---|
| 01 | 오늘 하루, 몇 점인가요? | How was your day? | 개인 점수 |
| 02 | 세상의 토픽을 함께 발견해요 | Explore the world. One topic at a time. | 월드 토픽 발견 |
| 03 | 같은 토픽, 다양한 시선. | One topic. Many perspectives. | 월드의 다양한 관점 |
| 04 | 멀리 있어도, 이어지는 공감. | Different places. Shared feelings. | 월드의 공감과 연결 |
| 05 | 나의 하루도, 차곡차곡. | Your days, worth keeping. | 개인 기록 |

해외용은 영어권 공용 문구와 영어 토픽·반응을 사용합니다. 세계 각지의 가상 인물과 일·문화·기술·스포츠·관계 토픽을 통해 연결을 표현했습니다. 사용량 수치는 로컬 예시 반응에서 계산했으며, 월드 3장 하단에 예시 콘텐츠임을 표시했습니다.

## 원본 및 검수

- 국내용 PNG 5장과 기존 국내용 ZIP은 변경하지 않았습니다. 기존 `validation.json`의 SHA-256과 일치하는지 검사합니다.
- 해외용은 실제 영어 앱 UI에서 촬영한 원본 PNG 5장을 `raw/en-US/iphone-6.9/`에 보관했습니다. 실제 앱 화면의 글자를 이미지 위에서 바꿔 그리지 않았습니다.
- 촬영 과정에서 발견한 메뉴·검색·시간·카테고리·기록·공유 안내 번역 누락은 앱 코드와 문자열 카탈로그에 반영했습니다. 한국어 문자열도 유지했습니다. 앱 전 화면의 다국어 QA 완료를 의미하지는 않습니다.
- 영어 캡처 테스트 `testEnglishWorldStoryScreenshots`가 최종 빌드에서 통과했습니다. 결과: `/tmp/scoor-store-world-english-v2.xcresult`.
- 모든 출력물의 크기, RGB 8-bit, 불투명 여부, 색상 프로파일, ZIP 무결성을 검사합니다. 이미지 문구 넘침은 렌더러에서도 검사합니다.
- 제작은 빌드 → 시뮬레이터 한 대에서 순차 촬영 → 종료 → 이미지 렌더링 순서로 진행했습니다.
- 이번 두 언어 패키지는 iPhone용입니다. 기존 iPad 지원 설정은 변경하지 않았습니다. 국내 원본의 세부 출처 및 iPad 관련 사항은 `README.md`를 참고하세요.

## 재생성

저장소 루트에서 한 번에 한 언어만 실행합니다.

```sh
swift -module-cache-path /tmp/scoor-artwork-module-cache design/app-store-2026-09-11/source/render.swift iphone-6.9 en-US
python3 design/app-store-2026-09-11/source/validate_bilingual_package.py
```

`Scoor-AppStore-World-ko-KR-en-US.zip`은 두 언어 통합본이며, `Scoor-AppStore-World-en-US.zip`은 해외용만 포함합니다. 기존 `Scoor-AppStore-World-ko-KR.zip`은 국내용입니다.
