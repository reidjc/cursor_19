# Face Liveness Detection App

A SwiftUI-based iOS application that uses the TrueDepth camera to detect and verify live human faces. The app implements advanced liveness detection algorithms to distinguish between real faces and spoof attempts.

## Features

- Real-time face detection using TrueDepth camera
- Advanced liveness detection with 9 comprehensive checks
- Detailed debug output with statistics and check results
- Test history tracking with timestamps
- Support for both light and dark mode
- Comprehensive error handling and user feedback

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
- **Optional Checks**: 5 (at least 4 must pass)
- **Minimum Depth Samples**: 30
- **Sampling Grid**: 10x10 points (100 total samples)

### Detailed Check Descriptions

#### Mandatory Checks

1. **Depth Variation**
   - Purpose: Ensures the face has natural depth variation
   - Thresholds:
     - Standard deviation ≥ 0.15
     - Depth range ≥ 0.3 meters
   - Why: Real faces have natural depth variations, while photos are typically flat

2. **Realistic Depth**
   - Purpose: Verifies depth values are within human face range
   - Thresholds:
     - Mean depth between 0.2 and 3.0 meters
   - Why: Ensures the face is at a reasonable distance from the camera

3. **Edge Variation**
   - Purpose: Checks for natural depth transitions at face edges
   - Thresholds:
     - Edge standard deviation ≥ 0.15
   - Why: Real faces have soft edges, while photos often have sharp edges

4. **Depth Profile**
   - Purpose: Analyzes natural depth profile across the face
   - Thresholds:
     - Standard deviation ≥ 0.2 OR
     - Depth range ≥ 0.4 meters
   - Why: Real faces have natural depth profiles, while photos are uniform

#### Optional Checks

1. **Center Variation**
   - Purpose: Verifies natural depth variation in face center
   - Thresholds:
     - Center standard deviation ≥ 0.1
   - Why: Real faces have natural depth variations in the center region

2. **Depth Distribution**
   - Purpose: Ensures non-linear depth distribution
   - Method: Statistical analysis of depth value distribution
   - Why: Real faces have natural, non-linear depth distributions

3. **Gradient Pattern**
   - Purpose: Checks for natural depth gradient patterns
   - Thresholds:
     - Gradient standard deviation ≥ 0.005
     - Gradient mean ≤ 0.2
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

A face is considered "live" if it meets ALL of the following criteria:
1. Has at least 30 valid depth samples
2. Passes all 4 mandatory checks
3. Passes at least 4 out of 5 optional checks

### Debug Output

The app provides detailed debug information including:
- Depth statistics (mean, standard deviation, range)
- Edge and center variation metrics
- Gradient pattern analysis
- Individual check results
- Micro-movement analysis
- Test history with timestamps

## Technical Details

The liveness detection system uses a combination of mandatory and optional checks:
- Mandatory checks must all pass for a face to be considered live
- At least 4 out of 5 optional checks must pass
- Minimum of 30 depth samples required for analysis
- Real-time processing of depth data at 10x10 sampling grid

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

[Guidelines for contributing to the project]

## Acknowledgments

- Apple for TrueDepth camera and Vision framework APIs
- Google ML Kit documentation for liveness detection concepts 
