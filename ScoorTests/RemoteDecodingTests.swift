//
//  RemoteDecodingTests.swift
//  ScoorTests
//
//  실제 Supabase 응답으로 하는 디코딩 테스트.
//
//  픽스처는 배포된 프로젝트에서 그대로 캡처한 것이다. 지금까지 이 프로젝트에서
//  나온 결함이 대부분 "서버가 주는 형태 ≠ 클라이언트가 기대한 형태"였고, 그건
//  빌드도 유닛 테스트도 통과시키면서 런타임에만 조용히 실패한다. 그 간극을
//  메우는 것이 이 파일의 목적이다.
//

import XCTest
@testable import Scoor

final class RemoteDecodingTests: XCTestCase {

    /// `GET /rest/v1/topics_feed?select=*` 실응답 (2026-07-26 캡처).
    /// 주목할 점: 타임스탬프가 **마이크로초 6자리** + `+00:00` 오프셋이다.
    /// Postgres가 이렇게 내려주며, ISO8601DateFormatter는 소수점 3자리까지만
    /// 받아들이기 때문에 순진하게 파싱하면 여기서 깨진다.
    private let topicsFeedJSON = """
    [
      {
        "id": "16a61c4f-b665-45b6-afa4-bc7791922adc",
        "category": "students",
        "title": "시험 기간 멘탈",
        "subtitle": "공부하는 사람들의 실시간 감정",
        "cover_emoji": "📚",
        "status": "live",
        "created_at": "2026-07-26T04:08:08.277851+00:00",
        "posts_count": 0,
        "global_score": 0,
        "score_delta": 0,
        "last_activity_at": "2026-07-26T04:08:08.277851+00:00"
      },
      {
        "id": "79fa6cb6-adbe-4127-850a-fb95bd094107",
        "category": "love",
        "title": "지금 내 연애 온도",
        "subtitle": "설렘부터 권태까지",
        "cover_emoji": "❤️",
        "status": "live",
        "created_at": "2026-07-26T04:08:08.277851+00:00",
        "posts_count": 12,
        "global_score": 64,
        "score_delta": -9,
        "last_activity_at": "2026-07-26T05:00:00+00:00"
      }
    ]
    """

    func testTopicsFeedDecodesFromLiveServerShape() throws {
        let rows = try SupabaseHTTPClient.decoder.decode(
            [TopicRow].self, from: Data(topicsFeedJSON.utf8)
        )
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].title, "시험 기간 멘탈")
        XCTAssertEqual(rows[0].category, "students")
        XCTAssertEqual(rows[1].globalScore, 64)
        XCTAssertEqual(rows[1].scoreDelta, -9)
    }

    /// 마이크로초와 초 단위 타임스탬프가 한 응답 안에 섞여 와도 둘 다 읽어야 한다.
    /// Postgres는 소수부가 0이면 아예 생략한다.
    func testDecodesBothMicrosecondAndWholeSecondTimestamps() throws {
        let rows = try SupabaseHTTPClient.decoder.decode(
            [TopicRow].self, from: Data(topicsFeedJSON.utf8)
        )
        XCTAssertEqual(
            rows[0].createdAt.timeIntervalSince1970,
            1785038888.277, accuracy: 0.01,
            "마이크로초 타임스탬프를 파싱하지 못했다"
        )
        XCTAssertEqual(
            rows[1].lastActivityAt.timeIntervalSince1970,
            1785042000, accuracy: 0.01,
            "소수부 없는 타임스탬프를 파싱하지 못했다"
        )
    }

    func testTopicRowMapsToDomain() throws {
        let rows = try SupabaseHTTPClient.decoder.decode(
            [TopicRow].self, from: Data(topicsFeedJSON.utf8)
        )
        let topic = try XCTUnwrap(rows[1].toDomain())
        XCTAssertEqual(topic.category, .love)
        XCTAssertEqual(topic.globalScore, 64)
        XCTAssertEqual(topic.emoji, "❤️")
        XCTAssertEqual(topic.postsCount, 12)
    }

    /// 갓 만들어진 토픽은 등락보다 "새 토픽"이 우선한다 — 콜드 스타트 구간에는
    /// 참여를 부르는 라벨이 더 유용하고, 표본 몇 개짜리 등락은 노이즈다.
    func testFreshTakesPriorityOverDeltaForNewTopics() throws {
        let topic = try XCTUnwrap(
            try SupabaseHTTPClient.decoder
                .decode([TopicRow].self, from: Data(topicsFeedJSON.utf8))[1]
                .toDomain()
        )
        XCTAssertEqual(topic.heat, .fresh, "오늘 만들어진 토픽은 fresh여야 한다")
    }

    /// 충분히 오래된 토픽에서는 등락이 그대로 드러나야 한다.
    func testEstablishedTopicShowsFalling() throws {
        let json = """
        [{"id":"79fa6cb6-adbe-4127-850a-fb95bd094107","category":"love","title":"오래된 토픽",
          "subtitle":null,"cover_emoji":"❤️","status":"live",
          "created_at":"2026-07-01T00:00:00+00:00","posts_count":120,
          "global_score":40,"score_delta":-9,"last_activity_at":"2026-07-26T05:00:00+00:00"}]
        """
        let topic = try XCTUnwrap(
            try SupabaseHTTPClient.decoder.decode([TopicRow].self, from: Data(json.utf8))[0].toDomain()
        )
        XCTAssertEqual(topic.heat, .falling)
    }

    /// 서버가 이 빌드가 모르는 카테고리를 내려주면 해당 토픽만 조용히 버린다 —
    /// 목록 전체가 깨지는 것보다 낫다.
    func testUnknownCategoryIsDroppedNotCrashed() throws {
        let json = """
        [{"id":"16a61c4f-b665-45b6-afa4-bc7791922adc","category":"quantum_physics",
          "title":"미래의 카테고리","subtitle":null,"cover_emoji":"🛸","status":"live",
          "created_at":"2026-07-26T04:08:08.277851+00:00","posts_count":0,
          "global_score":0,"score_delta":0,"last_activity_at":"2026-07-26T04:08:08.277851+00:00"}]
        """
        let rows = try SupabaseHTTPClient.decoder.decode([TopicRow].self, from: Data(json.utf8))
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows[0].toDomain())
    }

    // MARK: - Reactions

    /// `world_scores` + 임베딩된 `profiles`. 익명 행은 프로필이 조인돼 내려와도
    /// 화면에 이름이 새어나가면 안 된다.
    func testAnonymousReactionDoesNotLeakUsername() throws {
        let json = """
        [
          {"id":"11111111-1111-1111-1111-111111111111","value":88,"comment":"좋았다",
           "is_anonymous":false,"country_code":"KR","created_at":"2026-07-26T04:08:08.277851+00:00",
           "profiles":{"username":"yul","avatar_emoji":"🌙"}},
          {"id":"22222222-2222-2222-2222-222222222222","value":20,"comment":"힘들다",
           "is_anonymous":true,"country_code":"KR","created_at":"2026-07-26T04:08:08+00:00",
           "profiles":{"username":"secret_person","avatar_emoji":"🌑"}}
        ]
        """
        let rows = try SupabaseHTTPClient.decoder.decode(
            [TopicReactionRow].self, from: Data(json.utf8)
        )
        XCTAssertEqual(rows[0].identity.name, "yul")
        XCTAssertFalse(rows[0].identity.isAnonymous)

        XCTAssertEqual(rows[1].identity.name, "익명")
        XCTAssertTrue(rows[1].identity.isAnonymous)
        XCTAssertNotEqual(rows[1].identity.name, "secret_person")
    }

    /// 아바타 색 시드는 1...9 범위여야 하고, 같은 행이면 실행을 다시 해도 같아야
    /// 한다. Hashable의 hashValue는 프로세스마다 달라져 색이 깜빡인다.
    func testAvatarSeedIsStableAndInRange() throws {
        let json = """
        [{"id":"11111111-1111-1111-1111-111111111111","value":50,"comment":null,
          "is_anonymous":false,"country_code":null,"created_at":"2026-07-26T04:08:08+00:00",
          "profiles":{"username":"a","avatar_emoji":null}}]
        """
        let first = try SupabaseHTTPClient.decoder.decode(
            [TopicReactionRow].self, from: Data(json.utf8)
        )[0].identity.avatarSeed
        let second = try SupabaseHTTPClient.decoder.decode(
            [TopicReactionRow].self, from: Data(json.utf8)
        )[0].identity.avatarSeed

        XCTAssertEqual(first, second)
        XCTAssertTrue((1...9).contains(first), "시드 \(first)가 팔레트 범위(1...9)를 벗어났다")
    }

    // MARK: - Scores

    /// 동기화가 읽는 `scores` 행. `reason`/`mood`/`deleted_at`은 null일 수 있다.
    func testScoreRowDecodesWithNulls() throws {
        let json = """
        [{"user_id":"33333333-3333-3333-3333-333333333333","day":"2026-07-26","value":72,
          "reason":null,"mood":null,"client_updated_at":"2026-07-26T04:08:08.277851+00:00",
          "deleted_at":null}]
        """
        let rows = try SupabaseHTTPClient.decoder.decode([ScoreRow].self, from: Data(json.utf8))
        XCTAssertEqual(rows[0].value, 72)
        XCTAssertEqual(rows[0].day, "2026-07-26")
        XCTAssertNil(rows[0].reason)
        XCTAssertNil(rows[0].deletedAt)
    }

    func testScoreRowRoundTripsThroughEncoder() throws {
        let row = ScoreRow(
            userId: UUID(),
            day: "2026-07-26",
            value: 88,
            reason: "좋은 하루",
            mood: "calm",
            clientUpdatedAt: Date(timeIntervalSince1970: 1785038888.277),
            deletedAt: nil
        )
        let data = try SupabaseHTTPClient.encoder.encode([row])
        let decoded = try SupabaseHTTPClient.decoder.decode([ScoreRow].self, from: data)
        XCTAssertEqual(decoded[0].day, row.day)
        XCTAssertEqual(decoded[0].value, row.value)
        XCTAssertEqual(decoded[0].reason, row.reason)
        XCTAssertEqual(
            decoded[0].clientUpdatedAt.timeIntervalSince1970,
            row.clientUpdatedAt.timeIntervalSince1970,
            accuracy: 0.01,
            "업로드한 시각이 그대로 돌아오지 않으면 last-write-wins 비교가 틀어진다"
        )
    }
}
