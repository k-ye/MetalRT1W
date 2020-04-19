//
//  Material.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/18.
//  Copyright © 2020 zkk. All rights reserved.
//

import Foundation
import simd

enum MaterialKinds: Int32 {
    case lambertian = 1
    case mmetal
    case dielectrics
}

fileprivate let MaterialKindsSize = MemoryLayout<Int32>.size

protocol Material: MetalSerializable {
    var kind: MaterialKinds { get }
}

class Lambertian: Material {
    let albedo: simd_float3
    
    init(albedo: simd_float3) {
        self.albedo = albedo
    }
    
    var kind: MaterialKinds { get { return .lambertian } }
    
    var bytesOnMetal: Int32 {
        get {
            return Int32(MaterialKindsSize + MemoryLayout<simd_float3>.size)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: albedo)
    }
}

class MMetal: Material {
    let albedo: simd_float3
    let fuzz: Float
    
    init(albedo: simd_float3, fuzz: Float) {
        self.albedo = albedo
        self.fuzz = fuzz
    }
    
    var kind: MaterialKinds { get { return .mmetal } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = MaterialKindsSize
            // albedo
            result += MemoryLayout<simd_float3>.size
            // fuzz
            result += MemoryLayout<Float>.size
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: albedo)
        strm.memCpy(data: fuzz)
    }
}

class Dielectrics: Material {
    let refractIndex: Float
    let fuzz: Float
    
    init(refractIndex: Float, fuzz: Float) {
        self.refractIndex = refractIndex
        self.fuzz = fuzz
    }
    
    convenience init(refractIndex: Float) {
        self.init(refractIndex: refractIndex, fuzz: 0.0)
    }
    
    
    var kind: MaterialKinds { get { return .dielectrics } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = MaterialKindsSize
            // refIndex
            result += MemoryLayout<Float>.size
            // fuzz
            result += MemoryLayout<Float>.size
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: refractIndex)
        strm.memCpy(data: fuzz)
    }
}
