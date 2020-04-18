//
//  Geometry.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/14.
//  Copyright © 2020 zkk. All rights reserved.
//

import Foundation
import Metal
import simd

enum GeometryKinds: Int32 {
    case group = 0
    case sphere
}

// MemoryLayout<GeometryKinds>.size is 1, even if we specify it to derive from Int32.
fileprivate let GemoetryKindsSize = MemoryLayout<Int32>.size

protocol Geometry: MetalSerializable {
    var kind: GeometryKinds { get }
}

class GeometryGroup: Geometry {
    private var group = [Geometry]()
    
    var kind: GeometryKinds { get { return .group } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = 0
            result += GemoetryKindsSize
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
    
    init(center: simd_float3, radius: Float) {
        self.center = center
        self.radius = radius
    }

    var kind: GeometryKinds { get { return .sphere } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = 0
            result += GemoetryKindsSize
            // center
            result += MemoryLayout<simd_float3>.size
            // radius
            result += MemoryLayout<Float>.size
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: center)
        strm.memCpy(data: radius)
    }
}
