//
//  MapData.swift
//  Map data structures
//

import Foundation
import CoreGraphics
import UIKit

struct MapMetadata: Codable {
    let image: String
    let mode: String
    let resolution: Double
    let origin: [Double]
    let negate: Int
    let occupied_thresh: Double
    let free_thresh: Double
}

struct Anchor: Codable {
    let id: String
    let xy: [Double]
    let yaw_deg: Double
    
    var position: CGPoint {
        CGPoint(x: xy[0], y: xy[1])
    }
}

struct POI: Codable {
    let id: String
    let name: String
    let xy: [Double]
    
    var position: CGPoint {
        CGPoint(x: xy[0], y: xy[1])
    }
}

class MapData {
    let metadata: MapMetadata
    let gridImage: UIImage
    let gridArray: [[Bool]]  // true = free, false = obstacle
    let anchors: [Anchor]
    let pois: [POI]
    
    let width: Int
    let height: Int
    let resolution: Double
    let originX: Double
    let originY: Double
    
    init(mapDirectory: URL) throws {
        // Load metadata
        let yamlURL = mapDirectory.appendingPathComponent("grid.yaml")
        let yamlData = try Data(contentsOf: yamlURL)
        // Simple YAML parsing for our specific format
        let yamlString = String(data: yamlData, encoding: .utf8)!
        self.metadata = try MapData.parseYAML(yamlString)
        
        // Load grid image
        let imageURL = mapDirectory.appendingPathComponent("grid.png")
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw NSError(domain: "MapData", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load grid image"])
        }
        self.gridImage = image
        
        // Convert image to boolean array
        self.gridArray = MapData.imageToGrid(image)
        self.width = gridArray[0].count
        self.height = gridArray.count
        
        // Extract resolution and origin
        self.resolution = metadata.resolution
        self.originX = metadata.origin[0]
        self.originY = metadata.origin[1]
        
        // Load anchors
        let anchorsURL = mapDirectory.appendingPathComponent("anchors.json")
        if FileManager.default.fileExists(atPath: anchorsURL.path) {
            let anchorsData = try Data(contentsOf: anchorsURL)
            self.anchors = try JSONDecoder().decode([Anchor].self, from: anchorsData)
        } else {
            self.anchors = []
        }
        
        // Load POIs
        let poisURL = mapDirectory.appendingPathComponent("pois.json")
        if FileManager.default.fileExists(atPath: poisURL.path) {
            let poisData = try Data(contentsOf: poisURL)
            self.pois = try JSONDecoder().decode([POI].self, from: poisData)
        } else {
            self.pois = []
        }
    }
    
    // Convert world coordinates (meters) to pixel coordinates
    func metersToPixel(_ point: CGPoint) -> CGPoint {
        let px = (point.x - originX) / resolution
        let py = Double(height - 1) - (point.y - originY) / resolution
        return CGPoint(x: px, y: py)
    }
    
    // Convert pixel coordinates to world coordinates (meters)
    func pixelToMeters(_ point: CGPoint) -> CGPoint {
        let x = originX + point.x * resolution
        let y = originY + (Double(height - 1) - point.y) * resolution
        return CGPoint(x: x, y: y)
    }
    
    // Check if a pixel is free (navigable)
    func isFree(x: Int, y: Int) -> Bool {
        guard x >= 0 && x < width && y >= 0 && y < height else { return false }
        return gridArray[y][x]
    }
    
    // Check if a world position is free
    func isPositionFree(_ position: CGPoint) -> Bool {
        let pixel = metersToPixel(position)
        return isFree(x: Int(pixel.x), y: Int(pixel.y))
    }
    
    private static func imageToGrid(_ image: UIImage) -> [[Bool]] {
        guard let cgImage = image.cgImage else { return [] }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return []
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var grid = [[Bool]]()
        for y in 0..<height {
            var row = [Bool]()
            for x in 0..<width {
                let pixelIndex = ((width * y) + x) * bytesPerPixel
                let value = pixelData[pixelIndex]  // Red channel (grayscale)
                row.append(value < 128)  // < 128 = free (black), >= 128 = obstacle (white)
            }
            grid.append(row)
        }
        
        return grid
    }
    
    private static func parseYAML(_ yaml: String) throws -> MapMetadata {
        // Simple YAML parser for our specific format
        var dict: [String: Any] = [:]
        
        let lines = yaml.components(separatedBy: .newlines)
        var currentKey = ""
        var inOrigin = false
        var originValues: [Double] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            if inOrigin {
                if trimmed.hasPrefix("-") {
                    let value = trimmed.replacingOccurrences(of: "- ", with: "")
                    if let num = Double(value) {
                        originValues.append(num)
                    }
                } else {
                    dict["origin"] = originValues
                    inOrigin = false
                }
            }
            
            if !inOrigin && trimmed.contains(":") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    
                    if key == "origin" {
                        inOrigin = true
                        currentKey = key
                    } else if let num = Double(value) {
                        dict[key] = num
                    } else if let num = Int(value) {
                        dict[key] = num
                    } else {
                        dict[key] = value
                    }
                }
            }
        }
        
        if inOrigin {
            dict["origin"] = originValues
        }
        
        // Create MapMetadata
        return MapMetadata(
            image: dict["image"] as? String ?? "grid.png",
            mode: dict["mode"] as? String ?? "trinary",
            resolution: dict["resolution"] as? Double ?? 0.1,
            origin: dict["origin"] as? [Double] ?? [0, 0, 0],
            negate: dict["negate"] as? Int ?? 0,
            occupied_thresh: dict["occupied_thresh"] as? Double ?? 0.65,
            free_thresh: dict["free_thresh"] as? Double ?? 0.2
        )
    }
}