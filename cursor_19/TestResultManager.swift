import Foundation
import UIKit // For UIDeviceOrientation

class TestResultManager {
    
    // MARK: - Properties
    
    /// Maximum number of test results to store in app memory
    private let maxStoredResults: Int = 20
    
    /// Stored test results for analysis and debugging
    private var testResults: [TestResultData] = []
    
    /// Key for persisting test results in UserDefaults
    private let testResultsKey = "FaceDetectorTestResults"
    
    /// Current test ID to prevent duplicate results from the same test
    private var currentTestId: UUID? = nil
    
    // MARK: - Initialization
    
    init() {
        loadTestResults() // Load results on initialization
        // Optionally clear old results on launch if desired
        // clearAllResults() 
        print("TestResultManager initialized. Found \(testResults.count) saved results.")
    }
    
    // MARK: - Test Lifecycle
    
    /**
     * Starts a new test session by generating a new test ID.
     */
    func startNewTest() {
        currentTestId = UUID()
        print("Starting new test (ID: \(currentTestId?.uuidString.prefix(8) ?? "none"))")
    }
    
    /**
     * Returns the current test ID.
     */
    func getCurrentTestId() -> UUID? {
        return currentTestId
    }

    // MARK: - Storing Results

    /**
     * Stores the result of a completed liveness test, derived from LivenessCheckResults.
     */
    func storeCompletedTestResult(
        isLive: Bool,
        checkResults: LivenessCheckResults,
        passedOptionalChecksCount: Int,
        requiredOptionalChecks: Int, // Or maybe calculate required based on total optional checks?
        depthSampleCount: Int,
        deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation // Get orientation here
    ) {
        guard let testId = currentTestId else {
            print("Warning: Attempted to store completed test result without an active test ID.")
            return
        }
        
        // Prevent storing duplicate results for the same test ID
        if hasResultForTest(id: testId) {
             print("Warning: Result for test ID \(testId.uuidString.prefix(8)) already stored. Ignoring duplicate.")
             return
        }
        
        let totalChecks = 9 // Update if the number of checks changes
        let numPassedChecks = (checkResults.hasRealisticDepth ? 1 : 0) + 
                              (checkResults.hasNaturalCenterVariation ? 1 : 0) + 
                              passedOptionalChecksCount

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
            hasInconsistentTemporalChanges: checkResults.hasTemporalConsistency, // Note: Checker returns true if *inconsistent*
            hasUnnaturalMicroMovements: !checkResults.hasNaturalMicroMovements,
            numPassedChecks: numPassedChecks,
            requiredChecks: totalChecks,
            depthSampleCount: depthSampleCount,
            isStillFaceDetected: true, // Assuming if we got here, a face was detected
            deviceOrientation: deviceOrientation,
            timestamp: Date(),
            testId: testId
        )
        
        addResult(result)
        printTestResults(result) // Log the stored result
    }

    /**
     * Stores a test result indicating insufficient depth data.
     */
    func storeInsufficientDataResult(depthSampleCount: Int) {
        guard let testId = currentTestId else {
            print("Warning: Attempted to store insufficient data result without valid test ID.")
            return
        }

        if hasResultForTest(id: testId) {
            print("Warning: Result for test ID \(testId.uuidString.prefix(8)) already stored. Ignoring duplicate.")
            return
        }

        let currentTime = Date()
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
            isStillFaceDetected: false, // Indicates face detection might have failed or data was bad
            deviceOrientation: UIDevice.current.orientation,
            timestamp: currentTime,
            testId: testId
        )

        print("⚠️ INSUFFICIENT DATA: Storing FAIL result at \(formatDate(currentTime))")
        print("  - ID: \(testId.uuidString.prefix(8)), Depth samples: \(depthSampleCount)")
        
        addResult(result)
    }
    
    /**
     * Stores a manually determined test result (e.g., from user input or external decision).
     */
    func storeManualResult(isLive: Bool) {
        guard let testId = currentTestId else {
            print("Warning: Attempted to store manual test result without valid test ID.")
            return
        }

        if hasResultForTest(id: testId) {
            print("Warning: Result for test ID \(testId.uuidString.prefix(8)) already stored. Ignoring duplicate manual result.")
            return
        }

        let currentTime = Date()
        let totalChecks = 9
        let testResult = TestResultData(
            isLive: isLive,
            depthMean: 0, depthStdDev: 0, depthRange: 0,
            edgeMean: 0, edgeStdDev: 0, centerMean: 0, centerStdDev: 0,
            gradientMean: 0, gradientStdDev: 0,
            // Assume all checks failed if not live, passed if live (simplification for manual entry)
            isTooFlat: !isLive, isUnrealisticDepth: !isLive, hasSharpEdges: !isLive, isTooUniform: !isLive,
            hasNaturalCenterVariation: isLive, isLinearDistribution: !isLive, hasUnnaturalGradients: !isLive,
            hasInconsistentTemporalChanges: !isLive, hasUnnaturalMicroMovements: !isLive,
            numPassedChecks: isLive ? totalChecks : 0,
            requiredChecks: totalChecks,
            depthSampleCount: 0, // No depth data for manual result
            isStillFaceDetected: false, // Unknown for manual result
            deviceOrientation: UIDevice.current.orientation,
            timestamp: currentTime,
            testId: testId
        )
        
        print("📄 MANUAL TEST STORED: \(isLive ? "LIVE ✅" : "SPOOF ❌")")
        print("  - ID: \(testId.uuidString.prefix(8)), Time: \(formatDate(currentTime))")
        
        addResult(testResult)
    }
    
    // MARK: - Accessing Results
    
    /**
     * Returns all stored test results, most recent first.
     */
    func getAllResults() -> [TestResultData] {
        return testResults
    }
    
    /**
     * Returns the most recent test result, if available.
     */
    func getLastResult() -> TestResultData? {
        return testResults.first
    }
    
    /**
     * Checks if a result exists for the given test ID.
     */
    func hasResultForTest(id: UUID) -> Bool {
        return testResults.contains(where: { $0.testId == id })
    }
    
    // MARK: - Persistence
    
    /**
     * Loads test results from UserDefaults.
     */
    private func loadTestResults() {
        guard let data = UserDefaults.standard.data(forKey: testResultsKey) else {
            testResults = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            // Need to decode TestResultData which uses custom encoding for orientation
            // This requires TestResultData to be Decodable as well.
            // We'll assume TestResultData is made Decodable separately.
            testResults = try decoder.decode([TestResultData].self, from: data)
            // Ensure results are sorted most recent first if order isn't guaranteed by saving
            testResults.sort { $0.timestamp > $1.timestamp }
        } catch {
            print("Error loading test results: \(error). Clearing saved data.")
            testResults = []
            UserDefaults.standard.removeObject(forKey: testResultsKey)
        }
    }
    
    /**
     * Saves the current test results to UserDefaults.
     */
    private func saveTestResults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(testResults)
            UserDefaults.standard.set(data, forKey: testResultsKey)
            // synchronize() is generally not needed anymore
            // UserDefaults.standard.synchronize()
        } catch {
            print("Error saving test results: \(error)")
        }
    }
    
    /**
     * Adds a result to the in-memory array, maintains max count, and saves.
     */
    private func addResult(_ result: TestResultData) {
        // Insert at the beginning to keep it sorted by time (most recent first)
        testResults.insert(result, at: 0)
        
        // Limit the number of stored results
        if testResults.count > maxStoredResults {
            testResults.removeLast()
        }
        
        // Persist changes
        saveTestResults()
    }
    
    // MARK: - Clearing Results
    
    /**
     * Clears all test results from memory and persistent storage.
     */
    func clearAllResults() {
        testResults = []
        currentTestId = nil // Also reset current test ID
        UserDefaults.standard.removeObject(forKey: testResultsKey)
        print("All test results cleared.")
    }
    
    // MARK: - Exporting Results
    
    /**
     * Generates JSON representation of test results for export.
     */
    func exportResultsToJSON() -> Data? {
        do {
             // Use the standard Encodable conformance of TestResultData
             let encoder = JSONEncoder()
             encoder.outputFormatting = .prettyPrinted
             encoder.dateEncodingStrategy = .iso8601
             return try encoder.encode(testResults)
         } catch {
             print("Error encoding test results to JSON: \(error)")
             return nil
         }
    }
    
    // MARK: - Debugging Helpers (Moved from FaceDetector)
    
    private func printTestResults(_ result: TestResultData) {
        // Basic console logging for a single result
        print("\n--- Test Result (ID: \(result.testId.uuidString.prefix(8))) ---")
        print("Timestamp: \(formatDate(result.timestamp))")
        print("Overall Result: \(result.isLive ? "✅ LIVE" : "❌ SPOOF / FAILED")")
        print("Checks Passed: \(result.numPassedChecks) / \(result.requiredChecks)")
        print("Depth Samples: \(result.depthSampleCount)")
        print("Orientation: \(result.deviceOrientation.name)") // Use extension for name
        
        print("\n  Checks:")
        print("  - [M] Realistic Depth (≥0.2, ≤3.0m):   \(checkResultText(!result.isUnrealisticDepth))")
        print("  - [M] Center Variation (StdDev ≥0.005): \(checkResultText(result.hasNaturalCenterVariation))")
        print("  - [O] Depth Variation (StdDev ≥0.02):  \(checkResultText(!result.isTooFlat))")
        print("  - [O] Edge Variation (StdDev ≥0.02):   \(checkResultText(!result.hasSharpEdges))")
        print("  - [O] Depth Profile (StdDev ≥0.02):  \(checkResultText(!result.isTooUniform))") // Note: Original check was OR range >= 0.05
        print("  - [O] Distribution (Non-linear):      \(checkResultText(!result.isLinearDistribution))")
        print("  - [O] Gradient Pattern (StdDev ≥0.001): \(checkResultText(!result.hasUnnaturalGradients))")
        print("  - [O] Temporal Consistency (<0.0005|>1.5): \(checkResultText(!result.hasInconsistentTemporalChanges))")
        print("  - [O] Micro-Movements (Natural):      \(checkResultText(!result.hasUnnaturalMicroMovements))")

        print("\n  Statistics:")
        print("  - Depth: Mean=\(String(format: "%.3f", result.depthMean)), StdDev=\(String(format: "%.4f", result.depthStdDev)), Range=\(String(format: "%.4f", result.depthRange))")
        print("  - Edge: StdDev=\(String(format: "%.4f", result.edgeStdDev))")
        print("  - Center: StdDev=\(String(format: "%.4f", result.centerStdDev))")
        print("  - Gradient: Mean=\(String(format: "%.4f", result.gradientMean)), StdDev=\(String(format: "%.4f", result.gradientStdDev))")
        print("--------------------------------------\n")
    }

    private func listFailedChecks(_ result: TestResultData) -> String {
        // Helper to get a comma-separated list of failed checks (based on boolean flags)
        var failed: [String] = []
        if result.isTooFlat { failed.append("FlatDepth") }
        if result.isUnrealisticDepth { failed.append("UnrealisticDepth") }
        if result.hasSharpEdges { failed.append("SharpEdges") } // Note: Flag means *failed* edge variation
        if result.isTooUniform { failed.append("UniformProfile") }
        if !result.hasNaturalCenterVariation { failed.append("FlatCenter") }
        if result.isLinearDistribution { failed.append("LinearDist") }
        if result.hasUnnaturalGradients { failed.append("UnnaturalGrad") }
        if result.hasInconsistentTemporalChanges { failed.append("InconsistentTemp") }
        if result.hasUnnaturalMicroMovements { failed.append("UnnaturalMicroMove") }
        return failed.isEmpty ? "None" : failed.joined(separator: ", ")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func checkResultText(_ passed: Bool) -> String {
        return passed ? "✅" : "❌"
    }
}

// Helper extension for UIDeviceOrientation names (optional)
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

// NOTE: TestResultData needs to conform to Decodable for loading to work.
// This should be added in TestResultData.swift 