import Foundation
import GoogleGenerativeAI
import UIKit

class CloudObjectDetectionService {

    private let model = GenerativeModel(
        name: "gemini-3-flash-preview",
        apiKey: Secrets.API_KEY, // Replace with your real key securely
        generationConfig: GenerationConfig(
            responseMIMEType: "application/json" // <--- Capitalized MIME forces clean JSON output
        ),
        safetySettings: [
            SafetySetting(harmCategory: .hateSpeech, threshold: .blockMediumAndAbove),
            SafetySetting(harmCategory: .harassment, threshold: .blockMediumAndAbove),
            SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockMediumAndAbove),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockMediumAndAbove)
        ]
    )

    func findObjectInImage(uiImage: UIImage, targetObject: String, reviewString: String) async -> DetectionResult {
            
            // Don't waste network calls if the text is empty
            guard !targetObject.trimmingCharacters(in: .whitespaces).isEmpty else {
                return DetectionResult(isFound: false, isReviewSafe: false, details: "Please enter an object to search for.")
            }
            
            guard !reviewString.trimmingCharacters(in: .whitespaces).isEmpty else {
                return DetectionResult(isFound: false, isReviewSafe: false, details: "Please enter the product's review.")
            }

            // 2. The decoupled prompt instructs Gemini to separate the visual search from the text safety check
            let promptText = """
            You are a retail moderation assistant performing TWO completely independent tasks.
            
            TASK 1: OBJECT DETECTION
            Analyze this image and determine if it contains the object: "\(targetObject)".
            Allow for synonyms. Set `isFound` to true ONLY if the object is in the image and review meets the safety policies. Do not let the text review affect this.
            
            TASK 2: REVIEW SAFETY
            Analyze this product review: "\(reviewString)".
            Does it violate safety policies (e.g., contains profanity, hate speech, or harassment)?
            Set `isReviewSafe` to false if it violates policy, otherwise true.
            
            You MUST respond ONLY with raw, valid JSON matching this exact structure:
            {
              "isFound": true, 
              "isReviewSafe": true,
              "details": "Explicitly state the result of BOTH tasks. (e.g., 'The land was found in the image. However, the review contains offensive language.')"
            }
            """

            do {
                // 3. Send BOTH the raw UIImage and the prompt string directly to Gemini
                let response = try await model.generateContent(uiImage, promptText)
                let resultText = response.text ?? ""

                return parseDetectionJson(resultText)

            } catch {
                // 🚨 GOOGLE'S HARD CLOUD FILTER TRIPPED
                // If the text/image triggers your .blockMediumAndAbove settings, the API throws an error
                let errorMessage = error.localizedDescription.lowercased()
                if errorMessage.contains("safety") || errorMessage.contains("blocked") {
                    return DetectionResult(
                        isFound: false,
                        isReviewSafe: false,
                        details: "System Block: The content violates severe safety policies and was blocked by the cloud server."
                    )
                }
                
                // Standard network/timeout error fallback
                return DetectionResult(
                    isFound: false,
                    isReviewSafe: false,
                    details: "Cloud API error: \(error.localizedDescription)"
                )
            }
        }

    // 4. Robust JSON parser updated for the new dual-boolean struct
    private func parseDetectionJson(_ jsonString: String) -> DetectionResult {
        // Creating the backticks safely so it doesn't break the Markdown UI renderer
        let jsonMarker = "`" + "`" + "`json"
        let backticks = "`" + "`" + "`"
        
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: jsonMarker, with: "")
            .replacingOccurrences(of: backticks, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            return DetectionResult(
                isFound: false,
                isReviewSafe: false, // Required by the new struct
                details: jsonString.isEmpty ? "No valid response." : jsonString
            )
        }

        do {
            return try JSONDecoder().decode(DetectionResult.self, from: data)
        } catch {
            return DetectionResult(
                isFound: false,
                isReviewSafe: false, // Required by the new struct
                details: "Failed to parse JSON: \(jsonString)"
            )
        }
    }
}
