# App Privacy 신고안

제출 대상: Scoor 1.0 / 6810264505. 2026-09-15 App Store Connect에 8개 항목 저장·게시 완료.

| 데이터 | 수집 근거 | 목적 | 사용자 연결 | 추적 |
|---|---|---|---|---|
| 이름 | Apple/Google 프로필 이름·계정 메타데이터, AuthService.applyAuthenticatedIdentity | 앱 기능 | 예 | 아니요 |
| 이메일 주소 | SupabaseAuthClient 로그인/가입 | 앱 기능 | 예 | 아니요 |
| 사용자 ID | 모든 서버 레코드의 user_id/author_id | 앱 기능 | 예 | 아니요 |
| 기타 사용자 콘텐츠 | scores, posts, comments, topic_submissions | 앱 기능 | 예 | 아니요 |
| 민감 정보 | 정치 토픽과 연결된 world_scores | 앱 기능 | 예 | 아니요 |
| 제품 상호 작용 | post_likes, 신고/차단, 제안 알림 읽음 상태 | 앱 기능 | 예 | 아니요 |
| 기타 진단 데이터 | 운영 API Gateway 로그의 Scoor/OS 버전, 오류 상태, auth_user | 앱 기능 | 예 | 아니요 |
| 고객 지원 | 문의 이메일 및 인앱 신고 내용 | 앱 기능 | 예 | 아니요 |

현재 출시 앱은 광고 SDK·IDFA·타사 추적을 사용하지 않으며 선택 사진은 기기 내 저장입니다. 운영 API Gateway 로그에서 Scoor 앱 버전·OS 버전·응답 상태·요청 시각·경로와 auth_user가 함께 보관됨을 확인했습니다. 별도 crash/analytics SDK는 없습니다. 사용자 승인: 기존 7개 + 기타 진단 데이터, 앱 기능/연결/추적 없음. 단순 일기 점수를 의료 데이터라고 일괄 신고하지 않습니다. 위치정보는 GPS로 수집하지 않습니다.

자동 승인 검토가 항목별 정확성 근거가 부족하다는 이유로 UI 선택을 거절했습니다. 위 표는 실제 코드와 공개 방침을 대조한 검토 가능한 신고안입니다.
