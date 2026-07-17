//
//  RecapShareTests.swift
//  ScoorTests
//
//  리캡 이미지 렌더링(ImageRenderer) 로직 테스트.
//  실제 저장/공유/인스타 경로는 시뮬레이터에서 수동 검증.
//

import XCTest
import SwiftUI
@testable import Scoor

@MainActor
final class RecapShareTests: XCTestCase {

    func testRenderLightCardProducesImage() {
        let img = RecapShareService.render(RecapCardView(data: .placeholder, scheme: .light))
        XCTAssertNotNil(img, "라이트 카드 렌더 결과가 nil이면 안 된다")
        if let img { XCTAssertGreaterThan(img.size.width, 0) }
    }

    func testRenderDarkCardProducesImage() {
        let img = RecapShareService.render(RecapCardView(data: .placeholder, scheme: .dark))
        XCTAssertNotNil(img, "다크 카드 렌더 결과가 nil이면 안 된다")
    }

    func testRenderStoryHighResolution() {
        let scheme: ColorScheme = .light
        let img = RecapShareService.renderStory(.placeholder, scheme: scheme)
        let unwrapped = img
        guard let image = unwrapped else { return XCTFail("story render nil") }

        // 360×640 포인트를 scale 3으로 렌더 → 픽셀은 약 1080×1920.
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        XCTAssertEqual(pixelWidth, RecapStoryCanvas.pointWidth * 3, accuracy: 6)
        XCTAssertEqual(pixelHeight, RecapStoryCanvas.pointHeight * 3, accuracy: 6)
    }

    func testStoryAspectRatioIsNineSixteen() {
        guard let image = RecapShareService.renderStory(.placeholder, scheme: .dark) else {
            return XCTFail("story render nil")
        }
        let ratio = image.size.height / image.size.width
        XCTAssertEqual(ratio, 16.0 / 9.0, accuracy: 0.02, "스토리 비율은 9:16이어야 한다")
    }
}
