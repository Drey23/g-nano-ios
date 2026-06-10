import SwiftUI
import PhotosUI

struct ObjectFinderView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    @State private var targetObjectText: String = ""
    @State private var targetReviewText: String = ""
    @State private var isProcessing = false
    @State private var detectionResult: DetectionResult?
    
    private let detectionService = HybridObjectSearchService()
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("AI Object Finder")
                .font(.largeTitle)
                .bold()
                .padding(.top)
            
            // 1. The Search Text Field (Now triggers search on enter!)
            TextField("Type the product's review", text: $targetReviewText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .submitLabel(.search)
                .onSubmit {
                    // Trigger a new search when the user hits "Search" on the keyboard
                    runDetection()
                }
            
            // 1. The Search Text Field (Now triggers search on enter!)
            TextField("What are you looking for? (e.g., 'roses')", text: $targetObjectText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .submitLabel(.search)
                .onSubmit {
                    // Trigger a new search when the user hits "Search" on the keyboard
                    runDetection()
                }
            
            // 2. The Photo Picker
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Select Image to Search")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(targetObjectText.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(targetReviewText.isEmpty && targetObjectText.isEmpty)
            
            // 3. The Image Preview
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    .padding(.horizontal)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 300)
                    .overlay(Text("No image selected").foregroundColor(.gray))
                    .padding(.horizontal)
            }
            
            // 4. Status and Results
            if isProcessing {
                ProgressView("Reading review and Searching image...")
                    .padding()
            } else if let result = detectionResult {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: result.isFound ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.isFound ? .green : .red)
                        
                        Text(result.isFound ? "Match Found!" : "Not Found")
                            .font(.headline)
                            .foregroundColor(result.isFound ? .green : .red)
                    }
                    
                    Text(result.details)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(result.isFound ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    // Update the image immediately
                    await MainActor.run {
                        self.selectedImage = uiImage
                    }
                    
                    // Run the detection with the new image
                    runDetection()
                }
            }
        }
    }
    
    // 5. The abstracted detection logic
    private func runDetection() {
        // Ensure we have both an image and text before making an API call
        guard let uiImage = selectedImage, !targetObjectText.isEmpty else { return }
        
        Task {
            await MainActor.run {
                self.detectionResult = nil
                self.isProcessing = true
            }
            
            let result = await detectionService.findObjectInImage(
                uiImage: uiImage,
                targetObject: targetObjectText,
                reviewString: targetReviewText
            )
            
            await MainActor.run {
                self.detectionResult = result
                self.isProcessing = false
            }
        }
    }
}
