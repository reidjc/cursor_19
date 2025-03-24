import SwiftUI
import AVFoundation

/**
 * CameraPreview - SwiftUI wrapper for AVCaptureVideoPreviewLayer
 *
 * This struct bridges between SwiftUI and UIKit to display the camera feed.
 * It creates a UIView that hosts the AVCaptureVideoPreviewLayer from the CameraManager.
 *
 * The view is configured to display the camera preview full-screen with proper
 * aspect ratio handling.
 */
struct CameraPreview: UIViewRepresentable {
    /// Reference to the camera manager that provides the preview layer
    @ObservedObject var cameraManager: CameraManager
    
    /**
     * Creates the UIView that will host the camera preview.
     *
     * This method is called when the view is first created.
     * We initialize an empty view with black background here, and
     * defer adding the preview layer to updateUIView.
     *
     * - Parameter context: The context in which the view is created
     * - Returns: A configured UIView ready to display the camera preview
     */
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // We'll configure the preview layer in updateUIView to ensure 
        // it's properly set up after the camera session is running
        return view
    }
    
    /**
     * Updates the UIView with the current preview layer from the camera manager.
     *
     * This method is called whenever the observed camera manager changes.
     * It ensures the preview layer is correctly configured and added to the view.
     *
     * - Parameters:
     *   - uiView: The UIView that hosts the camera preview
     *   - context: The context in which the view is updated
     */
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove existing preview layer if it exists
        uiView.layer.sublayers?.filter { $0 is AVCaptureVideoPreviewLayer }.forEach { $0.removeFromSuperlayer() }
        
        // Get the preview layer from camera manager
        if let previewLayer = cameraManager.preview {
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            uiView.layer.addSublayer(previewLayer)
        }
    }
} 