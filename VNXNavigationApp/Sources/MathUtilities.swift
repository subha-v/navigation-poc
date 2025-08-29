import Foundation
import simd

extension FloatingPoint {
    var degreesToRadians: Self { self * .pi / 180 }
    var radiansToDegrees: Self { self * 180 / .pi }
}

func azimuth(from direction: simd_float3) -> Float {
    return asin(direction.x)
}

func elevation(from direction: simd_float3) -> Float {
    return atan2(direction.z, direction.y) + .pi / 2
}

enum DistanceDirectionState {
    case closeUpInFOV
    case notCloseUpInFOV
    case outOfFOV
    case unknown
}