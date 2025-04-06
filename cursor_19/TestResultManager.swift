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
        // Removed print statement, LogManager handles its own init log
        // print("TestResultManager initialized (Console printing only).")
    }
    
    // MARK: - Test Lifecycle
    /**
     * Starts tracking for a new test, allowing one result to be printed for it.
     */
    func startNewTest() {
        currentTestId = UUID()
        hasPrintedCurrentTest = false // Allow printing for this new test ID
        currentTestWasSuccessful = false // Reset success flag for new test
        LogManager.shared.log("--- Starting New Test (Manager ID: \(currentTestId?.uuidString.prefix(8) ?? "none")) ---")
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
        
        let totalChecks = 9 // Total number of checks remains 9
        // Correct calculation for passed checks based on 4 mandatory + passed optional
        let numPassedMandatory = (checkResults.hasRealisticDepth ? 1 : 0) + 
                                 (checkResults.hasNaturalCenterVariation ? 1 : 0) + 
                                 (checkResults.hasNaturalEdgeVariation ? 1 : 0) + 
                                 (checkResults.hasNaturalDepthProfile ? 1 : 0)
        // 'passedOptionalChecksCount' is correctly passed in from FaceDetector
        let numPassedChecks = numPassedMandatory + passedOptionalChecksCount

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
        
        // Log the formatted result using LogManager
        let logString = formatTestResultForLog(result)
        LogManager.shared.log(logString)
        
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
        
        // Construct and log the insufficient data message
        let logMessage = """
        ⚠️ INSUFFICIENT DATA (Test ID: \(managerTestId.uuidString.prefix(8))) at \(formatDate(currentTime))
          - Depth samples: \(depthSampleCount)
        """
        LogManager.shared.log(logMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Mark this test ID as printed (as it's a final result for this attempt)
        hasPrintedCurrentTest = true 
    }
    
    // MARK: - Accessing Results (Removed getAllResults, getLastResult, hasResultForTest)
    
    // MARK: - Persistence (Removed loadTestResults, saveTestResults, addResult)
    
    // MARK: - Clearing Results (Removed clearAllResults)
    
    // MARK: - Exporting Results (Removed exportResultsToJSON)
    
    // MARK: - Debugging Helpers (Keep for printing)
    
    // Renamed from printTestResults to formatTestResultForLog and now returns String
    private func formatTestResultForLog(_ result: TestResultData) -> String {
        // Basic console logging for a single result - build as a single string
        var logOutput = ""
        logOutput += "\n--- Liveness Test Result (ID: \(result.testId.uuidString.prefix(8))) ---"
        logOutput += "\nTimestamp: \(formatDate(result.timestamp))"
        logOutput += "\nOverall Result: \(result.isLive ? "✅ LIVE" : "❌ SPOOF / FAILED")"
        logOutput += "\nChecks Passed: \(result.numPassedChecks) / \(result.requiredChecks)"
        logOutput += "\nDepth Samples: \(result.depthSampleCount)"
        logOutput += "\nOrientation: \(result.deviceOrientation.name)"
        
        logOutput += "\n\n  Checks:"
        logOutput += "\n  - [M] Realistic Depth (≥0.2, ≤3.0m):   \(checkResultText(!result.isUnrealisticDepth))"
        logOutput += "\n  - [M] Center Variation (StdDev ≥0.005): \(checkResultText(result.hasNaturalCenterVariation))"
        logOutput += "\n  - [O] Depth Variation (StdDev ≥0.02):  \(checkResultText(!result.isTooFlat))"
        logOutput += "\n  - [M] Edge Variation (StdDev ≥0.02):   \(checkResultText(!result.hasSharpEdges))" // Note: Flag means *failed* edge variation
        logOutput += "\n  - [M] Depth Profile (StdDev ≥0.02):  \(checkResultText(!result.isTooUniform))"
        logOutput += "\n  - [O] Distribution (Non-linear):      \(checkResultText(!result.isLinearDistribution))"
        logOutput += "\n  - [O] Gradient Pattern (StdDev ≥0.001): \(checkResultText(!result.hasUnnaturalGradients))"
        logOutput += "\n  - [O] Temporal Consistency (<0.0005|>1.5): \(checkResultText(!result.hasInconsistentTemporalChanges))" // Note: Flag means inconsistent
        logOutput += "\n  - [O] Micro-Movements (Natural):      \(checkResultText(!result.hasUnnaturalMicroMovements))"

        logOutput += "\n\n  Statistics:"
        logOutput += "\n  - Depth: Mean=\(String(format: "%.3f", result.depthMean)), StdDev=\(String(format: "%.4f", result.depthStdDev)), Range=\(String(format: "%.4f", result.depthRange))"
        logOutput += "\n  - Edge: StdDev=\(String(format: "%.4f", result.edgeStdDev))"
        logOutput += "\n  - Center: StdDev=\(String(format: "%.4f", result.centerStdDev))"
        logOutput += "\n  - Gradient: Mean=\(String(format: "%.4f", result.gradientMean)), StdDev=\(String(format: "%.4f", result.gradientStdDev))"
        logOutput += "\n--------------------------------------\n"
        
        return logOutput.trimmingCharacters(in: .whitespacesAndNewlines) // Trim leading/trailing whitespace
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