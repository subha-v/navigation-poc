//
//  AStar.swift
//  A* pathfinding implementation
//

import Foundation
import CoreGraphics

struct GridNode: Hashable {
    let x: Int
    let y: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

class AStar {
    private let mapData: MapData
    private let sqrt2: Double = sqrt(2.0)
    
    init(mapData: MapData) {
        self.mapData = mapData
    }
    
    func findPath(from start: CGPoint, to goal: CGPoint) -> [CGPoint]? {
        // Convert world coordinates to pixels
        let startPixel = mapData.metersToPixel(start)
        let goalPixel = mapData.metersToPixel(goal)
        
        let startNode = GridNode(x: Int(startPixel.x), y: Int(startPixel.y))
        let goalNode = GridNode(x: Int(goalPixel.x), y: Int(goalPixel.y))
        
        // Check if start and goal are valid
        guard mapData.isFree(x: startNode.x, y: startNode.y) else {
            print("Start position is not free")
            return nil
        }
        guard mapData.isFree(x: goalNode.x, y: goalNode.y) else {
            print("Goal position is not free")
            return nil
        }
        
        // A* algorithm
        var openSet = Set<GridNode>([startNode])
        var cameFrom: [GridNode: GridNode] = [:]
        var gScore: [GridNode: Double] = [startNode: 0]
        var fScore: [GridNode: Double] = [startNode: heuristic(startNode, goalNode)]
        
        while !openSet.isEmpty {
            // Find node with lowest f score
            guard let current = openSet.min(by: { 
                (fScore[$0] ?? Double.infinity) < (fScore[$1] ?? Double.infinity)
            }) else { break }
            
            if current == goalNode {
                // Reconstruct path
                var path = [current]
                var node = current
                while let prev = cameFrom[node] {
                    path.append(prev)
                    node = prev
                }
                path.reverse()
                
                // Convert back to world coordinates
                return path.map { node in
                    mapData.pixelToMeters(CGPoint(x: node.x, y: node.y))
                }
            }
            
            openSet.remove(current)
            
            // Check all 8 neighbors
            for neighbor in getNeighbors(current) {
                guard mapData.isFree(x: neighbor.x, y: neighbor.y) else { continue }
                
                let moveCost = getMoveCost(current, neighbor)
                let tentativeGScore = (gScore[current] ?? Double.infinity) + moveCost
                
                if tentativeGScore < (gScore[neighbor] ?? Double.infinity) {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeGScore
                    fScore[neighbor] = tentativeGScore + heuristic(neighbor, goalNode)
                    openSet.insert(neighbor)
                }
            }
        }
        
        return nil  // No path found
    }
    
    private func getNeighbors(_ node: GridNode) -> [GridNode] {
        var neighbors: [GridNode] = []
        
        // 8-connected neighbors
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                
                let x = node.x + dx
                let y = node.y + dy
                
                if x >= 0 && x < mapData.width && y >= 0 && y < mapData.height {
                    neighbors.append(GridNode(x: x, y: y))
                }
            }
        }
        
        return neighbors
    }
    
    private func getMoveCost(_ from: GridNode, _ to: GridNode) -> Double {
        let dx = abs(from.x - to.x)
        let dy = abs(from.y - to.y)
        
        // Diagonal move
        if dx == 1 && dy == 1 {
            return sqrt2 * mapData.resolution
        }
        // Straight move
        return mapData.resolution
    }
    
    private func heuristic(_ from: GridNode, _ to: GridNode) -> Double {
        // Euclidean distance heuristic
        let dx = Double(abs(from.x - to.x))
        let dy = Double(abs(from.y - to.y))
        return sqrt(dx * dx + dy * dy) * mapData.resolution
    }
    
    // Smooth path using Douglas-Peucker algorithm
    func smoothPath(_ path: [CGPoint], epsilon: Double = 0.5) -> [CGPoint] {
        guard path.count > 2 else { return path }
        
        // Find point with maximum distance from line
        var maxDist = 0.0
        var maxIndex = 0
        
        for i in 1..<(path.count - 1) {
            let dist = perpendicularDistance(path[i], lineStart: path[0], lineEnd: path.last!)
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }
        
        // If max distance is greater than epsilon, recursively simplify
        if maxDist > epsilon {
            let leftPath = smoothPath(Array(path[0...maxIndex]), epsilon: epsilon)
            let rightPath = smoothPath(Array(path[maxIndex..<path.count]), epsilon: epsilon)
            
            return Array(leftPath.dropLast()) + rightPath
        } else {
            return [path[0], path.last!]
        }
    }
    
    private func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        if dx == 0 && dy == 0 {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        
        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)
        let t_clamped = max(0, min(1, t))
        
        let projX = lineStart.x + t_clamped * dx
        let projY = lineStart.y + t_clamped * dy
        
        return hypot(point.x - projX, point.y - projY)
    }
}