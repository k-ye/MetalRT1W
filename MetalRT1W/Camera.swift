//
//  Camera.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/19.
//  Copyright © 2020 zkk. All rights reserved.
//

import Foundation
import CoreGraphics
import simd

fileprivate let kEpsilon: Float = 1e-6

fileprivate func fromHomog(point: simd_float4) -> simd_float3 {
    let p = point / point.w
    return simd_float3(p.x, p.y, p.z)
}

fileprivate func fromHomog(vec: simd_float4) -> simd_float3 {
    return simd_float3(vec.x, vec.y, vec.z)
}

struct CameraParams {
    var position: simd_float3 = .zero
    var focalPlaneOrigin: simd_float3 = .zero
    var u: simd_float3 = .zero
    var v: simd_float3 = .zero
    var aperture: Float = .zero
}

class Camera {
    struct Config {
        var screenSize: simd_float2 = .zero
        var initRadius: Float = .zero
        var initFocalDistance: Float = .zero
        var initAperture: Float = .zero
        var sensitivity: Float = .zero
    }
    private let cfg: Config
    private var curRadius: Float
    private var curFocalDist: Float
    private var curAperture: Float
    
    private var xRotRad: Float  // pitch
    private var yRotRad: Float  // yaw
    
    var focalDistance: Float { get { return curFocalDist } }
    
    private var homogCamPosW: simd_float4 {
        get { return simd_float4(0.0, 0.0, -curRadius, 1.0) }
    }
    
    init(_ cfg: Config) {
        self.cfg = cfg
        curRadius = cfg.initRadius
        curFocalDist = cfg.initFocalDistance
        curAperture = cfg.initAperture
        
        xRotRad = 0.07
        yRotRad = .zero
    }
    
    func onPan(delta: CGPoint) {
        yRotRad += computeDeltaRad(dt: -delta.x)
        let tmpXRotRad = xRotRad + computeDeltaRad(dt: -delta.y)
        xRotRad = max(0.01, min(Float.pi * 0.5, tmpXRotRad))
    }
    
    func getParams() -> CameraParams {
        let rx = matrix_float4x4_rotate(radian: xRotRad, axis: simd_float3(1, 0, 0))
        let ry = matrix_float4x4_rotate(radian: yRotRad, axis: simd_float3(0, 1, 0))
        let rotMax = ry * rx

        // suffix:
        // - "W": world space
        // - "V": view space
        let camPosW = fromHomog(vec: rotMax * homogCamPosW)
        let targetDir = simd_float4(0.0, 0.0, curFocalDist, 0.0)
        let targetPosW = fromHomog(vec: rotMax * (homogCamPosW + targetDir))
        let upW = fromHomog(vec: rotMax * simd_float4(0.0, 1.0, 0.0, 0.0))
        let lookat = matrix_float4x4_lookat(eye: camPosW,
                                            target: targetPosW,
                                            up: upW)
        let invMat = simd_inverse(lookat)
        
        let camPosV = simd_float4(0.0, 0.0, 0.0, 1.0)
        let uV = simd_float4(cfg.screenSize.x, 0.0, 0.0, 0.0)
        let vV = simd_float4(0.0, cfg.screenSize.y, 0.0, 0.0)
        let focalPlaneOriginV = camPosV - targetDir - 0.5 * (uV + vV)
        
        var params = CameraParams()
        params.position = fromHomog(point: invMat * camPosV)
        params.focalPlaneOrigin = fromHomog(point: invMat * focalPlaneOriginV)
        params.u = fromHomog(vec: invMat * uV)
        params.v = fromHomog(vec: invMat * vV)
        params.aperture = curAperture
        
        return params
    }
    
    private func computeDeltaRad(dt: CGFloat) -> Float {
        let threshold: Float = .pi * 0.5
        return max(min(Float(dt) * cfg.sensitivity, threshold), -threshold)
    }
}
