import SwiftUI
import PhotosUI

struct ModerationView: View {
    // State for the picker and the preview
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // State for the moderation service
    @State private var isProcessing = false
    @State private var moderationResult: ModerationResult?
    
    // Instantiate your service
    private let moderationService = HybridModerationService()
    
    var body: some View {
        VStack(spacing: 24) {
            
            // 1. The Top Button (Opens the iOS Photo Library)
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Select Image")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // 2. The Image Preview
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 350)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
            } else {
                // Empty placeholder before an image is selected
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 350)
                    .overlay(
                        Text("No image selected")
                            .foregroundColor(.gray)
                    )
                    .padding(.horizontal)
            }
            
            // 3. Status and Results
            if isProcessing {
                ProgressView("Analyzing Image with Gemini...")
                    .padding()
            } else if let result = moderationResult {
                // Display the results returned from the API
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: result.isViolating ? "xmark.octagon.fill" : "checkmark.shield.fill")
                            .foregroundColor(result.isViolating ? .red : .green)
                        
                        Text(result.isViolating ? "Violation Detected" : "Image is Safe")
                            .font(.headline)
                            .foregroundColor(result.isViolating ? .red : .green)
                    }
                    
                    Text(result.reason)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(result.isViolating ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        // 4. The Logic: Triggered automatically when the user picks a new photo
        .onChange(of: selectedItem) { newItem in
            Task {
                // Convert the picked item into raw data, then into a UIImage
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    // Update UI on the main thread
                    await MainActor.run {
                        self.selectedImage = uiImage
                        self.moderationResult = nil
                        self.isProcessing = true
                    }
                    
                    // Send it to your backend service
                    let result = await moderationService.moderateImage(uiImage: uiImage)
                    
                    // Update UI with the result
                    await MainActor.run {
                        self.moderationResult = result
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}

#Preview {
    ModerationView()
}
