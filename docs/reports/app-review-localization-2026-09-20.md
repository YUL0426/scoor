# App Review 2.1(a) 언어 혼용 검토 — 2026-09-20

## 확인한 원인

심사 메시지는 1.0(4), iPad Air 11-inch (M3), iPadOS 27.0에서 영어와 한국어가 섞여 핵심 기능을 사용하기 어려웠다고 설명한다. iPad 전용 레이아웃 부족을 직접 지적한 메시지는 아니다.

- 같은 버전의 로컬 Xcode 아카이브 `Scoor 9-16-26, 1.19 PM.xcarchive`는 `UIDeviceFamily = [1]`이다. App Store에 업로드된 바이너리와의 바이트 단위 동일성까지 확인한 것은 아니다.
- 해당 아카이브의 영어 `Localizable.strings` 500개 값 중 **103개에 한국어가 남아 있다**. 예: 차단, 이메일 가입 안내, 기록 완료, 공유 문구. `오늘 기록하기` 등 일부 한국어 키는 영어 번들에 없어 원문으로 표시될 수 있다.
- 현재 문자열 카탈로그에서는 영어 누락 또는 한국어 잔존 **218개 항목**을 발견했다. 이전 정적 검사와 화면 검사가 JA/FR/PT-BR 중심이어서 영어 누락을 잡지 못했다.
- 최초 운영 서버 조회에서 공개 토픽 5개와 초안 1개의 제목·설명이 한국어로만 제공되고 있었다. 후속 수정으로 한국어 원문을 유지하며 7개 언어 번역을 운영 DB에 반영했다. 상세 내용은 [운영 토픽 현지화 보고서](topic-localization-2026-09-20.md)를 참고한다.

## iPad에서 심사한 이유

iPhone 전용 대상 설정은 iPad 네이티브 UI 지원을 제외하는 설정이다. iPad의 iPhone 호환 모드 실행과 심사까지 제외하지 않는다. Apple App Review 팀의 [공식 안내](https://developer.apple.com/forums/thread/817078)도 이를 명시한다. iPad 스크린샷 요구와 iPad에서의 호환 실행은 구분해야 한다.

## 수정

- 영어 218개 항목을 보완하고 한국어 원문을 보존했다. 서식 자리표시자도 검사했다.
- Home 빈 상태, 기록 입력, My Page, 설정, 팔로우, 신고, 토픽 제안 및 재평가 등 조건에 따라 달라지는 문구를 명시적으로 현지화했다.
- 서버의 기본 점수 설명 `부정적/긍정적`, `반대/찬성`은 화면에서 현지화한다. 운영 토픽 제목·설명·점수 기준은 서버의 언어별 번역을 사용하며, 사용자 작성 글은 원문을 유지한다.
- 문자열 카탈로그뿐 아니라 실제 컴파일된 영어 번들의 한국어 잔존 여부를 검사하는 회귀 테스트를 추가했다.
- 영어 가입·약관/개인정보 안내·개인 기록 저장·재실행 복원·설정·World·점수 입력 화면 검사를 추가했다.
- 영어 UI 수정 시 빌드 번호를 5로 올렸으며, 운영 토픽 현지화까지 포함한 최종 재제출 후보는 **1.0(6)**이다. iPhone 전용 설정과 빨간 시작 화면은 유지한다.

## 검증 범위

- 문자열 카탈로그 **659개**: 영어 fallback, JA/FR/PT-BR 자리표시자 및 약관 번역 원문 연결 검사 통과. Release에서 추출한 현지화 키도 카탈로그에 존재한다.
- 전체 단위 테스트 **155개 중 150개 통과, 5개 서버 통합 테스트 건너뜀, 실패 0개**. 새 테스트는 실제 영어 번들의 한국어 잔존과 사용자 정의 점수 설명 보존을 확인한다.
- iPhone 17 Pro / iPad Air 11-inch (M4), iOS/iPadOS **26.5**에서 영어 UI 테스트 실행. iPad는 iPhone 호환 모드다. 심사 기기인 M3 / 27.0과는 차이가 있다.
- **기기별 2개 흐름 통과**: 영어 가입·약관·개인정보 안내 → Home/World/알림 빈 상태 → 73점과 한 줄 저장 → 앱 재실행 후 복원 → 설정, 그리고 영어 World fixture → 토픽 상세 → 0~9 키패드의 44pt 이상 크기·화면 내 위치·입력 가능 여부·기본 점수 설명 번역. UI에 노출된 텍스트/버튼의 한국어 잔존 검사와 화면 캡처를 포함한다.
- [iPhone 최종 결과](/Users/yul/Desktop/scoor-workspace/release/review-2026-09-20/iphone-final.xcresult), [iPad 가입·저장·복원 통과 결과](/Users/yul/Desktop/scoor-workspace/release/review-2026-09-20/ipad-final.xcresult), [iPad World 최종 통과 결과](/Users/yul/Desktop/scoor-workspace/release/review-2026-09-20/ipad-world.xcresult). iPad 결과는 두 실행으로 나뉜다. 초기 실패는 테스트의 한국어 고정 기대값, 짧은 초기 전환 대기, 설정 목록 스크롤 및 호환 모드 좌표 가정을 보완해 해결했다. 최초 실패 로그도 같은 폴더에 보존했다.
- 서명된 Release **1.0(5)** 아카이브 생성 및 코드 서명 검증 통과. `UIDeviceFamily = [1]`, 서버/Google 설정 포함. 실제 영어 번들 **615개 값 중 한국어 잔존 0개**. Release 실행 파일에 Debug fixture 주소·실행 플래그·테스트 인증 이메일이 없음을 확인했다.
- [Release 아카이브](/Users/yul/Desktop/scoor-workspace/release/Scoor-2026-09-20-English-review.xcarchive), [아카이브 검사 결과](/Users/yul/Desktop/scoor-workspace/release/review-2026-09-20/archive-verification.json), [기존 빌드 4 증거](/Users/yul/Desktop/scoor-workspace/release/review-2026-09-20/submitted-build-4-audit.json).

위 빌드 5는 영어 UI 수정 시점의 검증 결과다. 운영 토픽 현지화까지 포함한 최신 아카이브는 [1.0(6)](/Users/yul/Desktop/scoor-workspace/release/Scoor-2026-09-20-Localized-topics.xcarchive)이며 [후속 검증 결과](topic-localization-2026-09-20.md)를 참고한다.

아카이브는 Apple Development 서명 상태다. Xcode Organizer의 Distribute App → App Store Connect 단계에서 배포 처리해야 한다. 업로드나 심사 제출은 실행하지 않았다.

자동 UI 테스트는 서버 설정을 비운 빌드에서 테스트용 로그인을 사용한다. World 검사는 네트워크 요청을 가로채는 Debug fixture를 사용하며 운영 서버로 글이나 점수를 제출하지 않는다. 실제 Apple/Google OAuth 로그인, 운영 서버 쓰기 및 심사 기기의 iPadOS 27.0 실기기 검증을 대체하지 않는다.

## 재심사 설명 시 주의할 점

“iPhone 전용이므로 iPad 심사는 불필요하다”는 답변으로 문제를 해결할 수 없다. 영어 UI와 운영 토픽 번역을 포함한 빌드 6을 연결하고, 사용자 작성 콘텐츠만 원문으로 표시되는 동작과 구분해 설명해야 한다.

아래는 수정된 빌드를 업로드하고 검증 내용을 확인한 뒤 사용할 답변 초안이다. Apple에 전송하지 않았다.

> Thank you for the review. We found missing English UI translations that caused some controls and guidance to appear in Korean when English was selected. We have corrected these translations in the updated build, including the recording flow, settings, moderation actions, and standard topic score labels.
>
> In version 1.0 (6), editorial topic titles, descriptions, score labels, and topic search now follow the app language. We added translations for all existing editorial topics in English, Japanese, Simplified Chinese, German, French, Brazilian Portuguese, and Spanish, while preserving the Korean originals. User-written content remains in its original language.
>
> Scoor targets iPhone, and we understand that it can also run on iPad in iPhone compatibility mode. We tested the English onboarding, private score recording and persistence, and topic score input layout on iPhone and iPad simulators running iOS/iPadOS 26.5. Please review the updated build. If a particular screen still prevents use, please share the screen and steps so we can investigate further.
