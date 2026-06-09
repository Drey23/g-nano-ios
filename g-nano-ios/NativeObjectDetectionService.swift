import Foundation
import FoundationModels
import UIKit
import Vision

class NativeObjectDetectionService {
    
    private var session: LanguageModelSession?
    
    init() {
        if SystemLanguageModel.default.isAvailable {
            self.session = LanguageModelSession()
        }
    }
    
    // 2. Add the targetObject parameter to the function
    func findObjectInImage(uiImage: UIImage, targetObject: String) async -> DetectionResult {
        guard let session = session else {
            return DetectionResult(isFound: false, details: "Apple Intelligence is disabled.")
        }
        
        // Don't waste compute if the user forgot to type something
        guard !targetObject.trimmingCharacters(in: .whitespaces).isEmpty else {
            return DetectionResult(isFound: false, details: "Please enter an object to search for.")
        }
        
        do {
            let visualMetadata = try await extractVisualMetadata(from: uiImage)
            
            // 3. Update the prompt to compare the tags with the user's text
            let prompt = """
            You are an image analysis assistant. I am looking for a specific object: "\(targetObject)".
            Here are the vision tags extracted from the image: \(visualMetadata).
            
            Determine if the object I am looking for is present in the image based on these tags. 
            Allow for synonyms (e.g., if looking for 'roses', the tag 'flowers' or 'floral' is a strong match).
            """
            
            let response = try await session.respond(
                to: prompt,
                generating: DetectionResult.self
            )
            
            return response.content
            
        } catch {
            return DetectionResult(isFound: false, details: "Native processing failed: \(error.localizedDescription)")
        }
    }
    
    private func extractVisualMetadata(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "Unknown" }
        let request = ClassifyImageRequest()
        let handler = ImageRequestHandler(cgImage)
        let observations = try await handler.perform(request)
        // Let's grab the top 15 tags instead of 5 to give the AI more context to search through!
        return observations.prefix(15).map { "\($0.identifier)" }.joined(separator: ", ")
    }
}
