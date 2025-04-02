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
    
    /// Possible results for a liveness test
    enum TestResult {
        case success    // A real, live face was detected
        case failure    // A face was detected but determined to be a spoof
        case timeout    // No face was detected within the time limit
        case insufficientData  // Not enough depth data to make a determination
    }
    
    // MARK: - View Body
    
    var body: some View {
        ZStack {
            // Camera preview - full screen
            CameraPreview(cameraManager: cameraManager)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    cameraManager.setupAndStartSession()
                }
            
            // Overlay VStack for UI elements
            VStack {
                // Test Status/Result Area (Moved to Top)
                VStack(spacing: 10) {
                    // Display Timer - REMOVED from top
                    /*
                    if isTestRunning {
                        Text("Testing: \(String(format: "%.1f", timeRemaining))s")
                            .font(.headline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 15)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundColor(.primary)
                            .transition(.opacity.animation(.easeInOut))
                    }
                    */
                            
                    // Hint Text (Stays at top for now)
                    if isTestRunning && cameraManager.faceDetected && !cameraManager.isLiveFace {
                        Text("Move closer")
                            .font(.caption)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundColor(.secondary)
                            .transition(.opacity.animation(.easeInOut))
                    }
                    
                    // Display Result after test (Re-added)
                    if let result = testResult {
                        Text(resultText(for: result))
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(resultBackground(for: result).opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .transition(.opacity.animation(.easeInOut))
                            .padding(.horizontal) 
                    }
                }
                .padding(.top, 50) // Add padding from the top safe area/notch
                .padding(.bottom, 10) // Padding below the top elements

                Spacer() // Pushes button/timer to the bottom
                                
                // Start Button / Timer Area (Combined at Bottom)
                Group {
                    if isTestRunning {
                        // Display Timer Text, styled like the button
                        Text("Testing: \(String(format: "%.1f", timeRemaining))s")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray) // Use a neutral color for timer background
                            .cornerRadius(15)
                    } else {
                        // Display Start Button
                        Button(action: startTest) {
                            Text("Start Liveness Test")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(15)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30) // Bottom safe area padding
                .transition(.opacity.animation(.easeInOut))

            }
            .animation(.easeInOut, value: isTestRunning) // Animate changes based on test running state
            .animation(.easeInOut, value: testResult)    // Animate changes based on result state
        }
        .onDisappear {
            // Clean up resources when view disappears
            cameraManager.stopSession()
            stopTimer()
        }
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
        
        // Reset face detection state and activate test mode using the manager method
        cameraManager.prepareForNewTest()
        
        // Reset the face detector - MOVED into prepareForNewTest
        // cameraManager.faceDetector.resetForNewTest()
        
        // Start timer with 0.1 second intervals for smooth countdown
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            timeRemaining -= 0.1
            
            // Check if we have a live face
            if cameraManager.faceDetected && cameraManager.isLiveFace {
                // Verification using getLastTestResult removed - rely on isLiveFace directly
                // if let lastResult = cameraManager.faceDetector.testResultManager.getLastTestResult() { ... }
                // Simplified success condition:
                print("Test verified: Live face detected.")
                testResult = .success
                stopTest()
            } else if timeRemaining <= 0 {
                if cameraManager.faceDetected {
                    // Checking lastResult removed - assume failure or insufficient data based on detection
                    // if let lastResult = cameraManager.faceDetector.testResultManager.getLastTestResult(), ...
                    testResult = .failure // Simplified: If face detected but not live by timeout = failure
                    
                    // Print the failed test result - REMOVED (Handled by final checkLiveness call implicitly)
                    // cameraManager.faceDetector.testResultManager.printManualResult(isLive: false)
                } else {
                    testResult = .timeout  // No face detected
                    // Print the timeout test result - REMOVED (Handled by final checkLiveness call implicitly)
                    // cameraManager.faceDetector.testResultManager.printManualResult(isLive: false)
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
                
        // Reset face detection state and deactivate test mode using the manager method
        cameraManager.finalizeTest()
        // cameraManager.faceDetected = false // Handled by finalize or prepare
        // cameraManager.isLiveFace = false // Handled by finalize or prepare
        // cameraManager.isTestActive = false // Handled by finalize
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
            return "Real Face Detected!"
        case .failure:
            return "Spoof Detected!"
        case .timeout:
            return "No Face Detected!"
        case .insufficientData:
            return "Insufficient Data!"
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
        case .insufficientData:
            return Color.orange
        }
    }
}

#Preview {
    ContentView()
}
