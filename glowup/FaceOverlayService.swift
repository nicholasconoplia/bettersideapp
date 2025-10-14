//
//  FaceOverlayService.swift
//  glowup
//
//  Created by AI Assistant
//

import UIKit
import Vision
import CoreImage
import ImageIO

/// Service that analyzes face and creates annotated image with overlays
actor FaceOverlayService {
    
    // MARK: - Face Analysis Result
    
    struct FaceAnalysisResult {
        let annotatedImage: UIImage
        let faceShape: String
        let faceBounds: CGRect
        let landmarks: VNFaceLandmarks2D?
    }
    
    // MARK: - Main Analysis Method
    
    func analyzeAndAnnotateImage(_ image: UIImage) async throws -> FaceAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw FaceOverlayError.invalidImage
        }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        // Detect face
        let faceObservations = try await detectFace(in: cgImage, orientation: orientation)
        
        guard let face = selectPrimaryFace(from: faceObservations) else {
            throw FaceOverlayError.noFaceDetected
        }
        
        // Determine face shape from landmarks
        let faceShape = determineFaceShape(from: face)
        
        // Create annotated image
        let annotatedImage = drawFaceOverlay(
            on: image,
            faceObservation: face,
            faceShape: faceShape
        )
        
        return FaceAnalysisResult(
            annotatedImage: annotatedImage,
            faceShape: faceShape,
            faceBounds: face.boundingBox,
            landmarks: face.landmarks
        )
    }
    
    // MARK: - Face Detection
    
    private func detectFace(in cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> [VNFaceObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: observations)
            }
            request.revision = VNDetectFaceLandmarksRequestRevision3
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func selectPrimaryFace(from observations: [VNFaceObservation]) -> VNFaceObservation? {
        guard !observations.isEmpty else { return nil }
        return observations.max { lhs, rhs in
            let lhsArea = lhs.boundingBox.width * lhs.boundingBox.height
            let rhsArea = rhs.boundingBox.width * rhs.boundingBox.height
            if abs(lhs.confidence - rhs.confidence) > 0.05 {
                return lhs.confidence < rhs.confidence
            }
            return lhsArea < rhsArea
        }
    }
    
    // MARK: - Face Shape Determination
    
    private func determineFaceShape(from observation: VNFaceObservation) -> String {
        guard let landmarks = observation.landmarks else {
            return "Oval"
        }
        
        let boundingBox = observation.boundingBox
        let width = boundingBox.width
        let height = boundingBox.height
        let ratio = height / width // >1 taller than wide
        
        // Get jawline points if available
        if let faceContour = landmarks.faceContour?.normalizedPoints {
            let jawWidth = calculateJawWidth(from: faceContour)
            let foreheadWidth = calculateForeheadWidth(from: faceContour)
            let cheekboneWidth = calculateCheekboneWidth(from: faceContour)
            let jawAngle = estimateJawAngle(from: faceContour)
            
            // Normalize widths relative to overall width
            let widthNorm = max(foreheadWidth, max(cheekboneWidth, jawWidth))
            let f = foreheadWidth / widthNorm
            let c = cheekboneWidth / widthNorm
            let j = jawWidth / widthNorm
            
            // Rules based on anthropometric heuristics
            // Oblong/Rectangular: significantly taller than wide
            if ratio >= 1.6 {
                return "Rectangular/Oblong"
            }
            
            // Diamond: cheekbones widest, forehead and jaw narrower, sharper jaw angle
            if c > f + 0.08 && c > j + 0.08 && jawAngle < 35 {
                return "Diamond"
            }
            
            // Heart: forehead widest, jaw clearly narrower, often sharper chin (small jaw width and angle)
            if f > c - 0.03 && f > j + 0.08 {
                return "Heart"
            }
            
            // Square: similar widths and strong jaw angle (near 45-60 degrees)
            if abs(f - j) < 0.06 && abs(c - f) < 0.08 && jawAngle >= 38 {
                return "Square"
            }
            
            // Round: width ~ height (ratio ~1) and soft jaw (angle low) and widths fairly similar
            if ratio <= 1.15 && abs(f - j) < 0.08 && abs(c - f) < 0.08 && jawAngle < 33 {
                return "Round"
            }
            
            // Oval: slightly taller than wide, cheekbones widest but not by much, softer jaw
            if ratio > 1.15 && ratio < 1.6 && c >= f - 0.04 && c >= j - 0.04 && jawAngle < 38 {
                return "Oval"
            }
            
            // Triangle (inverted triangle vs triangle): if jaw wider than forehead
            if j > f + 0.08 {
                return "Triangle"
            }
            
            // Default fallback based on ratio
            return ratio > 1.3 ? "Oval" : "Round"
        }
        
        // Fallback based on basic ratios
        if ratio > 1.5 {
            return "Oblong"
        } else if ratio > 1.2 {
            return "Oval"
        } else {
            return "Round"
        }
    }
    
    private func calculateJawWidth(from points: [CGPoint]) -> CGFloat {
        guard points.count > 10 else { return 0 }
        let lowerPoints = points.suffix(points.count / 3)
        let minX = lowerPoints.map { $0.x }.min() ?? 0
        let maxX = lowerPoints.map { $0.x }.max() ?? 0
        return maxX - minX
    }
    
    private func calculateForeheadWidth(from points: [CGPoint]) -> CGFloat {
        guard points.count > 10 else { return 0 }
        let upperPoints = points.prefix(points.count / 3)
        let minX = upperPoints.map { $0.x }.min() ?? 0
        let maxX = upperPoints.map { $0.x }.max() ?? 0
        return maxX - minX
    }
    
    private func calculateCheekboneWidth(from points: [CGPoint]) -> CGFloat {
        guard points.count > 10 else { return 0 }
        let start = points.count / 3
        let end = start * 2
        let midPoints = points[start..<end]
        let minX = midPoints.map { $0.x }.min() ?? 0
        let maxX = midPoints.map { $0.x }.max() ?? 0
        return maxX - minX
    }
    
    private func estimateJawAngle(from points: [CGPoint]) -> CGFloat {
        // Approximate angle at the jaw corners using three points near each side
        guard points.count > 6 else { return 0 }
        let leftTriplet = Array(points.prefix(3))
        let rightTriplet = Array(points.suffix(3))
        
        func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
            let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
            let dot = v1.dx * v2.dx + v1.dy * v2.dy
            let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
            let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
            guard mag1 > 0, mag2 > 0 else { return 0 }
            let cosTheta = max(-1.0, min(1.0, dot / (mag1 * mag2)))
            let rad = acos(cosTheta)
            return rad * 180 / .pi
        }
        let leftAngle = angle(leftTriplet[0], leftTriplet[1], leftTriplet[2])
        let rightAngle = angle(rightTriplet[2], rightTriplet[1], rightTriplet[0])
        // Return mean jaw angle; lower => softer/rounder
        return (leftAngle + rightAngle) / 2
    }
    
    // MARK: - Drawing Overlay
    
    private func drawFaceOverlay(
        on image: UIImage,
        faceObservation: VNFaceObservation,
        faceShape: String
    ) -> UIImage {
        let imageSize = image.size
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, image.scale)
        
        // Draw original image
        image.draw(at: .zero)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }
        
        // Convert Vision coordinates to UIKit coordinates
        let boundingBox = boundingRect(for: faceObservation, imageSize: imageSize)
        
        // Draw face outline
        drawFaceOutline(
            in: context,
            boundingBox: boundingBox,
            faceObservation: faceObservation,
            imageSize: imageSize,
            faceShape: faceShape
        )
        
        // Draw face shape label
        drawFaceShapeLabel(
            in: context,
            faceShape: faceShape,
            boundingBox: boundingBox
        )
        
        let annotatedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return annotatedImage
    }
    
    private func drawFaceOutline(
        in context: CGContext,
        boundingBox: CGRect,
        faceObservation: VNFaceObservation,
        imageSize: CGSize,
        faceShape: String
    ) {
        context.saveGState()
        
        // Set up drawing style - MUCH THICKER AND MORE VISIBLE
        context.setLineWidth(8.0)  // Increased from 3.0
        
        // Draw outer glow first (creates neon effect)
        context.setStrokeColor(UIColor(red: 1.0, green: 0.6, blue: 0.78, alpha: 0.5).cgColor)
        context.setLineWidth(12.0)
        context.setShadow(offset: .zero, blur: 10, color: UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.8).cgColor)
        
        if let faceContour = faceObservation.landmarks?.faceContour {
            // Draw actual face contour
            let points = faceContour.normalizedPoints.map {
                convert(point: $0, faceObservation: faceObservation, imageSize: imageSize)
            }
            
            if points.count > 1 {
                let contourPath = UIBezierPath()
                contourPath.move(to: points[0])
                for point in points.dropFirst() {
                    contourPath.addLine(to: point)
                }

                let fillPath = contourPath.copy() as! UIBezierPath
                fillPath.addLine(to: points.first!)
                fillPath.close()

                // Soft fill to make outline easier to see
                context.saveGState()
                context.addPath(fillPath.cgPath)
                context.setFillColor(UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.18).cgColor)
                context.setShadow(offset: .zero, blur: 20, color: UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.4).cgColor)
                context.fillPath()
                context.restoreGState()
                
                // Draw glow layer first
                context.beginPath()
                context.addPath(contourPath.cgPath)
                context.strokePath()
                
                // Draw main bright line on top
                context.setLineWidth(8.0)
                context.setStrokeColor(UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 1.0).cgColor)
                context.setShadow(offset: .zero, blur: 5, color: UIColor(red: 1.0, green: 0.6, blue: 0.78, alpha: 1.0).cgColor)
                
                context.beginPath()
                context.addPath(contourPath.cgPath)
                context.strokePath()
            }
        } else {
            // Fallback: draw bounding box with rounded corners and glow
            let expandedBox = boundingBox.insetBy(dx: -10, dy: -10)
            let path = UIBezierPath(roundedRect: expandedBox, cornerRadius: 30)
            
            context.saveGState()
            context.addPath(path.cgPath)
            context.setFillColor(UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.18).cgColor)
            context.setShadow(offset: .zero, blur: 20, color: UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.4).cgColor)
            context.fillPath()
            context.restoreGState()
            
            // Glow layer
            context.addPath(path.cgPath)
            context.strokePath()
            
            // Main bright line
            context.setLineWidth(8.0)
            context.setStrokeColor(UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 1.0).cgColor)
            context.setShadow(offset: .zero, blur: 5, color: UIColor(red: 1.0, green: 0.6, blue: 0.78, alpha: 1.0).cgColor)
            
            context.addPath(path.cgPath)
            context.strokePath()
        }
        
        // Draw key facial landmarks
        drawLandmarks(in: context, faceObservation: faceObservation, imageSize: imageSize)
        
        context.restoreGState()
    }
    
    private func drawLandmarks(
        in context: CGContext,
        faceObservation: VNFaceObservation,
        imageSize: CGSize
    ) {
        guard let landmarks = faceObservation.landmarks else { return }
        
        context.setFillColor(UIColor(red: 1.0, green: 0.6, blue: 0.78, alpha: 0.8).cgColor)
        
        // Draw eye contours - THICKER AND MORE VISIBLE
        if let leftEye = landmarks.leftEye {
            drawRegion(leftEye, in: context, faceObservation: faceObservation, imageSize: imageSize, closed: true, lineWidth: 5.0)
        }
        if let rightEye = landmarks.rightEye {
            drawRegion(rightEye, in: context, faceObservation: faceObservation, imageSize: imageSize, closed: true, lineWidth: 5.0)
        }
        
        // Draw nose
        if let nose = landmarks.nose {
            drawRegion(nose, in: context, faceObservation: faceObservation, imageSize: imageSize, closed: false, lineWidth: 4.0)
        }
        
        // Draw outer lips
        if let outerLips = landmarks.outerLips {
            drawRegion(outerLips, in: context, faceObservation: faceObservation, imageSize: imageSize, closed: true, lineWidth: 5.0)
        }
    }
    
    private func drawRegion(
        _ region: VNFaceLandmarkRegion2D,
        in context: CGContext,
        faceObservation: VNFaceObservation,
        imageSize: CGSize,
        closed: Bool,
        lineWidth: CGFloat = 2.0
    ) {
        let points = region.normalizedPoints.map { point in
            convert(point: point, faceObservation: faceObservation, imageSize: imageSize)
        }
        
        guard points.count > 1 else { return }
        
        // Glow layer
        context.setLineWidth(lineWidth + 4)
        context.setStrokeColor(UIColor(red: 1.0, green: 0.6, blue: 0.78, alpha: 0.3).cgColor)
        context.setShadow(offset: .zero, blur: 8, color: UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.6).cgColor)
        
        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        if closed {
            context.closePath()
        }
        context.strokePath()
        
        // Main bright line
        context.setLineWidth(lineWidth)
        context.setStrokeColor(UIColor(red: 1.0, green: 0.6, blue: 0.78, alpha: 0.9).cgColor)
        context.setShadow(offset: .zero, blur: 3, color: UIColor(red: 1.0, green: 0.6, blue: 0.78, alpha: 1.0).cgColor)
        
        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        if closed {
            context.closePath()
        }
        context.strokePath()
    }
    
    private func convert(point: CGPoint, faceObservation: VNFaceObservation, imageSize: CGSize) -> CGPoint {
        let boundingBox = faceObservation.boundingBox
        let normalizedPoint = CGPoint(
            x: boundingBox.origin.x + point.x * boundingBox.size.width,
            y: boundingBox.origin.y + point.y * boundingBox.size.height
        )
        
        return CGPoint(
            x: normalizedPoint.x * imageSize.width,
            y: (1 - normalizedPoint.y) * imageSize.height
        )
    }
    
    private func drawFaceShapeLabel(
        in context: CGContext,
        faceShape: String,
        boundingBox: CGRect
    ) {
        let text = faceShape
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),  // Larger font
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 1.0),
            .strokeWidth: -4.0  // Thicker stroke
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        
        // Position label above the face
        let labelRect = CGRect(
            x: boundingBox.midX - textSize.width / 2,
            y: boundingBox.minY - textSize.height - 20,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw glowing background with gradient
        let backgroundRect = labelRect.insetBy(dx: -16, dy: -8)
        
        // Add glow shadow
        context.setShadow(offset: .zero, blur: 15, color: UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.8).cgColor)
        
        // Draw background with gradient effect
        context.setFillColor(UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 0.9).cgColor)
        let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 16)
        context.addPath(backgroundPath.cgPath)
        context.fillPath()
        
        // Draw border
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(2.0)
        context.addPath(backgroundPath.cgPath)
        context.strokePath()
        
        // Reset shadow for text
        context.setShadow(offset: .zero, blur: 0, color: UIColor.clear.cgColor)
        
        // Draw text
        attributedText.draw(in: labelRect)
    }
    
    private func boundingRect(for observation: VNFaceObservation, imageSize: CGSize) -> CGRect {
        let bb = observation.boundingBox
        let x = bb.origin.x * imageSize.width
        let width = bb.size.width * imageSize.width
        let height = bb.size.height * imageSize.height
        // Vision coordinates are bottom-left origin; convert to UIKit top-left
        let y = (1 - bb.origin.y - bb.size.height) * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Orientation Helpers

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

// MARK: - Errors

enum FaceOverlayError: Error {
    case invalidImage
    case noFaceDetected
    
    var localizedDescription: String {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noFaceDetected:
            return "No face detected in the image"
        }
    }
}
