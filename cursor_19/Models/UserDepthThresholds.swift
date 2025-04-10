import Foundation

/**
 * Stores personalized depth thresholds calculated during user enrollment.
 * These thresholds are used by LivenessChecker to adapt checks to individual users.
 */
struct UserDepthThresholds: Codable {
    // Timestamp of when these thresholds were generated
    let calculationDate: Date
    
    // Thresholds derived from statistics across all captured enrollment frames
    
    // Mean Depth (for hasRealisticDepthRange: min <= mean <= max)
    let minMeanDepth: Float
    let maxMeanDepth: Float
    
    // Standard Deviation (for hasNaturalDepthVariation, hasNaturalDepthProfile)
    let minStdDev: Float
    
    // Range (for hasNaturalDepthVariation, hasNaturalDepthProfile)
    let minRange: Float
    
    // Edge Standard Deviation (for hasNaturalEdgeVariation)
    let minEdgeStdDev: Float
    
    // Center Standard Deviation (for hasNaturalCenterVariation)
    let minCenterStdDev: Float
    
    // Gradient Mean (for hasNaturalGradientPattern: mean <= max)
    let maxGradientMean: Float
    
    // Gradient Standard Deviation (for hasNaturalGradientPattern: stdDev >= min)
    let minGradientStdDev: Float
    
    // MARK: - Initialization
    
    init(
        calculationDate: Date = Date(), // Default to now
        minMeanDepth: Float,
        maxMeanDepth: Float,
        minStdDev: Float,
        minRange: Float,
        minEdgeStdDev: Float,
        minCenterStdDev: Float,
        maxGradientMean: Float,
        minGradientStdDev: Float
    ) {
        self.calculationDate = calculationDate
        self.minMeanDepth = minMeanDepth
        self.maxMeanDepth = maxMeanDepth
        self.minStdDev = minStdDev
        self.minRange = minRange
        self.minEdgeStdDev = minEdgeStdDev
        self.minCenterStdDev = minCenterStdDev
        self.maxGradientMean = maxGradientMean
        self.minGradientStdDev = minGradientStdDev
    }
}

// MARK: - Convenience Logging
extension UserDepthThresholds {
    func logSummary() {
        LogManager.shared.log("""
        --- Calculated UserDepthThresholds ---
        Date: \(calculationDate)
        Mean Depth Range: [\(String(format: "%.3f", minMeanDepth)) - \(String(format: "%.3f", maxMeanDepth))]
        Min Std Dev:      \(String(format: "%.4f", minStdDev))
        Min Range:        \(String(format: "%.4f", minRange))
        Min Edge StdDev:  \(String(format: "%.4f", minEdgeStdDev))
        Min Center StdDev:\(String(format: "%.4f", minCenterStdDev))
        Max Gradient Mean:\(String(format: "%.4f", maxGradientMean))
        Min Grad StdDev:  \(String(format: "%.4f", minGradientStdDev))
        ------------------------------------
        """)
    }
} 