//
//  SocialSeed.swift
//  Scoor
//
//  소셜 레이어의 시드 데이터 + 페이지네이션 + 오버레이 로직(순수 함수).
//  - 백엔드가 없으므로 MockFeed/MockWorld 시드를 "데이터 소스"로 사용하되,
//    페이지를 결정적(deterministic)으로 합성해 무한 스크롤을 흉내 낸다.
//  - 영속된 좋아요/댓글 수를 시드 위에 덧입히는(overlay) 로직을 한 곳에 모은다.
//  - 결정적 UUID 덕분에 합성 페이지의 글에도 좋아요/댓글이 안정적으로 붙는다.
//

import Foundation

enum SocialSeed {

    // MARK: - Deterministic UUID

    /// 문자열로부터 안정적인 UUID 생성(FNV-1a 64bit를 두 번 돌려 16바이트 구성).
    /// Swift 기본 Hasher는 실행마다 시드가 바뀌므로 직접 구현한다.
    static func deterministicUUID(_ seed: String) -> UUID {
        func fnv1a(_ s: String) -> UInt64 {
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in s.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x100000001b3
            }
            return hash
        }
        let a = fnv1a(seed)
        let b = fnv1a("salt::" + seed)
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        for i in 0..<8 { bytes.append(UInt8((a >> (UInt64(i) * 8)) & 0xff)) }
        for i in 0..<8 { bytes.append(UInt8((b >> (UInt64(i) * 8)) & 0xff)) }
        let t = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuid: t)
    }

    // MARK: - Feed pagination

    /// 페이지 0은 실제 시드(안정 id), 1+ 페이지는 결정적 합성 클론.
    static func feedPage(page: Int, pageSize: Int) -> [FeedEntry] {
        let base = MockFeed.entries
        guard page > 0 else { return Array(base.prefix(pageSize)) }
        // 합성: 시드를 반복하되 id/시간/카운트를 페이지별로 변형.
        return (0..<pageSize).map { i in
            let src = base[(page * pageSize + i) % base.count]
            let key = "feed::\(page)::\(i)::\(src.id.uuidString)"
            let minutesBack = 180 + page * 90 + i * 7
            return FeedEntry(
                id: deterministicUUID(key),
                identity: src.identity,
                countryFlag: src.countryFlag,
                city: src.city,
                postedAt: Date().addingTimeInterval(-Double(minutesBack) * 60),
                score: src.score,
                message: src.message,
                primaryMood: src.primaryMood,
                extraTags: src.extraTags,
                weather: src.weather,
                reactions: scaledReactions(src.reactions, page: page)
            )
        }
    }

    /// 월드 글 페이지네이션 — 동일 전략.
    static func worldPostsPage(page: Int, pageSize: Int) -> [WorldPost] {
        let base = MockWorld.posts
        guard page > 0 else { return Array(base.prefix(pageSize)) }
        return (0..<pageSize).map { i in
            let src = base[(page * pageSize + i) % base.count]
            let key = "world::\(page)::\(i)::\(src.id.uuidString)"
            let minutesBack = 200 + page * 80 + i * 9
            return WorldPost(
                id: deterministicUUID(key),
                identity: src.identity,
                topic: src.topic,
                postedAt: Date().addingTimeInterval(-Double(minutesBack) * 60),
                myScore: src.myScore,
                message: src.message,
                reactions: scaledReactions(src.reactions, page: page)
            )
        }
    }

    /// 합성 페이지는 카운트를 살짝 줄여 "더 오래된/덜 인기" 느낌을 준다. 내 반응은 초기화.
    private static func scaledReactions(_ r: PostReactions, page: Int) -> PostReactions {
        let factor = max(1, 4 - page)
        return PostReactions(
            likes: max(0, r.likes / factor),
            comments: max(0, r.comments / factor),
            reposts: max(0, r.reposts / factor),
            empathyTotal: max(0, r.empathyTotal / factor),
            likedByMe: false,
            empathyByMe: nil
        )
    }

    static let topics: [WorldTopic] = MockWorld.topics

    // MARK: - Overlay (영속 좋아요/댓글 수 덧입히기)

    /// 좋아요/댓글 수를 시드 reactions 위에 덧입힌다.
    /// - likeMap: postId → 내 좋아요 여부(영속). 없으면 시드값 사용.
    /// - extraComments: postId → 추가된(영속) 댓글 수.
    static func overlay(_ reactions: PostReactions,
                        postId: UUID,
                        likeMap: [UUID: Bool],
                        extraComments: [UUID: Int]) -> PostReactions {
        var r = reactions
        let seedLiked = reactions.likedByMe
        let baseLikes = reactions.likes - (seedLiked ? 1 : 0)   // 내 좋아요 제외 기준선
        let liked = likeMap[postId] ?? seedLiked
        r.likedByMe = liked
        r.likes = max(0, baseLikes + (liked ? 1 : 0))
        r.comments = reactions.comments + (extraComments[postId] ?? 0)
        return r
    }

    static func applyFeedOverlays(_ entries: [FeedEntry],
                                  likeMap: [UUID: Bool],
                                  extraComments: [UUID: Int]) -> [FeedEntry] {
        entries.map { e in
            var copy = e
            copy.reactions = overlay(e.reactions, postId: e.id, likeMap: likeMap, extraComments: extraComments)
            return copy
        }
    }

    static func applyWorldOverlays(_ posts: [WorldPost],
                                   likeMap: [UUID: Bool],
                                   extraComments: [UUID: Int]) -> [WorldPost] {
        posts.map { p in
            var copy = p
            copy.reactions = overlay(p.reactions, postId: p.id, likeMap: likeMap, extraComments: extraComments)
            return copy
        }
    }

    // MARK: - Discover (탐색 시드)

    /// MockFeed.identities + 점수 시드로 탐색용 사용자 카드 생성.
    static func discoverUsers(following: Set<String>) -> (popular: [DiscoverUser], recommended: [DiscoverUser]) {
        // 동일 이름의 익명 중복을 피하려고 비익명만 사용하고, 이름별로 1명씩.
        let named = MockFeed.identities.filter { !$0.isAnonymous }
        var seen = Set<String>()
        let unique = named.filter { seen.insert($0.name).inserted }

        let flags = ["🇰🇷", "🇯🇵", "🇺🇸", "🇪🇺", "🇰🇷", "🇫🇷", "🇰🇷", "🇩🇪", "🇦🇺"]
        let taglines = [
            "오늘도 한 줄 남기는 중",
            "감정 기록 152일째",
            "조용히 응원하는 사람",
            "새벽 감성 담당",
            "스포츠에 진심",
            "회복하는 중",
            "직장인의 하루",
            "데이터로 보는 내 기분",
            "여기 어딘가에서"
        ]

        let users: [DiscoverUser] = unique.enumerated().map { (idx, identity) in
            let avg = 60 + ((identity.avatarSeed * 7 + idx * 11) % 38)   // 60~97
            let posts = 12 + ((identity.avatarSeed * 13 + idx * 29) % 240)
            let followers = 80 + ((identity.avatarSeed * 137 + idx * 91) % 9_000)
            return DiscoverUser(
                id: deterministicUUID("discover::\(identity.name)::\(identity.avatarSeed)"),
                identity: identity,
                tagline: taglines[idx % taglines.count],
                averageScore: avg,
                postCount: posts,
                followers: followers,
                regionFlag: flags[idx % flags.count],
                isFollowing: following.contains(identity.name)
            )
        }

        // 인기: 팔로워 많은 순. 추천: 아직 팔로우 안 한 사람 우선 + 활동량.
        let popular = users.sorted { $0.followers > $1.followers }
        let recommended = users
            .filter { !following.contains($0.identity.name) }
            .sorted { $0.postCount > $1.postCount }
        return (popular, recommended)
    }

    /// 추천 콘텐츠 — 가장 뜨거운 토픽들에서 생성.
    static func recommendedContent() -> [RecommendedContent] {
        MockWorld.topics
            .sorted { $0.postsCount > $1.postsCount }
            .prefix(6)
            .map { t in
                RecommendedContent(
                    id: deterministicUUID("content::\(t.title)"),
                    title: t.title,
                    subtitle: "\(t.category.label) · \(CompactCount.format(t.postsCount))명 참여",
                    glyph: t.emoji,
                    score: t.globalScore,
                    heatLabel: t.heat.label
                )
            }
    }
}
