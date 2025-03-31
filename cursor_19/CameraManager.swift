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
    
    /// Access to the face detector for test result analysis
    private(set) var faceDetector = FaceDetector()
    
    // MARK: - Private Properties
    
    /// Queue for handling camera session operations
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    /// Output for receiving video frames from the camera
    private var videoOutput = AVCaptureVideoDataOutput()
    
    /// Output for receiving depth data from the TrueDepth camera
    private var depthOutput = AVCaptureDepthDataOutput()
    
    /// Stores previous depth values for temporal analysis
    private var previousDepthValues: [Float]?
    private var previousMean: Float?
    private var previousGradientPatterns: [[Float]] = []
    private let maxStoredPatterns = 5
    
    /// Flag to control when to store test results
    private var shouldStoreResult = false
    
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
    
    func depthDataOutput(_ depthData: AVDepthData) {
        // Convert depth data to the right format
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let pixelBuffer = convertedDepthData.depthDataMap
        
        // Check for flatness characteristics typical of photos
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        guard let baseAddress = baseAddress else { return }
        let buffer = baseAddress.assumingMemoryBound(to: Float32.self)
        
        // Sample more points in a grid pattern across where the face would be
        var depthValues: [Float] = []
        var edgeDepthValues: [Float] = [] // For edge detection
        var centerDepthValues: [Float] = [] // For center region analysis
        var gradientValues: [Float] = [] // For gradient analysis
        let gridSize = 10
        let centerX = width / 2
        let centerY = height / 2
        let offset = width / 4
        
        // Sample points in a grid pattern
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let sampleX = centerX + Int(Float(x) / Float(gridSize) * Float(offset)) - offset/2
                let sampleY = centerY + Int(Float(y) / Float(gridSize) * Float(offset)) - offset/2
                
                if sampleX >= 0 && sampleX < width && sampleY >= 0 && sampleY < height {
                    let index = sampleY * width + sampleX
                    let depthValue = buffer[index]
                    if depthValue > 0 && !depthValue.isNaN {
                        depthValues.append(depthValue)
                        
                        // Collect edge points (outer points of the grid)
                        if x == 0 || x == gridSize - 1 || y == 0 || y == gridSize - 1 {
                            edgeDepthValues.append(depthValue)
                        }
                        
                        // Collect center region points (inner 6x6 grid)
                        if x >= 2 && x < gridSize - 2 && y >= 2 && y < gridSize - 2 {
                            centerDepthValues.append(depthValue)
                        }
                        
                        // Calculate gradients between adjacent points
                        if x > 0 && y > 0 {
                            let leftIndex = sampleY * width + (sampleX - 1)
                            let topIndex = (sampleY - 1) * width + sampleX
                            let leftGradient = abs(depthValue - buffer[leftIndex])
                            let topGradient = abs(depthValue - buffer[topIndex])
                            gradientValues.append(leftGradient)
                            gradientValues.append(topGradient)
                        }
                    }
                }
            }
        }
        
        // Early check for sufficient depth data (at least 30 points required)
        let hasMinimumDataPoints = depthValues.count >= 30
        
        // Calculate depth statistics if we have enough data points
        if hasMinimumDataPoints {
            // Calculate standard deviation
            let mean = depthValues.reduce(0, +) / Float(depthValues.count)
            let variance = depthValues.reduce(0) { $0 + pow($1 - mean, 2) } / Float(depthValues.count)
            let stdDev = sqrt(variance)
            
            // Calculate min/max range
            guard let min = depthValues.min(), let max = depthValues.max() else {
                if shouldStoreResult {
                    self.faceDetector.storeTestResult(isLive: false)
                }
                return
            }
            let range = max - min
            
            // Calculate edge variation
            let edgeMean = edgeDepthValues.reduce(0, +) / Float(edgeDepthValues.count)
            let edgeVariance = edgeDepthValues.reduce(0) { $0 + pow($1 - edgeMean, 2) } / Float(edgeDepthValues.count)
            let edgeStdDev = sqrt(edgeVariance)
            
            // Calculate center region variation
            let centerMean = centerDepthValues.reduce(0, +) / Float(centerDepthValues.count)
            let centerVariance = centerDepthValues.reduce(0) { $0 + pow($1 - centerMean, 2) } / Float(centerDepthValues.count)
            let centerStdDev = sqrt(centerVariance)
            
            // Calculate gradient statistics
            let gradientMean = gradientValues.reduce(0, +) / Float(gradientValues.count)
            let gradientVariance = gradientValues.reduce(0) { $0 + pow($1 - gradientMean, 2) } / Float(gradientValues.count)
            let gradientStdDev = sqrt(gradientVariance)
            
            // Log statistics for debugging
            print("Depth stats - Mean: \(mean), StdDev: \(stdDev), Range: \(range)")
            print("Edge stats - Mean: \(edgeMean), StdDev: \(edgeStdDev)")
            print("Center stats - Mean: \(centerMean), StdDev: \(centerStdDev)")
            print("Gradient stats - Mean: \(gradientMean), StdDev: \(gradientStdDev)")
            
            // Enhanced checks for photo detection:
            // 1. Check if depth variation is too low (typical of photos)
            let isTooFlat = stdDev < 0.15 || range < 0.3  // More lenient thresholds
            
            // 2. Check if mean depth is outside reasonable range for a real face
            let isUnrealisticDepth = mean < 0.2 || mean > 3.0  // Wider range
            
            // 3. Check if edge variation is too low (photos typically have sharp edges)
            let hasSharpEdges = edgeStdDev < 0.15  // More lenient threshold
            
            // 4. Check if the depth profile is too uniform
            let isTooUniform = stdDev < 0.2 && range < 0.4  // More lenient thresholds
            
            // 5. Check if center region shows natural face-like depth variation
            let hasNaturalCenterVariation = centerStdDev >= 0.1
            
            // 6. Check if the depth distribution is too linear (typical of photos)
            let depthDistribution = depthValues.sorted()
            let isLinearDistribution = self.faceDetector.hasNaturalDepthDistribution(depthValues)
            
            // 7. Check for unnatural gradient patterns (typical of moving flat surfaces)
            let hasUnnaturalGradients = gradientStdDev < 0.005 || gradientMean > 0.2  // More lenient thresholds
            
            // 8. Check temporal consistency with more lenient thresholds
            let hasInconsistentTemporalChanges = self.faceDetector.checkTemporalConsistency(depthValues)
            
            // Store gradient pattern for temporal analysis
            let currentPattern = gradientValues
            previousGradientPatterns.append(currentPattern)
            if previousGradientPatterns.count > maxStoredPatterns {
                previousGradientPatterns.removeFirst()
            }
            
            // A face is considered "live" if it passes most checks (not all)
            // Require at least 6 out of 9 checks to pass
            let passedChecks = [
                !isTooFlat,
                !isUnrealisticDepth,
                !hasSharpEdges,
                !isTooUniform,
                hasNaturalCenterVariation,
                !isLinearDistribution,
                !hasUnnaturalGradients,
                !hasInconsistentTemporalChanges
            ].filter { $0 }.count
            
            // IMPORTANT: A face is only considered live if it passes at least 6 out of 8 checks
            let requiredChecks = 6
            let isLive = passedChecks >= requiredChecks
            
            // Debug log for liveness determination
            print("Liveness check: \(isLive ? "PASS" : "FAIL") - \(passedChecks)/8 checks passed")
            if !isLive {
                let failedChecks = [
                    isTooFlat ? "Depth Variation" : nil,
                    isUnrealisticDepth ? "Realistic Depth" : nil,
                    hasSharpEdges ? "Edge Variation" : nil,
                    isTooUniform ? "Depth Profile" : nil,
                    !hasNaturalCenterVariation ? "Center Variation" : nil,
                    isLinearDistribution ? "Depth Distribution" : nil,
                    hasUnnaturalGradients ? "Gradient Pattern" : nil,
                    hasInconsistentTemporalChanges ? "Temporal Consistency" : nil
                ].compactMap { $0 }
                print("Failed checks: \(failedChecks.joined(separator: ", "))")
            }
            
            // Store test result data only if explicitly requested
            if shouldStoreResult {
                self.faceDetector.storeTestResult(isLive: isLive)
            }
            
            // Update previous values for next frame
            previousDepthValues = depthValues
            previousMean = mean
        } else {
            // Not enough valid depth data points
            print("Insufficient depth data: only \(depthValues.count) points (minimum 30 required)")
            
            // Store insufficient data result if requested
            if shouldStoreResult {
                self.faceDetector.storeTestResult(isLive: false)
            }
        }
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
            
            // Convert depth data to the right format
            let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            let pixelBuffer = convertedDepthData.depthDataMap
            
            // First perform our basic depth analysis
            let basicDepthCheck = self.analyzeDepthData(depthData)
            
            // Determine when to store the result:
            // 1. Store if we have a face but it's not yet confirmed as live (transition state)
            // 2. OR store if we have a face that's confirmed live but no result is stored yet
            // This ensures we capture results for both transitioning and already-live faces
            let hasNoStoredResult = self.faceDetector.getLastTestResult() == nil || 
                                  !self.faceDetector.hasResultForTest(id: self.faceDetector.getCurrentTestId() ?? UUID())
            
            let shouldStoreResult = self.faceDetected && 
                                  ((!self.isLiveFace) || // Transition case 
                                   (self.isLiveFace && hasNoStoredResult)) // Already live but no stored result
            
            // Use FaceDetector's liveness check for additional verification
            let faceDetectorCheck = self.faceDetector.checkLiveness(with: pixelBuffer, storeResult: shouldStoreResult)
            
            // If detailed results have been stored, get the last test result
            // to verify the actual pass/fail status instead of just using the boolean
            var isLive = false
            
            if shouldStoreResult && faceDetectorCheck {
                // For extra verification, check the actual test result details
                if let lastResult = self.faceDetector.getLastTestResult() {
                    // Only consider it live if:
                    // 1. The result is marked as live in the detailed result
                    // 2. At least 6 security checks actually passed (as shown in debug)
                    // 3. There was sufficient depth data
                    isLive = lastResult.isLive && 
                             lastResult.numPassedChecks >= 6 && 
                             lastResult.depthSampleCount >= 30
                    
                    print("Test verification: isLive=\(isLive), checks=\(lastResult.numPassedChecks)/\(lastResult.requiredChecks), depth=\(lastResult.depthSampleCount)")
                } else {
                    // If no detailed result exists, use the basic checks
                    isLive = basicDepthCheck && faceDetectorCheck
                    print("No result stored yet, using basic checks: isLive=\(isLive)")
                }
            } else {
                // For ongoing checks without result storage, use both checks
                isLive = basicDepthCheck && faceDetectorCheck
            }
            
            // Store the result one more time if we're marking as live but don't have a stored result
            if isLive && hasNoStoredResult && !shouldStoreResult {
                print("Storing result for confirmed live face with no existing result")
                _ = self.faceDetector.checkLiveness(with: pixelBuffer, storeResult: true)
            }
            
            // Only update the published property on the main thread if there's a change
            DispatchQueue.main.async {
                if self.isLiveFace != isLive {
                    self.isLiveFace = isLive
                }
            }
        }
    }
} 