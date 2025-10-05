//
//  UI.swift
//  Cultured
//
//  Created by Nathaniel Lee on 10/4/25.
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
 
// MARK: - Main Content View

struct UI: View {
    @State private var showRecorder = false
    @State private var showLibrary = false
    @State private var lastVideoURL: URL?
    @State private var uploadedPublicURL: String?
    @State private var isUploading = false
    
    private let uploadService = VideoUploadService()
    
    var body: some View {
        TabView {
            ZStack {
                Color.black.opacity(0.02).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Text("HistoroVision Recorder")
                        .font(.title2)
                    
                    // Record Button
                    Button {
                        showRecorder = true
                    } label: {
                        HStack {
                            Image(systemName: "video.circle.fill")
                            Text("Record Video")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUploading)
                    
                    // Library Button
                    Button {
                        showLibrary = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from Library")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUploading)
                    
                    if isUploading {
                        ProgressView("Uploading...")
                            .padding()
                    }
                    
                    if let url = lastVideoURL {
                        VStack(spacing: 8) {
                            Text("Last: \(url.lastPathComponent)")
                                .font(.footnote)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            if let publicURL = uploadedPublicURL {
                                Text("✅ Uploaded")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                
                                Button("Copy URL") {
                                    UIPasteboard.general.string = publicURL
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            HStack {
                                Button("Re-upload") {
                                    Task { await handleUpload(url) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isUploading)
                                
                                ShareLink(item: url) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else {
                        Text("No video selected yet")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding()
            }
            .tabItem {
                Image(systemName: "video")
                Text("Record")
            }
        }
        .fullScreenCover(isPresented: $showRecorder) {
            VideoCaptureView { url in
                lastVideoURL = url
                Task { await handleUpload(url) }
            } onCancel: {
                print("Recording cancelled")
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            VideoLibraryPicker { url in
                lastVideoURL = url
                Task { await handleUpload(url) }
            } onCancel: {
                print("Library selection cancelled")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleUpload(_ url: URL) async {
        isUploading = true
        uploadedPublicURL = nil
        
        do {
            let publicURL = try await uploadService.uploadVideo(from: url)
            uploadedPublicURL = publicURL
            print("👉 Paste this in your browser:", publicURL)
        } catch {
            print("❌ Upload failed:", error.localizedDescription)
        }
        
        isUploading = false
    }
}
 
// MARK: - Video Camera Capture
 
struct VideoCaptureView: UIViewControllerRepresentable {
    
    var onPicked: (URL) -> Void
    var onCancel: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.sourceType = .camera
        picker.cameraCaptureMode = .video
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoCaptureView
        
        init(parent: VideoCaptureView) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            picker.dismiss(animated: true)
            if let url = info[.mediaURL] as? URL {
                parent.onPicked(url)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onCancel?()
        }
    }
}
 
// MARK: - Video Library Picker
 
struct VideoLibraryPicker: UIViewControllerRepresentable {
    
    var onPicked: (URL) -> Void
    var onCancel: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.movie"]
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .formSheet
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoLibraryPicker
        
        init(parent: VideoLibraryPicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            picker.dismiss(animated: true)
            if let url = info[.mediaURL] as? URL {
                parent.onPicked(url)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onCancel?()
        }
    }
}
