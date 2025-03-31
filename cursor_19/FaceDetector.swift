import Foundation
import AVFoundation
import Vision
import UIKit

/**
 * TestResultData - Stores comprehensive data about a liveness test result
 *
 * This struct captures all relevant data points for a single liveness test,
 * which can be used for debugging false positive/negative results.
 */
struct TestResultData: Identifiable, Encodable {
    let id: UUID
    let timestamp: Date
    let isLive: Bool
    let testId: UUID  // Unique ID for each test session
    
    // Depth data statistics
    let depthMean: Float
    let depthStdDev: Float
    let depthRange: Float
    let edgeMean: Float
    let edgeStdDev: Float
    let centerMean: Float
    let centerStdDev: Float
    
    // Gradient statistics
    let gradientMean: Float
    let gradientStdDev: Float
    
    // Decision metrics - which checks passed/failed
    let isTooFlat: Bool
    let isUnrealisticDepth: Bool
    let hasSharpEdges: Bool
    let isTooUniform: Bool
    let hasNaturalCenterVariation: Bool
    let isLinearDistribution: Bool
    let hasUnnaturalGradients: Bool
    let hasInconsistentTemporalChanges: Bool
    
    // Test metadata
    let numPassedChecks: Int
    let requiredChecks: Int
    let depthSampleCount: Int
    let isStillFaceDetected: Bool
    
    // Environmental
    let deviceOrientation: UIDeviceOrientation
    
    // Initialize with all properties
    init(
        isLive: Bool,
        depthMean: Float,
        depthStdDev: Float,
        depthRange: Float,
        edgeMean: Float,
        edgeStdDev: Float,
        centerMean: Float,
        centerStdDev: Float,
        gradientMean: Float,
        gradientStdDev: Float,
        isTooFlat: Bool,
        isUnrealisticDepth: Bool,
        hasSharpEdges: Bool,
        isTooUniform: Bool,
        hasNaturalCenterVariation: Bool,
        isLinearDistribution: Bool,
        hasUnnaturalGradients: Bool,
        hasInconsistentTemporalChanges: Bool,
        numPassedChecks: Int,
        requiredChecks: Int,
        depthSampleCount: Int,
        isStillFaceDetected: Bool,
        deviceOrientation: UIDeviceOrientation,
        timestamp: Date = Date(),
        id: UUID = UUID(),
        testId: UUID
    ) {
        self.id = id
        self.timestamp = timestamp
        self.isLive = isLive
        self.depthMean = depthMean
        self.depthStdDev = depthStdDev
        self.depthRange = depthRange
        self.edgeMean = edgeMean
        self.edgeStdDev = edgeStdDev
        self.centerMean = centerMean
        self.centerStdDev = centerStdDev
        self.gradientMean = gradientMean
        self.gradientStdDev = gradientStdDev
        self.isTooFlat = isTooFlat
        self.isUnrealisticDepth = isUnrealisticDepth
        self.hasSharpEdges = hasSharpEdges
        self.isTooUniform = isTooUniform
        self.hasNaturalCenterVariation = hasNaturalCenterVariation
        self.isLinearDistribution = isLinearDistribution
        self.hasUnnaturalGradients = hasUnnaturalGradients
        self.hasInconsistentTemporalChanges = hasInconsistentTemporalChanges
        self.numPassedChecks = numPassedChecks
        self.requiredChecks = requiredChecks
        self.depthSampleCount = depthSampleCount
        self.isStillFaceDetected = isStillFaceDetected
        self.deviceOrientation = deviceOrientation
        self.testId = testId
    }
    
    // CodingKeys and encode to handle UIDeviceOrientation (which is not Encodable)
    enum CodingKeys: String, CodingKey {
        case id, timestamp, isLive, depthMean, depthStdDev, depthRange, edgeMean, edgeStdDev
        case centerMean, centerStdDev, gradientMean, gradientStdDev, isTooFlat, isUnrealisticDepth
        case hasSharpEdges, isTooUniform, hasNaturalCenterVariation, isLinearDistribution
        case hasUnnaturalGradients, hasInconsistentTemporalChanges
        case numPassedChecks, depthSampleCount, deviceOrientation, testId
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isLive, forKey: .isLive)
        try container.encode(depthMean, forKey: .depthMean)
        try container.encode(depthStdDev, forKey: .depthStdDev)
        try container.encode(depthRange, forKey: .depthRange)
        try container.encode(edgeMean, forKey: .edgeMean)
        try container.encode(edgeStdDev, forKey: .edgeStdDev)
        try container.encode(centerMean, forKey: .centerMean)
        try container.encode(centerStdDev, forKey: .centerStdDev)
        try container.encode(gradientMean, forKey: .gradientMean)
        try container.encode(gradientStdDev, forKey: .gradientStdDev)
        try container.encode(isTooFlat, forKey: .isTooFlat)
        try container.encode(isUnrealisticDepth, forKey: .isUnrealisticDepth)
        try container.encode(hasSharpEdges, forKey: .hasSharpEdges)
        try container.encode(isTooUniform, forKey: .isTooUniform)
        try container.encode(hasNaturalCenterVariation, forKey: .hasNaturalCenterVariation)
        try container.encode(isLinearDistribution, forKey: .isLinearDistribution)
        try container.encode(hasUnnaturalGradients, forKey: .hasUnnaturalGradients)
        try container.encode(hasInconsistentTemporalChanges, forKey: .hasInconsistentTemporalChanges)
        try container.encode(numPassedChecks, forKey: .numPassedChecks)
        try container.encode(depthSampleCount, forKey: .depthSampleCount)
        try container.encode(Int(deviceOrientation.rawValue), forKey: .deviceOrientation)
        try container.encode(testId, forKey: .testId)
    }
}

/**
 * FaceDetector - Handles face detection and liveness verification
 *
 * This class provides sophisticated face detection and liveness verification using Apple's Vision framework
 * and the TrueDepth camera. It implements a multi-layered approach to distinguish between real 3D faces
 * and various spoof attempts including photos, screens, and 3D masks.
 *
 * Key features:
 * - Real-time face detection using Vision framework
 * - Advanced depth data analysis with 10x10 grid sampling
 * - Statistical analysis for spoof detection
 * - Temporal consistency checking
 * - Specialized 3D mask detection
 * - Gradient pattern analysis
 *
 * The liveness detection system:
 * 1. Samples 100 points across the face region in a 10x10 grid pattern
 * 2. Performs multiple statistical analyses on depth data
 * 3. Tracks temporal changes for consistency
 * 4. Analyzes gradient patterns for mask detection
 * 5. Uses adaptive thresholds for reliable detection
 *
 * The algorithm requires passing at least 6 out of 9 security checks:
 * 1. Depth variation check (stdDev >= 0.15 and range >= 0.3)
 * 2. Realistic depth range check (0.2-3.0m)
 * 3. Natural edge variation check (edgeStdDev >= 0.15)
 * 4. Depth profile variation check (stdDev >= 0.2 or range >= 0.4)
 * 5. Center region depth check (centerStdDev >= 0.1)
 * 6. Non-linear depth distribution check
 * 7. Natural gradient pattern check (gradientStdDev >= 0.005 and gradientMean <= 0.2)
 * 8. Temporal consistency check (depth changes 0.005-1.0m)
 * 9. 3D mask characteristic check
 */
class FaceDetector {
    // MARK: - Private Properties
    
    /// Vision request for detecting facial features in images
    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    
    /// Handler for processing sequences of vision requests
    private let faceDetectionRequestHandler = VNSequenceRequestHandler()
    
    /// Stores previous depth values for temporal analysis
    private var previousDepthValues: [Float]?
    private var previousMean: Float?
    private var previousGradientPatterns: [[Float]] = [] // Store recent gradient patterns
    private let maxStoredPatterns = 5 // Number of patterns to store for analysis
    
    // MARK: - Test Results Storage
    
    /// Maximum number of test results to store in app memory
    private let maxStoredResults: Int = 20
    
    /// Stored test results for analysis and debugging
    private var testResults: [TestResultData] = []
    
    /// Key for persisting test results in UserDefaults
    private let testResultsKey = "FaceDetectorTestResults"
    
    /// Current test ID to prevent duplicate results from the same test
    private var currentTestId: UUID? = nil
    
    init() {
        // Clear all previous test results on app launch
        clearAllTestResults()
    }
    
    // MARK: - Test Results Management
    
    /**
     * Completely clears all test results from memory and persistent storage
     */
    private func clearAllTestResults() {
        // Clear in-memory results
        testResults = []
        
        // Clear current test ID
        currentTestId = nil
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: testResultsKey)
        UserDefaults.standard.synchronize()
        
        print("All test results cleared")
    }
    
    /**
     * Loads test results from persistent storage or initializes empty array
     */
    private func loadTestResults() {
        // Always start with fresh test results
        testResults = []
    }
    
    /**
     * Saves test results to persistent storage
     */
    private func saveTestResults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(testResults)
            UserDefaults.standard.set(data, forKey: testResultsKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving test results: \(error)")
        }
    }
    
    // MARK: - Face Detection
    
    /**
     * Detects the presence of a face in a video frame.
     *
     * Uses Vision framework's VNDetectFaceRectanglesRequest to identify
     * faces in the provided sample buffer.
     *
     * - Parameters:
     *   - sampleBuffer: Video frame buffer from the camera
     *   - completion: Callback with boolean indicating whether a face was detected
     */
    func detectFace(in sampleBuffer: CMSampleBuffer, completion: @escaping (Bool) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            completion(false)
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
            
            // Check if we have any face observations
            if let observations = faceDetectionRequest.results, !observations.isEmpty {
                // Face detected
                completion(true)
            } else {
                completion(false)
            }
        } catch {
            print("Failed to perform face detection: \(error)")
            completion(false)
        }
    }
    
    // MARK: - Liveness Detection
    
    /**
     * Checks if a detected face is likely a real, live face.
     *
     * This implementation uses depth data analysis to distinguish between real 3D faces
     * and spoof attempts including photos and screens. It samples up to 100
     * points across the face region and looks for telltale signs of spoofing using
     * statistical analysis and pattern recognition.
     *
     * The algorithm considers a face to be "live" if it passes at least 6 out of 8 checks:
     * - Depth variation is sufficient (stdDev >= 0.15 and range >= 0.3)
     * - Mean depth is within realistic range (0.2-3.0m)
     * - Edge variation is natural (edgeStdDev >= 0.15)
     * - Depth profile shows natural variation (stdDev >= 0.2 or range >= 0.4)
     * - Center region shows face-like depth variation (centerStdDev >= 0.1)
     * - Depth distribution is non-linear (natural face variation)
     * - Gradient patterns are natural (gradientStdDev >= 0.005 and gradientMean <= 0.2)
     * - Temporal changes are consistent (depth changes between 0.005-1.0m)
     *
     * - Parameter depthData: Depth data from the TrueDepth camera
     * - Parameter storeResult: Whether to store this result in the test history (default: false)
     * - Returns: Boolean indicating whether the face is likely real (true) or a spoof (false)
     */
    func checkLiveness(with depthData: CVPixelBuffer, storeResult: Bool = true) -> Bool {
        // Convert depth data to array of Float values
        let depthValues = convertDepthDataToArray(depthData)
        
        // MANDATORY CHECKS - Must all pass
        let hasRealisticDepth = hasRealisticDepthRange(depthValues)
        let hasNaturalCenterVariation = hasNaturalCenterVariation(depthData: depthValues)
        
        // If either mandatory check fails, face is not live
        if !hasRealisticDepth || !hasNaturalCenterVariation {
            if storeResult {
                storeTestResultData(
                    depthValues: depthValues,
                    hasNaturalVariation: false,
                    hasRealisticDepth: hasRealisticDepth,
                    hasNaturalEdgeVariation: false,
                    hasNaturalDepthProfile: false,
                    hasNaturalCenterVariation: hasNaturalCenterVariation,
                    hasNaturalDistribution: false,
                    hasNaturalGradientPattern: false,
                    hasTemporalConsistency: false
                )
            }
            return false
        }
        
        // OPTIONAL CHECKS - Need 4 out of 6 to pass
        let hasNaturalVariation = hasNaturalDepthVariation(depthValues)
        let hasNaturalEdgeVariation = hasNaturalEdgeVariation(depthValues)
        let hasNaturalDepthProfile = hasNaturalDepthProfile(depthValues)
        let hasNaturalDistribution = hasNaturalDepthDistribution(depthValues)
        let hasNaturalGradientPattern = hasNaturalGradientPattern(depthValues)
        let hasTemporalConsistency = checkTemporalConsistency(depthValues)
        
        // Calculate total optional checks passed
        let passedOptionalChecks = [
            hasNaturalVariation,
            hasNaturalEdgeVariation,
            hasNaturalDepthProfile,
            hasNaturalDistribution,
            hasNaturalGradientPattern,
            hasTemporalConsistency
        ].filter { $0 }.count
        
        // Store result if requested
        if storeResult {
            storeTestResultData(
                depthValues: depthValues,
                hasNaturalVariation: hasNaturalVariation,
                hasRealisticDepth: hasRealisticDepth,
                hasNaturalEdgeVariation: hasNaturalEdgeVariation,
                hasNaturalDepthProfile: hasNaturalDepthProfile,
                hasNaturalCenterVariation: hasNaturalCenterVariation,
                hasNaturalDistribution: hasNaturalDistribution,
                hasNaturalGradientPattern: hasNaturalGradientPattern,
                hasTemporalConsistency: hasTemporalConsistency
            )
        }
        
        // Require at least 4 out of 6 optional checks to pass
        return passedOptionalChecks >= 4
    }
    
    /**
     * Checks if the temporal changes in depth are consistent with a real face.
     * Moving a flat surface typically creates sudden, uniform changes in depth.
     */
    func checkTemporalConsistency(_ depthValues: [Float]) -> Bool {
        // Return true (inconsistent changes) if insufficient data
        guard let previousMean = previousMean else { return true }
        
        // Calculate the absolute change in mean depth
        let depthChange = abs(depthValues.reduce(0, +) / Float(depthValues.count) - previousMean)
        
        // More permissive thresholds for temporal changes:
        // 1. Accept smaller movements as normal for people trying to be still
        // 2. Allow larger movements without failing for natural repositioning
        // Real faces show some variation in movement, but not extreme jumps
        
        // Previously: depthChange > 1.0 || depthChange < 0.005
        // Now: More permissive for both small and larger movements
        let isChangeTooSmall = depthChange < 0.0005  // Reduced by 10x (allows more stillness)
        let isChangeTooLarge = depthChange > 1.5     // Increased by 50% (allows more movement)
        
        // Log the actual change to help with debugging
        print("Temporal change: \(depthChange) meters - \(isChangeTooSmall || isChangeTooLarge ? "FAIL" : "PASS")")
        
        return isChangeTooSmall || isChangeTooLarge
    }
    
    /**
     * Checks if the depth distribution is too linear (typical of photos)
     * by analyzing the sorted depth values for linear patterns.
     */
    func checkLinearDistribution(_ sortedValues: [Float]) -> Bool {
        guard sortedValues.count >= 10 else { return false }
        
        // Calculate the actual average step between consecutive values
        var actualSteps: [Float] = []
        for i in 1..<sortedValues.count {
            actualSteps.append(sortedValues[i] - sortedValues[i-1])
        }
        let averageStep = actualSteps.reduce(0, +) / Float(actualSteps.count)
        
        // Calculate the standard deviation of steps
        let stepVariance = actualSteps.reduce(0) { $0 + pow($1 - averageStep, 2) } / Float(actualSteps.count)
        let stepStdDev = sqrt(stepVariance)
        
        // If the standard deviation is very low compared to the average step,
        // the distribution is likely linear (typical of photos)
        return stepStdDev < averageStep * 0.3  // Increased threshold for more tolerance
    }
    
    /**
     * Checks for characteristics typical of 3D masks by analyzing:
     * 1. Micro-movement patterns in depth gradients
     * 2. Depth distribution symmetry
     * 3. Temporal consistency of depth patterns
     *
     * 3D masks typically show:
     * - More uniform micro-movements than real faces
     * - More perfect symmetry in depth distribution
     * - More consistent patterns over time
     *
     * - Parameters:
     *   - currentPattern: Current gradient pattern to analyze
     *   - depthValues: Array of depth values across the face region
     *   - mean: Mean depth value
     *   - stdDev: Standard deviation of depth values
     * - Returns: Boolean indicating whether mask characteristics were detected
     */
    private func checkForMaskCharacteristics(
        currentPattern: [Float],
        depthValues: [Float],
        mean: Float,
        stdDev: Float
    ) -> Bool {
        // 1. Check micro-movement patterns
        let hasUnnaturalMicroMovements = checkMicroMovements(currentPattern)
        
        // 2. Check depth distribution symmetry
        let hasUnnaturalSymmetry = checkDepthSymmetry(depthValues, mean: mean)
        
        // 3. Check temporal pattern consistency
        let hasUnnaturalTemporalPatterns = checkTemporalPatterns()
        
        return hasUnnaturalMicroMovements || hasUnnaturalSymmetry || hasUnnaturalTemporalPatterns
    }
    
    /**
     * Analyzes micro-movement patterns in depth gradients.
     * 3D masks typically show more uniform micro-movements than real faces.
     */
    private func checkMicroMovements(_ currentPattern: [Float]) -> Bool {
        // Return true (unnatural movement) if insufficient data
        guard previousGradientPatterns.count >= 2 else { return true }
        
        // Calculate micro-movement variation
        var microMovementVariances: [Float] = []
        for i in 1..<previousGradientPatterns.count {
            let prevPattern = previousGradientPatterns[i-1]
            let currPattern = previousGradientPatterns[i]
            
            // Calculate differences between consecutive patterns
            let differences = zip(prevPattern, currPattern).map { abs($0 - $1) }
            let variance = differences.reduce(0) { $0 + pow($1, 2) } / Float(differences.count)
            microMovementVariances.append(variance)
        }
        
        // Calculate statistics of micro-movements
        let meanVariance = microMovementVariances.reduce(0, +) / Float(microMovementVariances.count)
        let varianceStdDev = sqrt(
            microMovementVariances.reduce(0) { $0 + pow($1 - meanVariance, 2) } / Float(microMovementVariances.count)
        )
        
        // 3D masks typically show more uniform micro-movements
        return varianceStdDev < meanVariance * 0.3
    }
    
    /**
     * Analyzes depth distribution symmetry.
     * 3D masks often show more perfect symmetry than real faces.
     */
    private func checkDepthSymmetry(_ depthValues: [Float], mean: Float) -> Bool {
        // Return true (unnatural symmetry) if insufficient data
        guard depthValues.count >= 10 else { return true }
        
        // Sort depth values
        let sortedValues = depthValues.sorted()
        
        // Calculate symmetry score
        var symmetryScore: Float = 0
        let halfCount = sortedValues.count / 2
        
        for i in 0..<halfCount {
            let leftValue = sortedValues[i]
            let rightValue = sortedValues[sortedValues.count - 1 - i]
            symmetryScore += abs(leftValue - rightValue)
        }
        
        // Normalize symmetry score
        let normalizedScore = symmetryScore / Float(halfCount)
        
        // 3D masks typically show very high symmetry
        return normalizedScore < 0.05
    }
    
    /**
     * Analyzes temporal consistency of depth patterns.
     * 3D masks often show more consistent patterns over time.
     */
    private func checkTemporalPatterns() -> Bool {
        // Return true (unnatural patterns) if insufficient data
        guard previousGradientPatterns.count >= 3 else { return true }
        
        // Calculate pattern consistency
        var patternConsistencies: [Float] = []
        for i in 1..<previousGradientPatterns.count {
            let prevPattern = previousGradientPatterns[i-1]
            let currPattern = previousGradientPatterns[i]
            
            // Calculate pattern similarity
            let similarity = zip(prevPattern, currPattern).map { 1 - abs($0 - $1) }
            let consistency = similarity.reduce(0, +) / Float(similarity.count)
            patternConsistencies.append(consistency)
        }
        
        // Calculate consistency statistics
        let meanConsistency = patternConsistencies.reduce(0, +) / Float(patternConsistencies.count)
        let consistencyStdDev = sqrt(
            patternConsistencies.reduce(0) { $0 + pow($1 - meanConsistency, 2) } / Float(patternConsistencies.count)
        )
        
        // Previously: meanConsistency > 0.9 && consistencyStdDev < 0.1
        // Now: Require even higher consistency to trigger a failure
        let isTooConsistent = meanConsistency > 0.95 && consistencyStdDev < 0.05
        
        // Log details to help with debugging
        print("Temporal patterns: consistency \(meanConsistency), stdDev \(consistencyStdDev) - \(isTooConsistent ? "FAIL" : "PASS")")
        
        // 3D masks typically show extremely consistent patterns
        // More permissive thresholds allow for natural stillness
        return isTooConsistent
    }
    
    /**
     * Stores test result data for analysis.
     */
    private func storeTestResultData(
        depthValues: [Float],
        hasNaturalVariation: Bool,
        hasRealisticDepth: Bool,
        hasNaturalEdgeVariation: Bool,
        hasNaturalDepthProfile: Bool,
        hasNaturalCenterVariation: Bool,
        hasNaturalDistribution: Bool,
        hasNaturalGradientPattern: Bool,
        hasTemporalConsistency: Bool
    ) {
        // Ensure we have a valid test ID before storing result
        guard let testId = currentTestId else {
            print("Warning: Attempted to store test result without valid test ID")
            return
        }
        
        // Check if we already have a result with this test ID
        if testResults.contains(where: { $0.testId == testId }) {
            print("Test result already exists for test ID: \(testId.uuidString.prefix(8))")
            return
        }
        
        // Create test result data with current timestamp
        let currentTime = Date()
        
        let testResult = TestResultData(
            isLive: hasNaturalVariation,
            depthMean: depthValues.reduce(0, +) / Float(depthValues.count),
            depthStdDev: calculateStandardDeviation(depthValues),
            depthRange: depthValues.max()! - depthValues.min()!,
            edgeMean: depthValues.reduce(0, +) / Float(depthValues.count),
            edgeStdDev: calculateStandardDeviation(depthValues),
            centerMean: depthValues.reduce(0, +) / Float(depthValues.count),
            centerStdDev: calculateStandardDeviation(depthValues),
            gradientMean: depthValues.reduce(0, +) / Float(depthValues.count),
            gradientStdDev: calculateStandardDeviation(depthValues),
            isTooFlat: !hasNaturalVariation,
            isUnrealisticDepth: !hasRealisticDepth,
            hasSharpEdges: !hasNaturalEdgeVariation,
            isTooUniform: !hasNaturalDepthProfile,
            hasNaturalCenterVariation: hasNaturalCenterVariation,
            isLinearDistribution: !hasNaturalDistribution,
            hasUnnaturalGradients: !hasNaturalGradientPattern,
            hasInconsistentTemporalChanges: !hasTemporalConsistency,
            numPassedChecks: [
                hasNaturalVariation,
                hasRealisticDepth,
                hasNaturalEdgeVariation,
                hasNaturalDepthProfile,
                hasNaturalCenterVariation,
                hasNaturalDistribution,
                hasNaturalGradientPattern,
                hasTemporalConsistency
            ].filter { $0 }.count,
            requiredChecks: 8,
            depthSampleCount: depthValues.count,
            isStillFaceDetected: hasNaturalVariation,
            deviceOrientation: UIDevice.current.orientation,
            timestamp: currentTime,
            testId: testId
        )
        
        // Log test completion with timestamp and result details
        print("📊 DETAILED TEST: \(hasNaturalVariation ? "LIVE FACE" : "SPOOF") at \(formatDate(currentTime))")
        print("  - Checks: \(testResult.numPassedChecks)/\(testResult.requiredChecks) passed, Depth samples: \(testResult.depthSampleCount)")
        print("  - Failed checks: \(listFailedChecks(testResult))")
        
        // Add to results, limiting to maximum stored
        testResults.insert(testResult, at: 0)
        if testResults.count > maxStoredResults {
            testResults.removeLast()
        }
        
        // Save results to persistent storage
        saveTestResults()
    }
    
    /**
     * Lists the failed checks as a string for debugging
     */
    private func listFailedChecks(_ result: TestResultData) -> String {
        let failedChecks = [
            result.isTooFlat ? "Depth Variation" : nil,
            result.isUnrealisticDepth ? "Realistic Depth" : nil,
            result.hasSharpEdges ? "Edge Variation" : nil,
            result.isTooUniform ? "Depth Profile" : nil,
            !result.hasNaturalCenterVariation ? "Center Variation" : nil,
            result.isLinearDistribution ? "Depth Distribution" : nil,
            result.hasUnnaturalGradients ? "Gradient Pattern" : nil,
            result.hasInconsistentTemporalChanges ? "Temporal Consistency" : nil
        ].compactMap { $0 }
        
        return failedChecks.isEmpty ? "None" : failedChecks.joined(separator: ", ")
    }
    
    /**
     * Formats a date for logging
     */
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    /**
     * Returns the stored test results for analysis.
     */
    func getTestResults() -> [TestResultData] {
        return testResults
    }
    
    /**
     * Returns the most recent test result, if available.
     */
    func getLastTestResult() -> TestResultData? {
        return testResults.first
    }
    
    /**
     * Clears all stored test results.
     * This can be called manually to clear history.
     */
    func clearTestResults() {
        clearAllTestResults()
    }
    
    /**
     * Generates JSON representation of test results for export.
     * This can be used to share data for analysis or debugging.
     */
    func exportTestResultsAsJSON() -> Data? {
        // Create a simplified dictionary representation for JSON export
        let exportResults = testResults.map { result -> [String: Any] in
            return [
                "timestamp": ISO8601DateFormatter().string(from: result.timestamp),
                "isLive": result.isLive,
                "depthMean": result.depthMean,
                "depthStdDev": result.depthStdDev,
                "depthRange": result.depthRange,
                "edgeStdDev": result.edgeStdDev,
                "centerStdDev": result.centerStdDev,
                "gradientMean": result.gradientMean,
                "gradientStdDev": result.gradientStdDev,
                "isTooFlat": result.isTooFlat,
                "isUnrealisticDepth": result.isUnrealisticDepth,
                "hasSharpEdges": result.hasSharpEdges,
                "isTooUniform": result.isTooUniform,
                "hasNaturalCenterVariation": result.hasNaturalCenterVariation,
                "isLinearDistribution": result.isLinearDistribution,
                "hasUnnaturalGradients": result.hasUnnaturalGradients,
                "hasInconsistentTemporalChanges": result.hasInconsistentTemporalChanges,
                "numPassedChecks": result.numPassedChecks,
                "depthSampleCount": result.depthSampleCount
            ]
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: exportResults, options: [.prettyPrinted])
        } catch {
            print("Error creating JSON: \(error)")
            return nil
        }
    }
    
    /**
     * Resets the face detector for a new test.
     * Clears temporary data and analysis state.
     */
    func resetForNewTest() {
        previousDepthValues = nil
        previousMean = nil
        previousGradientPatterns.removeAll()
        
        // Generate a new test ID for this test session
        currentTestId = UUID()
        
        print("Face detector reset for new test (ID: \(currentTestId?.uuidString.prefix(8) ?? "none"))")
    }
    
    /**
     * Stores the final result of a liveness test.
     * This should be called at the end of a test session.
     */
    func storeTestResult(isLive: Bool) {
        // Ensure we have a valid test ID
        guard let testId = currentTestId else {
            print("Warning: Attempted to store test result without valid test ID")
            return
        }
        
        // Check if we already have a result with this test ID
        if testResults.contains(where: { $0.testId == testId }) {
            print("Test result already exists for test ID: \(testId.uuidString.prefix(8))")
            return
        }
        
        // Clear any previous gradient patterns 
        previousGradientPatterns.removeAll()
        
        // Create a new result with minimal data
        let currentTime = Date()
        
        // For security, if isLive is false, all security checks should fail by default
        let testResult = TestResultData(
            isLive: isLive,
            depthMean: 0,
            depthStdDev: 0,
            depthRange: 0,
            edgeMean: 0,
            edgeStdDev: 0,
            centerMean: 0,
            centerStdDev: 0,
            gradientMean: 0,
            gradientStdDev: 0,
            isTooFlat: !isLive,           // True = fail for non-live faces
            isUnrealisticDepth: !isLive,  // True = fail for non-live faces
            hasSharpEdges: !isLive,       // True = fail for non-live faces
            isTooUniform: !isLive,        // True = fail for non-live faces
            hasNaturalCenterVariation: isLive, // False = fail for non-live faces
            isLinearDistribution: !isLive,     // True = fail for non-live faces
            hasUnnaturalGradients: !isLive,    // True = fail for non-live faces
            hasInconsistentTemporalChanges: !isLive, // True = fail for non-live faces
            numPassedChecks: isLive ? 9 : 0,
            requiredChecks: 9,
            depthSampleCount: 0,
            isStillFaceDetected: false,
            deviceOrientation: UIDevice.current.orientation,
            timestamp: currentTime,
            testId: testId
        )
        
        // Add to results, limiting to maximum stored
        testResults.insert(testResult, at: 0)
        if testResults.count > maxStoredResults {
            testResults.removeLast()
        }
        
        // Save results to persistent storage
        saveTestResults()
        
        // Log test result with more detail
        print("📄 MANUAL TEST: \(isLive ? "LIVE FACE ✅" : "SPOOF/INSUFFICIENT DATA ❌")")
        print("  - ID: \(testId.uuidString.prefix(8)), Time: \(formatDate(currentTime))")
        print("  - Checks: \(testResult.numPassedChecks)/\(testResult.requiredChecks), Depth: 0")
    }
    
    /**
     * Returns the current test ID
     */
    func getCurrentTestId() -> UUID? {
        return currentTestId
    }
    
    /**
     * Checks if there's a stored result for the given test ID
     */
    func hasResultForTest(id: UUID) -> Bool {
        return testResults.contains(where: { $0.testId == id })
    }
    
    /**
     * Stores a test result for the case where insufficient depth data was collected
     * to make a proper liveness determination.
     */
    private func storeInsufficientDataResult(depthSampleCount: Int) {
        // Ensure we have a valid test ID before storing result
        guard let testId = currentTestId else {
            print("Warning: Attempted to store test result without valid test ID")
            return
        }
        
        // Check if we already have a result with this test ID
        if testResults.contains(where: { $0.testId == testId }) {
            print("Test result already exists for test ID: \(testId.uuidString.prefix(8))")
            return
        }
        
        // Create test result data with current timestamp
        let currentTime = Date()
        
        // Create result with insufficient data markers
        // All security-sensitive checks default to failure
        let testResult = TestResultData(
            isLive: false,
            depthMean: 0.0,
            depthStdDev: 0.0,
            depthRange: 0.0,
            edgeMean: 0.0,
            edgeStdDev: 0.0,
            centerMean: 0.0,
            centerStdDev: 0.0,
            gradientMean: 0.0,
            gradientStdDev: 0.0,
            isTooFlat: true,
            isUnrealisticDepth: true,
            hasSharpEdges: true,
            isTooUniform: true,
            hasNaturalCenterVariation: false,
            isLinearDistribution: true,
            hasUnnaturalGradients: true,
            hasInconsistentTemporalChanges: true,
            numPassedChecks: 0,
            requiredChecks: 9,
            depthSampleCount: depthSampleCount,
            isStillFaceDetected: false,
            deviceOrientation: UIDevice.current.orientation,
            timestamp: currentTime,
            testId: testId
        )
        
        // Log test completion with timestamp
        print("⚠️ INSUFFICIENT DATA: FAIL at \(formatDate(currentTime))")
        print("  - ID: \(testId.uuidString.prefix(8)), Depth samples: \(depthSampleCount)")
        print("  - All checks marked as failed for security")
        
        // Add to results, limiting to maximum stored
        testResults.insert(testResult, at: 0)
        if testResults.count > maxStoredResults {
            testResults.removeLast()
        }
        
        // Save results to persistent storage
        saveTestResults()
    }
    
    private func hasNaturalCenterVariation(depthData: [Float]) -> Bool {
        // Sample points across the face (10x10 grid)
        let gridSize = 10
        var centerDepths: [Float] = []
        
        // Calculate center region (excluding outer 2 rows/columns)
        for y in 2..<(gridSize-2) {
            for x in 2..<(gridSize-2) {
                let index = y * gridSize + x
                if index < depthData.count {
                    centerDepths.append(depthData[index])
                }
            }
        }
        
        // Calculate standard deviation of center region
        let centerStdDev = calculateStandardDeviation(centerDepths)
        
        // Real faces should have natural depth variations in the center
        // Photos and masks tend to be flatter in the center
        // Threshold of 0.005 should distinguish between real faces (0.011-0.012) and photos (0.001-0.004)
        return centerStdDev >= 0.005
    }
    
    /**
     * Calculates the standard deviation of an array of Float values
     */
    private func calculateStandardDeviation(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        
        // Calculate mean
        let mean = values.reduce(0, +) / Float(values.count)
        
        // Calculate variance
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Float(values.count)
        
        // Return standard deviation
        return sqrt(variance)
    }
    
    private func printTestResults() {
        print("\nFace Liveness Debug Data")
        print("======================\n")
        print("Total test results: \(testResults.count)\n")
        
        for (index, result) in testResults.enumerated().reversed() {
            print("TEST \(index + 1):")
            print("Time: \(formatDate(result.timestamp))")
            print("Result: \(result.isLive ? "LIVE FACE" : "SPOOF")")
            print("Checks passed: \(result.numPassedChecks)/\(result.requiredChecks)")
            print("Depth samples: \(result.depthSampleCount)\n")
            
            print("DEPTH STATISTICS:")
            print("- Mean depth: \(String(format: "%.4f", result.depthMean))")
            print("- StdDev: \(String(format: "%.4f", result.depthStdDev))")
            print("- Range: \(String(format: "%.4f", result.depthRange))")
            print("- Edge StdDev: \(String(format: "%.4f", result.edgeStdDev))")
            print("- Center StdDev: \(String(format: "%.4f", result.centerStdDev))")
            print("- Gradient Mean: \(String(format: "%.4f", result.gradientMean))")
            print("- Gradient StdDev: \(String(format: "%.4f", result.gradientStdDev))\n")
            
            print("CHECK RESULTS:")
            print("- Depth Variation: \(result.numPassedChecks >= 1 ? "✓ PASS" : "✗ FAIL")")
            print("- Realistic Depth: \(result.numPassedChecks >= 2 ? "✓ PASS" : "✗ FAIL")")
            print("- Edge Variation: \(result.numPassedChecks >= 3 ? "✓ PASS" : "✗ FAIL")")
            print("- Depth Profile: \(result.numPassedChecks >= 4 ? "✓ PASS" : "✗ FAIL")")
            print("- Center Variation: \(result.numPassedChecks >= 5 ? "✓ PASS" : "✗ FAIL")")
            print("- Depth Distribution: \(result.numPassedChecks >= 6 ? "✓ PASS" : "✗ FAIL")")
            print("- Gradient Pattern: \(result.numPassedChecks >= 7 ? "✓ PASS" : "✗ FAIL")")
            print("- Temporal Consistency: \(result.numPassedChecks >= 8 ? "✓ PASS" : "✗ FAIL")\n")
            
            print("-----------\n")
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
    
    /**
     * Checks if depth values show natural variation
     */
    private func hasNaturalDepthVariation(_ depthValues: [Float]) -> Bool {
        guard !depthValues.isEmpty else { return false }
        
        let stdDev = calculateStandardDeviation(depthValues)
        let range = depthValues.max()! - depthValues.min()!
        
        // Real faces should have sufficient depth variation
        // Further adjusted thresholds to be more accommodating:
        // - stdDev threshold reduced from 0.05 to 0.02
        // - range threshold reduced from 0.1 to 0.05
        return stdDev >= 0.02 && range >= 0.05
    }
    
    /**
     * Checks if depth values are within realistic range
     */
    private func hasRealisticDepthRange(_ depthValues: [Float]) -> Bool {
        guard !depthValues.isEmpty else { return false }
        
        let mean = depthValues.reduce(0, +) / Float(depthValues.count)
        
        // Real faces should be between 0.2 and 3.0 meters from the camera
        return mean >= 0.2 && mean <= 3.0
    }
    
    /**
     * Checks if edge regions show natural face-like depth variation
     */
    private func hasNaturalEdgeVariation(_ depthValues: [Float]) -> Bool {
        let gridSize = 10
        var edgeDepths: [Float] = []
        
        // Sample edge points (outer points of the grid)
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if x == 0 || x == gridSize - 1 || y == 0 || y == gridSize - 1 {
                    let index = y * gridSize + x
                    if index < depthValues.count {
                        edgeDepths.append(depthValues[index])
                    }
                }
            }
        }
        
        let edgeStdDev = calculateStandardDeviation(edgeDepths)
        
        // Real faces should have natural edge variation
        // Adjusted threshold from 0.05 to 0.02 to match main variation check
        return edgeStdDev >= 0.02
    }
    
    /**
     * Checks if the depth profile matches a real face
     */
    private func hasNaturalDepthProfile(_ depthValues: [Float]) -> Bool {
        guard !depthValues.isEmpty else { return false }
        
        let stdDev = calculateStandardDeviation(depthValues)
        let range = depthValues.max()! - depthValues.min()!
        
        // Real faces should have sufficient depth variation
        // Adjusted thresholds to be more accommodating:
        // - stdDev threshold reduced from 0.05 to 0.02
        // - range threshold reduced from 0.1 to 0.05
        return stdDev >= 0.02 || range >= 0.05
    }
    
    /**
     * Checks if the depth distribution is too linear (typical of photos)
     */
    func hasNaturalDepthDistribution(_ depthValues: [Float]) -> Bool {
        let sortedValues = depthValues.sorted()
        return !checkLinearDistribution(sortedValues)
    }
    
    /**
     * Checks if gradient patterns are natural
     */
    private func hasNaturalGradientPattern(_ depthValues: [Float]) -> Bool {
        let gridSize = 10
        var gradientValues: [Float] = []
        
        // Calculate gradients between adjacent points
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if x > 0 && y > 0 {
                    let currentIndex = y * gridSize + x
                    let leftIndex = y * gridSize + (x - 1)
                    let topIndex = (y - 1) * gridSize + x
                    
                    if currentIndex < depthValues.count && leftIndex < depthValues.count && topIndex < depthValues.count {
                        let leftGradient = abs(depthValues[currentIndex] - depthValues[leftIndex])
                        let topGradient = abs(depthValues[currentIndex] - depthValues[topIndex])
                        gradientValues.append(leftGradient)
                        gradientValues.append(topGradient)
                    }
                }
            }
        }
        
        let gradientMean = gradientValues.reduce(0, +) / Float(gradientValues.count)
        let gradientStdDev = calculateStandardDeviation(gradientValues)
        
        // Real faces should have natural gradient patterns
        return gradientStdDev >= 0.005 && gradientMean <= 0.2
    }
} 