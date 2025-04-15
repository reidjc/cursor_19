# Enrollment Refactoring Plan: Distance Variation

**Goal:** Refactor the existing user enrollment process to capture depth data based on varying the face-to-phone distance while the user maintains a forward-facing pose. This replaces the previous multi-pose (Left, Right, Up, Down) capture sequence. The system will still calculate a single set of fixed `UserDepthThresholds`.

**Rationale:** Simplify the user experience during enrollment while still capturing data across a range of operational distances to establish robust liveness thresholds.

---

## Implementation Steps

**Phase 1: Modify Enrollment States and Sequence**

1.  **Update `EnrollmentState` Enum:**
    *   **Action:** Modify the `EnrollmentState` enum in `CameraManager.swift`. Remove states related to Left, Right, Up, Down captures. Add states for capturing during closer/further movement.
    *   **Specific Changes:**
        *   Remove: `.promptLeft`, `.capturingLeft`, `.promptRight`, `.capturingRight`, `.promptUp`, `.capturingUp`, `.promptDown`, `.capturingDown`.
        *   Keep/Modify: `.notEnrolled`, `.promptCenter` (initial pose), `.capturingCenter` (initial stable pose), `.promptCloser` (instruction), `.capturingCloserMovement` (new capture state), `.promptFurther` (instruction), `.capturingFurtherMovement` (new capture state), `.calculatingThresholds`, `.enrollmentComplete`, `.enrollmentFailed`.
    *   **Testing:** Code review. Ensure the enum compiles and reflects the intended states.

2.  **Update Enrollment Sequence:**
    *   **Action:** Modify the `enrollmentSequence` constant array in `CameraManager.swift` to reflect the new state flow.
    *   **Specific Changes:** Define the new sequence, for example:
        ```swift
        private let enrollmentSequence: [EnrollmentState] = [
            .promptCenter,          // Initial prompt
            .capturingCenter,       // Capture stable center pose (optional, but potentially good baseline)
            .promptCloser,          // Instruct to move closer
            .capturingCloserMovement, // Capture while moving closer
            .promptFurther,         // Instruct to move further
            .capturingFurtherMovement,// Capture while moving further
            .calculatingThresholds  // Final step
        ]
        ```
        *(Consider if a return-to-center step is needed between closer/further)*
    *   **Testing:** Code review. Verify the sequence logically follows the new desired flow.

**Phase 2: Update UI and Data Capture Logic**

3.  **Adapt UI Prompts (`ContentView.swift`):**
    *   **Action:** Modify the UI logic in `ContentView.swift` (specifically where it displays instructions based on `cameraManager.enrollmentState`) to show appropriate text for the *new* states (`.promptCloser`, `.promptFurther`, `.capturingCloserMovement`, `.capturingFurtherMovement`).
    *   **Specific Changes:** Update the `switch` statement or conditional logic that sets the instruction text. Examples:
        *   `.promptCloser`: "Slowly move phone closer to your face."
        *   `.capturingCloserMovement`: "Capturing data... Keep moving closer."
        *   `.promptFurther`: "Now slowly move phone further away."
        *   `.capturingFurtherMovement`: "Capturing data... Keep moving further."
    *   **Testing:** Manually trigger enrollment. Observe the instruction text displayed on screen. Step through the states (using debug controls or by letting it run) and verify the correct prompts appear for each new state in the sequence.

4.  **Modify Data Capture Trigger (`CameraManager.swift`):**
    *   **Action:** Update the condition in `CameraManager.captureOutput(_:didOutput:from:)` (within the `performDepthAnalysis` block) that decides *when* to store `LivenessCheckResults` for enrollment.
    *   **Specific Changes:** Change the check from the old `.capturing...` states to the *new* states: `.capturingCenter` (if kept), `.capturingCloserMovement`, and `.capturingFurtherMovement`.
        ```swift
        // Inside performDepthAnalysis...
        let shouldProcessForEnrollment = [.capturingCenter, .capturingCloserMovement, .capturingFurtherMovement].contains(currentPoseState) && self.faceDetected
        
        if shouldProcessForEnrollment {
            // ... existing logic to append checkResults to capturedEnrollmentData ...
        }
        ```
    *   **Testing:** Add temporary logging inside the `if shouldProcessForEnrollment` block. Run enrollment. Verify that logs indicating data capture only appear during the `.capturingCenter`, `.capturingCloserMovement`, and `.capturingFurtherMovement` states when a face is detected.

5.  **Adjust Frame Collection Logic (`CameraManager.swift`):**
    *   **Action:** Review the logic that advances the enrollment state after enough frames are collected (`if capturedCount >= self.framesNeededPerPose`). Decide if the *same* number of frames (`framesNeededPerPose`) is appropriate for the *movement* phases, or if it should be time-based or require a different count. For simplicity, start by keeping `framesNeededPerPose` but apply it to the new movement states. Ensure the timeout logic still functions correctly for these new states.
    *   **Specific Changes:** Confirm the existing frame counting and state advancement logic correctly uses the `capturedEnrollmentData` dictionary keys corresponding to the new states (`.capturingCenter`, `.capturingCloserMovement`, `.capturingFurtherMovement`). No structural change might be needed here if the state names are updated correctly in step 4. *Consider adding a minimum duration for movement states instead of just frame count.*
    *   **Testing:** Add logging just before `advanceEnrollmentState()` is called due to frame count being met. Run enrollment. Verify that the state advances automatically from `.capturingCenter` -> `.promptCloser` (or next step), `.capturingCloserMovement` -> `.promptFurther`, and `.capturingFurtherMovement` -> `.calculatingThresholds` after the required number of frames (or duration) is captured for each respective state. Test the timeout by obscuring the camera during a capture phase – verify it transitions to `.enrollmentFailed`.

**Phase 3: Adapt Threshold Calculation**

6.  **Modify Threshold Calculation Input (`CameraManager.swift`):**
    *   **Action:** Update the `calculateThresholds()` function to use the data collected during the new capture states. Instead of relying on specific `.capturingCenter`, `.capturingCloser`, `.capturingFurther` keys, it should now gather data from the keys corresponding to the states used in the refactored capture (e.g., `.capturingCenter`, `.capturingCloserMovement`, `.capturingFurtherMovement`).
    *   **Specific Changes:** Modify the lines where `capturedEnrollmentData` is accessed at the beginning of `calculateThresholds()`:
        ```swift
        enrollmentDataLock.lock()
        // Get data from the states where capture actually happened in the new sequence
        let centerResults = capturedEnrollmentData[.capturingCenter] ?? [] // If kept
        let closerMovementResults = capturedEnrollmentData[.capturingCloserMovement] ?? []
        let furtherMovementResults = capturedEnrollmentData[.capturingFurtherMovement] ?? []
        enrollmentDataLock.unlock()

        LogManager.shared.log("Starting threshold calculation with Center: \(centerResults.count), Closer Movement: \(closerMovementResults.count), Further Movement: \(furtherMovementResults.count) frames.")

        // --- Combine all valid results for analysis ---
        var allCombinedResults: [LivenessCheckResults] = []
        // Add results if they meet minimum frame counts (adjust minFramesPerPose if needed)
        let minFramesRequired = 3 // Or adjust as needed
        if centerResults.count >= minFramesRequired { allCombinedResults.append(contentsOf: centerResults) }
        if closerMovementResults.count >= minFramesRequired { allCombinedResults.append(contentsOf: closerMovementResults) }
        if furtherMovementResults.count >= minFramesRequired { allCombinedResults.append(contentsOf: furtherMovementResults) }

        guard !allCombinedResults.isEmpty else {
            LogManager.shared.log("Error: Insufficient valid data captured across movement phases.")
            return nil
        }
        
        // --- The rest of the calculation logic (calculating stats on allCombinedResults, deriving thresholds, clamping) can likely remain the same ---
        // ... calculate allMeans, allStdDevs, etc. from allCombinedResults ...
        // ... calculate final thresholds (minMeanDepth, maxMeanDepth, minStdDev, etc.) ...
        ```
    *   **Testing:** Add logging within `calculateThresholds` to output:
        *   The counts of frames retrieved for each relevant state (`centerResults.count`, etc.).
        *   The total number of frames in `allCombinedResults`.
        *   The final calculated `UserDepthThresholds` values.
        Complete the new enrollment process successfully. Check the logs to verify that data from the movement phases was included and that the calculated thresholds seem plausible (e.g., reasonable min/max values). Reset and re-enroll under slightly different lighting or distance ranges and observe how the thresholds change.

**Phase 4: Final Testing and Validation**

7.  **End-to-End Enrollment Test:**
    *   **Action:** Perform the complete enrollment flow using the modified process.
    *   **Testing:**
        *   Start the app with no prior enrollment. Verify the "Start Enrollment" button appears.
        *   Tap the button. Follow the prompts (Center, Move Closer, Move Further). Verify the UI text updates correctly.
        *   Observe the capture indicators (if any). Ensure the process flows smoothly between states.
        *   Verify it reaches the `.calculatingThresholds` state and then `.enrollmentComplete`. Note the success message.
        *   Close and reopen the app. Verify the "Start Liveness Test" button appears (indicating successful loading of saved thresholds).

8.  **Liveness Test Post-Enrollment:**
    *   **Action:** Perform a liveness test using the newly calculated thresholds.
    *   **Testing:**
        *   Tap "Start Liveness Test".
        *   Position face at various distances (within the enrolled range). Verify the test passes ("Real Face Detected"). Add logging inside `LivenessChecker` temporarily to confirm it's using the *user* thresholds.
        *   Test with a simple spoof (e.g., a phone displaying a static photo of the enrolled user). Verify the test fails ("Spoof Detected" or similar). Ensure the fallback mechanism (if still desired) works correctly.
        *   Test edge cases: What happens if the user is too close or too far during the test compared to enrollment? Does it fail correctly?

9.  **Reset Enrollment Test:**
    *   **Action:** Test the enrollment reset functionality.
    *   **Testing:**
        *   Find and use the "Reset Enrollment" button/mechanism.
        *   Verify that `UserDefaults` data is cleared (via logging or observing app state).
        *   Close and reopen the app. Verify the "Start Enrollment" button reappears.

---

This detailed plan provides discrete steps for refactoring the enrollment process and includes specific manual testing procedures for each stage to ensure the changes are implemented correctly and the system behaves as expected. 