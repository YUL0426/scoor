//
//  ProfileImageProcessor.swift
//  Scoor
//
//  Downscales/compresses a picked avatar image so the locally-stored file stays
//  small (and is a sensible payload for a future profile-image upload endpoint).
//

import Foundation
#if canImport(UIKit)
import UIKit

enum ProfileImageProcessor {
    /// Normalize raw image data to a square-ish, max-`maxDimension` JPEG.
    static func normalized(_ data: Data, maxDimension: CGFloat = 512, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
#endif
