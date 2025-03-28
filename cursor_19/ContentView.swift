//
//  ContentView.swift
//  cursor_19
//
//  Created by Jason Reid on 24/03/2025.
//

import SwiftUI
import UIKit

/**
 * ContentView - Main user interface for the Face Liveness Detection application
 *
 * This view manages the camera preview display and user interactions for the face liveness testing process.
 * It displays the camera feed, timer, test results, and control buttons. The view also provides real-time
 * feedback to guide users during the face detection process.
 *
 * Key features:
 * - Real-time camera preview with face detection feedback
 * - Precise 5-second countdown timer with 0.1-second updates
 * - Dynamic user guidance for optimal face positioning
 * - Clear visual feedback for test results
 * - Automatic test completion on successful liveness detection
 *
 * The liveness test follows this process:
 * 1. User taps the "Start Liveness Test" button to begin
 * 2. A 5-second countdown timer starts with 0.1-second precision
 * 3. The app continuously monitors for face detection and liveness
 * 4. Real-time feedback guides the user for optimal face positioning
 * 5. Test completes with one of three results:
 *    - Success: A real, live face was detected
 *    - Failure: A face was detected but determined to be a spoof
 *    - Timeout: No face was detected within the time limit
 */
struct ContentView: View {
    // MARK: - Properties
    
    /// Manages camera capture, face detection, and depth analysis
    @StateObject private var cameraManager = CameraManager()
    
    /// Indicates whether a liveness test is currently in progress
    @State private var isTestRunning = false
    
    /// Stores the result of the most recent liveness test
    @State private var testResult: TestResult?
    
    /// Countdown timer value (in seconds) for the current test
    @State private var timeRemaining = 5.0
    
    /// Timer object used for the test countdown
    @State private var timer: Timer?
    
    /// Controls whether share sheet is shown
    @State private var isSharePresented = false
    
    /// Items to share
    @State private var itemsToShare: [Any] = []
    
    // Reference to the share sheet controller for half-height presentation
    @State private var shareController: ActivityViewController?
    
    /// Possible results for a liveness test
    enum TestResult {
        case success  // A real, live face was detected
        case failure  // A face was detected but determined to be a spoof
        case timeout  // No face was detected within the time limit
    }
    
    // MARK: - View Body
    
    var body: some View {
        ZStack {
            // Camera preview - full screen
            CameraPreview(cameraManager: cameraManager)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // Make sure to set up and start the camera session when the view appears
                    cameraManager.setupAndStartSession()
                }
            
            // Debug button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        prepareDebugDataAndShare()
                    }) {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                }
                
                Spacer()
                
                // Controls and feedback overlays
                VStack {
                    // Test status display - shows countdown timer during a test
                    if isTestRunning {
                        Text("Testing: \(String(format: "%.1f", timeRemaining))s")
                            .font(.title)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                        // Display hint when face is detected but liveness not yet verified
                        if cameraManager.faceDetected && !cameraManager.isLiveFace {
                            Text("Move the camera closer to your face")
                                .font(.headline)
                                .padding()
                                .background(Color.blue.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.top, 10)
                        }
                    }
                    
                    // Result display - shows outcome after a test completes
                    if let result = testResult {
                        Text(resultText(for: result))
                            .font(.title)
                            .padding()
                            .background(resultBackground(for: result))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom, 20)
                    }
                    
                    // Start test button - initiates a new liveness test
                    if !isTestRunning {
                        Button(action: startTest) {
                            Text("Start Liveness Test")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(minWidth: 200)
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .background(ActivityViewControllerRepresentable(
            activityItems: itemsToShare,
            isPresented: $isSharePresented,
            controller: $shareController
        ))
        .onDisappear {
            // Clean up resources when view disappears
            cameraManager.stopSession()
            stopTimer()
        }
    }
    
    // MARK: - Debug Data Sharing
    
    /**
     * Prepares debug data and opens the system sharing sheet
     */
    private func prepareDebugDataAndShare() {
        let testResults = cameraManager.faceDetector.getTestResults()
        
        // Prepare text file with human-readable content
        var textContent = "Face Liveness Debug Data\n"
        textContent += "======================\n\n"
        textContent += "Total test results: \(testResults.count)\n\n"
        
        for (index, result) in testResults.enumerated() {
            textContent += "TEST \(testResults.count - index):\n"
            textContent += "Time: \(formatDate(result.timestamp))\n"
            textContent += "Result: \(result.isLive ? "LIVE FACE" : "SPOOF")\n"
            textContent += "Checks passed: \(result.numPassedChecks)/9\n"
            textContent += "Depth samples: \(result.depthSampleCount)\n\n"
            
            textContent += "DEPTH STATISTICS:\n"
            textContent += "- Mean depth: \(String(format: "%.4f", result.depthMean))\n"
            textContent += "- StdDev: \(String(format: "%.4f", result.depthStdDev))\n"
            textContent += "- Range: \(String(format: "%.4f", result.depthRange))\n"
            textContent += "- Edge StdDev: \(String(format: "%.4f", result.edgeStdDev))\n"
            textContent += "- Center StdDev: \(String(format: "%.4f", result.centerStdDev))\n"
            textContent += "- Gradient Mean: \(String(format: "%.4f", result.gradientMean))\n"
            textContent += "- Gradient StdDev: \(String(format: "%.4f", result.gradientStdDev))\n\n"
            
            textContent += "CHECK RESULTS:\n"
            textContent += "- Depth Variation: \(checkResultText(!result.isTooFlat))\n"
            textContent += "- Realistic Depth: \(checkResultText(!result.isUnrealisticDepth))\n" 
            textContent += "- Edge Variation: \(checkResultText(!result.hasSharpEdges))\n"
            textContent += "- Depth Profile: \(checkResultText(!result.isTooUniform))\n"
            textContent += "- Center Variation: \(checkResultText(result.hasNaturalCenterVariation))\n"
            textContent += "- Depth Distribution: \(checkResultText(!result.isLinearDistribution))\n"
            textContent += "- Gradient Pattern: \(checkResultText(!result.hasUnnaturalGradients))\n"
            textContent += "- Temporal Consistency: \(checkResultText(!result.hasInconsistentTemporalChanges))\n"
            textContent += "- No Mask Detected: \(checkResultText(!result.hasMaskCharacteristics))\n\n"
            
            textContent += "MASK DETECTION DETAILS:\n"
            textContent += "- Natural Micro-movements: \(checkResultText(!result.hasUnnaturalMicroMovements))\n"
            textContent += "- Natural Symmetry: \(checkResultText(!result.hasUnnaturalSymmetry))\n"
            textContent += "- Natural Temporal Patterns: \(checkResultText(!result.hasUnnaturalTemporalPatterns))\n\n"
            textContent += "-----------\n\n"
        }
        
        // Get JSON data
        let jsonData = cameraManager.faceDetector.exportTestResultsAsJSON()
        
        // Create temporary files and prepare for sharing
        if let textData = textContent.data(using: .utf8) {
            let textURL = createTempFile(withData: textData, filename: "liveness_debug.txt")
            let jsonURL = createTempFile(withData: jsonData, filename: "liveness_debug.json")
            
            var shareItems: [Any] = []
            if let textURL = textURL {
                shareItems.append(textURL)
            }
            if let jsonURL = jsonURL, let jsonData = jsonData {
                shareItems.append(jsonURL)
            }
            
            self.itemsToShare = shareItems
            self.isSharePresented = true
        }
    }
    
    /**
     * Creates a temporary file with the provided data
     */
    private func createTempFile(withData data: Data?, filename: String) -> URL? {
        guard let data = data else { return nil }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error creating temp file: \(error)")
            return nil
        }
    }
    
    /**
     * Returns a textual representation of a check result
     */
    private func checkResultText(_ passed: Bool) -> String {
        return passed ? "✓ PASS" : "✗ FAIL"
    }
    
    /**
     * Formats a date for display
     */
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Test Management
    
    /**
     * Starts a new liveness detection test.
     *
     * Initializes a 5-second timer and activates face detection processing.
     * The test will automatically end when either:
     * - A live face is detected (success)
     * - The timer expires (failure or timeout)
     */
    private func startTest() {
        isTestRunning = true
        testResult = nil
        timeRemaining = 5.0
        
        // Reset face detection state and activate test mode
        cameraManager.faceDetected = false
        cameraManager.isLiveFace = false
        cameraManager.isTestActive = true
        
        // Start timer with 0.1 second intervals for smooth countdown
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeRemaining -= 0.1
            
            // Check if we have a live face
            if cameraManager.faceDetected && cameraManager.isLiveFace {
                testResult = .success
                stopTest()
            } else if timeRemaining <= 0 {
                if cameraManager.faceDetected {
                    testResult = .failure // Face detected but not live
                } else {
                    testResult = .timeout // No face detected
                }
                stopTest()
            }
        }
    }
    
    /**
     * Stops the current liveness test.
     *
     * Cleans up the timer and resets the camera manager state.
     */
    private func stopTest() {
        isTestRunning = false
        stopTimer()
        
        // Reset face detection state and deactivate test mode
        cameraManager.faceDetected = false
        cameraManager.isLiveFace = false
        cameraManager.isTestActive = false
    }
    
    /**
     * Stops and invalidates the timer.
     */
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Result Formatting
    
    /**
     * Returns the appropriate text to display for a test result.
     *
     * - Parameter result: The test result to display
     * - Returns: A formatted string describing the result
     */
    private func resultText(for result: TestResult) -> String {
        switch result {
        case .success:
            return "Real Face Detected! ✅"
        case .failure:
            return "Spoof Detected! ❌"
        case .timeout:
            return "No Face Detected! ⏱"
        }
    }
    
    /**
     * Returns the appropriate background color for a test result display.
     *
     * - Parameter result: The test result to display
     * - Returns: Green for success, red for failure or timeout
     */
    private func resultBackground(for result: TestResult) -> Color {
        switch result {
        case .success:
            return Color.green
        case .failure, .timeout:
            return Color.red
        }
    }
}

// MARK: - Activity View Controller

class ActivityViewController: UIActivityViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure sheet presentation
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
        }
    }
}

struct ActivityViewControllerRepresentable: UIViewControllerRepresentable {
    var activityItems: [Any]
    @Binding var isPresented: Bool
    @Binding var controller: ActivityViewController?
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            // Create and configure activity view controller
            let activityVC = ActivityViewController(activityItems: activityItems, applicationActivities: nil)
            self.controller = activityVC
            
            // Configure for iPad
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityVC.popoverPresentationController?.sourceView = uiViewController.view
                activityVC.popoverPresentationController?.sourceRect = CGRect(
                    x: uiViewController.view.bounds.midX,
                    y: uiViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                activityVC.popoverPresentationController?.permittedArrowDirections = []
            }
            
            // Handle dismissal
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                self.isPresented = false
                self.controller = nil
            }
            
            uiViewController.present(activityVC, animated: true)
        }
    }
}

#Preview {
    ContentView()
}
