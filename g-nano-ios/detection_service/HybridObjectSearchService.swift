//
//  HybridObjectSearchService.swift
//  g-nano-ios
//
//  Created by Andrey Lindo on 6/8/26.
//

import UIKit
import FoundationModels // Apple Intelligence

class HybridObjectSearchService {
    
    // Instantiate both of the services we built earlier
    private let nativeService = NativeObjectDetectionService()
    private let cloudService = CloudObjectDetectionService()
    
    /// Analyzes an image, automatically choosing the best available compute path.
    func findObjectInImage(uiImage: UIImage, targetObject: String, reviewString: String) async -> DetectionResult {
        
        // 1. Validate OS Version and Hardware Availability
        // Apple Intelligence requires at least iOS 18.1 and a supported Neural Engine
        if #available(iOS 18.1, *), SystemLanguageModel.default.isAvailable {
            
            print("🚀 Hardware Supported: Routing to Offline Apple Intelligence.")
            let result = await nativeService.findObjectInImage(uiImage: uiImage, targetObject: targetObject, reviewString: reviewString)
            
            // Optional: If the native service fails for an unexpected reason,
            // you can still fall back to the cloud as a safety net!
            if result.details.contains("Native processing failed") {
                print("⚠️ Native failed. Bouncing to Gemini Cloud.")
                return await cloudService.findObjectInImage(uiImage: uiImage, targetObject: targetObject, reviewString: reviewString)
            }
            
            return result
            
        } else {
            // 2. Fallback for older iPhones (iPhone 14, 13, base 15, etc.)
            print("☁️ Hardware Unsupported: Routing to Gemini Cloud API.")
            return await cloudService.findObjectInImage(uiImage: uiImage, targetObject: targetObject, reviewString: reviewString)
        }
    }
}
