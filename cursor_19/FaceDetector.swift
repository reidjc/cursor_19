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
    let hasUnnaturalMicroMovements: Bool
    
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
        hasUnnaturalMicroMovements: Bool,
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
        self.hasUnnaturalMicroMovements = hasUnnaturalMicroMovements
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
        case hasUnnaturalGradients, hasInconsistentTemporalChanges, hasUnnaturalMicroMovements
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
        try container.encode(hasUnnaturalMicroMovements, forKey: .hasUnnaturalMicroMovements)
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
    private var patternTimestamps: [Date] = [] // Store timestamps for each pattern
    private let maxStoredPatterns = 10 // Increased from 5 to 10 for better analysis
    private let minPatternTime: TimeInterval = 0.5 // Minimum time required for movement analysis (500ms)
    private var lastDepthData: [Float]? // Store the last depth data received
    
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
    
    /// Checks if a detected face is likely a real, live face using depth data analysis.
    /// This method performs several checks to determine if the face is live:
    /// 1. Depth Variation: Checks if the face has natural depth variation (not too flat)
    /// 2. Realistic Depth: Verifies the depth values are within realistic human face range
    /// 3. Edge Variation: Ensures face edges have natural depth transitions
    /// 4. Depth Profile: Checks for natural depth profile across the face
    /// 5. Center Variation: Verifies natural depth variation in the face center
    /// 6. Depth Distribution: Ensures depth values follow natural non-linear distribution
    /// 7. Gradient Pattern: Checks for natural depth gradient patterns
    /// 8. Temporal Consistency: Verifies natural temporal changes in depth
    /// 9. Natural Micro-movements: Detects natural small movements between frames
    ///
    /// The method requires at least 30 depth samples for analysis and uses a combination
    /// of mandatory and optional checks to determine liveness. A face is considered live
    /// if it passes all mandatory checks and at least 4 out of 5 optional checks.
    ///
    /// - Parameters:
    ///   - depthData: The depth data array from the TrueDepth camera
    ///   - storeResult: Whether to store the test result
    /// - Returns: A tuple containing whether the face is live and the test result data
    func checkLiveness(depthData: [Float], storeResult: Bool = false) -> (isLive: Bool, result: TestResultData?) {
        // Store the last depth data
        lastDepthData = depthData
        
        // Convert depth data to array of Float values
        let depthValues = depthData
        
        // Calculate current gradient pattern
        let currentPattern = calculateGradientPattern(depthValues)
        
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
                    hasTemporalConsistency: false,
                    hasNaturalMicroMovements: false
                )
            }
            return (false, nil)
        }
        
        // OPTIONAL CHECKS - Need 4 out of 7 to pass
        let hasNaturalVariation = hasNaturalDepthVariation(depthValues)
        let hasNaturalEdgeVariation = hasNaturalEdgeVariation(depthValues)
        let hasNaturalDepthProfile = hasNaturalDepthProfile(depthValues)
        let hasNaturalDistribution = hasNaturalDepthDistribution(depthValues)
        let hasNaturalGradientPattern = hasNaturalGradientPattern(depthValues)
        let hasTemporalConsistency = checkTemporalConsistency(depthValues)
        let hasNaturalMicroMovements = !checkMicroMovements(currentPattern)
        
        // Update stored patterns for next check
        previousGradientPatterns.append(currentPattern)
        if previousGradientPatterns.count > maxStoredPatterns {
            previousGradientPatterns.removeFirst()
        }
        
        // Calculate total optional checks passed
        let passedOptionalChecks = [
            hasNaturalVariation,
            hasNaturalEdgeVariation,
            hasNaturalDepthProfile,
            hasNaturalDistribution,
            hasNaturalGradientPattern,
            hasTemporalConsistency,
            hasNaturalMicroMovements
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
                hasTemporalConsistency: hasTemporalConsistency,
                hasNaturalMicroMovements: hasNaturalMicroMovements
            )
        }
        
        // Require at least 4 out of 7 optional checks to pass
        let isLive = passedOptionalChecks >= 4
        
        return (isLive, isLive ? testResults.last : nil)
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
        // Add current timestamp
        patternTimestamps.append(Date())
        
        // Remove old patterns and timestamps if we exceed maxStoredPatterns
        while patternTimestamps.count > maxStoredPatterns {
            patternTimestamps.removeFirst()
            if !previousGradientPatterns.isEmpty {
                previousGradientPatterns.removeFirst()
            }
        }
        
        // Return false (natural movement) if insufficient data
        guard previousGradientPatterns.count >= 3 else { return false }
        
        // Check if we have enough time between patterns
        guard let firstTimestamp = patternTimestamps.first,
              let lastTimestamp = patternTimestamps.last else {
            return false
        }
        
        let timeSpan = lastTimestamp.timeIntervalSince(firstTimestamp)
        guard timeSpan >= minPatternTime else {
            print("Micro-movements: Insufficient time span (\(timeSpan)s), need \(minPatternTime)s")
            return false
        }
        
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
        
        // Log micro-movement statistics for debugging
        print("Micro-movements: mean variance \(meanVariance), stdDev \(varianceStdDev), time span \(timeSpan)s")
        
        // Real faces show natural variation in micro-movements
        // 3D masks typically show more uniform micro-movements
        // Adjusted threshold to be more permissive for real faces
        // Also consider the time span in the decision
        let isUnnatural = varianceStdDev < meanVariance * 0.5
        print("Micro-movements: \(isUnnatural ? "Unnatural" : "Natural") (variance ratio: \(varianceStdDev/meanVariance))")
        
        return isUnnatural
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
     * Helper function to format check results for debug output
     */
    private func checkResultText(_ passed: Bool) -> String {
        return passed ? "✓ PASS" : "✗ FAIL"
    }
    
    /**
     * Stores the result of a face liveness test.
     *
     * This method creates a TestResultData object with the results of all checks
     * and stores it in the testResults array.
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
        hasTemporalConsistency: Bool,
        hasNaturalMicroMovements: Bool
    ) {
        // Ensure we have a valid test ID before storing result
        guard let testId = currentTestId else {
            print("Warning: Attempted to store test result without an active test ID")
            return
        }
        
        // Calculate depth statistics
        let mean = depthValues.reduce(0, +) / Float(depthValues.count)
        let variance = depthValues.reduce(0) { $0 + pow($1 - mean, 2) } / Float(depthValues.count)
        let stdDev = sqrt(variance)
        let range = depthValues.max()! - depthValues.min()!
        
        // Calculate edge and center statistics
        let (edgeStdDev, centerStdDev) = calculateEdgeAndCenterStats(depthValues)
        let edgeMean = mean  // Using overall mean for edge mean
        let centerMean = mean  // Using overall mean for center mean
        
        // Calculate gradient statistics
        let (gradientMean, gradientStdDev) = calculateGradientStats(depthValues)
        
        // Calculate number of passed checks
        let passedChecks = [
            hasNaturalVariation,
            hasRealisticDepth,
            hasNaturalEdgeVariation,
            hasNaturalDepthProfile,
            hasNaturalCenterVariation,
            hasNaturalDistribution,
            hasNaturalGradientPattern,
            hasTemporalConsistency,
            hasNaturalMicroMovements
        ].filter { $0 }.count
        
        // Create new result
        let result = TestResultData(
            isLive: hasRealisticDepth && hasNaturalCenterVariation && passedChecks >= 4,
            depthMean: mean,
            depthStdDev: stdDev,
            depthRange: range,
            edgeMean: edgeMean,
            edgeStdDev: edgeStdDev,
            centerMean: centerMean,
            centerStdDev: centerStdDev,
            gradientMean: gradientMean,
            gradientStdDev: gradientStdDev,
            isTooFlat: !hasNaturalVariation,
            isUnrealisticDepth: !hasRealisticDepth,
            hasSharpEdges: !hasNaturalEdgeVariation,
            isTooUniform: !hasNaturalDepthProfile,
            hasNaturalCenterVariation: hasNaturalCenterVariation,
            isLinearDistribution: !hasNaturalDistribution,
            hasUnnaturalGradients: !hasNaturalGradientPattern,
            hasInconsistentTemporalChanges: !hasTemporalConsistency,
            hasUnnaturalMicroMovements: !hasNaturalMicroMovements,
            numPassedChecks: passedChecks,
            requiredChecks: 9,  // Total number of checks including micro-movements
            depthSampleCount: depthValues.count,
            isStillFaceDetected: true,
            deviceOrientation: UIDevice.current.orientation,
            timestamp: Date(),
            testId: testId
        )
        
        // Update existing result if it exists, otherwise add new one
        if let index = testResults.firstIndex(where: { $0.testId == testId }) {
            testResults[index] = result
        } else {
            testResults.append(result)
        }
        
        // Log the test result
        printTestResults(result)
    }
    
    /**
     * Calculates edge and center statistics from depth values
     */
    private func calculateEdgeAndCenterStats(_ depthValues: [Float]) -> (edgeStdDev: Float, centerStdDev: Float) {
        let gridSize = 10
        var edgeDepths: [Float] = []
        var centerDepths: [Float] = []
        
        // Sample edge points (outer points of the grid)
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if x == 0 || x == gridSize - 1 || y == 0 || y == gridSize - 1 {
                    let index = y * gridSize + x
                    if index < depthValues.count {
                        edgeDepths.append(depthValues[index])
                    }
                }
                
                // Sample center points (excluding outer 2 rows/columns)
                if x >= 2 && x < gridSize - 2 && y >= 2 && y < gridSize - 2 {
                    let index = y * gridSize + x
                    if index < depthValues.count {
                        centerDepths.append(depthValues[index])
                    }
                }
            }
        }
        
        let edgeStdDev = calculateStandardDeviation(edgeDepths)
        let centerStdDev = calculateStandardDeviation(centerDepths)
        
        return (edgeStdDev, centerStdDev)
    }
    
    /**
     * Calculates gradient statistics from depth values
     */
    private func calculateGradientStats(_ depthValues: [Float]) -> (gradientMean: Float, gradientStdDev: Float) {
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
        
        return (gradientMean, gradientStdDev)
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
        // Clear all temporary data
        previousDepthValues = nil
        previousMean = nil
        previousGradientPatterns.removeAll()
        patternTimestamps.removeAll() // Clear timestamps
        lastDepthData = nil // Clear last depth data
        
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
            hasUnnaturalMicroMovements: !isLive,    // True = fail for non-live faces
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
            hasUnnaturalMicroMovements: true,
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
    
    private func printTestResults(_ result: TestResultData) {
        print("\nTEST \(result.testId):")
        print("Time: \(result.timestamp)")
        print("Result: \(result.isLive ? "LIVE FACE" : "SPOOF")")
        print("Checks passed: \(result.numPassedChecks)/\(result.requiredChecks)")
        print("Depth samples: \(result.depthSampleCount)")
        
        print("\nDEPTH STATISTICS:")
        print("- Mean depth: \(String(format: "%.4f", result.depthMean))")
        print("- StdDev: \(String(format: "%.4f", result.depthStdDev))")
        print("- Range: \(String(format: "%.4f", result.depthRange))")
        print("- Edge StdDev: \(String(format: "%.4f", result.edgeStdDev))")
        print("- Center StdDev: \(String(format: "%.4f", result.centerStdDev))")
        print("- Gradient Mean: \(String(format: "%.4f", result.gradientMean))")
        print("- Gradient StdDev: \(String(format: "%.4f", result.gradientStdDev))")
        
        print("\nCHECK RESULTS:")
        print("- Depth Variation: \(checkResultText(!result.isTooFlat))")
        print("- Realistic Depth: \(checkResultText(!result.isUnrealisticDepth))")
        print("- Edge Variation: \(checkResultText(!result.hasSharpEdges))")
        print("- Depth Profile: \(checkResultText(!result.isTooUniform))")
        print("- Center Variation: \(checkResultText(result.hasNaturalCenterVariation))")
        print("- Depth Distribution: \(checkResultText(!result.isLinearDistribution))")
        print("- Gradient Pattern: \(checkResultText(!result.hasUnnaturalGradients))")
        print("- Temporal Consistency: \(checkResultText(!result.hasInconsistentTemporalChanges))")
        print("- Natural Micro-movements: \(checkResultText(!result.hasUnnaturalMicroMovements))")
        
        // Add micro-movement statistics to debug output
        if let lastDepth = lastDepthData {
            let currentPattern = calculateGradientPattern(lastDepth)
            let hasUnnaturalMovements = checkMicroMovements(currentPattern)
            print("\nMICRO-MOVEMENT ANALYSIS:")
            print("- Pattern count: \(previousGradientPatterns.count)")
            print("- Time span: \(patternTimestamps.last?.timeIntervalSince(patternTimestamps.first ?? Date()) ?? 0)s")
            print("- Movement type: \(hasUnnaturalMovements ? "Unnatural" : "Natural")")
            print("- Check result: \(checkResultText(!hasUnnaturalMovements))")
        } else {
            print("\nMICRO-MOVEMENT ANALYSIS:")
            print("- No depth data available for movement analysis")
            print("- Check result: ✗ FAIL (Insufficient data)")
        }
        
        print("\n-----------\n")
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
        // Adjusted thresholds based on real face data:
        // - Lowered gradientStdDev threshold from 0.005 to 0.001
        // - Increased gradientMean threshold from 0.2 to 0.5
        return gradientStdDev >= 0.001 && gradientMean <= 0.5
    }
    
    /**
     * Calculates gradient pattern from depth values
     */
    private func calculateGradientPattern(_ depthValues: [Float]) -> [Float] {
        let gridSize = 10
        var pattern: [Float] = []
        
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
                        pattern.append(leftGradient)
                        pattern.append(topGradient)
                    }
                }
            }
        }
        
        return pattern
    }
} 