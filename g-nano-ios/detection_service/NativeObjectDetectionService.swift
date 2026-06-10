import FoundationModels
import Vision
import UIKit

class NativeObjectDetectionService {
    
    private var session: LanguageModelSession?
    
    init() {
        if SystemLanguageModel.default.isAvailable {
            self.session = LanguageModelSession()
        }
    }
    
    func findObjectInImage(uiImage: UIImage, targetObject: String, reviewString: String) async -> DetectionResult {
        guard let session = session else {
            return DetectionResult(isFound: false, isReviewSafe: false, details: "Apple Intelligence is disabled.")
        }
        
        guard !targetObject.trimmingCharacters(in: .whitespaces).isEmpty else {
            return DetectionResult(isFound: false, isReviewSafe: false, details: "Please enter an object to search for.")
        }
        
        do {
            let visualMetadata = try await extractVisualMetadata(from: uiImage)
            
            // The prompt explicitly tells the AI how to use your two booleans independently
            let prompt = """
            You are a retail moderation assistant performing TWO completely independent tasks.
            
            TASK 1: OBJECT DETECTION
            Look for the specific object: "\(targetObject)" using these vision tags: \(visualMetadata). 
            Allow for synonyms. 
            Result: Set `isFound` to true ONLY if the object is in the image. Do not let the text review affect this.
            
            TASK 2: REVIEW SAFETY
            Analyze this product review: "\(reviewString)".
            Does it violate safety policies (e.g., contains profanity, hate speech, or harassment)?
            Result: Set `isReviewSafe` to false if it violates policy, otherwise true.
            
            Finally, in the `details` string, explicitly state the result of BOTH tasks. (e.g., "The land was found in the image. However, the review contains offensive language.")
            """
            
            let response = try await session.respond(
                to: prompt,
                generating: DetectionResult.self
            )
            
            return response.content
            
        } catch LanguageModelSession.GenerationError.guardrailViolation(_) {
            // 🚨 APPLE'S HARD NATIVE FILTER TRIPPED
            return DetectionResult(
                isFound: false,
                isReviewSafe: false,
                details: "System Block: The review contains severe policy violations and was blocked by Apple."
            )
            
        } catch {
            return DetectionResult(
                isFound: false,
                isReviewSafe: false,
                details: "Native processing failed: \(error.localizedDescription)"
            )
        }
    }
    
    private func extractVisualMetadata(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "Unknown" }
        let request = ClassifyImageRequest()
        let handler = ImageRequestHandler(cgImage)
        let observations = try await handler.perform(request)
        return observations.prefix(15).map { "\($0.identifier)" }.joined(separator: ", ")
    }
}
