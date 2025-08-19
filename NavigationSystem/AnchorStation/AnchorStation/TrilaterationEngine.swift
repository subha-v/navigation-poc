//
//  TrilaterationEngine.swift
//  Calculates position using trilateration from multiple anchor measurements
//

import Foundation
import CoreGraphics
import simd

struct AnchorMeasurement {
    let anchorId: String
    let position: CGPoint
    let distance: Float
    let direction: simd_float3?
    let timestamp: Date
}

class TrilaterationEngine {
    private var measurements: [String: AnchorMeasurement] = [:]
    private var lastCalculatedPosition: CGPoint?
    private let settings = AnchorConfiguration.NavigationSettings.self
    
    // Smoothing
    private var positionHistory: [CGPoint] = []
    private let maxHistorySize = 5
    
    func updateMeasurement(anchorId: String, position: CGPoint, distance: Float, direction: simd_float3? = nil) {
        measurements[anchorId] = AnchorMeasurement(
            anchorId: anchorId,
            position: position,
            distance: distance,
            direction: direction,
            timestamp: Date()
        )
        
        // Remove stale measurements (older than 2 seconds)
        let now = Date()
        measurements = measurements.filter { _, measurement in
            now.timeIntervalSince(measurement.timestamp) < 2.0
        }
    }
    
    func calculatePosition() -> CGPoint? {
        // Filter valid measurements within range
        let validMeasurements = measurements.values.filter { measurement in
            measurement.distance <= settings.maxAnchorRange &&
            measurement.distance > 0
        }
        
        // Need at least 3 anchors for trilateration
        guard validMeasurements.count >= settings.minAnchorsForTrilateration else {
            return nil
        }
        
        // Sort by distance and take the closest anchors
        let sortedMeasurements = validMeasurements.sorted { $0.distance < $1.distance }
        let selectedMeasurements = Array(sortedMeasurements.prefix(4)) // Use up to 4 anchors
        
        // Perform trilateration
        var position: CGPoint?
        
        if selectedMeasurements.count >= 3 {
            position = trilateratePosition(measurements: selectedMeasurements)
        }
        
        // Apply NLOS detection
        if let pos = position {
            position = applyNLOSDetection(position: pos, measurements: selectedMeasurements)
        }
        
        // Apply smoothing
        if let pos = position {
            position = smoothPosition(pos)
        }
        
        lastCalculatedPosition = position
        return position
    }
    
    private func trilateratePosition(measurements: [AnchorMeasurement]) -> CGPoint? {
        guard measurements.count >= 3 else { return nil }
        
        // Use weighted least squares for trilateration
        // This is more robust than simple geometric trilateration
        
        let n = measurements.count
        var A = [[Double]](repeating: [Double](repeating: 0, count: 2), count: n-1)
        var b = [Double](repeating: 0, count: n-1)
        
        let ref = measurements[0]
        
        for i in 1..<n {
            let anchor = measurements[i]
            
            // Build system of linear equations
            A[i-1][0] = 2 * (Double(anchor.position.x) - Double(ref.position.x))
            A[i-1][1] = 2 * (Double(anchor.position.y) - Double(ref.position.y))
            
            let d1_sq = Double(ref.distance * ref.distance)
            let d2_sq = Double(anchor.distance * anchor.distance)
            let x1_sq = Double(ref.position.x * ref.position.x)
            let y1_sq = Double(ref.position.y * ref.position.y)
            let x2_sq = Double(anchor.position.x * anchor.position.x)
            let y2_sq = Double(anchor.position.y * anchor.position.y)
            
            b[i-1] = d1_sq - d2_sq - x1_sq - y1_sq + x2_sq + y2_sq
        }
        
        // Solve using least squares
        if let solution = solveLeastSquares(A: A, b: b) {
            return CGPoint(x: solution[0], y: solution[1])
        }
        
        // Fallback to simple geometric method for 3 anchors
        if measurements.count == 3 {
            return geometricTrilateration(
                p1: measurements[0].position, r1: CGFloat(measurements[0].distance),
                p2: measurements[1].position, r2: CGFloat(measurements[1].distance),
                p3: measurements[2].position, r3: CGFloat(measurements[2].distance)
            )
        }
        
        return nil
    }
    
    private func geometricTrilateration(p1: CGPoint, r1: CGFloat, p2: CGPoint, r2: CGFloat, p3: CGPoint, r3: CGFloat) -> CGPoint? {
        // Simple geometric trilateration for 3 circles
        let A = 2 * p2.x - 2 * p1.x
        let B = 2 * p2.y - 2 * p1.y
        let C = r1 * r1 - r2 * r2 - p1.x * p1.x + p2.x * p2.x - p1.y * p1.y + p2.y * p2.y
        
        let D = 2 * p3.x - 2 * p2.x
        let E = 2 * p3.y - 2 * p2.y
        let F = r2 * r2 - r3 * r3 - p2.x * p2.x + p3.x * p3.x - p2.y * p2.y + p3.y * p3.y
        
        let denominator = A * E - B * D
        guard abs(denominator) > 0.001 else { return nil }
        
        let x = (C * E - F * B) / denominator
        let y = (A * F - D * C) / denominator
        
        return CGPoint(x: x, y: y)
    }
    
    private func solveLeastSquares(A: [[Double]], b: [Double]) -> [Double]? {
        // Simple least squares solver using normal equations
        // A^T * A * x = A^T * b
        
        let m = A.count
        let n = A[0].count
        
        // Compute A^T * A
        var AtA = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in 0..<n {
                var sum = 0.0
                for k in 0..<m {
                    sum += A[k][i] * A[k][j]
                }
                AtA[i][j] = sum
            }
        }
        
        // Compute A^T * b
        var Atb = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var sum = 0.0
            for k in 0..<m {
                sum += A[k][i] * b[k]
            }
            Atb[i] = sum
        }
        
        // Solve 2x2 system (for our case)
        if n == 2 {
            let det = AtA[0][0] * AtA[1][1] - AtA[0][1] * AtA[1][0]
            guard abs(det) > 0.001 else { return nil }
            
            let x = (Atb[0] * AtA[1][1] - Atb[1] * AtA[0][1]) / det
            let y = (AtA[0][0] * Atb[1] - AtA[1][0] * Atb[0]) / det
            
            return [x, y]
        }
        
        return nil
    }
    
    private func applyNLOSDetection(position: CGPoint, measurements: [AnchorMeasurement]) -> CGPoint {
        // Check if measured distances are consistent with calculated position
        var adjustedPosition = position
        var outliers: [AnchorMeasurement] = []
        
        for measurement in measurements {
            let calculatedDistance = distance(from: position, to: measurement.position)
            let error = abs(calculatedDistance - CGFloat(measurement.distance))
            
            if error > CGFloat(settings.nlosDetectionThreshold) {
                outliers.append(measurement)
            }
        }
        
        // If we have outliers, recalculate without them
        if !outliers.isEmpty && measurements.count - outliers.count >= settings.minAnchorsForTrilateration {
            let filteredMeasurements = measurements.filter { measurement in
                !outliers.contains(where: { $0.anchorId == measurement.anchorId })
            }
            
            if let newPosition = trilateratePosition(measurements: filteredMeasurements) {
                adjustedPosition = newPosition
            }
        }
        
        return adjustedPosition
    }
    
    private func smoothPosition(_ position: CGPoint) -> CGPoint {
        positionHistory.append(position)
        
        if positionHistory.count > maxHistorySize {
            positionHistory.removeFirst()
        }
        
        // Apply exponential moving average
        if let lastPosition = lastCalculatedPosition {
            let alpha = CGFloat(settings.positionSmoothingFactor)
            let smoothedX = alpha * position.x + (1 - alpha) * lastPosition.x
            let smoothedY = alpha * position.y + (1 - alpha) * lastPosition.y
            return CGPoint(x: smoothedX, y: smoothedY)
        }
        
        return position
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func reset() {
        measurements.removeAll()
        positionHistory.removeAll()
        lastCalculatedPosition = nil
    }
    
    func getActiveMeasurements() -> [AnchorMeasurement] {
        return Array(measurements.values)
    }
    
    func getConfidenceLevel() -> Float {
        let validCount = measurements.values.filter { 
            $0.distance <= settings.maxAnchorRange && $0.distance > 0 
        }.count
        
        if validCount >= 4 { return 1.0 }
        if validCount == 3 { return 0.75 }
        if validCount == 2 { return 0.25 }
        return 0.0
    }
}