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

## 5. Implementation Steps

1.  **Yaw Data Source:**
    *   Investigate `cursor_19`'s `ViewController`, `LivenessChecker`, or related classes (`ARSessionDelegate` / `Vision` handlers) to confirm how/if head pose (specifically yaw) is currently accessed.
    *   If not available, implement yaw tracking using `ARKit` (`ARFaceAnchor`) or `Vision` (`VNDetectFaceRectanglesRequest` + `VNFaceObservation`). Prefer `ARKit` if already in use for depth data.
    *   Determine the yaw angle unit (radians/degrees) and sign convention. Add conversion if necessary.

2.  **Challenge Logic Implementation:**
    *   Create Swift equivalents for the Android `ChallengeType` enum (with only `.turnLeft`, `.turnRight`) and the `ChallengeState` data structure (to track `p1Detected`, `p2Detected`, `p3Detected`, `p1p2Array`, `p2p3Array`, `passed`, etc.).
    *   Create a new Swift class, e.g., `HeadTurnChallengeProcessor`.
    *   Port the core logic from `FaceProcessor.handleHeadChallenge` and its helper functions (`areArraysIdenticallyOrdered`, `isArrayDirectionallyCorrect`, `averageDifference`) into `HeadTurnChallengeProcessor`. Adapt for Swift syntax and the identified iOS yaw data source.
    *   Implement methods in `HeadTurnChallengeProcessor` like `startChallenge(type: ChallengeType)` and `process(yaw: Float)` -> `ChallengeResult?` (returning `.pass`, `.fail`, or `nil` if ongoing).

3.  **Integration into Liveness Flow:**
    *   Modify the class responsible for the liveness test state (`LivenessChecker` or `TestResultManager`).
    *   Add states for `fallbackChallengeIssued`, `fallbackChallengeTracking`.
    *   In the logic where the fallback to hardcoded thresholds currently happens (after 5s timeout with face detected):
        *   Instead of hardcoded checks, randomly select `ChallengeType.turnLeft` or `.turnRight`.
        *   Instantiate/reset `HeadTurnChallengeProcessor`.
        *   Start the 10-second challenge timer.
        *   Update the UI to display the challenge instruction.
        *   Transition state to `fallbackChallengeIssued`.
    *   In the main frame processing loop (e.g., `ARSessionDelegate` or `Vision` completion handler):
        *   If in `fallbackChallengeIssued` or `fallbackChallengeTracking` state:
            *   Extract the current yaw angle.
            *   Feed it to `HeadTurnChallengeProcessor.process(yaw:)`.
            *   Handle the result:
                *   If `.pass`: Stop timer, update UI (Success), set final liveness result to success.
                *   If `.fail`: Stop timer, update UI (Failed), set final liveness result to failure/spoof.
                *   If `nil`: Continue tracking.
            *   Check the challenge timer; if expired: Update UI (Timeout/Failed), set final liveness result to failure/spoof.
            *   Handle face tracking loss: If face is lost during the challenge, treat as failure.

4.  **UI Updates:**
    *   Modify the `ViewController` or relevant UI code.
    *   Add UI elements (e.g., a `UILabel`) to display challenge instructions ("Turn Head Left", "Turn Head Right").
    *   Update the UI to show challenge status (e.g., progress indicator, success/failure message).

## 6. Build Steps

*   Build the `cursor_19` project using Xcode as usual.
*   Ensure any new Swift files (`HeadTurnChallengeProcessor`, etc.) are added to the target membership.

## 7. Testing Strategy

1.  **Unit Tests:**
    *   Create unit tests for `HeadTurnChallengeProcessor`:
        *   Test P1, P2, P3 detection logic with various yaw sequences and thresholds.
        *   Test the array verification checks (`areArraysIdenticallyOrdered`, `isArrayDirectionallyCorrect`, `averageDifference`) with edge cases (empty arrays, static poses, correct sequences, incorrect sequences).
        *   Test the `process(yaw:)` function for correct state transitions and result reporting.
2.  **Integration Tests:**
    *   Verify the fallback mechanism triggers correctly (only after 5s timeout *with* a face detected using personalized thresholds).
    *   Verify the random selection between "Turn Left" and "Turn Right".
    *   Verify UI updates correctly display instructions and results.
    *   Verify the 10-second timeout triggers a failure.
    *   Verify face loss during the challenge triggers a failure.
    *   Verify the final liveness result is correctly set based on challenge outcome (Pass/Fail/Timeout).
3.  **Manual Tests:**
    *   Perform the liveness test enrollment.
    *   Perform the liveness test and deliberately fail the initial depth check (e.g., hold a photo) to trigger the fallback.
    *   Test completing the "Turn Left" challenge correctly.
    *   Test completing the "Turn Right" challenge correctly.
    *   Test failing by turning the wrong way.
    *   Test failing by not turning enough.
    *   Test failing by turning too slowly (timeout).
    *   Test failing by turning correctly but not returning towards the center.
    *   Test under different lighting conditions.
    *   Test with different devices if possible.
    *   Observe UI feedback throughout the process. 