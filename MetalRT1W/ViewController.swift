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

fileprivate func makeRayTracingParams(_ viewSize: CGSize) -> RayTracingParams {
    var rtParams = RayTracingParams()
    rtParams.screenSize.x = Float(viewSize.width)
    rtParams.screenSize.y = Float(viewSize.height)
    rtParams.cameraPos.x = rtParams.screenSize.x * 0.5
    rtParams.cameraPos.y = rtParams.screenSize.y * 0.5
    rtParams.cameraPos.z = -rtParams.screenSize.y * 0.6
    rtParams.aperture = 12.0
    rtParams.focusDist = abs(rtParams.cameraPos.z)
    rtParams.maxDepth = 50
    rtParams.sampleBatchSize = 16
    rtParams.curBatchIdx = 0
    print("\(rtParams)")
    return rtParams
}


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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Recent iphone models can have |nativeScale| at 3.0, which will result
        // in a too large texture.
//        let scale = view.window?.screen.nativeScale ?? 2.0
        let scale: CGFloat = 2.0
        let viewSize = view.bounds.size
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        // Have to use BGRA
        // https://developer.apple.com/documentation/quartzcore/cametallayer/1478155-pixelformat
        metalLayer.pixelFormat = .bgra8Unorm
        // Need |framebufferOnly| = false so that the underlying texture
        // is blittable.
        metalLayer.framebufferOnly = false
        metalLayer.frame = view.layer.frame
        metalLayer.drawableSize = CGSize(width: viewSize.width * scale,
                                         height: viewSize.height * scale)
        view.layer.addSublayer(metalLayer)

        let rtParams = makeRayTracingParams(viewSize)
        var cfg = RTScene.Config()
        cfg.rtParams = rtParams
        cfg.rootGeometry = makeGeometries(rtParams)
        cfg.maxRenderIter = 32
        scene = RTScene(cfg, device)
        
        timer = CADisplayLink(target: self, selector: #selector(renderLoop))
        timer.add(to: .main, forMode: .default)
    }
    
    private func makeGeometries(_ rtParams: RayTracingParams) -> Geometry {
        let screenSize = rtParams.screenSize
        let root = GeometryGroup()
        let s1 = Sphere(center: simd_float3(screenSize.x * 0.5,
                                            -screenSize.y * 1.55,
                                            screenSize.y * 0.4),
                        radius: screenSize.y * 2,
                        mat: Lambertian(albedo: simd_float3(0.4, 0.7, 0.3)))
        let s2 = Sphere(center: simd_float3(screenSize.x * 0.6,
                                            screenSize.y * 0.6,
                                            /*z-*/screenSize.y * 0.2),
                        radius: screenSize.y * 0.1,
                        mat: MMetal(albedo: simd_float3(0.8, 0.5, 0.4),
                                    fuzz: 0.0))
        let s3 = Sphere(center: simd_float3(screenSize.x * 0.35,
                                            screenSize.y * 0.5,
                                            /*z-*/screenSize.y * 0.1),
                        radius: 50.0,
                        mat: Lambertian(albedo: simd_float3(0.7, 0.14, 0.2)))
        let s4 = Sphere(center: simd_float3(screenSize.x * 0.75,
                                            screenSize.y * 0.51,
                                            /*z-*/screenSize.y * 0.01),
                        radius: 50.0,
                        mat: Dielectrics(refractIndex: 2.4))
        let s5 = Sphere(center: simd_float3(screenSize.x * 0.52,
                            screenSize.y * 0.42,
                            /*z-*/-screenSize.y * 0.15),
                        radius: 30.0,
                        mat: Lambertian(albedo: simd_float3(0.2, 0.53, 0.9)))
//        return s1
        root.append(s1)
        root.append(s2)
        root.append(s3)
        root.append(s4)
        root.append(s5)
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

