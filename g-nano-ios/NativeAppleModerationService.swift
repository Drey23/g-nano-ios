import UIKit
import Vision
import FoundationModels 


class NativeAppleModerationService {
    
    private var session: LanguageModelSession?
    
    init() {
        // Automatically connects to the Apple Neural Engine (ANE)
        if SystemLanguageModel.default.isAvailable {
            self.session = LanguageModelSession()
        }
    }
    
    func moderateImageOffline(uiImage: UIImage) async -> ModerationResult {
        guard let session = session else {
            return ModerationResult(isViolating: true, reason: "Apple Intelligence is not available on this device.")
        }
        
        do {
            // STEP 1: Use Apple's Vision framework to "see" the image natively
            let visualDescription = try await extractVisualData(from: uiImage)
            
            // STEP 2: Feed what Vision saw into Apple Intelligence
            let promptText = """
            Analyze the following visual data extracted from an image. 
            Determine if it contains explicit content, hate speech, or dangerous activities.
            
            Image Data:
            \(visualDescription)
            """
            
            // STEP 3: Generate the type-safe struct directly on-device
            let response = try await session.respond(
                to: promptText,
                generating: ModerationResult.self
            )
            
            return response.content
            
        } catch {
            return ModerationResult(isViolating: true, reason: "Native processing failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Native Vision Processing (The "Eyes")
    
    /// Scans the image using Apple's built-in neural models (Zero downloads required)
    private func extractVisualData(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw URLError(.badServerResponse) }
        
        return try await withCheckedThrowingContinuation { continuation in
            // 1. Set up a classification request (Detects objects, scenes, actions)
            let classificationRequest = VNClassifyImageRequest()
            
            // 2. Set up an OCR request (Detects written text in the image)
            let textRequest = VNRecognizeTextRequest()
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([classificationRequest, textRequest])
                
                var description = ""
                
                // Extract top 10 most confident visual labels
                if let classifications = classificationRequest.results {
                    let topLabels = classifications.prefix(10)
                        .filter { $0.confidence > 0.6 }
                        .map { "\($0.identifier)" }
                    
                    if !topLabels.isEmpty {
                        description += "Objects and scene detected: \(topLabels.joined(separator: ", ")).\n"
                    }
                }
                
                // Extract any text found in the image
                if let textResults = textRequest.results {
                    let recognizedText = textResults.compactMap { $0.topCandidates(1).first?.string }
                    
                    if !recognizedText.isEmpty {
                        description += "Text written in the image: \"\(recognizedText.joined(separator: " "))\"."
                    }
                }
                
                // If it couldn't figure out what the image is
                if description.isEmpty {
                    description = "Unclear or abstract image content."
                }
                
                continuation.resume(returning: description)
                
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
