//
//  RecapSnapshotTests.swift
//  ScoorTests
//
//  공유 카드/스토리 캔버스를 실제로 렌더해 스크린샷 첨부로 남긴다(Task 3 산출물).
//  RecapShareService.render는 실제 공유 시트가 쓰는 바로 그 뷰를 렌더한다.
//

import XCTest
import SwiftUI
@testable import Scoor

@MainActor
final class RecapSnapshotTests: XCTestCase {

    private func attach(_ image: UIImage?, _ name: String) {
        guard let image, let data = image.pngData() else {
            return XCTFail("render nil for \(name)")
        }
        let att = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    func testRenderRecapCardLight() {
        attach(RecapShareService.render(RecapCardView(data: .placeholder, scheme: .light)),
               "10-recap-card-light")
    }

    func testRenderRecapCardDark() {
        attach(RecapShareService.render(RecapCardView(data: .placeholder, scheme: .dark)),
               "11-recap-card-dark")
    }

    func testRenderStoryLight() {
        attach(RecapShareService.renderStory(.placeholder, scheme: .light),
               "12-recap-story-light")
    }

    func testRenderStoryDark() {
        attach(RecapShareService.renderStory(.placeholder, scheme: .dark),
               "13-recap-story-dark")
    }
}
