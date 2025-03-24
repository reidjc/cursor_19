//
//  ContentView.swift
//  cursor_19
//
//  Created by Jason Reid on 24/03/2025.
//

import SwiftUI

/**
 * ContentView - Main user interface for the Face Liveness Detection application
 *
 * This view manages the camera preview display and user interactions for the face liveness testing process.
 * It displays the camera feed, timer, test results, and control buttons.
 *
 * The liveness test follows this process:
 * 1. User taps the "Start Liveness Test" button to begin a 5-second test
 * 2. During the test, the app analyzes camera frames to detect faces and assess liveness
 * 3. Once complete, results are displayed (success, failure, or timeout)
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
            
            // Controls and feedback overlays
            VStack {
                Spacer()
                
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
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 30)
                }
            }
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

#Preview {
    ContentView()
}
