import Foundation

struct LivenessCheckResults {
    let hasNaturalVariation: Bool
    let hasRealisticDepth: Bool
    let hasNaturalEdgeVariation: Bool
    let hasNaturalDepthProfile: Bool
    let hasNaturalCenterVariation: Bool
    let hasNaturalDistribution: Bool
    let hasNaturalGradientPattern: Bool
    let hasTemporalConsistency: Bool
    let hasNaturalMicroMovements: Bool
    
    // Statistics needed for TestResultData
    let mean: Float
    let stdDev: Float
    let range: Float
    let edgeStdDev: Float
    let centerStdDev: Float
    let gradientMean: Float
    let gradientStdDev: Float
}

class LivenessChecker {
    
    // MARK: - State Properties
    
    private var previousDepthValues: [Float]?
    private var previousMean: Float?
    private var previousGradientPatterns: [[Float]] = [] // Store recent gradient patterns
    private var patternTimestamps: [Date] = [] // Store timestamps for each pattern
    private let maxStoredPatterns = 10 // Increased from 5 to 10 for better analysis
    private let minPatternTime: TimeInterval = 0.5 // Minimum time required for movement analysis (500ms)
    
    // MARK: - Public Methods

    /**
     * Performs all liveness checks on the provided depth data.
     * - Parameter depthValues: Array of depth values from the TrueDepth camera.
     * - Returns: A `LivenessCheckResults` struct containing the boolean outcome of each check and calculated statistics.
     */
    func performLivenessChecks(depthValues: [Float]) -> LivenessCheckResults {
        
        // --- Calculations ---
        let mean = calculateMean(depthValues)
        let stdDev = calculateStandardDeviation(depthValues)
        let range = calculateRange(depthValues)
        let (edgeStdDev, centerStdDev) = calculateEdgeAndCenterStats(depthValues)
        let (gradientMean, gradientStdDev) = calculateGradientStats(depthValues)
        let currentPattern = calculateGradientPattern(depthValues)

        // --- Individual Checks ---
        let hasRealisticDepthCheck = hasRealisticDepthRange(mean: mean) // Use calculated mean
        let hasNaturalCenterVariationCheck = hasNaturalCenterVariation(centerStdDev: centerStdDev) // Use calculated centerStdDev
        
        // Only proceed with optional checks if mandatory ones pass (can be decided by caller)
        let hasNaturalVariationCheck = hasNaturalDepthVariation(stdDev: stdDev, range: range)
        let hasNaturalEdgeVariationCheck = hasNaturalEdgeVariation(edgeStdDev: edgeStdDev)
        let hasNaturalDepthProfileCheck = hasNaturalDepthProfile(stdDev: stdDev, range: range)
        let hasNaturalDistributionCheck = hasNaturalDepthDistribution(depthValues) // Needs sorted values
        let hasNaturalGradientPatternCheck = hasNaturalGradientPattern(gradientMean: gradientMean, gradientStdDev: gradientStdDev)
        
        // Temporal checks require previous state
        let hasTemporalConsistencyCheck = checkTemporalConsistency(currentMean: mean) // Needs previousMean
        let hasNaturalMicroMovementsCheck = !checkMicroMovements(currentPattern) // Needs previous patterns

        // --- Update State ---
        // Note: Temporal checks use state from *before* this frame, so update after checks.
        updateTemporalState(currentMean: mean, currentPattern: currentPattern)

        return LivenessCheckResults(
            hasNaturalVariation: hasNaturalVariationCheck,
            hasRealisticDepth: hasRealisticDepthCheck,
            hasNaturalEdgeVariation: hasNaturalEdgeVariationCheck,
            hasNaturalDepthProfile: hasNaturalDepthProfileCheck,
            hasNaturalCenterVariation: hasNaturalCenterVariationCheck,
            hasNaturalDistribution: hasNaturalDistributionCheck,
            hasNaturalGradientPattern: hasNaturalGradientPatternCheck,
            hasTemporalConsistency: hasTemporalConsistencyCheck, // Result is inverted: true if *inconsistent*
            hasNaturalMicroMovements: hasNaturalMicroMovementsCheck,
            mean: mean,
            stdDev: stdDev,
            range: range,
            edgeStdDev: edgeStdDev,
            centerStdDev: centerStdDev,
            gradientMean: gradientMean,
            gradientStdDev: gradientStdDev
        )
    }
    
    /**
     * Resets the internal state for a new liveness test sequence.
     */
    func reset() {
        previousDepthValues = nil
        previousMean = nil
        previousGradientPatterns.removeAll()
        patternTimestamps.removeAll()
        print("LivenessChecker state reset.")
    }

    // MARK: - State Update
    
    private func updateTemporalState(currentMean: Float, currentPattern: [Float]) {
        previousMean = currentMean // Update for the *next* frame's checkTemporalConsistency
        
        // Update stored patterns for next micro-movement check
        previousGradientPatterns.append(currentPattern)
        patternTimestamps.append(Date())
        
        while patternTimestamps.count > maxStoredPatterns {
            patternTimestamps.removeFirst()
            if !previousGradientPatterns.isEmpty {
                previousGradientPatterns.removeFirst()
            }
        }
    }

    // MARK: - Liveness Check Implementations
    
    /**
     * Checks if depth values show natural variation (not too flat).
     * Uses pre-calculated stdDev and range.
     */
    private func hasNaturalDepthVariation(stdDev: Float, range: Float) -> Bool {
        // Real faces should have sufficient depth variation
        // Adjusted thresholds to be more accommodating
        return stdDev >= 0.02 && range >= 0.05
    }

    /**
     * Checks if depth values are within realistic range (0.2m - 3.0m).
     * Uses pre-calculated mean.
     */
    private func hasRealisticDepthRange(mean: Float) -> Bool {
        // Real faces should be between 0.2 and 3.0 meters from the camera
        return mean >= 0.2 && mean <= 3.0
    }

    /**
     * Checks if edge regions show natural face-like depth variation.
     * Uses pre-calculated edge standard deviation.
     */
    private func hasNaturalEdgeVariation(edgeStdDev: Float) -> Bool {
        // Real faces should have natural edge variation
        // Adjusted threshold to match main variation check
        return edgeStdDev >= 0.02
    }

    /**
     * Checks if the depth profile matches a real face (sufficient variation).
     * Uses pre-calculated stdDev and range.
     */
    private func hasNaturalDepthProfile(stdDev: Float, range: Float) -> Bool {
        // Real faces should have sufficient depth variation
        // Adjusted thresholds to be more accommodating
        return stdDev >= 0.02 || range >= 0.05
    }
    
    /**
     * Checks if the center region has natural depth variation.
     * Uses pre-calculated center standard deviation.
     */
    private func hasNaturalCenterVariation(centerStdDev: Float) -> Bool {
        // Real faces should have natural depth variations in the center
        // Photos and masks tend to be flatter in the center
        // Threshold based on empirical data
        return centerStdDev >= 0.005
    }
    
    /**
     * Checks if the depth distribution is non-linear (typical of real faces).
     */
    private func hasNaturalDepthDistribution(_ depthValues: [Float]) -> Bool {
        guard depthValues.count >= 10 else { return true } // Assume natural if not enough data
        let sortedValues = depthValues.sorted()
        
        // Calculate the actual average step between consecutive values
        var actualSteps: [Float] = []
        for i in 1..<sortedValues.count {
            actualSteps.append(sortedValues[i] - sortedValues[i-1])
        }
        guard !actualSteps.isEmpty else { return true } // Assume natural if no steps
        
        let averageStep = actualSteps.reduce(0, +) / Float(actualSteps.count)
        guard averageStep > .ulpOfOne else { return true } // Avoid division by zero or near-zero

        // Calculate the standard deviation of steps
        let stepVariance = actualSteps.reduce(0) { $0 + pow($1 - averageStep, 2) } / Float(actualSteps.count)
        let stepStdDev = sqrt(stepVariance)

        // If the standard deviation is very low compared to the average step,
        // the distribution is likely linear (typical of photos). We want the opposite.
        // Increased threshold for more tolerance for real faces.
        let isLinear = stepStdDev < averageStep * 0.3
        return !isLinear
    }

    /**
     * Checks if gradient patterns are natural.
     * Uses pre-calculated gradient mean and standard deviation.
     */
    private func hasNaturalGradientPattern(gradientMean: Float, gradientStdDev: Float) -> Bool {
        // Real faces should have natural gradient patterns
        // Adjusted thresholds based on real face data
        return gradientStdDev >= 0.001 && gradientMean <= 0.5
    }
    
    /**
     * Checks if the temporal changes in depth mean are consistent with a real face.
     * Returns `true` if changes are *inconsistent* (too small or too large).
     */
    private func checkTemporalConsistency(currentMean: Float) -> Bool {
        guard let prevMean = previousMean else {
            // Not enough data for temporal check yet, consider it consistent for now
            // Or maybe inconsistent? Let's return true (inconsistent) as the original did.
            // This means the first frame always "fails" this check unless state is primed.
            return true // Consistent with original logic's initial state
        }
        
        let depthChange = abs(currentMean - prevMean)
        
        // More permissive thresholds for temporal changes:
        let isChangeTooSmall = depthChange < 0.0005  // Reduced threshold (allows more stillness)
        let isChangeTooLarge = depthChange > 1.5     // Increased threshold (allows more movement)
        
        let isInconsistent = isChangeTooSmall || isChangeTooLarge
        
        // Log via LogManager instead of print
        LogManager.shared.log("Debug Temporal Check: deltaMean = \(String(format: "%.6f", depthChange)), TooStable=\(isChangeTooSmall), TooErratic=\(isChangeTooLarge)")
        
        return isInconsistent // True if inconsistent
    }

    /**
     * Analyzes micro-movement patterns in depth gradients.
     * Returns `true` if movements seem *unnatural* (too uniform, typical of masks).
     */
    private func checkMicroMovements(_ currentPattern: [Float]) -> Bool {
        // This check requires the state (previousGradientPatterns, patternTimestamps)
        // which is updated *after* the checks in performLivenessChecks.
        // Therefore, this check uses data from frames up to N-1 compared to the current frame N.
        
        // Need at least 3 previous patterns stored to compare movements.
        // The `previousGradientPatterns` will include the pattern from N-1.
        guard previousGradientPatterns.count >= 2 else { // Need at least 2 patterns to have 1 movement variance
             // print("Micro-movements: Not enough patterns (need >= 2 stored).")
             return false // Assume natural if insufficient data
        }

        // Check time span between the *relevant* patterns used for variance calculation
        // We calculate variances between (P0, P1), (P1, P2), ..., (Pn-2, Pn-1)
        // So we need timestamps for P0 to Pn-1.
        let relevantTimestamps = Array(patternTimestamps.dropLast()) // Exclude timestamp for current pattern (not yet used for variance)
        let relevantPatterns = Array(previousGradientPatterns.dropLast()) // Exclude current pattern

        guard relevantPatterns.count >= 2, relevantTimestamps.count == relevantPatterns.count else {
             // print("Micro-movements: Mismatch between relevant patterns and timestamps.")
             return false // Assume natural
        }

        guard let firstTimestamp = relevantTimestamps.first,
              let lastTimestamp = relevantTimestamps.last else {
             // print("Micro-movements: Could not get timestamps.")
            return false // Assume natural
        }
        
        let timeSpan = lastTimestamp.timeIntervalSince(firstTimestamp)
        // Need enough time *between the patterns used* for the analysis to be meaningful.
        // If only 2 patterns, timeSpan is 0. Need at least 3 patterns for a non-zero span.
        guard relevantPatterns.count >= 3 && timeSpan >= minPatternTime else {
             // print("Micro-movements: Insufficient time span (\\(timeSpan)s / \\(relevantPatterns.count) patterns), need \\(minPatternTime)s and >= 3 patterns.")
            return false // Assume natural if insufficient time span or pattern count
        }

        // Calculate micro-movement variation (variance of differences)
        var microMovementVariances: [Float] = []
        for i in 1..<relevantPatterns.count {
            let prevPattern = relevantPatterns[i-1]
            let currPattern = relevantPatterns[i]
            
            guard prevPattern.count == currPattern.count, !prevPattern.isEmpty else { continue }
            
            let differences = zip(prevPattern, currPattern).map { abs($0 - $1) }
            // Calculate variance of the differences for this pair of patterns
            let meanDiff = differences.reduce(0, +) / Float(differences.count)
            let variance = differences.reduce(0) { $0 + pow($1 - meanDiff, 2) } / Float(differences.count)
            microMovementVariances.append(variance)
        }

        guard !microMovementVariances.isEmpty else {
             // print("Micro-movements: Could not calculate any variances.")
            return false // Assume natural if no variances calculated
        }

        // Calculate statistics of the variances themselves
        let meanVariance = microMovementVariances.reduce(0, +) / Float(microMovementVariances.count)
        guard meanVariance > .ulpOfOne else {
            // If mean variance is zero or tiny, movements are extremely uniform (unnatural)
            // print("Micro-movements: Mean variance is near zero (\\(meanVariance)). Unnatural.")
            return true // Unnatural if mean variance is zero/tiny
        }
        
        let varianceStdDev = sqrt(
            microMovementVariances.reduce(0) { $0 + pow($1 - meanVariance, 2) } / Float(microMovementVariances.count)
        )

        // Real faces show natural variation in micro-movements (higher varianceStdDev relative to meanVariance)
        // 3D masks typically show more uniform micro-movements (lower varianceStdDev relative to meanVariance)
        // Adjusted threshold to be more permissive for real faces
        let isUnnatural = varianceStdDev < meanVariance * 0.5
        
        // Log micro-movement statistics for debugging (optional)
        // print("Micro-movements: mean variance \\(meanVariance), stdDev \\(varianceStdDev), time span \\(timeSpan)s")
        // print("Micro-movements: \\(isUnnatural ? "Unnatural" : "Natural") (variance ratio: \\(varianceStdDev/meanVariance))")
        
        return isUnnatural // True if unnatural
    }
    
    // MARK: - Statistical Helper Functions
    
    private func calculateMean(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }
    
    private func calculateStandardDeviation(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 } // Need more than 1 value for std dev
        
        let mean = calculateMean(values)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Float(values.count) // Population variance
        return sqrt(variance)
    }
    
    private func calculateRange(_ values: [Float]) -> Float {
        guard let minVal = values.min(), let maxVal = values.max() else { return 0 }
        return maxVal - minVal
    }

    /**
     * Calculates edge and center standard deviations from depth values
     */
    private func calculateEdgeAndCenterStats(_ depthValues: [Float]) -> (edgeStdDev: Float, centerStdDev: Float) {
        guard depthValues.count >= 100 else { // Expecting 10x10 grid data
             // Also log this warning via LogManager
             LogManager.shared.log("Warning: Insufficient depth values (\(depthValues.count)) for edge/center stats. Expected 100.")
             return (0, 0)
        }
        
        let gridSize = 10 // Assuming a 10x10 grid
        var edgeDepths: [Float] = []
        var centerDepths: [Float] = []
        
        // Sample edge points (outer border of the grid)
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                // Check if the point is on the border
                if x == 0 || x == gridSize - 1 || y == 0 || y == gridSize - 1 {
                    let index = y * gridSize + x
                    // Ensure index is within bounds (though should be if count >= 100)
                    if index < depthValues.count {
                        edgeDepths.append(depthValues[index])
                    }
                }
            }
        }

        // Sample center points (e.g., inner 6x6 grid, excluding outer 2 rows/columns)
        let border = 2
        if gridSize > border * 2 { // Ensure there's a center region
            for y in border..<(gridSize - border) {
                for x in border..<(gridSize - border) {
                    let index = y * gridSize + x
                    if index < depthValues.count {
                        centerDepths.append(depthValues[index])
                    }
                }
            }
        }
        
        // Add explicit checks for empty arrays before calculating std dev
        let edgeStdDev = edgeDepths.isEmpty ? 0 : calculateStandardDeviation(edgeDepths)
        let centerStdDev = centerDepths.isEmpty ? 0 : calculateStandardDeviation(centerDepths)
        
        return (edgeStdDev, centerStdDev)
    }

    /**
     * Calculates gradient statistics (mean and std dev) from depth values
     */
    private func calculateGradientStats(_ depthValues: [Float]) -> (gradientMean: Float, gradientStdDev: Float) {
        guard depthValues.count >= 100 else { // Expecting 10x10 grid data
            // Also log this warning via LogManager
            LogManager.shared.log("Warning: Insufficient depth values (\(depthValues.count)) for gradient stats. Expected 100.")
            return (0, 0)
        }
        
        let gradientValues = calculateGradientValues(depthValues)
        
        guard !gradientValues.isEmpty else { return (0, 0) }
        
        let gradientMean = calculateMean(gradientValues)
        let gradientStdDev = calculateStandardDeviation(gradientValues)
        
        return (gradientMean, gradientStdDev)
    }
    
    /**
     * Calculates gradient pattern (array of absolute differences) from depth values
     */
     private func calculateGradientPattern(_ depthValues: [Float]) -> [Float] {
         return calculateGradientValues(depthValues) // The pattern is just the list of gradient values
     }

    /**
     * Helper to calculate individual gradient values between adjacent points in a grid.
     */
    private func calculateGradientValues(_ depthValues: [Float]) -> [Float] {
        guard depthValues.count >= 100 else { return [] } // Need grid data
        let gridSize = 10 // Assuming 10x10 grid
        var gradientValues: [Float] = []

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let currentIndex = y * gridSize + x
                guard currentIndex < depthValues.count else { continue } // Should not happen if count >= 100

                // Calculate gradient with right neighbor
                if x < gridSize - 1 {
                    let rightIndex = y * gridSize + (x + 1)
                    if rightIndex < depthValues.count {
                        let horizontalGradient = abs(depthValues[currentIndex] - depthValues[rightIndex])
                        gradientValues.append(horizontalGradient)
                    }
                }
                
                // Calculate gradient with bottom neighbor
                if y < gridSize - 1 {
                    let bottomIndex = (y + 1) * gridSize + x
                    if bottomIndex < depthValues.count {
                         let verticalGradient = abs(depthValues[currentIndex] - depthValues[bottomIndex])
                         gradientValues.append(verticalGradient)
                    }
                }
            }
        }
        return gradientValues
    }
}

// Extension for math functions if needed, though Foundation provides sqrt and pow
// import Darwin // Or import Foundation for basic math

