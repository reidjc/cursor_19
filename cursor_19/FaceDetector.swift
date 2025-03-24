import Foundation
import AVFoundation
import Vision

/**
 * FaceDetector - Handles face detection and liveness verification
 *
 * This class provides face detection functionality using Apple's Vision framework
 * and implements a depth-based liveness detection system using the TrueDepth camera.
 * It analyzes video frames to detect faces and uses depth data analysis to distinguish
 * between real 3D faces and spoof attempts including photos, screens, and 3D masks.
 *
 * The liveness detection works by:
 * 1. Sampling multiple points across the face region in a 10x10 grid pattern
 * 2. Analyzing depth variations to identify characteristics of flat surfaces
 * 3. Using statistical analysis (standard deviation and range) to detect photos
 * 4. Analyzing micro-movements and patterns to detect 3D masks
 * 5. Requiring sufficient depth variation to confirm a real 3D face
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
     * - Returns: Boolean indicating whether the face is likely real (true) or a spoof (false)
     */
    func checkLiveness(with depthData: AVDepthData) -> Bool {
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
            if let min = depthValues.min(), let max = depthValues.max() {
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
                
                // Update previous values for next frame
                previousDepthValues = depthValues
                previousMean = mean
                
                return passedChecks >= 6
            }
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
} 