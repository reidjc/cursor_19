import AVFoundation
import SwiftUI
import Combine

/**
 * CameraManager - Handles camera capture, face detection, and depth analysis
 *
 * This class is responsible for:
 * - Setting up and managing the camera capture session
 * - Processing video frames for face detection
 * - Analyzing depth data to determine face liveness
 * - Managing camera permissions and error handling
 *
 * It uses TrueDepth camera capabilities to capture both regular video
 * and depth data, which is essential for effective liveness detection.
 */
class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    /// The AVCaptureSession that manages camera input and output
    @Published var session = AVCaptureSession()
    
    /// The video preview layer used to display camera feed in the UI
    @Published var preview: AVCaptureVideoPreviewLayer?
    
    /// Indicates whether the camera session is currently running
    @Published var isSessionRunning = false
    
    /// Holds any errors that occur during camera setup or usage
    @Published var error: CameraError?
    
    /// Indicates whether a face has been detected in the current frame
    @Published var faceDetected = false
    
    /// Indicates whether the detected face appears to be a real, live face
    @Published var isLiveFace = false
    
    /// Controls whether face detection processing is active
    @Published var isTestActive = false
    
    // MARK: - Private Properties
    
    /// Queue for handling camera session operations
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    /// Output for receiving video frames from the camera
    private var videoOutput = AVCaptureVideoDataOutput()
    
    /// Output for receiving depth data from the TrueDepth camera
    private var depthOutput = AVCaptureDepthDataOutput()
    
    /// Utility for detecting faces in video frames
    private let faceDetector = FaceDetector()
    
    // MARK: - Error Types
    
    /// Errors that can occur during camera setup and operation
    enum CameraError: Error {
        case cameraUnavailable     // TrueDepth camera is not available on this device
        case cannotAddInput        // Cannot add camera input to the session
        case cannotAddOutput       // Cannot add video/depth output to the session
        case createCaptureInput(Error) // Error creating camera input
    }
    
    // MARK: - Camera Setup
    
    /**
     * Checks and requests camera permission if needed.
     *
     * This must be called before attempting to use the camera.
     */
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { [weak self] authorized in
                guard authorized else { return }
                self?.sessionQueue.resume()
            }
        case .restricted:
            error = .cameraUnavailable
        case .denied:
            error = .cameraUnavailable
        case .authorized:
            break
        @unknown default:
            error = .cameraUnavailable
        }
    }
    
    /**
     * Initializes and starts the camera capture session.
     *
     * This is the main entry point for setting up the camera.
     * It checks permissions, configures the session, and starts capturing.
     */
    func setupAndStartSession() {
        checkPermissions()
        
        sessionQueue.async { [weak self] in
            self?.setupSession()
            self?.startSession()
        }
    }
    
    /**
     * Configures the camera capture session with appropriate inputs and outputs.
     *
     * Sets up:
     * - TrueDepth camera input
     * - Video output for face detection
     * - Depth data output for liveness analysis
     * - Preview layer for UI display
     */
    private func setupSession() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            error = .cameraUnavailable
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                error = .cannotAddInput
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            
            guard session.canAddOutput(videoOutput) else {
                error = .cannotAddOutput
                session.commitConfiguration()
                return
            }
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            session.addOutput(videoOutput)
            
            if device.activeDepthDataFormat != nil && session.canAddOutput(depthOutput) {
                depthOutput.setDelegate(self, callbackQueue: sessionQueue)
                session.addOutput(depthOutput)
                
                // Connect depth output to video output
                let connection = depthOutput.connection(with: .depthData)
                connection?.isEnabled = true
            }
            
            session.commitConfiguration()
            
            // Create the preview layer on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Create a new preview layer with our capture session
                let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                previewLayer.videoGravity = .resizeAspectFill
                
                // Set it in our published property so SwiftUI can access it
                self.preview = previewLayer
            }
        } catch {
            self.error = .createCaptureInput(error)
            session.commitConfiguration()
        }
    }
    
    /**
     * Starts the camera capture session if it's not already running.
     */
    func startSession() {
        if !session.isRunning {
            sessionQueue.async { [weak self] in
                self?.session.startRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = self?.session.isRunning ?? false
                    
                    // Log status for debugging
                    print("Camera session running: \(self?.isSessionRunning ?? false)")
                }
            }
        }
    }
    
    /**
     * Stops the camera capture session if it's running.
     */
    func stopSession() {
        if session.isRunning {
            sessionQueue.async { [weak self] in
                self?.session.stopRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = self?.session.isRunning ?? false
                }
            }
        }
    }
    
    // MARK: - Depth Analysis
    
    /**
     * Analyzes depth data to determine if a face is three-dimensional (real).
     *
     * This method:
     * 1. Converts depth data to a usable format
     * 2. Samples multiple points around the center of the depth map
     * 3. Calculates the standard deviation of depth values
     * 4. Determines if there's sufficient depth variation for a real face
     *
     * - Parameter depthData: Depth data from the TrueDepth camera
     * - Returns: Boolean indicating whether the depth data likely represents a real face
     */
    func analyzeDepthData(_ depthData: AVDepthData) -> Bool {
        // Convert depth data to the right format
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        
        // Access the pixel buffer
        let pixelBuffer = convertedDepthData.depthDataMap
        
        // Analyze depth values - this is a simplified check
        // Real implementation would require more sophisticated analysis
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        var hasValidDepthVariation = false
        
        // Sample depth values from different regions
        if let baseAddress = baseAddress {
            let buffer = baseAddress.assumingMemoryBound(to: Float32.self)
            
            // Sample center region
            let centerX = width / 2
            let centerY = height / 2
            
            // Check depth variation in a few points around the center
            // This is simplified - real implementation would be more thorough
            let pointsToCheck = 5
            var depthValues: [Float] = []
            
            for i in 0..<pointsToCheck {
                let offset = i * 10
                if centerY + offset < height && centerX + offset < width {
                    let index = (centerY + offset) * width + (centerX + offset)
                    let depthValue = buffer[index]
                    if depthValue > 0 && !depthValue.isNaN {
                        depthValues.append(depthValue)
                    }
                }
            }
            
            // Check if we have enough depth variation
            if depthValues.count >= 3 {
                // Calculate standard deviation
                let mean = depthValues.reduce(0, +) / Float(depthValues.count)
                let variance = depthValues.reduce(0) { $0 + pow($1 - mean, 2) } / Float(depthValues.count)
                let stdDev = sqrt(variance)
                
                // Consider it a live face if there's sufficient depth variation
                hasValidDepthVariation = stdDev > 0.01 // Adjust threshold based on testing
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        return hasValidDepthVariation
    }
}

// MARK: - Capture Delegates

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    /**
     * Processes video frames from the camera to detect faces.
     *
     * This method is called for each new video frame.
     * It delegates face detection to the FaceDetector class.
     */
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Only process face detection if a test is active
        guard isTestActive else { return }
        
        // Use FaceDetector to detect faces, but do it on a background queue to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isTestActive else { return }
            
            self.faceDetector.detectFace(in: sampleBuffer) { detected in
                DispatchQueue.main.async {
                    self.faceDetected = detected
                }
            }
        }
    }
    
    /**
     * Processes depth data from the TrueDepth camera to analyze face liveness.
     *
     * This method is called for each new depth frame.
     * It combines a basic depth variation analysis with the FaceDetector's
     * liveness check to determine if a detected face is real.
     */
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Only process depth data if a test is active
        guard isTestActive else { return }
        
        // Process depth data on a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.isTestActive else { return }
            
            // First perform our basic depth analysis
            let basicDepthCheck = self.analyzeDepthData(depthData)
            
            // Then use FaceDetector's liveness check for additional verification
            let faceDetectorCheck = self.faceDetector.checkLiveness(with: depthData)
            
            // Consider it a live face if both checks pass
            let isLive = basicDepthCheck && faceDetectorCheck
            
            DispatchQueue.main.async {
                self.isLiveFace = isLive
            }
        }
    }
} 