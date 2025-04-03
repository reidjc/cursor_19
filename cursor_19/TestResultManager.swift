import Foundation
import UIKit // For UIDeviceOrientation

/**
 * TestResultManager - Handles formatting and printing test results to the console.
 */
class TestResultManager {
    
    // MARK: - Properties
    // Re-add properties for tracking the current test print status
    private var currentTestId: UUID?
    private var hasPrintedCurrentTest: Bool = false
    /// Tracks if the *current* test session resulted in a 'LIVE / PASSED' outcome.
    private(set) var currentTestWasSuccessful: Bool = false
    
    // MARK: - Initialization
    
    init() {
        // No loading needed anymore
        print("TestResultManager initialized (Console printing only).")
    }
    
    // MARK: - Test Lifecycle
    /**
     * Starts tracking for a new test, allowing one result to be printed for it.
     */
    func startNewTest() {
        currentTestId = UUID()
        hasPrintedCurrentTest = false // Allow printing for this new test ID
        currentTestWasSuccessful = false // Reset success flag for new test
        print("--- Starting New Test (Manager ID: \(currentTestId?.uuidString.prefix(8) ?? "none")) ---")
    }
    
    // MARK: - Printing Results

    /**
     * Constructs and prints the result of a completed liveness test.
     */
    func printCompletedTestResult(
        isLive: Bool,
        checkResults: LivenessCheckResults,
        passedOptionalChecksCount: Int,
        requiredOptionalChecks: Int,
        depthSampleCount: Int,
        deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    ) {
        // Create the result data locally first
        // Use the *manager's* currentTestId for consistency check
        guard let managerTestId = currentTestId else { 
            // This might happen if checkLiveness is called before startNewTest
            // print("Debug: PrintCompletedResult called with no active manager test ID.")
            return 
        }
        
        // Prevent printing if we've already printed for this test ID
        guard !hasPrintedCurrentTest else { 
            // print("Debug: Already printed result for ID \(managerTestId.uuidString.prefix(8)). Skipping.")
            return 
        }
        
        let totalChecks = 9 // Update if the number of checks changes
        let numPassedChecks = (checkResults.hasRealisticDepth ? 1 : 0) + 
                              (checkResults.hasNaturalCenterVariation ? 1 : 0) + 
                              passedOptionalChecksCount

        // Create the result data locally for printing
        let result = TestResultData(
            isLive: isLive,
            depthMean: checkResults.mean,
            depthStdDev: checkResults.stdDev,
            depthRange: checkResults.range,
            edgeMean: checkResults.mean, // Using overall mean as placeholder
            edgeStdDev: checkResults.edgeStdDev,
            centerMean: checkResults.mean, // Using overall mean as placeholder
            centerStdDev: checkResults.centerStdDev,
            gradientMean: checkResults.gradientMean,
            gradientStdDev: checkResults.gradientStdDev,
            isTooFlat: !checkResults.hasNaturalVariation,
            isUnrealisticDepth: !checkResults.hasRealisticDepth,
            hasSharpEdges: !checkResults.hasNaturalEdgeVariation,
            isTooUniform: !checkResults.hasNaturalDepthProfile,
            hasNaturalCenterVariation: checkResults.hasNaturalCenterVariation,
            isLinearDistribution: !checkResults.hasNaturalDistribution,
            hasUnnaturalGradients: !checkResults.hasNaturalGradientPattern,
            hasInconsistentTemporalChanges: checkResults.hasTemporalConsistency,
            hasUnnaturalMicroMovements: !checkResults.hasNaturalMicroMovements,
            numPassedChecks: numPassedChecks,
            requiredChecks: totalChecks,
            depthSampleCount: depthSampleCount,
            isStillFaceDetected: true,
            deviceOrientation: deviceOrientation,
            timestamp: Date(),
            testId: managerTestId
        )
        
        // Set the success flag *before* potentially returning due to hasPrintedCurrentTest
        if isLive {
            self.currentTestWasSuccessful = true
        }

        // Prevent printing if we've already printed for this test ID
        guard !hasPrintedCurrentTest else { 
            // print("Debug: Already printed result for ID \(managerTestId.uuidString.prefix(8)). Skipping.")
            return 
        }
        
        // Print the result directly to the console
        printTestResults(result)
        // Mark this test ID as printed
        hasPrintedCurrentTest = true
    }

    /**
     * Constructs and prints a test result indicating insufficient depth data.
     */
    func printInsufficientDataResult(depthSampleCount: Int) {
        // Use the manager's currentTestId for consistency check
        guard let managerTestId = currentTestId else { 
            // print("Debug: printInsufficientDataResult called with no active manager test ID.")
            return 
        }

        // Ensure the success flag remains false for insufficient data
        // (It should already be false from startNewTest, but explicitly ensure)
        // self.currentTestWasSuccessful = false // Implicitly false already

        // Prevent printing if we've already printed for this test ID
        guard !hasPrintedCurrentTest else { 
            // print("Debug: Already printed result for ID \(managerTestId.uuidString.prefix(8)). Skipping insufficient data print.")
            return 
        }

        let currentTime = Date()
        
        // Create result locally for printing
        let result = TestResultData(
            isLive: false,
            depthMean: 0.0, depthStdDev: 0.0, depthRange: 0.0,
            edgeMean: 0.0, edgeStdDev: 0.0,
            centerMean: 0.0, centerStdDev: 0.0,
            gradientMean: 0.0, gradientStdDev: 0.0,
            isTooFlat: true, isUnrealisticDepth: true, hasSharpEdges: true, isTooUniform: true,
            hasNaturalCenterVariation: false,
            isLinearDistribution: true, hasUnnaturalGradients: true,
            hasInconsistentTemporalChanges: true, hasUnnaturalMicroMovements: true,
            numPassedChecks: 0, requiredChecks: 9,
            depthSampleCount: depthSampleCount,
            isStillFaceDetected: false,
            deviceOrientation: UIDevice.current.orientation,
            timestamp: currentTime,
            testId: managerTestId
        )

        print("⚠️ INSUFFICIENT DATA (Test ID: \(managerTestId.uuidString.prefix(8))) at \(formatDate(currentTime))")
        print("  - Depth samples: \(depthSampleCount)")
        // Optionally print the full details:
        // printTestResults(result) 
        
        // Mark this test ID as printed (as it's a final result for this attempt)
        hasPrintedCurrentTest = true 
    }
    
    // MARK: - Accessing Results (Removed getAllResults, getLastResult, hasResultForTest)
    
    // MARK: - Persistence (Removed loadTestResults, saveTestResults, addResult)
    
    // MARK: - Clearing Results (Removed clearAllResults)
    
    // MARK: - Exporting Results (Removed exportResultsToJSON)
    
    // MARK: - Debugging Helpers (Keep for printing)
    
    private func printTestResults(_ result: TestResultData) {
        // Basic console logging for a single result
        print("\n--- Liveness Test Result (ID: \(result.testId.uuidString.prefix(8))) ---")
        print("Timestamp: \(formatDate(result.timestamp))")
        print("Overall Result: \(result.isLive ? "✅ LIVE" : "❌ SPOOF / FAILED")")
        print("Checks Passed: \(result.numPassedChecks) / \(result.requiredChecks)")
        print("Depth Samples: \(result.depthSampleCount)")
        print("Orientation: \(result.deviceOrientation.name)")
        
        print("\n  Checks:")
        print("  - [M] Realistic Depth (≥0.2, ≤3.0m):   \(checkResultText(!result.isUnrealisticDepth))")
        print("  - [M] Center Variation (StdDev ≥0.005): \(checkResultText(result.hasNaturalCenterVariation))")
        print("  - [O] Depth Variation (StdDev ≥0.02):  \(checkResultText(!result.isTooFlat))")
        print("  - [O] Edge Variation (StdDev ≥0.02):   \(checkResultText(!result.hasSharpEdges))") // Note: Flag means *failed* edge variation
        print("  - [O] Depth Profile (StdDev ≥0.02):  \(checkResultText(!result.isTooUniform))")
        print("  - [O] Distribution (Non-linear):      \(checkResultText(!result.isLinearDistribution))")
        print("  - [O] Gradient Pattern (StdDev ≥0.001): \(checkResultText(!result.hasUnnaturalGradients))")
        print("  - [O] Temporal Consistency (<0.0005|>1.5): \(checkResultText(!result.hasInconsistentTemporalChanges))") // Note: Flag means inconsistent
        print("  - [O] Micro-Movements (Natural):      \(checkResultText(!result.hasUnnaturalMicroMovements))")

        print("\n  Statistics:")
        print("  - Depth: Mean=\(String(format: "%.3f", result.depthMean)), StdDev=\(String(format: "%.4f", result.depthStdDev)), Range=\(String(format: "%.4f", result.depthRange))")
        print("  - Edge: StdDev=\(String(format: "%.4f", result.edgeStdDev))")
        print("  - Center: StdDev=\(String(format: "%.4f", result.centerStdDev))")
        print("  - Gradient: Mean=\(String(format: "%.4f", result.gradientMean)), StdDev=\(String(format: "%.4f", result.gradientStdDev))")
        print("--------------------------------------\n")
    }

    // Keep listFailedChecks if useful for console output, otherwise remove
    // private func listFailedChecks(_ result: TestResultData) -> String { ... }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func checkResultText(_ passed: Bool) -> String {
        return passed ? "✅" : "❌"
    }
}

// Helper extension for UIDeviceOrientation names (Keep)
extension UIDeviceOrientation {
    var name: String {
        switch self {
            case .unknown: return "Unknown"
            case .portrait: return "Portrait"
            case .portraitUpsideDown: return "PortraitUpsideDown"
            case .landscapeLeft: return "LandscapeLeft"
            case .landscapeRight: return "LandscapeRight"
            case .faceUp: return "FaceUp"
            case .faceDown: return "FaceDown"
            @unknown default: return "Unknown"
        }
    }
}

// NOTE: TestResultData no longer needs Decodable conformance if not saving/loading.
// Keep Codable for now as Encodable is still used implicitly by JSONEncoder if export is ever re-added. 