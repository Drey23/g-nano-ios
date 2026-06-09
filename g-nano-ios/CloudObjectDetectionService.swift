import Foundation
import GoogleGenerativeAI
import UIKit

class CloudObjectDetectionService {

    private let model = GenerativeModel(
        name: "gemini-3-flash-preview",
        apiKey: "AIzaSyAUU4LX-F-F8LpTh6iu4uUfnD4c1N1hSas", // Replace with your real key securely
        generationConfig: GenerationConfig(
            responseMIMEType: "application/json" // <--- Capitalized MIME forces clean JSON output
        )
    )

    func findObjectInImage(uiImage: UIImage, targetObject: String) async -> DetectionResult {
        
        // Don't waste network calls if the text is empty
        guard !targetObject.trimmingCharacters(in: .whitespaces).isEmpty else {
            return DetectionResult(isFound: false, details: "Please enter an object to search for.")
        }

        // 2. The prompt instructs Gemini what to look for and strictly enforces the JSON shape
        let promptText = """
        Analyze this image and determine if it contains the following object: "\(targetObject)".
        Allow for synonyms and be reasonably flexible (e.g., if looking for 'dog', a 'golden retriever' is a match).
        
        You MUST respond ONLY with raw, valid JSON matching this exact structure:
        {
          "isFound": true, 
          "details": "Explain exactly where you see it in the image, or why you don't."
        }
        """

        do {
            // 3. Send BOTH the raw UIImage and the prompt string directly to Gemini
            let response = try await model.generateContent(uiImage, promptText)
            let resultText = response.text ?? ""

            return parseDetectionJson(resultText)

        } catch {
            return DetectionResult(
                isFound: false,
                details: "Cloud API error: \(error.localizedDescription)"
            )
        }
    }

    // 4. Robust JSON parser (Fully Complete)
    private func parseDetectionJson(_ jsonString: String) -> DetectionResult {
        // Clean the string if the model returns it wrapped in markdown code blocks
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            return DetectionResult(isFound: false, details: jsonString.isEmpty ? "No valid response." : jsonString)
        }

        do {
            return try JSONDecoder().decode(DetectionResult.self, from: data)
        } catch {
            // Fallback if the model returned raw unformatted text
            return DetectionResult(isFound: false, details: jsonString)
        }
    }
}
