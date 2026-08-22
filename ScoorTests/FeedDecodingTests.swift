//
//  FeedDecodingTests.swift
//  ScoorTests
//
//  `public.feed_posts` 응답 디코딩 + 도메인 매핑 (spec-13 §3.3).
//
//  RemoteDecodingTests와 같은 이유로 존재한다: 이 프로젝트에서 나온 결함은
//  대부분 "서버가 주는 형태 ≠ 클라이언트가 기대한 형태"였고, 그건 빌드도 유닛
//  테스트도 통과시키면서 런타임에만 조용히 실패한다.
//
//  픽스처의 형태는 supabase/migrations/20260822000007_feed.sql의 뷰 정의를 그대로
//  따른다 — 공식 글은 author_name = 'Scoor', author_id = null이고, 익명 사용자
//  글은 author_name도 null이다.
//

import XCTest
@testable import Scoor

final class FeedDecodingTests: XCTestCase {

    private let feedJSON = """
    [
      {
        "id": "aaaaaaaa-0000-0000-0000-000000000001",
        "is_official": true,
        "score": 72,
        "message": "오늘 하루는 몇 점인가요?",
        "primary_mood": "calm",
        "extra_moods": [],
        "weather": null,
        "is_anonymous": false,
        "country_code": null,
        "city": null,
        "created_at": "2026-08-22T04:08:08.277851+00:00",
        "is_hidden": false,
        "deleted_at": null,
        "author_name": "Scoor",
        "author_emoji": null,
        "author_id": null,
        "likes_count": 3,
        "comments_count": 1,
        "liked_by_me": true
      },
      {
        "id": "aaaaaaaa-0000-0000-0000-000000000002",
        "is_official": false,
        "score": 88,
        "message": "좋은 하루였다",
        "primary_mood": "happy",
        "extra_moods": ["healing", "love"],
        "weather": "sunny",
        "is_anonymous": false,
        "country_code": "KR",
        "city": "Seoul",
        "created_at": "2026-08-22T05:00:00+00:00",
        "is_hidden": false,
        "deleted_at": null,
        "author_name": "alice",
        "author_emoji": "🌙",
        "author_id": "11111111-1111-1111-1111-111111111111",
        "likes_count": 0,
        "comments_count": 0,
        "liked_by_me": false
      },
      {
        "id": "aaaaaaaa-0000-0000-0000-000000000003",
        "is_official": false,
        "score": 40,
        "message": "말하기 어려운 하루",
        "primary_mood": "lonely",
        "extra_moods": [],
        "weather": null,
        "is_anonymous": true,
        "country_code": null,
        "city": null,
        "created_at": "2026-08-22T06:00:00+00:00",
        "is_hidden": false,
        "deleted_at": null,
        "author_name": null,
        "author_emoji": null,
        "author_id": null,
        "likes_count": 2,
        "comments_count": 0,
        "liked_by_me": false
      }
    ]
    """

    private func decode() throws -> [FeedPostRow] {
        try SupabaseHTTPClient.decoder.decode([FeedPostRow].self, from: Data(feedJSON.utf8))
    }

    func testFeedPostsDecodeFromViewShape() throws {
        let rows = try decode()
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows[0].isOfficial)
        XCTAssertEqual(rows[1].extraMoods, ["healing", "love"])
        XCTAssertEqual(rows[1].likesCount, 0)
        XCTAssertNil(rows[2].authorName)
    }

    /// 공식 글은 "Scoor" 이름 + 배지로 그려져야 한다. 이 플래그가 떨어지면
    /// 운영자가 쓴 글이 일반 사용자 글과 구별되지 않는다 (P0-1).
    func testOfficialPostKeepsItsBadgeAndName() throws {
        let entry = try decode()[0].toDomain()
        XCTAssertTrue(entry.isOfficial)
        XCTAssertEqual(entry.identity.name, "Scoor")
        XCTAssertFalse(entry.identity.isAnonymous)
        XCTAssertNil(entry.authorId, "공식 글에는 차단할 작성자가 없다")
        XCTAssertTrue(entry.reactions.likedByMe)
        XCTAssertEqual(entry.reactions.comments, 1)
    }

    func testUserPostMapsMoodsWeatherAndFlag() throws {
        let entry = try decode()[1].toDomain()
        XCTAssertFalse(entry.isOfficial)
        XCTAssertEqual(entry.primaryMood, .happy)
        XCTAssertEqual(entry.extraTags, [.healing, .love])
        XCTAssertEqual(entry.weather, .sunny)
        XCTAssertEqual(entry.countryFlag, "🇰🇷")
        XCTAssertEqual(entry.city, "Seoul")
        XCTAssertNotNil(entry.authorId, "실명 글은 신고 시트에서 차단까지 제안할 수 있어야 한다")
    }

    /// 익명 글에서 작성자를 알아낼 수 있으면 익명이 아니다. 뷰가 author_id를
    /// null로 내리고, 클라이언트도 그것을 그대로 유지해야 한다.
    func testAnonymousPostExposesNoAuthor() throws {
        let entry = try decode()[2].toDomain()
        XCTAssertTrue(entry.identity.isAnonymous)
        XCTAssertNil(entry.authorId)
    }

    /// 서버 글에는 아바타 색 시드 필드가 없어서 이름에서 만든다. 같은 사람이
    /// 화면을 새로 그릴 때마다 다른 색이면 안 된다.
    func testAvatarSeedIsStableAndInRange() {
        XCTAssertEqual(AvatarSeed.from("alice"), AvatarSeed.from("alice"))
        XCTAssertNotEqual(AvatarSeed.from("alice"), AvatarSeed.from("bob"))
        for name in ["alice", "bob", "Scoor", "익명", ""] {
            let seed = AvatarSeed.from(name)
            XCTAssertTrue((1...9).contains(seed), "\(name) → \(seed)는 팔레트 범위를 벗어난다")
        }
    }

    func testCountryFlagHandlesMissingAndMalformedCodes() {
        XCTAssertEqual(CountryFlag.emoji("KR"), "🇰🇷")
        XCTAssertEqual(CountryFlag.emoji("us"), "🇺🇸")
        XCTAssertNil(CountryFlag.emoji(nil))
        XCTAssertNil(CountryFlag.emoji("KOR"))
        XCTAssertNil(CountryFlag.emoji(""))
    }

    /// 마이크로초 6자리(Postgres 기본)와 소수부 없는 형태가 한 응답에 섞여 온다.
    func testDecodesBothTimestampShapes() throws {
        let rows = try decode()
        XCTAssertEqual(rows[0].createdAt.timeIntervalSince1970, 1787371688.277, accuracy: 0.01)
        XCTAssertEqual(rows[1].createdAt.timeIntervalSince1970, 1787374800, accuracy: 0.01)
    }
}
