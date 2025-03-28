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
    let hasMaskCharacteristics: Bool
    
    // Advanced mask detection metrics
    let hasUnnaturalMicroMovements: Bool
    let hasUnnaturalSymmetry: Bool
    let hasUnnaturalTemporalPatterns: Bool
    
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
        hasMaskCharacteristics: Bool,
        hasUnnaturalMicroMovements: Bool,
        hasUnnaturalSymmetry: Bool,
        hasUnnaturalTemporalPatterns: Bool,
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
        self.hasMaskCharacteristics = hasMaskCharacteristics
        self.hasUnnaturalMicroMovements = hasUnnaturalMicroMovements
        self.hasUnnaturalSymmetry = hasUnnaturalSymmetry
        self.hasUnnaturalTemporalPatterns = hasUnnaturalTemporalPatterns
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
        case hasUnnaturalGradients, hasInconsistentTemporalChanges, hasMaskCharacteristics
        case hasUnnaturalMicroMovements, hasUnnaturalSymmetry, hasUnnaturalTemporalPatterns
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
        try container.encode(hasMaskCharacteristics, forKey: .hasMaskCharacteristics)
        try container.encode(hasUnnaturalMicroMovements, forKey: .hasUnnaturalMicroMovements)
        try container.encode(hasUnnaturalSymmetry, forKey: .hasUnnaturalSymmetry)
        try container.encode(hasUnnaturalTemporalPatterns, forKey: .hasUnnaturalTemporalPatterns)
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
     * and spoof attempts including photos, screens, and 3D masks. It samples up to 100
     * points across the face region and looks for telltale signs of spoofing using
     * statistical analysis and pattern recognition.
     *
     * The algorithm considers a face to be "live" if it passes at least 6 out of 9 checks:
     * - Depth variation is sufficient (stdDev >= 0.15 and range >= 0.3)
     * - Mean depth is within realistic range (0.2-3.0m)
     * - Edge variation is natural (edgeStdDev >= 0.15)
     * - Depth profile shows natural variation (stdDev >= 0.2 or range >= 0.4)
     * - Center region shows face-like depth variation (centerStdDev >= 0.1)
     * - Depth distribution is non-linear (natural face variation)
     * - Gradient patterns are natural (gradientStdDev >= 0.005 and gradientMean <= 0.2)
     * - Temporal changes are consistent (depth changes between 0.005-1.0m)
     * - No mask characteristics detected (micro-movements, symmetry, patterns)
     *
     * - Parameter depthData: Depth data from the TrueDepth camera
     * - Parameter storeResult: Whether to store this result in the test history (default: false)
     * - Returns: Boolean indicating whether the face is likely real (true) or a spoof (false)
     */
    func checkLiveness(with depthData: AVDepthData, storeResult: Bool = false) -> Bool {
        // Convert depth data to the right format
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let pixelBuffer = convertedDepthData.depthDataMap
        
        // Check for flatness characteristics typical of photos
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        guard let baseAddress = baseAddress else { return false }
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
        
        // Log for debugging
        print("Collected \(depthValues.count) valid depth points")
        
        // Check for characteristics of a photo (very flat depth profile)
        if depthValues.count >= 30 {
            // Calculate standard deviation
            let mean = depthValues.reduce(0, +) / Float(depthValues.count)
            let variance = depthValues.reduce(0) { $0 + pow($1 - mean, 2) } / Float(depthValues.count)
            let stdDev = sqrt(variance)
            
            // Calculate min/max range
            guard let min = depthValues.min(), let max = depthValues.max() else {
                return false
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
            let hasNaturalCenterVariation = centerStdDev >= 0.1  // More lenient threshold
            
            // 6. Check if the depth distribution is too linear (typical of photos)
            let depthDistribution = depthValues.sorted()
            let isLinearDistribution = checkLinearDistribution(depthDistribution)
            
            // 7. Check for unnatural gradient patterns (typical of moving flat surfaces)
            let hasUnnaturalGradients = gradientStdDev < 0.005 || gradientMean > 0.2  // More lenient thresholds
            
            // 8. Check temporal consistency with more lenient thresholds
            let hasInconsistentTemporalChanges = checkTemporalConsistency(mean: mean)
            
            // Store gradient pattern for temporal analysis
            let currentPattern = gradientValues
            previousGradientPatterns.append(currentPattern)
            if previousGradientPatterns.count > maxStoredPatterns {
                previousGradientPatterns.removeFirst()
            }
            
            // 9. Check for 3D mask characteristics
            let hasMaskCharacteristics = checkForMaskCharacteristics(
                currentPattern: currentPattern,
                depthValues: depthValues,
                mean: mean,
                stdDev: stdDev
            )
            
            // Get individual mask detection results for data collection
            let hasUnnaturalMicroMovements = checkMicroMovements(currentPattern)
            let hasUnnaturalSymmetry = checkDepthSymmetry(depthValues, mean: mean)
            let hasUnnaturalTemporalPatterns = checkTemporalPatterns()
            
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
                !hasInconsistentTemporalChanges,
                !hasMaskCharacteristics
            ].filter { $0 }.count
            
            let isLive = passedChecks >= 6
            
            // Store test result data only if explicitly requested
            if storeResult {
                storeTestResultData(
                    isLive: isLive,
                    depthMean: mean,
                    depthStdDev: stdDev,
                    depthRange: range,
                    edgeMean: edgeMean,
                    edgeStdDev: edgeStdDev,
                    centerMean: centerMean,
                    centerStdDev: centerStdDev,
                    gradientMean: gradientMean,
                    gradientStdDev: gradientStdDev,
                    isTooFlat: isTooFlat,
                    isUnrealisticDepth: isUnrealisticDepth,
                    hasSharpEdges: hasSharpEdges,
                    isTooUniform: isTooUniform,
                    hasNaturalCenterVariation: hasNaturalCenterVariation,
                    isLinearDistribution: isLinearDistribution,
                    hasUnnaturalGradients: hasUnnaturalGradients,
                    hasInconsistentTemporalChanges: hasInconsistentTemporalChanges,
                    hasMaskCharacteristics: hasMaskCharacteristics,
                    hasUnnaturalMicroMovements: hasUnnaturalMicroMovements,
                    hasUnnaturalSymmetry: hasUnnaturalSymmetry,
                    hasUnnaturalTemporalPatterns: hasUnnaturalTemporalPatterns,
                    numPassedChecks: passedChecks,
                    requiredChecks: 9,
                    depthSampleCount: depthValues.count,
                    isStillFaceDetected: isLive
                )
            }
            
            // Update previous values for next frame
            previousDepthValues = depthValues
            previousMean = mean
            
            return isLive
        }
        
        // Not enough valid depth data points, or couldn't calculate range
        return false
    }
    
    /**
     * Checks if the temporal changes in depth are consistent with a real face.
     * Moving a flat surface typically creates sudden, uniform changes in depth.
     */
    private func checkTemporalConsistency(mean: Float) -> Bool {
        guard let previousMean = previousMean else { return false }
        
        // Calculate the absolute change in mean depth
        let depthChange = abs(mean - previousMean)
        
        // More lenient thresholds for temporal changes
        // Real faces can show more variation in movement
        return depthChange > 1.0 || depthChange < 0.005
    }
    
    /**
     * Checks if the depth distribution is too linear (typical of photos)
     * by analyzing the sorted depth values for linear patterns.
     */
    private func checkLinearDistribution(_ sortedValues: [Float]) -> Bool {
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
        guard previousGradientPatterns.count >= 2 else { return false }
        
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
        guard previousGradientPatterns.count >= 3 else { return false }
        
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
        
        // 3D masks typically show very consistent patterns
        return meanConsistency > 0.9 && consistencyStdDev < 0.1
    }
    
    /**
     * Stores test result data for analysis.
     */
    private func storeTestResultData(
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
        hasMaskCharacteristics: Bool,
        hasUnnaturalMicroMovements: Bool,
        hasUnnaturalSymmetry: Bool,
        hasUnnaturalTemporalPatterns: Bool,
        numPassedChecks: Int,
        requiredChecks: Int,
        depthSampleCount: Int,
        isStillFaceDetected: Bool
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
            isLive: isLive,
            depthMean: depthMean,
            depthStdDev: depthStdDev,
            depthRange: depthRange,
            edgeMean: edgeMean,
            edgeStdDev: edgeStdDev,
            centerMean: centerMean,
            centerStdDev: centerStdDev,
            gradientMean: gradientMean,
            gradientStdDev: gradientStdDev,
            isTooFlat: isTooFlat,
            isUnrealisticDepth: isUnrealisticDepth,
            hasSharpEdges: hasSharpEdges,
            isTooUniform: isTooUniform,
            hasNaturalCenterVariation: hasNaturalCenterVariation,
            isLinearDistribution: isLinearDistribution,
            hasUnnaturalGradients: hasUnnaturalGradients,
            hasInconsistentTemporalChanges: hasInconsistentTemporalChanges,
            hasMaskCharacteristics: hasMaskCharacteristics,
            hasUnnaturalMicroMovements: hasUnnaturalMicroMovements,
            hasUnnaturalSymmetry: hasUnnaturalSymmetry,
            hasUnnaturalTemporalPatterns: hasUnnaturalTemporalPatterns,
            numPassedChecks: numPassedChecks,
            requiredChecks: requiredChecks,
            depthSampleCount: depthSampleCount,
            isStillFaceDetected: isStillFaceDetected,
            deviceOrientation: UIDevice.current.orientation,
            timestamp: currentTime,
            testId: testId
        )
        
        // Log test completion with timestamp
        print("Test completed at \(formatDate(currentTime)): \(isLive ? "LIVE FACE" : "SPOOF")")
        
        // Add to results, limiting to maximum stored
        testResults.insert(testResult, at: 0)
        if testResults.count > maxStoredResults {
            testResults.removeLast()
        }
        
        // Save results to persistent storage
        saveTestResults()
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
                "hasMaskCharacteristics": result.hasMaskCharacteristics,
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
            isTooFlat: false,
            isUnrealisticDepth: false,
            hasSharpEdges: false,
            isTooUniform: false,
            hasNaturalCenterVariation: false,
            isLinearDistribution: false,
            hasUnnaturalGradients: false,
            hasInconsistentTemporalChanges: false,
            hasMaskCharacteristics: false,
            hasUnnaturalMicroMovements: false,
            hasUnnaturalSymmetry: false,
            hasUnnaturalTemporalPatterns: false,
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
        
        // Log test completion
        print("Test result stored: \(isLive ? "LIVE FACE" : "SPOOF"), ID: \(testId.uuidString.prefix(8))")
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
} 