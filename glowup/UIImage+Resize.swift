//
//  UIImage+Resize.swift
//  glowup
//
//  Lightweight helpers for resizing images before API calls.
//

#if canImport(UIKit)
import UIKit

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else {
            return self
        }

        let scale = maxDimension / longest
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
}
#endif
