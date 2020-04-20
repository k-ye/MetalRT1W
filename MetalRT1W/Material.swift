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
    case lightSource
}

fileprivate let MaterialKindsSize = MemoryLayout<Int32>.size

protocol Material: MetalSerializable {
    var kind: MaterialKinds { get }
}

class Lambertian: Material {
    let albedo: simd_float3
    let texIndex: Int32
    
    init(albedo: simd_float3, texIndex: Int) {
        self.albedo = albedo
        self.texIndex = Int32(texIndex)
    }
    
    convenience init(albedo: simd_float3) {
        self.init(albedo: albedo, texIndex: -1)
    }
    
    var kind: MaterialKinds { get { return .lambertian } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = MaterialKindsSize
            // albedo
            result += MemoryLayout<simd_float3>.size
            // texIndex
            result += MemoryLayout<Int32>.size
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: albedo)
        strm.memCpy(data: texIndex)
    }
}

class MMetal: Material {
    let albedo: simd_float3
    let fuzz: Float
    let texIndex: Int32
    
    init(albedo: simd_float3, fuzz: Float, texIndex: Int) {
        self.albedo = albedo
        self.fuzz = fuzz
        self.texIndex = Int32(texIndex)
    }
    
    convenience init(albedo: simd_float3, fuzz: Float) {
        self.init(albedo: albedo, fuzz: fuzz, texIndex: -1)
    }
    
    var kind: MaterialKinds { get { return .mmetal } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = MaterialKindsSize
            // albedo
            result += MemoryLayout<simd_float3>.size
            // fuzz
            result += MemoryLayout<Float>.size
            // texIndex
            result += MemoryLayout<Int32>.size
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: albedo)
        strm.memCpy(data: fuzz)
        strm.memCpy(data: texIndex)
    }
}

class Dielectrics: Material {
    let refractIndex: Float
    let fuzz: Float
    let texIndex: Int32
    
    init(refractIndex: Float, fuzz: Float, texIndex: Int) {
        self.refractIndex = refractIndex
        self.fuzz = fuzz
        self.texIndex = Int32(texIndex)
    }
    
    convenience init(refractIndex: Float) {
        self.init(refractIndex: refractIndex, fuzz: 0.0, texIndex: -1)
    }
    
    
    var kind: MaterialKinds { get { return .dielectrics } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = MaterialKindsSize
            // refIndex
            result += MemoryLayout<Float>.size
            // fuzz
            result += MemoryLayout<Float>.size
            // texIndex
            result += MemoryLayout<Int32>.size
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: refractIndex)
        strm.memCpy(data: fuzz)
        strm.memCpy(data: texIndex)
    }
}

class LightSource: Material {
    let color: simd_float3
    let texIndex: Int32
    
    init(color: simd_float3, texIndex: Int) {
        self.color = color
        self.texIndex = Int32(texIndex)
    }
    
    convenience init(color: simd_float3) {
        self.init(color: color, texIndex: -1)
    }
    
    var kind: MaterialKinds { get { return .lightSource } }
    
    var bytesOnMetal: Int32 {
        get {
            var result = MaterialKindsSize
            // color
            result += MemoryLayout<simd_float3>.size
            // texIndex
            result += MemoryLayout<Int32>.size
            return Int32(result)
        }
    }
    
    func serialize(to strm: MetalSerializableWriteStream) {
        strm.memCpy(data: kind.rawValue)
        strm.memCpy(data: color)
        strm.memCpy(data: texIndex)
    }
}
