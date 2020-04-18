//
//  ViewController.swift
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/14.
//  Copyright © 2020 zkk. All rights reserved.
//

import UIKit
import Metal
import simd

fileprivate let kForwardVertKernel = "forward_vert"
fileprivate let kRenderFragKernel = "render_frag"

class ViewController: UIViewController {
    var viewSize: SIMD2<Int> = .zero
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var metalLayer: CAMetalLayer!
    var timer: CADisplayLink!
    var scene: RTScene!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        // Have to use BGRA
        // https://developer.apple.com/documentation/quartzcore/cametallayer/1478155-pixelformat
        metalLayer.pixelFormat = .bgra8Unorm
        // Need |framebufferOnly| = false so that the underlying texture
        // is blittable.
        metalLayer.framebufferOnly = false
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)

        let rtParams = makeRayTracingParams()
        var cfg = RTScene.Config()
        cfg.rtParams = rtParams
        cfg.rootGeometry = makeGeometries(rtParams)
        cfg.maxRenderIter = 50
        scene = RTScene(cfg, device)
        
        timer = CADisplayLink(target: self, selector: #selector(renderLoop))
        timer.add(to: .main, forMode: .default)
    }
    
    private func makeRayTracingParams() -> RayTracingParams {
        var rtParams = RayTracingParams()
        rtParams.screenSize.x = Float(view.bounds.size.width)
        rtParams.screenSize.y = Float(view.bounds.size.height)
        rtParams.cameraPos.x = rtParams.screenSize.x * 0.5
        rtParams.cameraPos.y = rtParams.screenSize.y * 0.5
        rtParams.cameraPos.z = -rtParams.screenSize.y * 1.2
        rtParams.maxDepth = 50
        rtParams.sampleBatchSize = 32
        rtParams.curBatchIdx = 0
        print("\(rtParams)")
        return rtParams
    }
    
    private func makeGeometries(_ rtParams: RayTracingParams) -> Geometry {
        let screenSize = rtParams.screenSize
        let root = GeometryGroup()
        let s1 = Sphere(center: simd_float3(screenSize.x * 0.6,
                                            screenSize.y * 0.6,
                                            /*z-*/screenSize.y * 0.4 - 200),
                        radius: screenSize.y * 0.1)
        let s2 = Sphere(center: simd_float3(screenSize.x * 0.5,
                                            0,
                                            screenSize.y * 0.4),
                        radius: screenSize.y * 0.5)
//        return s2
        root.append(s1)
        root.append(s2)
        return root
    }
    
    private var neesSample = true
    @objc func renderLoop() {
        autoreleasepool {
            guard neesSample else { return }
            let commandBuffer = commandQueue.makeCommandBuffer()!
            
            neesSample = scene.render(metalLayer.nextDrawable()!, commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
    
}

