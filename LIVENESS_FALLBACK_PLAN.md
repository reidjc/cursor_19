# Liveness Test Challenge/Response Fallback Implementation Plan

## 1. Goal

Replace the current liveness test fallback mechanism (hardcoded depth thresholds) in the `cursor_19` project with a challenge/response mechanism. This new mechanism will randomly prompt the user to "Turn Left" or "Turn Right" and track head movement to verify liveness if the primary user-specific depth threshold checks fail within the initial 5-second window. The core logic for challenge processing will be adapted from the Android `liveness` project found within this workspace.

## 2. Background

Currently, `cursor_19` performs liveness detection as follows:
1.  Uses personalized depth thresholds (calculated during enrollment) for 5 seconds.
2.  If successful, the test passes.
3.  If unsuccessful after 5 seconds *and* a face was detected:
    *   It re-runs checks on the last captured frame using hardcoded depth thresholds.
    *   The result depends on this fallback check.
4.  If no face was detected, it fails.

This plan replaces step 3.a with the challenge/response flow.

## 3. Proposed Challenge/Response Mechanism

If the initial depth checks (using personalized thresholds) fail after 5 seconds but a face *was* detected, the following challenge/response fallback will be initiated:

### 3.1. Challenge Selection
*   Randomly select either "Turn Left" or "Turn Right" as the challenge.
*   Display the instruction clearly to the user (e.g., "Turn Head Left", "Turn Head Right").

### 3.2. Head Pose Tracking (Yaw)
*   Continuously track the user's head yaw angle using the appropriate iOS framework (`ARKit` `ARFaceAnchor.transform` or `Vision` `VNFaceObservation.yaw`). Determine which source is currently used or best suited in `cursor_19`.
*   **Assumption:** The chosen framework provides reliable yaw updates frequently enough for this interaction. Angles might need conversion (e.g., radians to degrees). MLKit uses degrees, where positive yaw often corresponds to the user turning their head left. This needs verification in the iOS context.

### 3.3. State Machine & Timeout
*   A state machine will manage the challenge process: `Idle`, `ChallengeIssued`, `Tracking`, `Success`, `Fail`, `Timeout`.
*   A timer (e.g., 10 seconds, based on the Android `liveness` project) will start when the challenge is issued.

### 3.4. Success Criteria (Adapted from `liveness/FaceProcessor.kt`)
The system tracks the yaw angle through three phases based on the challenge direction:
*   **Target Thresholds (Degrees - adapt if necessary):**
    *   `TurnLeft`: P1 uses +5°, P2 uses +25°
    *   `TurnRight`: P1 uses -5°, P2 uses -25°
    *   P3 uses the P1 threshold for the return direction.
*   **Phase Detection Logic (Based on `FaceProcessor.kt`):**
    1.  **P1 (Initial State):** Detects when the head is initially somewhat centered *before* the main turn.
        *   `TurnLeft`: Detected when yaw is **< +5°**.
        *   `TurnRight`: Detected when yaw is **> -5°**.
    2.  **P2 (Full Turn):** Detects when the head has turned significantly in the correct direction.
        *   `TurnLeft`: Detected when yaw is **> +25°** (after P1).
        *   `TurnRight`: Detected when yaw is **< -25°** (after P1).
    3.  **P3 (Return Towards Center):** Detects when the head starts turning back towards the center, crossing the initial threshold again.
        *   `TurnLeft`: Detected when yaw is **< +5°** (after P2).
        *   `TurnRight`: Detected when yaw is **> -5°** (after P2).
*   **Data Collection:** Record the sequence of yaw angles between P1->P2 and P2->P3.
*   **Verification Checks (after P3 detected):**
    1.  **Non-Static Check:** Ensure the sorted lists of angles from P1->P2 and P2->P3 are not identical.
    2.  **Direction Check:** Verify the angle sequence generally moved in the correct direction during each phase.
    3.  **Movement Dynamics Check:** Calculate the average angle change between frames for P1->P2 and P2->P3. Ensure these average changes are distinct.
*   **Result:** If P1, P2, P3 are detected sequentially and all verification checks pass before the timeout, the challenge result is `Success`.

### 3.5. Failure Conditions
The challenge results in `Failure` if:
*   The 10-second timer expires before success criteria are met (`Timeout`).
*   The user turns the wrong way (P1/P2 detected for the opposite direction).
*   The user doesn't turn enough (P2 never detected).
*   The user turns correctly but doesn't return towards center (P3 never detected).
*   The final verification checks on the angle arrays fail.
*   Face tracking is lost during the challenge.

## 4. Assumptions
*   `cursor_19` can reliably access and process head yaw angle data from `ARKit` or `Vision` during the liveness test phase.
*   The performance overhead of continuous yaw tracking during the fallback phase is acceptable.
*   Yaw angle interpretation (degrees vs. radians, sign convention for left/right) from the chosen iOS framework can be determined and aligned with the logic.

## 5. Implementation & Testing Phases (PoC)

This implementation will proceed in phases, with manual testing after each phase to validate functionality before proceeding.

### Phase 1: Yaw Data Acquisition & Validation

**Implementation:**
1.  Investigate `cursor_19`'s `ViewController`, `LivenessChecker`, or related classes (`ARSessionDelegate` / `Vision` handlers) to confirm how/if head pose (specifically yaw) is currently accessed.
2.  If not available, implement yaw tracking using `ARKit` (`ARFaceAnchor.transform`) or `Vision` (`VNDetectFaceRectanglesRequest` + `VNFaceObservation`). Prefer `ARKit` if already in use for depth data.
3.  Determine the yaw angle unit (radians/degrees) and sign convention provided by the chosen framework. Add conversion to degrees if necessary, ensuring positive degrees mean head turned left (user's perspective) and negative means head turned right, consistent with the planned logic.
4.  Temporarily log the calculated yaw angle to the console during the liveness test phase.

**Manual Testing (Phase 1):**
1.  Build and run the app on a device.
2.  Start the liveness test.
3.  Observe the console logs.
4.  Turn your head left: Verify that the logged yaw angle increases (becomes more positive).
5.  Turn your head right: Verify that the logged yaw angle decreases (becomes more negative).
6.  Look straight ahead: Verify the logged yaw angle is close to 0.
7.  Confirm the angles are logged frequently and appear stable.

### Phase 2: Core Challenge Logic Implementation

**Implementation:**
1.  Create Swift equivalents for the Android `ChallengeType` enum (with only `.turnLeft`, `.turnRight`) and the `ChallengeState` data structure (to track `p1Detected`, `p2Detected`, `p3Detected`, `p1p2Array`, `p2p3Array`, `passed`, etc.).
2.  Create a new Swift class: `HeadTurnChallengeProcessor`.
3.  Port the core logic from the Android `liveness` project's `FaceProcessor.handleHeadChallenge` and its helper functions (`areArraysIdenticallyOrdered`, `isArrayDirectionallyCorrect`, `averageDifference`) into `HeadTurnChallengeProcessor`. Adapt for Swift syntax.
4.  Implement methods in `HeadTurnChallengeProcessor`:
    *   `startChallenge(type: ChallengeType)`: Resets state and sets the target challenge.
    *   `process(yaw: Float)` -> `ChallengeResult?`: Takes a yaw angle (in degrees, matching Phase 1's output), updates the internal state machine (P1/P2/P3 detection, array population), performs verification checks if P3 is reached, and returns `.pass`, `.fail`, or `nil` (ongoing). Define a simple `ChallengeResult` enum (`pass`, `fail`, `inProgress`, `timeout`).
    *   `reset()`: Clears the state.

**Manual Testing (Phase 2):**
*   **Requires temporary test harness code:** Add temporary buttons or controls in the UI to:
    *   Trigger `startChallenge(.turnLeft)` or `startChallenge(.turnRight)` on the processor instance.
    *   Manually input yaw angle values (e.g., via a slider or text field) and feed them to `process(yaw:)`.
    *   Display the result (`pass`, `fail`, `inProgress`) returned by `process(yaw:)`.
    *   Display the internal state (P1/P2/P3 detected, array contents).
*   **Test Scenarios:**
    1.  **Turn Left Success:** Start `turnLeft`. Input yaw sequence: 0, -2, 3 (P1 detected), 10, 20, 26 (P2 detected), 15, 10, 4 (P3 detected). Verify result becomes `.pass`. Check arrays for reasonable content and verification logic outcome.
    2.  **Turn Right Success:** Start `turnRight`. Input yaw sequence: 0, 2, -3 (P1 detected), -10, -20, -28 (P2 detected), -15, -10, -4 (P3 detected). Verify result becomes `.pass`.
    3.  **Failure (Wrong Turn):** Start `turnLeft`. Input yaw sequence: 0, -10, -20. Verify result remains `inProgress` or potentially transitions to a specific `.fail(reason: .wrongDirection)` state if implemented.
    4.  **Failure (Insufficient Turn):** Start `turnLeft`. Input yaw sequence: 0, 5, 10, 15, 10, 5. Verify P2 is never detected, result remains `inProgress`. (Timeout would handle this in full integration).
    5.  **Failure (No Return):** Start `turnLeft`. Input yaw sequence: 0, 5, 10, 28, 30, 28. Verify P3 is never detected, result remains `inProgress`.
    6.  **Failure (Static Pose):** Start `turnLeft`. Input sequence simulating holding the head steady after P1, P2, or P3. Verify verification checks fail (e.g., identical sorted arrays, non-distinct average differences).

### Phase 3: Integration into Liveness Flow & UI

**Implementation:**
1.  Remove temporary logging and test harnesses from Phase 1 & 2.
2.  Instantiate `HeadTurnChallengeProcessor` within the appropriate class managing the liveness test (`LivenessChecker` or `TestResultManager`).
3.  Modify the liveness test state machine: Add states like `fallbackChallengeInstructing`, `fallbackChallengeTracking`.
4.  Integrate the challenge trigger: In the logic where the fallback to hardcoded thresholds currently occurs (after 5s timeout with face detected):
    *   Randomly select `ChallengeType.turnLeft` or `.turnRight`.
    *   Call `HeadTurnChallengeProcessor.startChallenge(type:)`.
    *   Start a 10-second challenge timer.
    *   Update the UI to display the instruction ("Turn Head Left" / "Turn Head Right").
    *   Transition state to `fallbackChallengeInstructing` (allow a brief moment for user to read). Then transition to `fallbackChallengeTracking`.
5.  Integrate yaw processing: In the main frame processing loop (`ARSessionDelegate` / `Vision` handler):
    *   If in `fallbackChallengeTracking` state:
        *   Get the yaw angle (from Phase 1 work).
        *   Feed it to `HeadTurnChallengeProcessor.process(yaw:)`.
        *   Handle the result:
            *   If `.pass`: Stop timer, update UI ("Success!"), set final liveness result to `success`, transition out of fallback states.
            *   If `.fail`: Stop timer, update UI ("Challenge Failed"), set final liveness result to `failure`/`spoof`, transition out.
            *   If `nil` / `.inProgress`: Continue.
        *   Check the 10s timer; if expired: Call `HeadTurnChallengeProcessor.reset()`, stop timer, update UI ("Timeout"), set final liveness result to `failure`/`spoof`, transition out.
        *   Handle face tracking loss: If the underlying face tracking fails during the challenge, treat as `.fail`.
6.  UI Updates:
    *   Implement the actual `UILabel` or view to show challenge instructions.
    *   Implement UI feedback for challenge success, failure, or timeout.

**Manual Testing (Phase 3):**
1.  Perform the liveness test enrollment if needed (to use personalized thresholds initially).
2.  Start the liveness test.
3.  **Deliberately fail the initial depth check:** Hold the device still or use a method known to fail the depth checks but keep the face detected (e.g., presenting a photo *if* the depth check is the primary differentiator). Verify the fallback challenge is triggered after 5 seconds.
4.  Observe the UI instruction ("Turn Head Left" or "Turn Head Right").
5.  **Test Success:** Perform the requested head turn correctly (turn, then return towards center) within 10 seconds. Verify the UI shows "Success!" and the final test result is positive. Repeat for both Left and Right challenges.
6.  **Test Failure (Timeout):** Trigger the challenge but do not move your head. Verify the UI shows "Timeout" or "Failed" after 10 seconds and the final test result is negative.
7.  **Test Failure (Wrong Turn):** Trigger "Turn Left", but turn your head right. Verify the UI shows "Challenge Failed" and the final test result is negative. Repeat for the "Turn Right" challenge.
8.  **Test Failure (Insufficient Turn):** Trigger "Turn Left", but only turn slightly (e.g., 10 degrees) and return. Verify the UI shows "Challenge Failed" (likely via timeout in this PoC) and the final test result is negative.
9.  **Test Failure (No Return):** Trigger "Turn Left", turn fully (>25 degrees), but *keep* your head turned. Verify the UI shows "Timeout" or "Failed" after 10 seconds and the final test result is negative.
10. **Test Face Loss:** Trigger the challenge, start turning, then move the phone so the face is no longer detected. Verify the challenge fails immediately.
11. Observe overall flow and UI responsiveness.

## 6. Build Steps

*   Build the `cursor_19` project using Xcode as usual.
*   Ensure any new Swift files (`HeadTurnChallengeProcessor`, etc.) are added to the target membership.

// Delete the following section entirely:
// ## 7. Testing Strategy ... (all content within this section) 