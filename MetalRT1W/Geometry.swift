//
//  Geometry.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/14.
//  Copyright © 2020 zkk. All rights reserved.
//

import Foundation
import simd

enum GeometryKinds: Int32 {
    case group = 1
    case sphere
    case plane
}

// MemoryLayout<GeometryKinds>.size is 1, even if we specify it to derive from Int32.
fileprivate let GeometryKindsSize = MemoryLayout<Int32>.size

protocol Geometry: MetalSerializable {
    var kind: GeometryKinds { get }
}

class GeometryGroup: Geometry {
    private var group = [Geometry]()
    
    var kind: GeometryKinds { get { return .group } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = 0
            result += GeometryKindsSize
            // Elements count
            result += MemoryLayout<Int32>.size
            for g in group {
                result += MetalSerializableWriteStream.getBytesRequired(g)
            }
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: Int32(group.count))
        for g in group {
            strm.append(g)
        }
    }
    
    func append(_ g: Geometry) {
        group.append(g)
    }
}

class Sphere: Geometry {
    let center: simd_float3
    let radius: Float
    let material: Material
    
    init(center: simd_float3, radius: Float, mat: Material) {
        self.center = center
        self.radius = radius
        self.material = mat
    }

    var kind: GeometryKinds { get { return .sphere } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = GeometryKindsSize
            // center
            result += MemoryLayout<simd_float3>.size
            // radius
            result += MemoryLayout<Float>.size
            // material
            result += MetalSerializableWriteStream.getBytesRequired(material)
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: center)
        strm.memCpy(data: radius)
        strm.append(material)
    }
}

class Plane: Geometry {
    let pointOnPlane: simd_float3
    let normal: simd_float3
    let material: Material
    
    init(pointOnPlane: simd_float3, normal: simd_float3, mat: Material) {
        self.pointOnPlane = pointOnPlane
        self.normal = normalize(normal)
        self.material = mat
    }
    
    var kind: GeometryKinds { get { return .plane } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = GeometryKindsSize
            // pointOnPlane
            result += MemoryLayout<simd_float3>.size
            // normal
            result += MemoryLayout<simd_float3>.size
            // material
            result += MetalSerializableWriteStream.getBytesRequired(material)
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: pointOnPlane)
        strm.memCpy(data: normal)
        strm.append(material)
    }
}
