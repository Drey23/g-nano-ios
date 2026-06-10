import Foundation
import GoogleGenerativeAI
import UIKit

class CloudModerationService {

    // 2. Exact configuration parity with your Kotlin setup
    private let model = GenerativeModel(
        name: "gemini-3-flash-preview",
        apiKey: Config.API_KEY, // Replace with your real key securely
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

    func moderateImage(uiImage: UIImage) async -> ModerationResult {
        do {
            // 3. Pass the native UIImage and your prompt string directly into the variadic arguments list
            let response = try await model.generateContent(uiImage, Constants.promptText)
            let resultText = response.text ?? ""

            return parseModerationJson(resultText)

        } catch {
            // Catches API network errors or when safety filters block the generation request
            return ModerationResult(
                isViolating: true,
                reason: "Blocked by safety filters or API error: \(error.localizedDescription)"
            )
        }
    }

    private func parseModerationJson(_ jsonString: String) -> ModerationResult {
        // Clean the string if the model returns it wrapped in markdown code blocks
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleaned.data(using: .utf8) else {
            return ModerationResult(
                isViolating: false, 
                reason: jsonString.isEmpty ? "No description provided." : jsonString
            )
        }

        do {
            // Use Swift's native JSONDecoder instead of looking up manual keys
            return try JSONDecoder().decode(ModerationResult.self, from: data)
        } catch {
            // Fallback if the model returned raw unformatted text instead of structured JSON
            return ModerationResult(
                isViolating: false,
                reason: jsonString.isEmpty ? "No description provided by model." : jsonString
            )
        }
    }
}

// Dummy configuration container to replicate your Android object
struct Constants {
    static let promptText = "Analyze this image and return a JSON matching {isViolating: bool, reason: string}"
}
