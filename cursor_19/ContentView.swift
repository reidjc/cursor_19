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

// MARK: - Helper Shapes

struct OvalShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Calculate oval bounds based on the view's rect
        // Make it slightly smaller than the full view and portrait oriented
        let width = rect.width * 0.75
        let height = rect.height * 0.5 // Reduced height multiplier from 0.6 to 0.5
        let xOffset = (rect.width - width) / 2
        let yOffset = (rect.height - height) / 2
        let ovalRect = CGRect(x: xOffset, y: yOffset, width: width, height: height)
        
        return Path(ellipseIn: ovalRect)
    }
}

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
        case fallbackSuccess // Passed only after falling back to hardcoded thresholds
        case fallbackFailure // Failed *even after* falling back to hardcoded thresholds
    }
    
    /// Possible outcomes for the enrollment process
    enum EnrollmentOutcome {
        case success    // Enrollment completed successfully
        case failure    // Enrollment failed
    }
    @State private var enrollmentOutcome: EnrollmentOutcome?
    
    // MARK: - Computed Properties
    
    /// Target scale factor for the oval during the center/test phase
    private let targetOvalScale: CGFloat = 1.0
    /// Scale factor for the oval when guiding user closer
    private let closerOvalScale: CGFloat = 0.7
    /// Scale factor for the oval when guiding user further
    private let furtherOvalScale: CGFloat = 1.3

    /// Determines the current scale factor for the oval guide
    private var currentOvalScale: CGFloat {
        switch cameraManager.enrollmentState {
        case .capturingCenter, .enrollmentComplete, .notEnrolled, .enrollmentFailed:
            // Also use target scale during standard liveness test (when enrollmentComplete)
            return targetOvalScale 
        case .capturingCloserMovement:
            return closerOvalScale
        case .capturingFurtherMovement:
            return furtherOvalScale
        // Intermediate states (prompts, calculating) can use the target scale
        // or potentially animate from/to the previous/next scale if we add animation later.
        case .promptCenter, .promptCloser, .promptFurther, .calculatingThresholds:
            return targetOvalScale // Default to target for simplicity
        }
    }
    
    /// Determines the color of the oval guide
    private var ovalColor: Color {
        switch cameraManager.enrollmentState {
        case .capturingCenter, .capturingCloserMovement, .capturingFurtherMovement:
            return .green // Green during active capture phases
        case .enrollmentComplete, .notEnrolled, .enrollmentFailed:
             // White/clearer during idle or test states
             // Consider making it more prominent during the test?
             return .white.opacity(0.7)
        default:
            // White during prompts/calculating
            return .white
        }
    }
    
    /// Determines if the oval should be visible
    private var showOval: Bool {
        // Show during enrollment and during active liveness test
        return isTestRunning || cameraManager.enrollmentState != .notEnrolled
    }
    
    /// Determines if the main action button should be disabled
    private var isActionButtonDisabled: Bool {
        isTestRunning ||
        [.promptCenter, .capturingCenter,
         .promptCloser, .capturingCloserMovement,
         .promptFurther, .capturingFurtherMovement,
         .calculatingThresholds].contains(cameraManager.enrollmentState)
    }
    
    /// Provides the text for the main action button
    private var actionButtonText: String {
        switch cameraManager.enrollmentState {
        case .notEnrolled, .enrollmentFailed:
            return "Start Enrollment"
        case .enrollmentComplete:
            return "Start Liveness Test"
        default:
            // During active enrollment steps, the button is disabled, but might show previous text briefly
            // Let's keep the "Start Test" text as a default fallback during transitions
            return "Start Liveness Test"
        }
    }
    
    /// Provides the instruction or status text displayed above the button
    private var instructionText: String? {
        if isTestRunning {
            // Test instruction
            return "Keep face centered in oval"
        }
        switch cameraManager.enrollmentState {
        case .promptCenter: return "Fit face in oval"
        case .capturingCenter: return "Hold steady..."
        case .promptCloser: return "Move closer to keep face in shrinking oval"
        case .capturingCloserMovement: return "Capturing... Keep moving closer"
        case .promptFurther: return "Move back to keep face in growing oval"
        case .capturingFurtherMovement: return "Capturing... Keep moving back"
        case .calculatingThresholds: return "Calculating..."
        // For enrollment complete, show standard button text instead of instruction
        case .enrollmentComplete: return nil 
        // No specific instruction text needed for idle/failed states (button text suffices)
        default: return nil 
        }
    }
    
    /// Determines the color of the instruction text
    private var instructionTextColor: Color {
        switch cameraManager.enrollmentState {
        case .capturingCenter, .capturingCloserMovement, .capturingFurtherMovement:
            return .green // Indicate active capture
        default:
            return .white // Default color for prompts/timer
        }
    }
    
    // MARK: - View Body
    
    var body: some View {
        ZStack {
            // Camera preview - full screen
            CameraPreview(cameraManager: cameraManager)
                .overlay(
                    // Add the oval overlay
                    Group {
                        if showOval {
                            OvalShape()
                                .stroke(ovalColor, lineWidth: 4) // Use dynamic color
                                .scaleEffect(currentOvalScale) // Use dynamic scale
                                .animation(.easeInOut(duration: 0.5), value: currentOvalScale) // Animate scale changes
                        }
                    }
                )
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
                            .foregroundColor(.white) // Ensure white text
                            .padding()
                            .frame(maxWidth: .infinity)
                            // Revert to solid background with opacity
                            .background(resultBackground(for: result).opacity(0.8))
                            // Remove the material background and overlay
                            // .background(Material.thin)
                            // .overlay( ... )
                            .cornerRadius(15)
                            .transition(.opacity.animation(.easeInOut))
                            .padding(.horizontal) 
                    } else if let outcome = enrollmentOutcome { // Show enrollment outcome if no test result
                        Text(enrollmentOutcomeText(for: outcome))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(enrollmentOutcomeBackground(for: outcome).opacity(0.8))
                            .cornerRadius(15)
                            .transition(.opacity.animation(.easeInOut))
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal) // Horizontal padding for banner
                // Reduced top padding significantly, relies more on safe area
                .padding(.top, 10) 
                // Removed bottom padding from here
                
                Spacer() // This will push the bottom HStack down
                                
                // Container for bottom elements - Changed to HStack
                HStack(spacing: 15) { 
                    
                    // Reset Enrollment Button (Icon)
                    Button {
                        cameraManager.resetEnrollment()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.title2) 
                            .padding(10)   
                    }
                    .background(.ultraThinMaterial, in: Circle()) 
                    // Removed opacity modifier to keep button visible
                    // Set disabled state based on test running or wrong enrollment state
                    .disabled(isTestRunning || !(cameraManager.enrollmentState == .enrollmentComplete || cameraManager.enrollmentState == .enrollmentFailed))
                    // Apply tint dynamically based on active/disabled state
                    .tint( (cameraManager.enrollmentState == .enrollmentComplete || cameraManager.enrollmentState == .enrollmentFailed) && !isTestRunning ? .orange : .gray )
                    .frame(width: 50, height: 50) 

                    // Central Action Button (Takes up remaining space)
                    Button(action: { 
                        handleEnrollmentOrTestButtonTap()
                    }) { 
                        Text(instructionText ?? actionButtonText)
                        .font(.headline)
                        .foregroundColor(instructionTextColor == .green ? .green : .white)
                        .padding() 
                        .frame(maxWidth: .infinity) // Allow to expand
                        .frame(height: 50) // Match icon button height
                        .background(isActionButtonDisabled ? Color.gray.opacity(0.7) : Color.blue) // Adjust disabled look
                        .cornerRadius(15)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(isActionButtonDisabled)
                    .transition(.opacity.animation(.easeInOut))
                    
                    // Share Logs Button (Icon)
                    Button { 
                        shareLogs()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2) // Adjust icon size
                            .padding(10)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    .tint(.secondary)
                    .opacity(isTestRunning ? 0 : 1)
                    .disabled(isTestRunning)
                    .frame(width: 50, height: 50) // Give it a fixed frame

                }
                .padding(.horizontal) // Keep horizontal padding for the HStack
                // Reduced bottom padding, relies more on safe area
                .padding(.bottom, 10) 

            }
            .animation(.easeInOut, value: isTestRunning) // Keep animations
            .animation(.easeInOut, value: testResult)    // Animate changes based on result state
            .animation(.easeInOut, value: enrollmentOutcome) // Animate enrollment outcome changes
            .animation(.easeInOut, value: cameraManager.enrollmentState) // Animate enrollment state changes
        }
        .onDisappear {
            // Clean up resources when view disappears
            cameraManager.stopSession()
            stopTimer()
        }
        // Add onChange modifier to handle enrollment state transitions
        .onChange(of: cameraManager.enrollmentState) { oldValue, newState in
            handleEnrollmentStateChange(newState: newState)
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
        LogManager.shared.log("=== New Test Started ===") // Log start marker
        isTestRunning = true
        testResult = nil
        enrollmentOutcome = nil // Clear enrollment outcome when starting test
        timeRemaining = 5.0
        
        // Reset face detection state and activate test mode using the manager method
        cameraManager.prepareForNewTest()
        
        // Reset the face detector - MOVED into prepareForNewTest
        // cameraManager.faceDetector.resetForNewTest()
        
        // Start timer with 0.1 second intervals for smooth countdown
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            timeRemaining -= 0.1
            
            // Log the flag value being checked
            LogManager.shared.log("Debug Timer Check: currentTestWasSuccessful = \(cameraManager.faceDetector.testResultManager.currentTestWasSuccessful)")
            
            // Check if the *authoritative* result manager has flagged success for this test run
            if cameraManager.faceDetector.testResultManager.currentTestWasSuccessful {
                 // This flag is set only when TestResultManager logs a definitive ✅ LIVE result.
                 testResult = .success
                 stopTest()
             } else if timeRemaining <= 0 {
                  // --- Timeout Condition ---
                  LogManager.shared.log("Debug Timeout: Checking faceWasDetectedThisTest = \(cameraManager.faceWasDetectedThisTest)")
                  if cameraManager.faceWasDetectedThisTest {
                      // Face detected, but failed initial checks. Try fallback.
                      LogManager.shared.log("Debug Timeout: faceWasDetectedThisTest is TRUE. Checking for persisted thresholds...")
                      if cameraManager.persistedThresholds != nil { // Only fallback if user thresholds were active
                          LogManager.shared.log("Info: Test timed out with user thresholds. Performing fallback check...")
                          if cameraManager.performHardcodedFallbackCheck() { // Check 3: Fallback passes
                              LogManager.shared.log("Info: Fallback check PASSED.")
                              testResult = .fallbackSuccess
                          } else {
                              LogManager.shared.log("Debug: Assigning testResult = .failure (Fallback Failed)")
                              testResult = .fallbackFailure
                              LogManager.shared.log("Info: Fallback check FAILED.")
                          }
                      } else { // User thresholds were NOT active
                          LogManager.shared.log("Debug Timeout: persistedThresholds is NIL.")
                          LogManager.shared.log("Debug: Assigning testResult = .failure (No User Thresholds)")
                          testResult = .failure
                      }
                   } else { // No face detected during test
                      LogManager.shared.log("Debug Timeout: faceWasDetectedThisTest is FALSE.")
                      LogManager.shared.log("Debug: Assigning testResult = .timeout")
                      testResult = .timeout
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
    
    // MARK: - Enrollment Management
    
    private func handleEnrollmentOrTestButtonTap() {
        switch cameraManager.enrollmentState {
        case .notEnrolled, .enrollmentFailed:
            // Start the enrollment process (needs implementation in CameraManager)
            LogManager.shared.log("Starting enrollment process...")
            // Reset outcomes before starting
            testResult = nil
            enrollmentOutcome = nil
            cameraManager.startEnrollmentSequence() // Assuming this method exists/will be added
        case .enrollmentComplete:
            // Start the liveness test
            startTest()
        default:
            // Should not be tappable in other states due to .disabled modifier
            LogManager.shared.log("Warning: Enrollment/Test button tapped in unexpected state: \(cameraManager.enrollmentState.rawValue)")
            break
        }
    }
    
    private func handleEnrollmentStateChange(newState: EnrollmentState) {
        // Clear results when enrollment starts or progresses
        if [.promptCenter, .capturingCenter,
            .promptCloser, .capturingCloserMovement,
            .promptFurther, .capturingFurtherMovement,
            .calculatingThresholds].contains(newState) {
            if testResult != nil || enrollmentOutcome != nil {
                 testResult = nil
                 enrollmentOutcome = nil
                 LogManager.shared.log("Cleared previous results as enrollment is active.")
            }
        }
        
        // Set outcome when enrollment finishes
        switch newState {
        case .enrollmentComplete:
            enrollmentOutcome = .success
            LogManager.shared.log("Enrollment completed successfully.")
        case .enrollmentFailed:
            enrollmentOutcome = .failure
            LogManager.shared.log("Enrollment failed.")
        default:
            // No outcome change needed for other states
            break
        }
    }
    
    // MARK: - Log Sharing
    
    private func shareLogs() {
        let logString = LogManager.shared.getLogsAsString()

        guard !logString.isEmpty else {
            LogManager.shared.log("Share Logs attempted, but no logs found.")
            // TODO: Optionally show an alert to the user that logs are empty
            return
        }
        
        LogManager.shared.log("Presenting share sheet for logs.")

        let activityViewController = UIActivityViewController(activityItems: [logString], applicationActivities: nil)

        // Find the key window scene to present the activity view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, 
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            LogManager.shared.log("Error: Could not find root view controller to present share sheet.")
            return
        }

        // Ensure presentation happens on the main thread
        DispatchQueue.main.async {
            // Handle iPad popover presentation
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = rootViewController.view
                // Center the popover source rect
                popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                                    y: rootViewController.view.bounds.midY, 
                                                    width: 0, height: 0)
                popoverController.permittedArrowDirections = [] // No arrow for centered popover
            }
            
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
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
        case .fallbackSuccess:
            return "Real Face Detected (Fallback)" // More descriptive text
        case .fallbackFailure:
            return "Spoof Detected (Fallback)" // More descriptive text
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
        case .fallbackSuccess:
            return Color.orange // Use orange to indicate it wasn't a standard success
        case .fallbackFailure:
            return Color.orange.opacity(0.8) // Use dark orange for fallback failure?
        }
    }
    
    // MARK: - Enrollment Outcome Formatting
    
    /**
     * Returns the appropriate text to display for an enrollment outcome.
     */
    private func enrollmentOutcomeText(for outcome: EnrollmentOutcome) -> String {
        switch outcome {
        case .success:
            return "Enrollment Complete!"
        case .failure:
            return "Enrollment Failed. Please try again."
        }
    }
    
    /**
     * Returns the appropriate background color for an enrollment outcome display.
     */
    private func enrollmentOutcomeBackground(for outcome: EnrollmentOutcome) -> Color {
        switch outcome {
        case .success:
            return Color.green
        case .failure:
            return Color.red
        }
    }
}

#Preview {
    ContentView()
}
