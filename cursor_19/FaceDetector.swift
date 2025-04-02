import Foundation
import AVFoundation
import Vision
import UIKit

/**
 * FaceDetector - Handles face detection and liveness verification
 *
 * Orchestrates the face detection process using Vision and delegates
 * liveness checking to LivenessChecker and results management to TestResultManager.
 */
class FaceDetector {
    // MARK: - Private Properties
    
    /// Vision request for detecting facial features in images
    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    
    /// Handler for processing sequences of vision requests - Might not be needed if only doing single frame detection?
    // private let faceDetectionRequestHandler = VNSequenceRequestHandler() // Consider if sequence handling is truly needed
    
    /// The liveness checker instance
    private let livenessChecker = LivenessChecker()
    
    /// Manager for handling test results
    let testResultManager = TestResultManager() // Handles storage details
    
    // Remove properties now managed by LivenessChecker or TestResultManager
    private var lastDepthData: [Float]? // Keep for potential debugging/display?
    
    // MARK: - Initialization
    
    init() {
        // Initialization logic for FaceDetector itself, if any.
        // LivenessChecker and TestResultManager are initialized automatically.
        print("FaceDetector initialized.")
    }
    
    // MARK: - Face Detection
    
    /**
     * Detects the presence of a face in a video frame.
     */
    func detectFace(in sampleBuffer: CMSampleBuffer, completion: @escaping (Bool) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            completion(false)
            return
        }
        
        // Use VNImageRequestHandler for single image analysis
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right) // Assuming orientation is fixed
        
        // The perform method can throw, so keep the do-catch
        // but remove the incorrect assignment to results.
        do {
            // Reset previous request results - REMOVED: .results is get-only
            // faceDetectionRequest.results = nil 
            
            try imageRequestHandler.perform([faceDetectionRequest])
            
            // Check if we have any face observations
            if let observations = faceDetectionRequest.results, !observations.isEmpty {
                completion(true)
            } else {
                completion(false)
            }
        } catch {
            print("Failed to perform face detection: \(error)")
            completion(false)
        }
    }
    
    // MARK: - Liveness Detection (Orchestration)
    
    /// Checks if a detected face is likely a real, live face using depth data analysis.
    /// Delegates the core logic to LivenessChecker and result storage to TestResultManager.
    ///
    /// - Parameters:
    ///   - depthData: The depth data array from the TrueDepth camera (expected 100 values).
    ///   - storeResult: Whether to store the detailed test result data.
    /// - Returns: A boolean indicating whether the face is considered live.
    func checkLiveness(depthData: [Float], storeResult: Bool = true) -> Bool {
        
        // Basic sanity check for depth data size
        guard depthData.count >= 100 else {
            print("Error: Insufficient depth data (\(depthData.count)) for liveness check. Expected 100.")
            if storeResult { 
                // Use the dedicated print method in TestResultManager
                testResultManager.printInsufficientDataResult(depthSampleCount: depthData.count)
            }
            return false
        }
        
        // Store last depth data if needed (e.g., for display or debugging)
        self.lastDepthData = depthData
        
        // Perform all checks using the LivenessChecker
        let checkResults = livenessChecker.performLivenessChecks(depthValues: depthData)
        
        // --- Decision Logic ---
        // Mandatory checks:
        let mandatoryChecksPassed = checkResults.hasRealisticDepth && checkResults.hasNaturalCenterVariation
        
        // Optional checks:
        let optionalChecks = [
            checkResults.hasNaturalVariation,
            checkResults.hasNaturalEdgeVariation,
            checkResults.hasNaturalDepthProfile,
            checkResults.hasNaturalDistribution,
            checkResults.hasNaturalGradientPattern,
            !checkResults.hasTemporalConsistency, // Remember: true from checker means *inconsistent*
            checkResults.hasNaturalMicroMovements
        ]
        let passedOptionalChecksCount = optionalChecks.filter { $0 }.count
        let requiredOptionalChecks = 4 // Need 4 out of 7 optional checks
        
        let optionalChecksPassed = passedOptionalChecksCount >= requiredOptionalChecks
        
        // Final liveness decision
        let isLive = mandatoryChecksPassed && optionalChecksPassed
        
        // Print detailed result if requested
        if storeResult {
            // Use the dedicated print method in TestResultManager
            testResultManager.printCompletedTestResult(
                isLive: isLive,
                checkResults: checkResults,
                passedOptionalChecksCount: passedOptionalChecksCount,
                requiredOptionalChecks: requiredOptionalChecks,
                depthSampleCount: depthData.count
                // deviceOrientation is handled by TestResultManager
            )
        }
        
        return isLive
    }
    
    /**
     * Resets the face detector and its components for a new test.
     */
    func resetForNewTest() {
        livenessChecker.reset() // Reset checker state
        testResultManager.startNewTest() // Reset print tracking in manager
        lastDepthData = nil
        print("FaceDetector reset for new test.")
    }
    
    // MARK: - Removed Methods & Properties
    
    // - All `check...`, `has...`, `calculate...` methods related to liveness logic (now in LivenessChecker)
    // - All `store...`, `load...`, `save...`, `clear...`, `get...`, `export...` methods for results (now in TestResultManager)
    // - Properties: `previousMean`, `previousGradientPatterns`, `patternTimestamps`, `maxStoredPatterns`, `minPatternTime` (in LivenessChecker)
    // - Properties: `maxStoredResults`, `testResults`, `testResultsKey`, `currentTestId` (in TestResultManager, except currentTestId is managed there)
    // - Helper methods `formatDate`, `checkResultText`, `printTestResults`, `listFailedChecks` (moved to TestResultManager)
} 