#if DEBUG
import Foundation

/// Marketing-only sample content, rendered through the shipping World API/UI.
/// This session intercepts every request locally; it has no credentials and
/// rejects writes. It is never registered with URLSession.shared.
enum AppStoreWorldScreenshotFixture {
    @MainActor
    static func makeService() -> RemoteWorldService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStoreWorldScreenshotProtocol.self]
        let client = SupabaseHTTPClient(
            config: SupabaseConfig(baseURL: URL(string: "https://screenshots.invalid")!, anonKey: "screenshot-fixture"),
            tokenProvider: nil,
            session: URLSession(configuration: configuration)
        )
        return RemoteWorldService(client: client, currentUserID: { nil })
    }
}

private final class AppStoreWorldScreenshotProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, url.host == "screenshots.invalid", request.httpMethod == "GET" else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let data = try Self.payload(for: url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}

    private nonisolated static func topicID(_ index: Int) -> String {
        String(format: "A55A5A55-2000-4000-8000-%012d", index)
    }

    private nonisolated static func payload(for url: URL) throws -> Data {
        let query = Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        let formatter = ISO8601DateFormatter()
        let now = Date()
        let isKorean = Locale.preferredLanguages.first?.hasPrefix("ko") == true
        func time(_ secondsAgo: Double) -> String { formatter.string(from: now.addingTimeInterval(-secondsAgo)) }
        let topicSpecs: [(String, String, String, String)] = isKorean ? [
            ("work", "주 4일 근무, 어떻게 생각해?", "🌿", "일과 삶의 균형, 여러분이 바라는 일주일은 어떤 모습인가요?"),
            ("tech", "AI와 함께하는 일상", "🤖", "기술이 바꾸는 우리의 일상. 기대와 고민을 나눠보세요."),
            ("entertainment", "자막을 넘어 통하는 이야기", "🎬", "다른 언어의 영화에서 나와 닮은 마음을 발견한 적 있나요?"),
            ("sports", "스포츠가 우리를 연결하는 순간", "⚽️", "응원하는 팀이 달라도, 함께 즐기는 순간에 점수를 남겨보세요."),
            ("society", "멀리 살아도 가까운 사이", "🌏", "서로 다른 곳에 사는 우리가 가까워지는 순간은 언제인가요?")
        ] : [
            ("work", "A four-day workweek?", "🌿", "What would a better balance between work and life look like for you?"),
            ("tech", "Everyday life with AI", "🤖", "Technology is changing our days. Share what excites you, and what gives you pause."),
            ("entertainment", "Stories beyond subtitles", "🎬", "Have you ever found a little of yourself in a film from somewhere else?"),
            ("sports", "The moments that unite us", "⚽️", "Different teams. One shared love of the game. How does that feel?"),
            ("society", "Far apart. Still close.", "🌏", "What helps you feel connected to people in other parts of the world?")
        ]
        // All people, reactions and aggregates below are illustrative samples.
        let samples: [(Int, String, String, Int, String)] = isKorean ? [
            (1, "Mina", "KR", 92, "하루의 여유가 생기면, 일할 때 더 집중할 수 있을 것 같아요."),
            (2, "Alex", "US", 82, "기술이 시간을 돌려준다면, 그 시간은 사람에게."),
            (3, "Haru", "JP", 88, "다른 언어의 영화에서 내 이야기를 발견했어요."),
            (1, "Noah", "GB", 85, "Different cities, the same wish for balance."),
            (4, "Sofia", "ES", 94, "서로 다른 팀을 응원해도, 함께 웃을 수 있으니까."),
            (5, "Lina", "DE", 89, "멀리 사는 친구와 오늘의 이야기를 나눌 때요."),
            (1, "Alex", "US", 78, "More time for life, more focus at work."),
            (1, "Haru", "JP", 64, "쉬는 날만큼, 함께 일하는 방식도 중요해요."),
            (1, "Sofia", "ES", 71, "서로의 속도를 존중하는 변화라면 좋아요."),
            (1, "Jun", "KR", 58, "같은 업무량이라면 먼저 일하는 방식부터 바꾸고 싶어요."),
            (1, "Lina", "DE", 88, "우리 팀에도 이런 선택지가 생겼으면!")
        ] : [
            (1, "Mina", "KR", 92, "A little more time to live. A little more energy to give."),
            (2, "Alex", "US", 82, "If tech gives us time back, let's spend it on people."),
            (3, "Haru", "JP", 88, "Different language. A story that felt just like mine."),
            (1, "Noah", "GB", 85, "Different cities, the same wish for balance."),
            (4, "Sofia", "ES", 94, "Rival teams, but we're all here for the same joy."),
            (5, "Lina", "DE", 89, "Sharing the little things with a friend far away."),
            (1, "Alex", "US", 78, "More time for life, more focus at work."),
            (1, "Haru", "JP", 64, "How we work together matters as much as time off."),
            (1, "Sofia", "ES", 71, "I like the idea of making room for different rhythms."),
            (1, "Jun", "KR", 58, "First, let's rethink the workload, not just the week."),
            (1, "Lina", "DE", 88, "I'd love to see our team give this a try!")
        ]
        let topics: [[String: Any]] = topicSpecs.enumerated().map { index, spec in
            let votes = samples.filter { $0.0 == index+1 }.map { $0.3 }
            let average = Int((Double(votes.reduce(0,+))/Double(votes.count)).rounded())
            return ["id": topicID(index+1), "category": spec.0, "title": spec.1,
                    "cover_emoji": spec.2, "subtitle": spec.3, "created_at": time(86_400),
                    "last_activity_at": time(180), "posts_count": votes.count, "global_score": average,
                    "score_delta": 0, "status": "live", "origin": "admin",
                    "score_low_label": isKorean ? "반대" : "Against",
                    "score_high_label": isKorean ? "찬성" : "In favor"]
        }
        let reactions: [[String: Any]] = samples.enumerated().map { index, sample in
            let spec = topicSpecs[sample.0-1]
            return ["id": String(format: "A55A5A55-3000-4000-8000-%012d", index+1),
                    "topic_id": topicID(sample.0), "value": sample.3, "comment": sample.4,
                    "is_anonymous": false, "country_code": sample.2, "created_at": time(Double((index+1)*180)),
                    "profiles": ["username": sample.1, "avatar_emoji": ""],
                    "topics": ["id": topicID(sample.0), "title": spec.1, "category": spec.0, "cover_emoji": spec.2]]
        }
        var rows: [[String: Any]]
        switch url.lastPathComponent {
        case "topics_feed":
            rows = topics
            if let value = query["id"] {
                rows = rows.filter { "eq.\(($0["id"] as! String).lowercased())" == value.lowercased() }
            }
        case "world_scores":
            rows = reactions
            if let value = query["topic_id"] {
                rows = rows.filter { "eq.\(($0["topic_id"] as! String).lowercased())" == value.lowercased() }
            }
            if let value = query["topics.category"] {
                rows = rows.filter { "eq.\(($0["topics"] as! [String: String])["category"]!)" == value }
            }
        case "topic_submission_notifications": rows = []
        default: throw URLError(.unsupportedURL)
        }
        let offset = Int(query["offset"] ?? "0") ?? 0
        let limit = Int(query["limit"] ?? "50") ?? 50
        return try JSONSerialization.data(withJSONObject: Array(rows.dropFirst(offset).prefix(limit)), options: [.sortedKeys])
    }
}
#endif
