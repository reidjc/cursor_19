# Face Liveness Detection App

A SwiftUI-based iOS application that uses the TrueDepth camera to detect and verify live human faces. The app implements advanced liveness detection algorithms to distinguish between real faces and spoof attempts.

## Features

- Real-time face detection using TrueDepth camera
- Advanced liveness detection with 9 comprehensive checks
- Detailed debug output with statistics and check results
- Test history tracking with timestamps
- Support for both light and dark mode
- Comprehensive error handling and user feedback
- User enrollment and personalized thresholds
- Fallback mechanism if liveness check fails with personalized thresholds
- Spoof detection to reject presentation attacks

## Requirements

- iOS 15.0 or later
- iPhone with TrueDepth camera (iPhone X or newer)
- Xcode 13.0 or later
- Swift 5.5 or later

## Installation

1. Clone the repository
2. Open the project in Xcode
3. Build and run on a compatible device

## Usage

1. Launch the app
2. Grant camera permissions when prompted
3. Position your face within the frame
4. The app will automatically detect your face and perform liveness checks
5. Results will be displayed in real-time with detailed statistics

## Liveness Detection System

The app uses a sophisticated liveness detection system that combines multiple checks to verify that a detected face is real and live. The system requires a minimum of 30 valid depth samples to perform analysis.

### Check Requirements

- **Total Checks**: 9
- **Mandatory Checks**: 4 (must all pass)
- **Optional Checks**: 5 (at least 3 must pass)
- **Minimum Depth Samples**: 30
- **Sampling Grid**: 10x10 points (100 total samples)

### Detailed Check Descriptions

#### Mandatory Checks

1. **Realistic Depth**
   - Purpose: Verifies depth values are within human face range
   - Thresholds:
     - Mean depth between 0.2 and 3.0 meters
   - Why: Ensures the face is at a reasonable distance from the camera

2. **Center Variation**
   - Purpose: Verifies natural depth variation in face center
   - Thresholds:
     - Center standard deviation ≥ 0.005 (*Hardcoded fallback value*)
   - Why: Real faces have natural depth variations in the center region

3. **Edge Variation**
   - Purpose: Checks for natural depth transitions at face edges
   - Thresholds:
     - Edge standard deviation ≥ 0.02 (*Hardcoded fallback value*)
   - Why: Real faces have soft edges, while photos often have sharp edges

4. **Depth Profile**
   - Purpose: Analyzes natural depth profile across the face
   - Thresholds:
     - Standard deviation ≥ 0.02 OR
     - Depth range ≥ 0.05 meters (*Hardcoded fallback values*)
   - Why: Real faces have natural depth profiles, while photos are uniform

#### Optional Checks

1. **Depth Variation**
   - Purpose: Ensures the face has sufficient overall depth variation
   - Thresholds: `stdDev ≥ 0.02` AND `range ≥ 0.05` (*Hardcoded fallback values*). Checks against personalized or hardcoded minimums
   - Why: Real faces have natural depth variations, while photos are typically flat

2. **Depth Distribution**
   - Purpose: Ensures non-linear depth distribution
   - Method: Statistical analysis of depth value distribution
   - Why: Real faces have natural, non-linear depth distributions

3. **Gradient Pattern**
   - Purpose: Checks for natural depth gradient patterns
   - Thresholds: `gradientStdDev ≥ 0.001` AND `gradientMean ≤ 0.5` (*Hardcoded fallback values*). Checks against personalized or hardcoded thresholds
   - Why: Real faces have natural depth gradients

4. **Temporal Consistency**
   - Purpose: Verifies natural temporal changes in depth
   - Method: Analysis of depth changes between frames
   - Why: Real faces show natural, consistent depth changes over time

5. **Natural Micro-movements**
   - Purpose: Detects natural small movements between frames
   - Method: Analysis of gradient pattern changes over time
   - Requirements:
     - Minimum 500ms between samples
     - Up to 10 stored patterns for analysis
   - Why: Real faces show natural micro-movements

### Test Result Requirements

A face is considered "live" if it meets ALL of the following criteria during the test window:
1. Has enough valid depth samples (typically 100 from a 10x10 grid)
2. Passes all 4 mandatory checks
3. Passes at least 3 out of 5 optional checks

*If the above criteria are not met within the time limit using personalized thresholds, a fallback check using hardcoded thresholds is performed on the last frame.*

### Debug Output

The app provides detailed debug information including:
- Depth statistics (mean, standard deviation, range)
- Edge and center variation metrics
- Gradient pattern analysis
- Individual check results
- Micro-movement analysis
- Test history with timestamps

## Technical Details

The system uses `AVFoundation` for camera capture (including depth data) and `Vision` for face detection. Liveness logic resides primarily in `LivenessChecker.swift`, using thresholds calculated in `CameraManager.swift`. Personalized thresholds are stored in `UserDefaults`. Enrollment and test states are managed via `EnrollmentState` enum and UI logic in `ContentView.swift`.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

[Guidelines for contributing to the project]

## Acknowledgments

- Inspired by concepts and best practices for liveness detection discussed in documentation for Google's ML Kit and Apple's Vision framework.
- This project utilizes Apple's Vision framework for face detection.
