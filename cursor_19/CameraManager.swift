import AVFoundation
import SwiftUI
import Combine

// MARK: - Enrollment State Enum
enum EnrollmentState: String { // Conforming to String for potential logging/debugging
    case notEnrolled
    case promptCenter
    case capturingCenter
    case promptCloser
    case capturingCloserMovement
    case promptFurther
    case capturingFurtherMovement
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
    
    // --- Enrollment Distance Tracking ---
    private var avgCenterDistance: Float? = nil
    private var avgCloserDistance: Float? = nil
    private var avgFurtherDistance: Float? = nil
    
    private let requiredCenterToCloseDelta: Float = 0.15 // 15cm minimum closer movement
    private let requiredCloseToFarDelta: Float = 0.25    // 25cm minimum further movement from closest point
    // --- End Enrollment Distance Tracking ---

    // --- Consecutive Frame Tracking for Liveness Test ---
    private var consecutiveSuccessFrames: Int = 0
    private let requiredConsecutiveFrames: Int = 3 // Require 3 consecutive passes
    // --- End Consecutive Frame Tracking ---

    /// Stores the most recently processed depth values for potential fallback check
    private var lastProcessedDepthValues: [Float]?
    
    /// Holds the thresholds loaded from UserDefaults, if available
    var persistedThresholds: UserDepthThresholds?
    
    /// UserDefaults key for storing thresholds
    private let userDefaultsKey = "userDepthThresholds"
    
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
    
    // MARK: - Initialization
    override init() {
        super.init()
        // Attempt to load saved thresholds on initialization
        self.persistedThresholds = loadThresholds()
        // Set initial enrollment state based on loaded thresholds
        self.enrollmentState = (self.persistedThresholds != nil) ? .enrollmentComplete : .notEnrolled
        // Pass loaded thresholds to the checker
        self.faceDetector.livenessChecker.userThresholds = self.persistedThresholds
        LogManager.shared.log("CameraManager initialized. Enrollment state: \(self.enrollmentState.rawValue)")
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
        // Reset consecutive frame counter for liveness test
        consecutiveSuccessFrames = 0
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
        // Reset distance tracking variables
        avgCenterDistance = nil
        avgCloserDistance = nil
        avgFurtherDistance = nil
        LogManager.shared.log("Cleared captured enrollment data and distance tracking.")
    }

    /**
     * Clears captured enrollment data for a specific state.
     * - Parameter state: The EnrollmentState to clear data for.
     */
    private func clearEnrollmentData(for state: EnrollmentState) {
        enrollmentDataLock.lock()
        capturedEnrollmentData[state]?.removeAll()
        // Or, more robustly ensure the key exists but the array is empty:
        // capturedEnrollmentData[state] = [] 
        enrollmentDataLock.unlock()
        LogManager.shared.log("Cleared captured enrollment data for state: \(state.rawValue)")
    }
    
    /**
     * Calculates the average mean depth from the captured LivenessCheckResults for a specific state.
     * - Parameter state: The EnrollmentState to calculate the average for.
     * - Returns: The average mean depth, or nil if no data or an error occurs.
     */
    private func calculateAverageMeanDepth(for state: EnrollmentState) -> Float? {
        enrollmentDataLock.lock()
        let results = capturedEnrollmentData[state] ?? []
        enrollmentDataLock.unlock()

        guard !results.isEmpty else {
            LogManager.shared.log("Warning: No LivenessCheckResults found for state \(state.rawValue) to calculate average depth.")
            return nil
        }

        let means = results.map { $0.mean }
        let average = means.reduce(0, +) / Float(means.count)
        
        LogManager.shared.log("Calculated average mean depth for state \(state.rawValue): \(average)")
        return average
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
        .promptCloser,
        .capturingCloserMovement,
        .promptFurther,
        .capturingFurtherMovement,
        .calculatingThresholds
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
            case .promptCenter, .promptCloser, .promptFurther:
                // Schedule transition to corresponding 'capturing' state after a delay
                let workItem = DispatchWorkItem { [weak self] in
                    self?.advanceEnrollmentState() // Move to the next step in the sequence (which should be a capturing state)
                }
                self.enrollmentTimerWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem) // 1.5 second delay
                
            case .capturingCenter, .capturingCloserMovement, .capturingFurtherMovement:
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
                        // Persist the newly calculated thresholds
                        self.saveThresholds(calculatedThresholds)
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
         // Reset state without clearing potentially saved thresholds
         // If thresholds were calculated and saved, next launch should still find them.
         // If cancelled mid-way, it will revert to .notEnrolled or .enrollmentFailed.
         if enrollmentState != .enrollmentComplete {
             updateEnrollmentState(to: .enrollmentFailed) 
         }
         LogManager.shared.log("Enrollment sequence cancelled.")
     }
    
    // MARK: - Threshold Calculation
    
    /// Helper struct to hold calculated statistics for a set of LivenessCheckResults
    private struct MetricStats {
        let meanOfMeans: Float
        let stdDevOfMeans: Float
        let meanOfStdDevs: Float
        let stdDevOfStdDevs: Float
        let meanOfRanges: Float
        let stdDevOfRanges: Float
        let meanOfEdgeStdDevs: Float
        let stdDevOfEdgeStdDevs: Float
        let meanOfCenterStdDevs: Float
        let stdDevOfCenterStdDevs: Float
        let meanOfGradientMeans: Float
        let stdDevOfGradientMeans: Float
        let meanOfGradientStdDevs: Float
        let stdDevOfGradientStdDevs: Float
        
        // Absolute min/max observed values (useful for range checks)
        let minObservedMean: Float
        let maxObservedMean: Float
    }
    
    /**
     * Calculates personalized thresholds based on the captured enrollment data.
     * Uses data from center, closer, and further poses to establish broader thresholds.
     * - Returns: A `UserDepthThresholds` object or nil if calculation fails.
     */
    private func calculateThresholds() -> UserDepthThresholds? {
        enrollmentDataLock.lock()
        let centerResults = capturedEnrollmentData[.capturingCenter] ?? []
        let closerMovementResults = capturedEnrollmentData[.capturingCloserMovement] ?? []
        let furtherMovementResults = capturedEnrollmentData[.capturingFurtherMovement] ?? []
        enrollmentDataLock.unlock()
        
        LogManager.shared.log("Starting threshold calculation with Center: \(centerResults.count), Closer Movement: \(closerMovementResults.count), Further Movement: \(furtherMovementResults.count) frames.")
        
        let minFramesPerPose = 3 // Require at least 3 frames for a pose/phase to be included
        guard centerResults.count >= minFramesPerPose || closerMovementResults.count >= minFramesPerPose || furtherMovementResults.count >= minFramesPerPose else {
            LogManager.shared.log("Error: Insufficient data captured across all enrollment phases (Center: \(centerResults.count), Closer: \(closerMovementResults.count), Further: \(furtherMovementResults.count)). Min required: \(minFramesPerPose). Cannot calculate thresholds.")
            return nil
        }
        
        // --- Calculate statistics for each relevant pose dataset --- 
        var poseStatsList: [MetricStats] = [] // Might not be used by final threshold logic
        
        if centerResults.count >= minFramesPerPose, let centerStats = calculateMetricStats(from: centerResults, poseName: "Center") {
            poseStatsList.append(centerStats)
            LogManager.shared.log("Included Center phase data in stats calculation.")
        }
        if closerMovementResults.count >= minFramesPerPose, let closerStats = calculateMetricStats(from: closerMovementResults, poseName: "CloserMovement") {
             poseStatsList.append(closerStats)
             LogManager.shared.log("Included Closer Movement phase data in stats calculation.")
        } else {
            LogManager.shared.log("Warning: Insufficient Closer Movement data (\(closerMovementResults.count) < \(minFramesPerPose)). Skipping for stats calculation.")
        }
        if furtherMovementResults.count >= minFramesPerPose, let furtherStats = calculateMetricStats(from: furtherMovementResults, poseName: "FurtherMovement") {
             poseStatsList.append(furtherStats)
             LogManager.shared.log("Included Further Movement phase data in stats calculation.")
        } else {
             LogManager.shared.log("Warning: Insufficient Further Movement data (\(furtherMovementResults.count) < \(minFramesPerPose)). Skipping for stats calculation.")
        }
        
        // --- REVISED APPROACH: Calculate min/max observed directly from all combined results --- 
        enrollmentDataLock.lock()
        var allCombinedResults: [LivenessCheckResults] = []
        if centerResults.count >= minFramesPerPose { allCombinedResults.append(contentsOf: centerResults) }
        if closerMovementResults.count >= minFramesPerPose { allCombinedResults.append(contentsOf: closerMovementResults) }
        if furtherMovementResults.count >= minFramesPerPose { allCombinedResults.append(contentsOf: furtherMovementResults) }
        enrollmentDataLock.unlock()

        guard !allCombinedResults.isEmpty else {
            LogManager.shared.log("Error: No combined results available for calculation after filtering.")
            return nil
        }

        let allMeans = allCombinedResults.map { $0.mean }
        let allStdDevs = allCombinedResults.map { $0.stdDev }
        let allRanges = allCombinedResults.map { $0.range }
        let allEdgeStdDevs = allCombinedResults.map { $0.edgeStdDev }
        let allCenterStdDevs = allCombinedResults.map { $0.centerStdDev }
        let allGradientStdDevs = allCombinedResults.map { $0.gradientStdDev }
        
        // Helper to get min/max bounds for a metric across poses
        func getBounds( 
            valueExtractor: (MetricStats) -> (mean: Float, stdDev: Float),
            boundType: ThresholdBoundType,
            absoluteClampMin: Float? = nil, 
            absoluteClampMax: Float? = nil,
            hardcodedRef: Float // Original hardcoded value for clamping logic
        ) -> Float {
            let k: Float = 2.0 // Multiplier for std dev range (tunable parameter)
            let bounds = poseStatsList.map { stats -> Float in
                let (mean, stdDev) = valueExtractor(stats)
                // Ensure stdDev is non-negative before potentially subtracting
                let safeStdDev = max(0, stdDev) 
                switch boundType {
                case .min:
                    var finalBound = mean - k * safeStdDev
                    // Clamp: Don't let personalized min be *less strict* (lower) than hardcoded.
                    // Take the HIGHER (stricter) of the calculated bound and the hardcoded reference.
                    // Also apply absolute floor.
                    finalBound = max(finalBound, hardcodedRef)
                    if let clamp = absoluteClampMin { finalBound = max(clamp, finalBound) }
                    return finalBound
                case .max:
                    var finalBound = mean + k * safeStdDev
                    // Clamp: Don't let personalized max be *less strict* (higher) than hardcoded.
                    // Take the LOWER (stricter) of the calculated bound and the hardcoded reference.
                    finalBound = min(finalBound, hardcodedRef)
                    if let clamp = absoluteClampMax { finalBound = min(clamp, finalBound) }
                    return finalBound
                }
            }
            
            var finalBound: Float
            switch boundType {
            case .min:
                finalBound = bounds.min() ?? hardcodedRef // Fallback to hardcoded if no bounds calculated
                // Clamp: Don't let personalized min be *less strict* (lower) than hardcoded.
                // Take the HIGHER (stricter) of the calculated bound and the hardcoded reference.
                // Also apply absolute floor.
                finalBound = max(finalBound, hardcodedRef)
                if let clamp = absoluteClampMin { finalBound = max(clamp, finalBound) }
            case .max:
                finalBound = bounds.max() ?? hardcodedRef // Fallback to hardcoded
                // Clamp: Don't let personalized max be *less strict* (higher) than hardcoded.
                // Take the LOWER (stricter) of the calculated bound and the hardcoded reference.
                finalBound = min(finalBound, hardcodedRef)
                if let clamp = absoluteClampMax { finalBound = min(clamp, finalBound) }
            }
            return finalBound
        }

        enum ThresholdBoundType { case min, max }

        // --- Calculate final thresholds (Using Min Observed for Lower Bounds) --- 
        
        // Mean Depth Range: Use observed min/max across included poses, clamped
        let minObservedMeanOverall = allMeans.min() ?? 0.2
        let maxObservedMeanOverall = allMeans.max() ?? 3.0
        // Define range based on observed min/max during enrollment, plus buffer, clamped
        let buffer: Float = 0.1 // 10cm buffer
        let minMeanDepth = max(0.15, minObservedMeanOverall - buffer) // Clamp floor at 15cm
        let maxMeanDepth = min(3.5, maxObservedMeanOverall + buffer) // Clamp ceiling at 3.5m

        // Min Standard Deviation (Lower bound: min observed - buffer, clamped by hardcoded min)
        let hardcodedMinStdDev: Float = 0.02
        let minObservedStdDev = allStdDevs.min() ?? hardcodedMinStdDev
        let minStdDevBuffer: Float = max(0.001, minObservedStdDev * 0.15) // 15% buffer or 0.001
        let minStdDev = max(hardcodedMinStdDev, minObservedStdDev - minStdDevBuffer)

        // Min Range (Similar to StdDev)
        let hardcodedMinRange: Float = 0.05
        let minObservedRange = allRanges.min() ?? hardcodedMinRange
        let minRangeBuffer: Float = max(0.005, minObservedRange * 0.15) // 15% buffer or 0.005
        let minRange = max(hardcodedMinRange, minObservedRange - minRangeBuffer)

        // Min Edge StdDev (Similar to StdDev)
        let hardcodedMinEdgeStdDev: Float = 0.02
        let minObservedEdgeStdDev = allEdgeStdDevs.min() ?? hardcodedMinEdgeStdDev
        let minEdgeStdDevBuffer: Float = max(0.001, minObservedEdgeStdDev * 0.15)
        let minEdgeStdDev = max(hardcodedMinEdgeStdDev, minObservedEdgeStdDev - minEdgeStdDevBuffer)

        // Min Center StdDev (Similar to StdDev)
        let hardcodedMinCenterStdDev: Float = 0.005
        let minObservedCenterStdDev = allCenterStdDevs.min() ?? hardcodedMinCenterStdDev
        let minCenterStdDevBuffer: Float = max(0.0005, minObservedCenterStdDev * 0.15)
        let minCenterStdDev = max(hardcodedMinCenterStdDev, minObservedCenterStdDev - minCenterStdDevBuffer)

        // Max Gradient Mean (Upper bound: mean + k*stddev)
        let maxGradientMean = getBounds(valueExtractor: { ($0.meanOfGradientMeans, $0.stdDevOfGradientMeans) }, 
                                      boundType: .max, 
                                      absoluteClampMax: 1.0, // Absolute reasonable ceiling 
                                      hardcodedRef: 0.5) // Original hardcoded value

        // Min Gradient StdDev (Similar to StdDev)
        let hardcodedMinGradStdDev: Float = 0.001
        let minObservedGradStdDev = allGradientStdDevs.min() ?? hardcodedMinGradStdDev
        let minGradStdDevBuffer: Float = max(0.0001, minObservedGradStdDev * 0.15)
        let minGradientStdDev = max(hardcodedMinGradStdDev, minObservedGradStdDev - minGradStdDevBuffer)
        
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
     * Calculates metric statistics for a given set of LivenessCheckResults.
     */
    private func calculateMetricStats(from results: [LivenessCheckResults], poseName: String) -> MetricStats? {
        guard !results.isEmpty else {
            LogManager.shared.log("Warning: No results provided for calculating metric stats for pose \(poseName).")
            return nil
        }

        let means = results.map { $0.mean }
        let stdDevs = results.map { $0.stdDev }
        let ranges = results.map { $0.range }
        let edgeStdDevs = results.map { $0.edgeStdDev }
        let centerStdDevs = results.map { $0.centerStdDev }
        let gradientMeans = results.map { $0.gradientMean }
        let gradientStdDevs = results.map { $0.gradientStdDev }

        let (meanOfMeans, stdDevOfMeans) = calculateStats(from: means)
        let (meanOfStdDevs, stdDevOfStdDevs) = calculateStats(from: stdDevs)
        let (meanOfRanges, stdDevOfRanges) = calculateStats(from: ranges)
        let (meanOfEdgeStdDevs, stdDevOfEdgeStdDevs) = calculateStats(from: edgeStdDevs)
        let (meanOfCenterStdDevs, stdDevOfCenterStdDevs) = calculateStats(from: centerStdDevs)
        let (meanOfGradientMeans, stdDevOfGradientMeans) = calculateStats(from: gradientMeans)
        let (meanOfGradientStdDevs, stdDevOfGradientStdDevs) = calculateStats(from: gradientStdDevs)

        // Find absolute min/max for mean depth
        let minObservedMean = means.min() ?? 0
        let maxObservedMean = means.max() ?? 0

        return MetricStats(
            meanOfMeans: meanOfMeans,
            stdDevOfMeans: stdDevOfMeans,
            meanOfStdDevs: meanOfStdDevs,
            stdDevOfStdDevs: stdDevOfStdDevs,
            meanOfRanges: meanOfRanges,
            stdDevOfRanges: stdDevOfRanges,
            meanOfEdgeStdDevs: meanOfEdgeStdDevs,
            stdDevOfEdgeStdDevs: stdDevOfEdgeStdDevs,
            meanOfCenterStdDevs: meanOfCenterStdDevs,
            stdDevOfCenterStdDevs: stdDevOfCenterStdDevs,
            meanOfGradientMeans: meanOfGradientMeans,
            stdDevOfGradientMeans: stdDevOfGradientMeans,
            meanOfGradientStdDevs: meanOfGradientStdDevs,
            stdDevOfGradientStdDevs: stdDevOfGradientStdDevs,
            minObservedMean: minObservedMean,
            maxObservedMean: maxObservedMean
        )
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
    
    // MARK: - Persistence (UserDefaults)
    
    /**
     * Saves the provided thresholds to UserDefaults.
     */
    private func saveThresholds(_ thresholds: UserDepthThresholds) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(thresholds)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            LogManager.shared.log("Successfully saved user thresholds to UserDefaults.")
            // Update the in-memory persisted thresholds as well
            self.persistedThresholds = thresholds
            // Update the checker instance with the new thresholds
            self.faceDetector.livenessChecker.userThresholds = thresholds
        } catch {
            LogManager.shared.log("Error: Failed to encode or save user thresholds: \(error.localizedDescription)")
        }
    }
    
    /**
     * Loads thresholds from UserDefaults.
     * - Returns: The loaded `UserDepthThresholds` or nil if not found or decoding fails.
     */
    private func loadThresholds() -> UserDepthThresholds? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            LogManager.shared.log("Info: No saved user thresholds found in UserDefaults.")
            return nil
        }
        
        let decoder = JSONDecoder()
        do {
            let thresholds = try decoder.decode(UserDepthThresholds.self, from: data)
            LogManager.shared.log("Successfully loaded user thresholds from UserDefaults.")
            thresholds.logSummary() // Log loaded thresholds for confirmation
            return thresholds
        } catch {
            LogManager.shared.log("Error: Failed to decode user thresholds from UserDefaults: \(error.localizedDescription). Clearing invalid data.")
            // Clear invalid data to prevent repeated errors
            clearSavedThresholds()
            return nil
        }
    }
    
    /**
     * Clears any saved thresholds from UserDefaults and resets in-memory state.
     */
    private func clearSavedThresholds() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        self.persistedThresholds = nil
        // Clear thresholds from the checker instance
        self.faceDetector.livenessChecker.userThresholds = nil
        LogManager.shared.log("Cleared saved user thresholds from UserDefaults.")
    }
    
    /**
     * Public method to reset enrollment: clears saved data and resets state.
     */
    func resetEnrollment() {
        LogManager.shared.log("Resetting enrollment...")
        clearSavedThresholds()
        // Update state to reflect that enrollment is now needed
        updateEnrollmentState(to: .notEnrolled)
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
        let isEnrollingAndCapturing = [.capturingCenter, .capturingCloserMovement, .capturingFurtherMovement].contains(enrollmentState)
                                     
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
            
            // Store the latest depth values before performing checks
            self.lastProcessedDepthValues = self.convertDepthDataToArray(pixelBuffer)
            
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
                 
                 // --- Check if enough frames collected AND perform distance validation --- 
                 if capturedCount >= self.framesNeededPerPose {
                    
                     guard let averageDepth = self.calculateAverageMeanDepth(for: currentPoseState) else {
                         LogManager.shared.log("Error: Could not calculate average depth for state \(currentPoseState.rawValue). Failing enrollment.")
                         self.updateEnrollmentState(to: .enrollmentFailed)
                         return // Exit work item early
                     }

                     switch currentPoseState {
                     case .capturingCenter:
                         // Store center distance and advance
                         self.avgCenterDistance = averageDepth
                         LogManager.shared.log("Info: Sufficient frames captured for Center. Stored avg distance: \(averageDepth). Advancing state.")
                         self.advanceEnrollmentState()
                         
                     case .capturingCloserMovement:
                         // Store closer distance and validate
                         self.avgCloserDistance = averageDepth
                         guard let centerDist = self.avgCenterDistance else {
                             LogManager.shared.log("Error: avgCenterDistance is nil. Cannot validate closer movement. Failing enrollment.")
                             self.updateEnrollmentState(to: .enrollmentFailed)
                             return
                         }
                         let actualDelta = centerDist - averageDepth
                         if actualDelta >= self.requiredCenterToCloseDelta {
                             LogManager.shared.log("Info: Sufficient frames captured for Closer Movement. Stored avg distance: \(averageDepth). Delta (\(actualDelta)) meets requirement (≥\(self.requiredCenterToCloseDelta)). Advancing state.")
                             self.advanceEnrollmentState()
                         } else {
                             // --- INSUFFICIENT CLOSER MOVEMENT: Clear data and wait for more movement --- 
                             LogManager.shared.log("Warning: Insufficient closer movement detected (Required delta: ≥\(self.requiredCenterToCloseDelta), Actual delta: \(actualDelta)). Resetting frame count for this phase.")
                             // Clear the insufficient data for this state
                             self.clearEnrollmentData(for: .capturingCloserMovement)
                             // DO NOT change state, just return and let capture continue for this state
                             return // Exit work item, wait for user to move more
                         }
                         
                     case .capturingFurtherMovement:
                         // Store further distance and validate
                         self.avgFurtherDistance = averageDepth
                         guard let centerDist = self.avgCenterDistance, let closerDist = self.avgCloserDistance else {
                             LogManager.shared.log("Error: avgCenterDistance or avgCloserDistance is nil. Cannot validate further movement. Failing enrollment.")
                             self.updateEnrollmentState(to: .enrollmentFailed)
                             return
                         }
                         let actualCloseToFarDelta = averageDepth - closerDist
                         let isFurtherThanCenter = averageDepth > centerDist
                         
                         let check1 = actualCloseToFarDelta >= self.requiredCloseToFarDelta
                         let check2 = isFurtherThanCenter
                         
                         if check1 && check2 {
                             LogManager.shared.log("Info: Sufficient frames captured for Further Movement. Stored avg distance: \(averageDepth). Close->Far Delta (\(actualCloseToFarDelta) ≥ \(self.requiredCloseToFarDelta)) AND Further > Center passed. Advancing state.")
                             self.advanceEnrollmentState() // Advance to calculatingThresholds
                         } else {
                             // --- INSUFFICIENT FURTHER MOVEMENT: Clear data and wait for more movement --- 
                             var reason = "Insufficient further movement detected."
                             if !check1 { reason += " Required close-to-far delta: ≥\(self.requiredCloseToFarDelta), Actual: \(actualCloseToFarDelta)." }
                             if !check2 { reason += " Further distance (\(averageDepth)) not greater than center distance (\(centerDist))." }
                             LogManager.shared.log("Warning: \(reason) Resetting frame count for this phase.")
                             // Clear the insufficient data for this state
                             self.clearEnrollmentData(for: .capturingFurtherMovement)
                             // DO NOT change state, just return and let capture continue for this state
                             return // Exit work item, wait for user to move more
                         }

                     default:
                        // Should not happen for the defined sequence, but handle defensively
                        LogManager.shared.log("Warning: Reached frame count completion in unexpected state: \(currentPoseState.rawValue)")
                        // Optionally advance anyway or fail?
                        self.advanceEnrollmentState() 
                     }
                 }
            // --- Liveness Test Logic ---
            } else if shouldProcessForLivenessTest {
                // Perform the liveness check BUT do not store the result directly via the detector
                let isLive = self.faceDetector.checkLiveness(depthData: depthValues, storeResult: false)
                
                if isLive {
                    self.consecutiveSuccessFrames += 1
                    LogManager.shared.log("Debug: Liveness check PASSED for frame. Consecutive successes: \(self.consecutiveSuccessFrames)/\(self.requiredConsecutiveFrames)")
                    
                    if self.consecutiveSuccessFrames >= self.requiredConsecutiveFrames {
                        // --- REACHED REQUIRED CONSECUTIVE PASSES --- 
                        LogManager.shared.log("Info: Reached \(self.requiredConsecutiveFrames) consecutive successful frames. Setting success flag.")
                        // Call the new method to set the flag
                        self.faceDetector.testResultManager.markTestAsSuccessful()
                        // Reset counter after success is signaled
                        self.consecutiveSuccessFrames = 0 
                    }
                } else {
                    // --- LIVENESS CHECK FAILED FOR FRAME --- 
                    if self.consecutiveSuccessFrames > 0 {
                         LogManager.shared.log("Debug: Liveness check FAILED for frame. Resetting consecutive success count from \(self.consecutiveSuccessFrames) to 0.")
                    }
                    // Reset counter on any single failure
                    self.consecutiveSuccessFrames = 0
                }
                
                 // Update isLiveFace on main thread based on the *instantaneous* result for UI feedback
                 DispatchQueue.main.async {
                     if self.isLiveFace != isLive {
                         self.isLiveFace = isLive
                     }
                 }

                 // Store last processed values regardless of pass/fail for potential fallback
                 self.lastProcessedDepthValues = depthValues
            }
        }
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    /**
     * Performs a liveness check using only hardcoded thresholds on the last processed depth data.
     * To be called only as a fallback when a test times out after failing with user thresholds.
     * - Returns: True if the hardcoded check passes, false otherwise.
     */
    func performHardcodedFallbackCheck() -> Bool {
        guard let lastDepthValues = self.lastProcessedDepthValues else {
            LogManager.shared.log("Error: Cannot perform fallback check, no last depth values available.")
            return false
        }
        
        guard self.persistedThresholds != nil else {
             LogManager.shared.log("Warning: Fallback check requested, but no user thresholds were active initially.")
             return false 
        }

        LogManager.shared.log("Performing fallback check with hardcoded thresholds...")
        
        // Temporarily clear user thresholds
        let originalThresholds = self.faceDetector.livenessChecker.userThresholds
        self.faceDetector.livenessChecker.userThresholds = nil
        
        // Run check (don't store result again)
        let fallbackResult = self.faceDetector.checkLiveness(depthData: lastDepthValues, storeResult: false)
        
        // Restore thresholds
        self.faceDetector.livenessChecker.userThresholds = originalThresholds
        
        return fallbackResult
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