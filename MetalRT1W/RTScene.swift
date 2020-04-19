//
//  RTScene.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/14.
//  Copyright © 2020 zkk. All rights reserved.
//

import Foundation
import MetalKit

fileprivate let kForwardVertKernel = "forward_vert"
fileprivate let kRayTraceFragKernel = "ray_trace_frag"

fileprivate func makeQuadVertexBuffers(lo: Float, hi: Float, _ device: MTLDevice) -> MTLBuffer {
    // xy: position coord
    // zw: texture coord
    // https://developer.apple.com/documentation/metal/creating_and_sampling_textures
    let points = [
        simd_float4(hi, lo, 1.0, 1.0),
        simd_float4(lo, lo, 0.0, 1.0),
        simd_float4(lo, hi, 0.0, 0.0),
        simd_float4(hi, hi, 1.0, 0.0),
    ]
    
    let vertices = [
        points[0],
        points[1],
        points[2],
        
        points[0],
        points[2],
        points[3],
    ]
    return device.makeBuffer(bytes: vertices,
                             length: vertices.count * MemoryLayout<simd_float4>.stride,
                             options: [])!
}

fileprivate func makeRenderPipelineState(_ device: MTLDevice) -> MTLRenderPipelineState {
    let defaultLib = device.makeDefaultLibrary()!
    let vertexFunc = defaultLib.makeFunction(name: kForwardVertKernel)!
    let fragFunc = defaultLib.makeFunction(name: kRayTraceFragKernel)!
    
    let pipelineStateDesc = MTLRenderPipelineDescriptor()
    pipelineStateDesc.vertexFunction = vertexFunc
    pipelineStateDesc.fragmentFunction = fragFunc
    
    let colorAttachment = pipelineStateDesc.colorAttachments[0]!
    colorAttachment.pixelFormat = .bgra8Unorm
    return try! device.makeRenderPipelineState(descriptor: pipelineStateDesc)
}

struct RayTracingParams {
    var cameraPos: simd_float3 = .zero
    var aperture: Float = .zero
    var focusDist: Float = .zero
    var screenSize: simd_float2 = .zero
    var sampleBatchSize: Int32 = .zero
    var curBatchIdx: Int32 = .zero
    var maxDepth: Int32 = .zero
}

class RTScene {
    struct Config {
        var rtParams: RayTracingParams!
        var rootGeometry: Geometry!
        var maxRenderIter: Int = .zero
    }
    
    private weak var device: MTLDevice!
    private let cfg: Config
    
    private let geometryBuffer: MTLBuffer
    private var rtParams: RayTracingParams {
        get { return cfg.rtParams }
    }
    private let rtParamsBuffer: MTLBuffer
    private let randSeedBuffer: MTLBuffer
    
    private let renderQuadVertexBuffer: MTLBuffer
    private let renderPipelineState: MTLRenderPipelineState
    private var colorTexture: MTLTexture!
    
    init(_ cfg: Config, _ device: MTLDevice) {
        self.device = device
        self.cfg = cfg
        
        geometryBuffer = device.makeBuffer(
            length: MetalSerializableWriteStream.getBytesRequired(cfg.rootGeometry) ,
            options: [])!
        let mswriter = MetalSerializableWriteStream(geometryBuffer)
        mswriter.append(cfg.rootGeometry)
        
        var rtParamsCopy = cfg.rtParams!
        rtParamsBuffer = device.makeBuffer(bytes: &rtParamsCopy, length: MemoryLayout<RayTracingParams>.stride, options: [])!
        randSeedBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: [])!
        // Metal NDC XY: [-1.0, 1.0], Z: [0.0, 1.0]
        renderQuadVertexBuffer = makeQuadVertexBuffers(lo: -1.0, hi: 1.0, device)
        renderPipelineState = makeRenderPipelineState(device)
    }

    func render(_ drawable: CAMetalDrawable, _ commandBuffer: MTLCommandBuffer) -> Bool {
        let fbTex = drawable.texture
        mayeInitColorTexture(fbTex)
        launchRenderCommand(fbTex, commandBuffer)
        blitToColorTexture(fbTex, commandBuffer)
        commandBuffer.present(drawable)
        return incIterOrTerminate()
    }
    
    private func incIterOrTerminate() -> Bool {
        let ptr = rtParamsBuffer.contents().bindMemory(to: RayTracingParams.self, capacity: 1)
        if ptr.pointee.curBatchIdx >= cfg.maxRenderIter {
            return false
        }
        ptr.pointee.curBatchIdx += 1
        return true
    }
    
    private func mayeInitColorTexture(_ fbTex: MTLTexture) {
        if colorTexture != nil {
            return
        }
        
        // https://stackoverflow.com/questions/51476909/render-to-an-offscreen-framebuffer-in-metal
        // https://stackoverflow.com/questions/51511686/off-screen-rendering-metal
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: fbTex.width,
            height: fbTex.height,
            mipmapped: false)
        desc.storageMode = .private
        desc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        colorTexture = device.makeTexture(descriptor: desc)!
    }

    private func launchRenderCommand(_ fbTex: MTLTexture, _ commandBuffer: MTLCommandBuffer) {
        randSeedBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee = UInt32.random(in: 0..<UINT32_MAX)

        let renderPassDesc = MTLRenderPassDescriptor()
        
        let colorAttachment = renderPassDesc.colorAttachments[0]!
        colorAttachment.texture = fbTex
        colorAttachment.loadAction = .load
        colorAttachment.storeAction = .store
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc)!
        commandEncoder.setRenderPipelineState(renderPipelineState)
        commandEncoder.setVertexBuffer(renderQuadVertexBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentBuffer(geometryBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentBuffer(rtParamsBuffer, offset: 0, index: 1)
        commandEncoder.setFragmentBuffer(randSeedBuffer, offset: 0, index: 2)
        commandEncoder.setFragmentTexture(colorTexture, index: 0)
        commandEncoder.setTriangleFillMode(.fill)
        // A quad contains two triangle, therefore a total of 6 vertices
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        commandEncoder.endEncoding()
    }
    
    private func blitToColorTexture(_ fbTex: MTLTexture, _ commandBuffer: MTLCommandBuffer) {
        let commandEncoder = commandBuffer.makeBlitCommandEncoder()!
        commandEncoder.copy(from: fbTex, to: colorTexture!)
        commandEncoder.endEncoding()
    }
}
