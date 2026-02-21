import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

struct QualityScores {
    let sharpness: Double
    let exposure: Double
    let faceQuality: Double
    let motionStability: Double

    var composite: Double {
        sharpness * 0.4 + exposure * 0.3 + faceQuality * 0.2 + motionStability * 0.1
    }
}

actor ImageQualityAnalyzer {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func analyze(image: UIImage) async -> QualityScores {
        guard let ciImage = CIImage(image: image) else {
            return QualityScores(sharpness: 0, exposure: 0, faceQuality: 0, motionStability: 0)
        }

        async let sharpness = computeSharpness(ciImage: ciImage)
        async let exposure = computeExposure(ciImage: ciImage)
        async let face = computeFaceQuality(image: image)
        async let motion = computeMotionStability(ciImage: ciImage)

        return await QualityScores(
            sharpness: sharpness,
            exposure: exposure,
            faceQuality: face,
            motionStability: motion
        )
    }

    // MARK: - Sharpness (Laplacian variance)

    private func computeSharpness(ciImage: CIImage) -> Double {
        let laplacianWeights: [CGFloat] = [
             0, -1,  0,
            -1,  4, -1,
             0, -1,  0
        ]

        let kernel = CIVector(values: laplacianWeights, count: 9)
        guard let filter = CIFilter(name: "CIConvolution3X3") else { return 0.5 }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(kernel, forKey: "inputWeights")
        filter.setValue(0 as NSNumber, forKey: "inputBias")

        guard let output = filter.outputImage else { return 0.5 }

        // Compute mean luminance of filtered image as sharpness proxy
        let avgFilter = CIFilter.areaAverage()
        avgFilter.inputImage = output
        avgFilter.extent = output.extent

        guard let avgOutput = avgFilter.outputImage else { return 0.5 }

        var bitmap = [Float](repeating: 0, count: 4)
        ciContext.render(avgOutput,
                         toBitmap: &bitmap,
                         rowBytes: 16,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBAf,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        // Normalize: high variance = sharp; cap at reasonable threshold
        let variance = Double(bitmap[0])
        return min(variance / 0.05, 1.0)
    }

    // MARK: - Exposure

    private func computeExposure(ciImage: CIImage) -> Double {
        let histFilter = CIFilter.areaHistogram()
        histFilter.inputImage = ciImage
        histFilter.extent = ciImage.extent
        histFilter.scale = 1.0
        histFilter.count = 256

        guard histFilter.outputImage != nil else { return 0.5 }

        // Sample mean luminance using areaAverage on original
        let avgFilter = CIFilter.areaAverage()
        avgFilter.inputImage = ciImage
        avgFilter.extent = ciImage.extent

        guard let avgOutput = avgFilter.outputImage else { return 0.5 }

        var bitmap = [Float](repeating: 0, count: 4)
        ciContext.render(avgOutput,
                         toBitmap: &bitmap,
                         rowBytes: 16,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBAf,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        let mean = (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / 3.0

        // Penalize extremes; ideal range 0.2–0.8
        if mean < 0.2 {
            return mean / 0.2
        } else if mean > 0.8 {
            return (1.0 - mean) / 0.2
        }
        return 1.0
    }

    // MARK: - Face Quality

    private func computeFaceQuality(image: UIImage) async -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }

        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, _ in
                let observations = request.results as? [VNFaceObservation] ?? []
                if observations.isEmpty {
                    continuation.resume(returning: 0.0)
                    return
                }
                // Average faceCaptureQuality across detected faces
                let qualities = observations.compactMap(\.faceCaptureQuality).map(Double.init)
                let avg = qualities.isEmpty ? 0.0 : qualities.reduce(0, +) / Double(qualities.count)
                continuation.resume(returning: avg)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Motion / Stability proxy

    private func computeMotionStability(ciImage: CIImage) -> Double {
        // Use VNDetectHorizonRequest as a stability proxy — a detectable horizon
        // implies a steady, level shot. VNImageRequestHandler.perform is synchronous
        // so the completion fires before perform returns; no semaphore needed.
        guard let cgImage = ciContext.createCGImage(
            ciImage,
            from: CGRect(x: 0, y: 0, width: min(ciImage.extent.width, 256), height: min(ciImage.extent.height, 256))
        ) else { return 0.5 }

        var score = 0.5

        let request = VNDetectHorizonRequest { request, _ in
            if let obs = request.results?.first as? VNHorizonObservation {
                let deviation = abs(obs.angle)
                score = max(0, 1.0 - Double(deviation) / (.pi / 4))
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        return score
    }
}
