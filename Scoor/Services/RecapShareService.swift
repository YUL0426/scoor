//
//  RecapShareService.swift
//  Scoor
//
//  리캡 카드를 고해상도 이미지로 내보내고 공유/저장하는 헬퍼.
//  - ImageRenderer로 렌더(scale 3 → 고해상도)
//  - Photos에 저장 (NSPhotoLibraryAddUsageDescription 필요)
//  - 시스템 공유는 SwiftUI ShareLink가 담당(렌더된 Image 전달)
//  - 인스타 스토리는 pasteboard + instagram-stories://share 딥링크
//

import Photos
import SwiftUI
import UIKit

enum RecapShareError: Error {
    case renderFailed
    case saveDenied
    case saveFailed
    case instagramUnavailable
}

enum RecapShareService {

    /// SwiftUI 뷰를 고해상도 UIImage로 렌더.
    @MainActor
    static func render(_ view: some View, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = false
        return renderer.uiImage
    }

    /// 스토리 캔버스를 1080×1920급 이미지로 렌더.
    @MainActor
    static func renderStory(_ data: RecapData, scheme: ColorScheme) -> UIImage? {
        render(RecapStoryCanvas(data: data, scheme: scheme))
    }

    /// 사진 보관함에 저장. 권한 요청 포함.
    static func saveToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw RecapShareError.saveDenied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw RecapShareError.saveFailed
        }
    }

    /// 인스타그램 스토리로 공유. 설치되어 있지 않으면 실패를 던진다.
    @MainActor
    static func shareToInstagramStory(_ image: UIImage) throws {
        guard let url = URL(string: "instagram-stories://share?source_application=com.euro.Scoor"),
              UIApplication.shared.canOpenURL(url),
              let data = image.pngData() else {
            throw RecapShareError.instagramUnavailable
        }
        let items: [String: Any] = ["com.instagram.sharedSticker.backgroundImage": data]
        UIPasteboard.general.setItems(
            [items],
            options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
        )
        UIApplication.shared.open(url)
    }
}
