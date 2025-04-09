import AVFoundation
import SwiftUI
import Combine

// MARK: - Enrollment State Enum
enum EnrollmentState: String { // Conforming to String for potential logging/debugging
    case notEnrolled
    case promptCenter
    case capturingCenter
    case promptLeft
    case capturingLeft
    case promptRight
    case capturingRight
    case promptUp
    case capturingUp
    case promptDown
    case capturingDown
    case promptCloser
    case capturingCloser
    case promptFurther
    case capturingFurther
    case calculatingThresholds
    case enrollmentComplete
    case enrollmentFailed
}

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
    
    /// Manages the current state of the user enrollment process
    @Published var enrollmentState: EnrollmentState = .notEnrolled
    
    /// Flag to track if a face was seen at any point during the current test
    var faceWasDetectedThisTest = false
    
    /// Access to the face detector for test result analysis
    private(set) var faceDetector = FaceDetector()
    
    /// Timer work item for delayed state transitions during enrollment
    private var enrollmentTimerWorkItem: DispatchWorkItem?
    
    /// Dictionary to store captured enrollment data (LivenessCheckResults per state)
    private var capturedEnrollmentData: [EnrollmentState: [LivenessCheckResults]] = [:]
    /// How many valid frames to capture for each pose during enrollment
    private let framesNeededPerPose = 7 // Capture 7 frames per pose
    /// Timeout for capturing data for a single pose
    private let captureTimeout: TimeInterval = 10.0 // 10 seconds timeout per pose
    /// Lock for thread-safe access to capturedEnrollmentData
    private let enrollmentDataLock = NSLock()
    
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
    
    // MARK: - Test State Management
    
    /**
     * Resets the CameraManager state for a new enrollment or test.
     */
    func prepareForNewTest() {
        LogManager.shared.log("Preparing for new test/enrollment...")
        // Reset Face Detector (includes LivenessChecker state)
        faceDetector.resetForNewTest()
        // Reset flags
        faceDetected = false
        isLiveFace = false 
        faceWasDetectedThisTest = false
        // Reset enrollment data if starting fresh
        resetEnrollmentData()
        // Activate test mode (enables depth processing etc.)
        isTestActive = true 
        LogManager.shared.log("CameraManager prepared.")
    }

    /**
     * Clears captured enrollment data.
     */
    private func resetEnrollmentData() {
        enrollmentDataLock.lock()
        capturedEnrollmentData.removeAll()
        enrollmentDataLock.unlock()
        LogManager.shared.log("Cleared captured enrollment data.")
    }

    /**
     * Finalizes the current test or enrollment attempt.
     */
    func finalizeTest() {
        // Check if a face was ever detected during this test before resetting flags
        if isTestActive && !faceWasDetectedThisTest {
            print("Debug: Test completed without detecting any face.")
        }
        
        // Reset state variables after checking the flag
        isTestActive = false
        // It might be good practice to also reset these here, although prepareForNewTest handles the next run
        // faceDetected = false 
        // isLiveFace = false
        print("CameraManager finalized test.")
    }
    
    // MARK: - Enrollment Sequence Control
    
    // Define the sequence of poses required for enrollment
    private let enrollmentSequence: [EnrollmentState] = [
        .promptCenter,
        .capturingCenter,
        .promptLeft,
        .capturingLeft,
        .promptCenter, // Return to center
        .capturingCenter,
        .promptRight,
        .capturingRight,
        .promptCenter, // Return to center
        .capturingCenter,
        .promptUp,
        .capturingUp,
        .promptCenter, // Return to center
        .capturingCenter,
        .promptDown,
        .capturingDown,
        .promptCenter, // Return to center
        .capturingCenter,
        .promptCloser,
        .capturingCloser,
        .promptCenter, // Return to center
        .capturingCenter,
        .promptFurther,
        .capturingFurther,
        .promptCenter, // Final center pose
        .capturingCenter,
        .calculatingThresholds // Final step
    ]
    
    private var currentEnrollmentStepIndex = -1
    
    /**
     * Starts the user enrollment sequence.
     */
    func startEnrollmentSequence() {
        guard enrollmentState == .notEnrolled || enrollmentState == .enrollmentFailed else {
            LogManager.shared.log("Warning: Enrollment sequence requested but already in state \(enrollmentState.rawValue)")
            return
        }
        LogManager.shared.log("Enrollment sequence started.")
        // Reset manager state (clears old results, resets flags, resets enrollment data)
        prepareForNewTest()
        
        currentEnrollmentStepIndex = -1 // Reset index
        advanceEnrollmentState() // Start with the first step
    }
    
    /**
     * Advances the enrollment process to the next state in the sequence.
     * Handles delays for prompt states and triggers next steps.
     */
    private func advanceEnrollmentState() {
        // Cancel any pending timer from the previous state
        enrollmentTimerWorkItem?.cancel()
        
        currentEnrollmentStepIndex += 1
        
        guard currentEnrollmentStepIndex < enrollmentSequence.count else {
            // Reached the end of the defined sequence (should end on .calculatingThresholds)
            LogManager.shared.log("Enrollment sequence index out of bounds. Completing.")
            // This path shouldn't ideally be hit if sequence includes calculating
            updateEnrollmentState(to: .calculatingThresholds) 
            return
        }
        
        let nextState = enrollmentSequence[currentEnrollmentStepIndex]
        updateEnrollmentState(to: nextState)
    }

    /**
     * Updates the enrollmentState on the main thread and handles timed transitions.
     * - Parameter newState: The state to transition to.
     */
    private func updateEnrollmentState(to newState: EnrollmentState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Avoid redundant updates
            guard self.enrollmentState != newState else { return }
            
            self.enrollmentState = newState
            LogManager.shared.log("Enrollment state changed to: \(newState.rawValue)")
            
            // Handle automatic transitions after delays
            switch newState {
            case .promptCenter, .promptLeft, .promptRight, .promptUp, .promptDown, .promptCloser, .promptFurther:
                // Schedule transition to corresponding 'capturing' state after a delay
                let workItem = DispatchWorkItem { [weak self] in
                    self?.advanceEnrollmentState() // Move to the next step in the sequence (which should be a capturing state)
                }
                self.enrollmentTimerWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem) // 1.5 second delay
                
            case .capturingCenter, .capturingLeft, .capturingRight, .capturingUp, .capturingDown, .capturingCloser, .capturingFurther:
                // Data capture logic (Step 1.5) will eventually trigger advanceEnrollmentState()
                // Start a timeout timer for this capture state
                let timeoutWorkItem = DispatchWorkItem { [weak self] in
                    guard let self = self, self.enrollmentState == newState else { return } // Only timeout if still in this state
                    LogManager.shared.log("Error: Timeout occurred while capturing data for state \(newState.rawValue). Failing enrollment.")
                    self.updateEnrollmentState(to: .enrollmentFailed)
                }
                self.enrollmentTimerWorkItem = timeoutWorkItem
                DispatchQueue.main.asyncAfter(deadline: .now() + self.captureTimeout, execute: timeoutWorkItem)
                
            case .calculatingThresholds:
                // Trigger actual threshold calculation
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in // Perform calculation off main thread
                    guard let self = self else { return }
                    if let calculatedThresholds = self.calculateThresholds() {
                        // TODO: Step 2.7 - Persist these thresholds
                        // For now, just log and transition state
                        self.updateEnrollmentState(to: .enrollmentComplete)
                    } else {
                        LogManager.shared.log("Error: Threshold calculation failed.")
                        self.updateEnrollmentState(to: .enrollmentFailed)
                    }
                }
                
            case .enrollmentComplete, .enrollmentFailed, .notEnrolled:
                // Final states, cancel any pending timers
                self.enrollmentTimerWorkItem?.cancel()
                self.currentEnrollmentStepIndex = -1 // Reset sequence progress
            }
        }
    }
    
    /**
     * Cancels the enrollment process, resetting the state.
     */
     func cancelEnrollment() {
         enrollmentTimerWorkItem?.cancel()
         currentEnrollmentStepIndex = -1
         // Reset to .notEnrolled if it wasn't complete, otherwise keep .enrollmentComplete?
         // Let's reset to failed for now if cancelled midway
         if enrollmentState != .enrollmentComplete {
             updateEnrollmentState(to: .enrollmentFailed) 
         }
         LogManager.shared.log("Enrollment sequence cancelled.")
     }
    
    // MARK: - Threshold Calculation
    
    /**
     * Calculates personalized thresholds based on the captured enrollment data.
     * Uses the mean +/- k * stddev approach across all valid captured frames.
     * - Returns: A `UserDepthThresholds` object or nil if calculation fails.
     */
    private func calculateThresholds() -> UserDepthThresholds? {
        enrollmentDataLock.lock()
        // --- Use only data from center poses for baseline thresholds --- 
        let centerResults = capturedEnrollmentData[.capturingCenter] ?? [] 
        enrollmentDataLock.unlock()
        
        LogManager.shared.log("Starting threshold calculation using \(centerResults.count) frames from '.capturingCenter' state.")
        
        // Need a minimum number of frames to calculate meaningful stats
        // Require fewer frames if only using center data, but still need enough for stats
        guard centerResults.count >= 5 else { // Require at least 5 center frames
            LogManager.shared.log("Error: Insufficient center pose data captured (\(centerResults.count) frames < 5) for threshold calculation.")
            return nil
        }
        
        // Extract individual statistic arrays
        let means = centerResults.map { $0.mean }
        let stdDevs = centerResults.map { $0.stdDev }
        let ranges = centerResults.map { $0.range }
        let edgeStdDevs = centerResults.map { $0.edgeStdDev }
        let centerStdDevs = centerResults.map { $0.centerStdDev }
        let gradientMeans = centerResults.map { $0.gradientMean }
        let gradientStdDevs = centerResults.map { $0.gradientStdDev }
        
        // --- Calculate Thresholds (Initial Strategy: Mean +/- k * StdDev based on Center Poses) ---
        let k: Float = 2.0 // Multiplier for std dev range (tunable parameter)
        
        // Mean Depth Range (Special case: use min/max directly? Or mean +/- k*stddev?)
        // Let's try mean +/- k * stddev for consistency, but clamp to realistic bounds.
        let (meanOfMeans, stdDevOfMeans) = calculateStats(from: means)
        let calculatedMinMean = meanOfMeans - k * stdDevOfMeans
        let calculatedMaxMean = meanOfMeans + k * stdDevOfMeans
        // Clamp to reasonable overall limits (e.g., 0.1m to 4.0m) to avoid extremes
        let minMeanDepth = max(0.1, calculatedMinMean)
        let maxMeanDepth = min(4.0, calculatedMaxMean)

        // Min Standard Deviation (Lower bound: mean - k*stddev, clamped at > 0)
        let (meanStdDev, stdDevOfStdDev) = calculateStats(from: stdDevs)
        let calculatedMinStdDev = meanStdDev - k * stdDevOfStdDev
        let minStdDev = max(0.001, calculatedMinStdDev) // Ensure minimum > 0

        // Min Range (Similar to StdDev)
        let (meanRange, stdDevOfRange) = calculateStats(from: ranges)
        let calculatedMinRange = meanRange - k * stdDevOfRange
        let minRange = max(0.001, calculatedMinRange)

        // Min Edge StdDev (Similar to StdDev)
        let (meanEdgeStdDev, stdDevOfEdgeStdDev) = calculateStats(from: edgeStdDevs)
        let calculatedMinEdgeStdDev = meanEdgeStdDev - k * stdDevOfEdgeStdDev
        let minEdgeStdDev = max(0.001, calculatedMinEdgeStdDev)

        // Min Center StdDev (Similar to StdDev)
        let (meanCenterStdDev, stdDevOfCenterStdDev) = calculateStats(from: centerStdDevs)
        let calculatedMinCenterStdDev = meanCenterStdDev - k * stdDevOfCenterStdDev
        let minCenterStdDev = max(0.001, calculatedMinCenterStdDev)

        // Max Gradient Mean (Upper bound: mean + k*stddev)
        let (meanGradientMean, stdDevOfGradientMean) = calculateStats(from: gradientMeans)
        let maxGradientMean = meanGradientMean + k * stdDevOfGradientMean

        // Min Gradient StdDev (Similar to StdDev)
        let (meanGradientStdDev, stdDevOfGradientStdDev) = calculateStats(from: gradientStdDevs)
        let calculatedMinGradientStdDev = meanGradientStdDev - k * stdDevOfGradientStdDev
        let minGradientStdDev = max(0.0001, calculatedMinGradientStdDev)
        
        let thresholds = UserDepthThresholds(
            minMeanDepth: minMeanDepth,
            maxMeanDepth: maxMeanDepth,
            minStdDev: minStdDev,
            minRange: minRange,
            minEdgeStdDev: minEdgeStdDev,
            minCenterStdDev: minCenterStdDev,
            maxGradientMean: maxGradientMean,
            minGradientStdDev: minGradientStdDev
        )
        
        thresholds.logSummary() // Log the calculated thresholds
        return thresholds
    }
    
    /**
     * Helper to calculate mean and standard deviation for an array of Floats.
     * - Parameter values: Array of Float values.
     * - Returns: Tuple containing (mean, standardDeviation). Returns (0, 0) for empty or single-element arrays.
     */
    private func calculateStats(from values: [Float]) -> (mean: Float, standardDeviation: Float) {
        let count = Float(values.count)
        guard count > 1 else { return (values.first ?? 0, 0) } // Return mean if only 1 value, 0 stddev
        
        let mean = values.reduce(0, +) / count
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / count // Population variance
        let standardDeviation = sqrt(variance)
        
        return (mean, standardDeviation)
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
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Or if we are in an enrollment capturing state AND a face is detected
        let isEnrollingAndCapturing = [.capturingCenter, .capturingLeft, .capturingRight, 
                                     .capturingUp, .capturingDown, .capturingCloser, 
                                     .capturingFurther].contains(enrollmentState)
                                     
        let shouldProcessForLivenessTest = isTestActive && faceDetected && !isEnrollingAndCapturing
        let shouldProcessForEnrollment = isEnrollingAndCapturing && faceDetected
        
        guard shouldProcessForLivenessTest || shouldProcessForEnrollment else {
            // If the test is active but no face is detected, print a debug message - REMOVED
            /*
            if isTestActive && !faceDetected {
                print("Debug: Depth data received, but no face detected. Skipping liveness check.")
            }
            */
            // If no face is detected, ensure isLiveFace is false
            if isLiveFace { // Avoid unnecessary main thread dispatches
                 DispatchQueue.main.async {
                     self.isLiveFace = false
                 }
            }
            return 
        }
        
        // --- Process depth data on background queue ---
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Convert depth data to the right format
            let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            let pixelBuffer = convertedDepthData.depthDataMap
            let currentPoseState = self.enrollmentState // Capture state for logging/use
            
            // Convert depth data to array of Float values
            let depthValues = self.convertDepthDataToArray(pixelBuffer)
            
            // Log depth data dimensions for debugging
            // print("Depth data dimensions: \(CVPixelBufferGetWidth(pixelBuffer))x\(CVPixelBufferGetHeight(pixelBuffer))")
            // print("Sampled points: \(depthValues.count)")
            
            // Perform the core liveness checks to get statistics
            // Use the livenessChecker directly associated with the faceDetector
            let checkResults = self.faceDetector.livenessChecker.performLivenessChecks(depthValues: depthValues)
            
            // --- Enrollment Data Capture Logic ---
            if shouldProcessForEnrollment {
                 LogManager.shared.log("Debug: Processing frame for enrollment state: \(currentPoseState.rawValue)")
                 
                 self.enrollmentDataLock.lock()
                 var currentDataForState = self.capturedEnrollmentData[currentPoseState] ?? []
                 currentDataForState.append(checkResults)
                 self.capturedEnrollmentData[currentPoseState] = currentDataForState
                 let capturedCount = currentDataForState.count
                 self.enrollmentDataLock.unlock()
                 
                 LogManager.shared.log("Debug: Captured frame \(capturedCount)/\(self.framesNeededPerPose) for \(currentPoseState.rawValue)")
                 
                 // Check if enough frames are collected for the current pose
                 if capturedCount >= self.framesNeededPerPose {
                     LogManager.shared.log("Info: Sufficient frames captured for \(currentPoseState.rawValue). Advancing state.")
                     // Advance to the next state (e.g., next prompt or calculating)
                     self.advanceEnrollmentState()
                 }
            // --- Liveness Test Logic ---
            } else if shouldProcessForLivenessTest {
                // Original liveness check logic (using FaceDetector's method which uses the results)
                // Note: `checkLiveness` inside FaceDetector already calls performLivenessChecks
                let isLive = self.faceDetector.checkLiveness(depthData: depthValues, storeResult: true)
                
                // Update isLiveFace on main thread
                DispatchQueue.main.async {
                    self.isLiveFace = isLive
                }
            }
        }
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
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
                    // If a face is detected during an active test, set the flag
                    if detected && self.isTestActive {
                        self.faceWasDetectedThisTest = true
                    }
                }
            }
        }
    }
    
    /**
     * Converts CVPixelBuffer depth data to an array of Float values
     */
    private func convertDepthDataToArray(_ depthData: CVPixelBuffer) -> [Float] {
        CVPixelBufferLockBaseAddress(depthData, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthData, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthData)
        let height = CVPixelBufferGetHeight(depthData)
        let baseAddress = CVPixelBufferGetBaseAddress(depthData)
        
        guard let baseAddress = baseAddress else { return [] }
        let buffer = baseAddress.assumingMemoryBound(to: Float32.self)
        
        var depthValues: [Float] = []
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
                    }
                }
            }
        }
        
        return depthValues
    }
} 