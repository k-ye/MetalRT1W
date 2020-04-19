//
//  MathExtension.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/19.
//  Copyright © 2020 zkk. All rights reserved.
//

import Foundation
import simd
import GLKit

func deg2rad(_ deg: Float) -> Float {
    return deg * .pi / 180
}

extension matrix_float4x4 {
    init(glk: GLKMatrix4) {
        self.init(columns: (
            SIMD4<Float>(x: glk.m00, y: glk.m01, z: glk.m02, w: glk.m03),
            SIMD4<Float>(x: glk.m10, y: glk.m11, z: glk.m12, w: glk.m13),
            SIMD4<Float>(x: glk.m20, y: glk.m21, z: glk.m22, w: glk.m23),
            SIMD4<Float>(x: glk.m30, y: glk.m31, z: glk.m32, w: glk.m33)
        ))
    }
}

func matrix_float4x4_translate(tx: Float, ty: Float, tz: Float) -> matrix_float4x4 {
    return matrix_float4x4(glk: GLKMatrix4MakeTranslation(tx, ty, tz))
}

func matrix_float4x4_translate(t: simd_float3) -> matrix_float4x4 {
    return matrix_float4x4_translate(tx: t[0], ty: t[1], tz: t[2])
}

func matrix_float4x4_rotate(radian: Float, axisX: Float, axisY: Float, axisZ: Float) -> matrix_float4x4 {
    return matrix_float4x4(glk: GLKMatrix4MakeRotation(radian, axisX, axisY, axisZ))
}

func matrix_float4x4_rotate(radian: Float, axis: simd_float3) -> matrix_float4x4 {
    return matrix_float4x4_rotate(radian: radian, axisX: axis[0], axisY: axis[1], axisZ: axis[2])
}

func matrix_float4x4_scale(sX: Float, sY: Float, sZ: Float) -> matrix_float4x4 {
    return matrix_float4x4(glk: GLKMatrix4MakeScale(sX, sY, sZ))
}

func matrix_float4x4_scale(scale: Float) -> matrix_float4x4 {
    return matrix_float4x4_scale(sX: scale, sY: scale, sZ: scale)
}

func matrix_float4x4_lookat(eyeX: Float, eyeY: Float, eyeZ: Float,
                            tgtX: Float, tgtY: Float, tgtZ: Float,
                            upX: Float, upY: Float, upZ: Float) -> matrix_float4x4 {
    return matrix_float4x4(glk: GLKMatrix4MakeLookAt(eyeX, eyeY, eyeZ, tgtX, tgtY, tgtZ, upX, upY, upZ))
}

func matrix_float4x4_lookat(eye: simd_float3, target: simd_float3, up: simd_float3) -> matrix_float4x4 {
    return matrix_float4x4_lookat(
        eyeX: eye[0], eyeY: eye[1], eyeZ: eye[2],
        tgtX: target[0], tgtY: target[1], tgtZ: target[2],
        upX: up[0], upY: up[1], upZ: up[2]
    )
}
