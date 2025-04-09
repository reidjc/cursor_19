# Enrollment and Personalized Threshold Implementation Plan

This document outlines the steps to implement a user enrollment process for capturing personalized depth data and calculating custom thresholds for the TrueDepth-based liveness check in the `cursor_19` application.

**Goal:** Improve the accuracy and reliability of the depth-based liveness check across different users by tailoring detection thresholds based on individual facial characteristics captured during enrollment.

**Key Statistics for Thresholds:**
Based on `LivenessChecker.swift`, the following statistics will be captured during enrollment and used to derive personalized thresholds:
*   Mean depth (`mean`)
*   Standard deviation of depth (`stdDev`)
*   Range of depth (`range`)
*   Standard deviation of edge depth values (`edgeStdDev`)
*   Standard deviation of center depth values (`centerStdDev`)
*   Mean of depth gradients (`gradientMean`)
*   Standard deviation of depth gradients (`gradientStdDev`)

---

## Implementation Plan

**Phase 1: Enrollment UI and Data Capture**

1.  **Create Plan Document:** (Completed)
    *   Create a new file named `ENROLLMENT_PLAN.md` in the project root.
    *   Copy this plan into the document for tracking.
    *   *Testing:* Verify the file exists and contains the plan.

2.  **Enrollment State Management:** (Completed)
    *   Define an `enum EnrollmentState` to manage the steps of the enrollment process. Suggested states: `.notEnrolled`, `.promptCenter`, `.capturingCenter`, `.promptLeft`, `.capturingLeft`, `.promptRight`, `.capturingRight`, `.promptUp`, `.capturingUp`, `.promptDown`, `.capturingDown`, `.promptCloser`, `.capturingCloser`, `.promptFurther`, `.capturingFurther`, `.calculatingThresholds`, `.enrollmentComplete`, `.enrollmentFailed`.
    *   Add an `@Published var enrollmentState: EnrollmentState = .notEnrolled` property, likely within `CameraManager` or a new `EnrollmentManager` class. If creating a new manager, ensure `CameraManager` can interact with it.
    *   *Testing:* No direct test yet, this underpins subsequent steps.

3.  **Basic Enrollment UI:** (Completed)
    *   Modify `ContentView.swift` (or the relevant UI view).
    *   When `enrollmentState` is `.notEnrolled`, show an "Start Enrollment" button instead of the usual "Start Test" button.
    *   During enrollment states (`.prompt...`, `.capturing...`), display simple text instructions based on the current `enrollmentState` (e.g., "Look straight ahead", "Turn head left", "Move phone closer"). Keep the rest of the UI (camera preview) the same.
    *   Add a visual indicator (perhaps change text color or add a small icon) during `.capturing...` states.
    *   Display a success or failure message based on the final state (`.enrollmentComplete`, `.enrollmentFailed`).
    *   *Testing:* Manually launch the app. Verify the "Start Enrollment" button appears. Tap it and verify the text prompts change sequentially as you manually advance the state (initially, you might need debug buttons or code to force state transitions).

4.  **Challenge Sequence Logic:** (Completed)
    *   In `CameraManager` (or `EnrollmentManager`), implement the logic to transition through the `EnrollmentState` sequence when the "Start Enrollment" button is tapped.
    *   The sequence should be: Center -> Left -> Center -> Right -> Center -> Up -> Center -> Down -> Center -> Closer -> Center -> Further -> Center -> Calculate -> Complete/Fail. Returning to center between movements helps ensure distinct poses are captured.
    *   For each `.prompt...` state, wait a short duration (e.g., 1-2 seconds) before automatically transitioning to the corresponding `.capturing...` state.
    *   *Testing:* Manually trigger enrollment. Observe the UI prompts automatically cycling through the defined sequence (Center, Left, Right, Up, Down, Closer, Further, with pauses).

5.  **Conditional Data Capture:** (Completed)
    *   Modify the `depthDataOutput` delegate method in `CameraManager.swift`.
    *   Inside the method, check the current `enrollmentState`. Only proceed with depth data processing if the state is one of the `.capturing...` states.
    *   When in a `.capturing...` state, ensure a face is detected (`faceDetected` is true) before processing depth data for enrollment.
    *   Collect multiple (e.g., 5-10) valid depth frames for *each* capturing state (`.capturingCenter`, `.capturingLeft`, etc.).
    *   Store the calculated `LivenessCheckResults` (or at least the key statistics: mean, stdDev, range, edgeStdDev, centerStdDev, gradientMean, gradientStdDev) for each captured frame, grouped by the state they were captured in (e.g., a dictionary `[EnrollmentState: [LivenessCheckResults]]`).
    *   Once enough frames are collected for a given state, automatically transition to the next `.prompt...` state in the sequence. Add timeouts to prevent getting stuck if data isn't captured (transition to `.enrollmentFailed`).
    *   *Testing:* Add logging inside `depthDataOutput` to confirm that:
        *   Data is only processed during `.capturing...` states.
        *   Data is associated with the correct state.
        *   The state transitions automatically after collecting the target number of frames per pose.
        *   Manually obstruct the camera or look away during a capture phase to test the failure/timeout logic.

**Phase 2: Threshold Calculation and Integration**

6.  **Threshold Calculation Strategy:** (Completed - Revised)
    *   Create a new structure, perhaps `UserDepthThresholds: Codable`, to hold the calculated min/max values for each key statistic (e.g., `minCenterStdDev`, `maxCenterStdDev`, `minEdgeStdDev`, etc.).
    *   Implement a function `calculateThresholds(from capturedData: [EnrollmentState: [LivenessCheckResults]]) -> UserDepthThresholds?`.
    *   **Initial Strategy:** (Discarded) Mean +/- k\*stddev across *all* captured poses. Produced counter-intuitive results compared to hardcoded values.
    *   **Revised Strategy (Implemented):** Mean +/- k\*stddev using statistics calculated *only* from data captured during `.capturingCenter` states. Produced more plausible results, but still highlighted potential issues with using mean/stddev for defining minimum required variation.
    *   Call this function when the enrollment sequence reaches the `.calculatingThresholds` state. Transition to `.enrollmentComplete` if successful, `.enrollmentFailed` otherwise.
    *   *Testing:* Add logging to output the captured statistics for each pose and the final calculated `UserDepthThresholds`. Manually inspect these values to see if they seem reasonable (e.g., are the ranges plausible?). Perform the enrollment process multiple times under slightly different conditions (lighting, distance) and see how the thresholds vary.

7.  **Persistence:** (Completed)
    *   Add capability to save the calculated `UserDepthThresholds` to `UserDefaults` (or another persistent store). Use `JSONEncoder` since the struct is `Codable`.
    *   Add capability to load thresholds on app startup. Add a flag or check to see if thresholds exist.
    *   Update the initial state logic: If thresholds are loaded successfully, set `enrollmentState` to `.enrollmentComplete` directly, otherwise set to `.notEnrolled`.
    *   Add a "Reset Enrollment" button somewhere (perhaps in a settings view or debug menu) to clear saved thresholds and allow re-enrollment.
    *   *Testing:* Complete enrollment successfully. Close and reopen the app. Verify enrollment is not required again. Reset enrollment, close and reopen. Verify enrollment *is* required again. Check `UserDefaults` manually (if possible) or add logging to confirm saving/loading.

8.  **Integrate Thresholds into Liveness Check:** (Completed)
    *   Modify `LivenessChecker.swift`. Add a property `var userThresholds: UserDepthThresholds?`.
    *   Update the individual check functions (`hasNaturalDepthVariation`, `hasRealisticDepthRange`, `hasNaturalEdgeVariation`, `hasNaturalCenterVariation`, etc.) to use the values from `userThresholds` if available, otherwise fall back to the original hardcoded values.
    *   In `CameraManager` or `FaceDetector`, ensure the loaded `UserDepthThresholds` are passed to the `LivenessChecker` instance before performing checks.
    *   Update `ContentView` (or relevant UI): If `enrollmentState` is `.enrollmentComplete`, the main button should say "Start Test" and trigger the standard liveness check flow (using the new personalized thresholds).
    *   *Testing:*
        *   Clear enrollment. Run the standard test (it should use hardcoded thresholds). Observe results (likely fails for faces other than the original test subject).
        *   Enroll a *new* face. Run the standard test again. Verify the test now uses the *personalized* thresholds (add logging in `LivenessChecker` to confirm which thresholds are being used). The test should ideally pass more reliably for the newly enrolled face.
        *   Test with spoofs (photos/videos) after enrollment to ensure the personalized thresholds are still effective at rejecting them (i.e., maintain security). Tune the threshold calculation (`k` factor) if necessary.

9.  **Implement Fallback:**
    *   If a standard liveness test (using depth + personalized thresholds) fails, provide an option or automatically trigger a fallback to the challenge/response mechanism (similar to the enrollment flow, but perhaps shorter/simpler, just proving liveness without saving data). This requires adding states to the main testing flow, not just enrollment. (Defer this implementation until the core enrollment and personalized threshold system works well).

10. **Refine Threshold Calculation:**
    *   Based on testing results (especially false positives/negatives across different enrolled users), refine the threshold calculation strategy in step 6. Analyze the collected `TestResultData` for patterns. Maybe certain poses are more critical for specific thresholds? Maybe a weighted average is needed?
    *   **Alternative Strategies to Explore:**
        *   **Combined Pose Data:** Calculate stats for Center, Close, and Far poses separately. Derive final thresholds by taking the min-of-minimums and max-of-maximums across these poses to establish a broader acceptable range that accounts for distance variation without needing a dynamic model.
        *   **Percentile-Based:** Instead of mean/stddev, use percentiles (e.g., 5th percentile for minimums, 95th for maximums) based on the collected data (either center-only or combined).
        *   **Clamping:** Ensure calculated thresholds don't become excessively strict or lenient by clamping them relative to the original hardcoded values (e.g., `finalMin = max(hardcodedMin, calculatedMin)`).
        *   **Distance Scaling Model:** Explicitly model how thresholds should change based on the measured distance during the live test, using the close/center/far enrollment data to define the scaling factor.

--- 