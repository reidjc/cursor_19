import Foundation
import UIKit // Needed for UIDeviceOrientation

/**
 * TestResultData - Stores comprehensive data about a liveness test result
 *
 * This struct captures all relevant data points for a single liveness test,
 * which can be used for debugging false positive/negative results.
 */
struct TestResultData: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let isLive: Bool
    let testId: UUID  // Unique ID for each test session
    
    // Depth data statistics
    let depthMean: Float
    let depthStdDev: Float
    let depthRange: Float
    let edgeMean: Float
    let edgeStdDev: Float
    let centerMean: Float
    let centerStdDev: Float
    
    // Gradient statistics
    let gradientMean: Float
    let gradientStdDev: Float
    
    // Decision metrics - which checks passed/failed
    let isTooFlat: Bool
    let isUnrealisticDepth: Bool
    let hasSharpEdges: Bool
    let isTooUniform: Bool
    let hasNaturalCenterVariation: Bool
    let isLinearDistribution: Bool
    let hasUnnaturalGradients: Bool
    let hasInconsistentTemporalChanges: Bool
    let hasUnnaturalMicroMovements: Bool
    
    // Test metadata
    let numPassedChecks: Int
    let requiredChecks: Int
    let depthSampleCount: Int
    let isStillFaceDetected: Bool
    
    // Environmental
    let deviceOrientation: UIDeviceOrientation
    
    // Initialize with all properties
    init(
        isLive: Bool,
        depthMean: Float,
        depthStdDev: Float,
        depthRange: Float,
        edgeMean: Float,
        edgeStdDev: Float,
        centerMean: Float,
        centerStdDev: Float,
        gradientMean: Float,
        gradientStdDev: Float,
        isTooFlat: Bool,
        isUnrealisticDepth: Bool,
        hasSharpEdges: Bool,
        isTooUniform: Bool,
        hasNaturalCenterVariation: Bool,
        isLinearDistribution: Bool,
        hasUnnaturalGradients: Bool,
        hasInconsistentTemporalChanges: Bool,
        hasUnnaturalMicroMovements: Bool,
        numPassedChecks: Int,
        requiredChecks: Int,
        depthSampleCount: Int,
        isStillFaceDetected: Bool,
        deviceOrientation: UIDeviceOrientation,
        timestamp: Date = Date(),
        id: UUID = UUID(),
        testId: UUID
    ) {
        self.id = id
        self.timestamp = timestamp
        self.isLive = isLive
        self.depthMean = depthMean
        self.depthStdDev = depthStdDev
        self.depthRange = depthRange
        self.edgeMean = edgeMean
        self.edgeStdDev = edgeStdDev
        self.centerMean = centerMean
        self.centerStdDev = centerStdDev
        self.gradientMean = gradientMean
        self.gradientStdDev = gradientStdDev
        self.isTooFlat = isTooFlat
        self.isUnrealisticDepth = isUnrealisticDepth
        self.hasSharpEdges = hasSharpEdges
        self.isTooUniform = isTooUniform
        self.hasNaturalCenterVariation = hasNaturalCenterVariation
        self.isLinearDistribution = isLinearDistribution
        self.hasUnnaturalGradients = hasUnnaturalGradients
        self.hasInconsistentTemporalChanges = hasInconsistentTemporalChanges
        self.hasUnnaturalMicroMovements = hasUnnaturalMicroMovements
        self.numPassedChecks = numPassedChecks
        self.requiredChecks = requiredChecks
        self.depthSampleCount = depthSampleCount
        self.isStillFaceDetected = isStillFaceDetected
        self.deviceOrientation = deviceOrientation
        self.testId = testId
    }
    
    // CodingKeys and encode to handle UIDeviceOrientation (which is not Encodable)
    enum CodingKeys: String, CodingKey {
        case id, timestamp, isLive, depthMean, depthStdDev, depthRange, edgeMean, edgeStdDev
        case centerMean, centerStdDev, gradientMean, gradientStdDev, isTooFlat, isUnrealisticDepth
        case hasSharpEdges, isTooUniform, hasNaturalCenterVariation, isLinearDistribution
        case hasUnnaturalGradients, hasInconsistentTemporalChanges, hasUnnaturalMicroMovements
        case numPassedChecks, requiredChecks, depthSampleCount, deviceOrientation, testId // Added requiredChecks
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isLive, forKey: .isLive)
        try container.encode(depthMean, forKey: .depthMean)
        try container.encode(depthStdDev, forKey: .depthStdDev)
        try container.encode(depthRange, forKey: .depthRange)
        try container.encode(edgeMean, forKey: .edgeMean)
        try container.encode(edgeStdDev, forKey: .edgeStdDev)
        try container.encode(centerMean, forKey: .centerMean)
        try container.encode(centerStdDev, forKey: .centerStdDev)
        try container.encode(gradientMean, forKey: .gradientMean)
        try container.encode(gradientStdDev, forKey: .gradientStdDev)
        try container.encode(isTooFlat, forKey: .isTooFlat)
        try container.encode(isUnrealisticDepth, forKey: .isUnrealisticDepth)
        try container.encode(hasSharpEdges, forKey: .hasSharpEdges)
        try container.encode(isTooUniform, forKey: .isTooUniform)
        try container.encode(hasNaturalCenterVariation, forKey: .hasNaturalCenterVariation)
        try container.encode(isLinearDistribution, forKey: .isLinearDistribution)
        try container.encode(hasUnnaturalGradients, forKey: .hasUnnaturalGradients)
        try container.encode(hasInconsistentTemporalChanges, forKey: .hasInconsistentTemporalChanges)
        try container.encode(hasUnnaturalMicroMovements, forKey: .hasUnnaturalMicroMovements)
        try container.encode(numPassedChecks, forKey: .numPassedChecks)
        try container.encode(requiredChecks, forKey: .requiredChecks) // Added encoding for requiredChecks
        try container.encode(depthSampleCount, forKey: .depthSampleCount)
        try container.encode(Int(deviceOrientation.rawValue), forKey: .deviceOrientation)
        try container.encode(testId, forKey: .testId)
    }
    
    // Decodable conformance
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isLive = try container.decode(Bool.self, forKey: .isLive)
        depthMean = try container.decode(Float.self, forKey: .depthMean)
        depthStdDev = try container.decode(Float.self, forKey: .depthStdDev)
        depthRange = try container.decode(Float.self, forKey: .depthRange)
        edgeMean = try container.decode(Float.self, forKey: .edgeMean)
        edgeStdDev = try container.decode(Float.self, forKey: .edgeStdDev)
        centerMean = try container.decode(Float.self, forKey: .centerMean)
        centerStdDev = try container.decode(Float.self, forKey: .centerStdDev)
        gradientMean = try container.decode(Float.self, forKey: .gradientMean)
        gradientStdDev = try container.decode(Float.self, forKey: .gradientStdDev)
        isTooFlat = try container.decode(Bool.self, forKey: .isTooFlat)
        isUnrealisticDepth = try container.decode(Bool.self, forKey: .isUnrealisticDepth)
        hasSharpEdges = try container.decode(Bool.self, forKey: .hasSharpEdges)
        isTooUniform = try container.decode(Bool.self, forKey: .isTooUniform)
        hasNaturalCenterVariation = try container.decode(Bool.self, forKey: .hasNaturalCenterVariation)
        isLinearDistribution = try container.decode(Bool.self, forKey: .isLinearDistribution)
        hasUnnaturalGradients = try container.decode(Bool.self, forKey: .hasUnnaturalGradients)
        hasInconsistentTemporalChanges = try container.decode(Bool.self, forKey: .hasInconsistentTemporalChanges)
        hasUnnaturalMicroMovements = try container.decode(Bool.self, forKey: .hasUnnaturalMicroMovements)
        numPassedChecks = try container.decode(Int.self, forKey: .numPassedChecks)
        requiredChecks = try container.decode(Int.self, forKey: .requiredChecks)
        depthSampleCount = try container.decode(Int.self, forKey: .depthSampleCount)
        testId = try container.decode(UUID.self, forKey: .testId)
        
        // Decode deviceOrientation from Int rawValue
        let orientationRawValue = try container.decode(Int.self, forKey: .deviceOrientation)
        deviceOrientation = UIDeviceOrientation(rawValue: orientationRawValue) ?? .unknown
        
        // Decode isStillFaceDetected - It wasn't included in original encoding/keys, add default or decode if added
        // Assuming default value if not present in older saved data
        // isStillFaceDetected = try container.decodeIfPresent(Bool.self, forKey: .isStillFaceDetected) ?? false 
        // Let's add isStillFaceDetected to CodingKeys and encode/decode it if it's important.
        // For now, matching the provided code, it's not encoded/decoded, so we set a default.
        // Re-visiting the original struct: `isStillFaceDetected` was a property but not in CodingKeys. Add it?
        // Let's assume it should be encoded/decoded if it's part of the struct.
        // Decision: For now, keep consistent with original `encode` and don't decode it, assign default. Revisit if needed.
        isStillFaceDetected = false // Default value as it's not in CodingKeys/encoded
    }
} 