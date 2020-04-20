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


fileprivate func makeCamera(_ viewSize: CGSize, focalDist: Float) -> Camera {
    var cfg = Camera.Config()
    cfg.screenSize.x = Float(viewSize.width)
    cfg.screenSize.y = Float(viewSize.height)
    cfg.initRadius = focalDist
    cfg.initFocalDistance = focalDist
    cfg.initAperture = 15.0
    cfg.sensitivity = 0.015
    return Camera(cfg)
}

fileprivate func makeRayTracingParams(_ viewSize: CGSize, _ camera: Camera) -> RayTracingParams {
    var rtParams = RayTracingParams()
    rtParams.screenSize.x = Float(viewSize.width)
    rtParams.screenSize.y = Float(viewSize.height)
    rtParams.maxDepth = 50
    rtParams.sampleBatchSize = 8
    rtParams.curBatchIdx = 0
    print("\(rtParams)")
    return rtParams
}

class ViewController: UIViewController {
    var viewSize: SIMD2<Int> = .zero
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var metalLayer: CAMetalLayer!
    var camera: Camera!
    var rtParams: RayTracingParams!
    var scene: RTScene!
    var timer: CADisplayLink!
    
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    
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
        
        camera = makeCamera(viewSize, focalDist: Float(viewSize.height) * 1.5)
        rtParams = makeRayTracingParams(viewSize, camera)
        var cfg = RTScene.Config()
        cfg.rtParams = rtParams
        cfg.cameraPaarms = camera.getParams()
        cfg.rootGeometry = makeGeometries()
        cfg.maxRenderIter = 50
        scene = RTScene(cfg, device)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        tapRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(tapRecognizer)
        
        timer = CADisplayLink(target: self, selector: #selector(renderLoop))
        timer.add(to: .main, forMode: .default)
    }
    
    private func makeGeometries() -> Geometry {
        let screenSize = rtParams.screenSize
        let root = GeometryGroup()
        let p1 = Plane(pointOnPlane: simd_float3(0, screenSize.y * -0.1, 0),
                       normal: simd_float3(-0.08, 1.0, 0.0),
                       mat: Lambertian(albedo: simd_float3(0.4, 0.7, 0.35)))
        let s2 = Sphere(center: simd_float3(screenSize.x * -0.25,
                                            screenSize.y * 0.0,
                                            screenSize.y * -0.25),
                        radius: screenSize.y * 0.09,
                        mat: MMetal(albedo: simd_float3(0.8, 0.5, 0.4),
                                    fuzz: 0.03))
        let s3 = Sphere(center: simd_float3(screenSize.x * 0.0,
                                            screenSize.y * 0.0,
                                            screenSize.y * 0.0),
                        radius: screenSize.y * 0.09,
                        mat: Dielectrics(refractIndex: 1.5))
        let s4 = Sphere(center: simd_float3(screenSize.x * 0.25,
                                            screenSize.y * 0.005,
                                            screenSize.y * 0.25),
                        radius: screenSize.y * 0.09,
                        mat: Lambertian(albedo: simd_float3(0.7, 0.14, 0.2)))
        let ls1 = Sphere(center: simd_float3(screenSize.x * -0.32,
                                            screenSize.y * 0.12,
                                            screenSize.y * 0.3),
                        radius: 40.0,
                        mat: LightSource(color: simd_float3(0.9, 0.52, 0.3) * 3.5))
        let ls2 = Sphere(center: simd_float3(screenSize.x * 0.41,
                                             screenSize.y * 0.045,
                                             screenSize.y * -0.35),
                         radius: 28.0,
                         mat: LightSource(color: simd_float3(0.74, 0.37, 0.21) * 1.5))
        root.append(p1)
        root.append(s2)
        root.append(s3)
        root.append(s4)
        root.append(ls1)
        root.append(ls2)
        
        var minX = 0.12 * screenSize.x
        var maxX = 0.7 * screenSize.x
        var rangeX = maxX - minX
        var minY = -0.075 * screenSize.y
        var maxY = 0.005 * screenSize.y
        var rangeY = maxY - minY
        var minZ = -0.4 * screenSize.y
        var maxZ = 0.1 * screenSize.y
        var rangeZ = maxZ - minZ
        let randomColor = { simd_float3(Float.random(in: 0.1..<1),
                                        Float.random(in: 0.1..<1),
                                        Float.random(in: 0.1..<1))}
        let numPerDim = 4
        let invNumPerDiv = 1.0 / Float(numPerDim)
        for i in 0..<numPerDim {
            for j in 0..<(i + 1) {
                let radius = Float.random(in: 0.15..<0.32) * rangeY
                let xi = (Float(i) + Float.random(in: -0.5..<0.5))
                let zi = (Float(j) + Float.random(in: -0.5..<0.5))
                let center = simd_float3(minX + xi * rangeX * invNumPerDiv,
                                         radius + Float.random(in: 0.5..<2.0) + minY,
                                         minZ + zi * rangeZ * invNumPerDiv)
                var mat: Material!
                let prob = Float.random(in: 0..<1)
                if prob < 0.6 {
                    mat = Lambertian(albedo: randomColor())
                } else if prob < 0.8 {
                    mat = MMetal(albedo: randomColor(), fuzz: Float.random(in: 0.0..<0.1))
                } else {
                    mat = Dielectrics(refractIndex: Float.random(in: 1.5..<2.4), fuzz: 0.0)
                }
                let s = Sphere(center: center, radius: radius, mat: mat)
                root.append(s)
            }
        }
        
        minX = -0.7 * screenSize.x
        maxX = -0.12 * screenSize.x
        rangeX = maxX - minX
        minY = -0.105 * screenSize.y
        maxY = -0.01 * screenSize.y
        rangeY = maxY - minY
        minZ = -0.1 * screenSize.y
        maxZ = 0.4 * screenSize.y
        rangeZ = maxZ - minZ
        for i in 0..<numPerDim {
            for j in 0..<(i + 1) {
                let radius = Float.random(in: 0.15..<0.32) * rangeY
                let xi = (Float(i) + Float.random(in: -0.5..<0.5))
                let zi = (Float(j) + Float.random(in: -0.5..<0.5))
                let center = simd_float3(minX + xi * rangeX * invNumPerDiv,
                                         radius + Float.random(in: 0.5..<2.0) + minY,
                                         minZ + zi * rangeZ * invNumPerDiv)
                var mat: Material!
                let prob = Float.random(in: 0..<1)
                if prob < 0.6 {
                    mat = Lambertian(albedo: randomColor())
                } else if prob < 0.8 {
                    mat = MMetal(albedo: randomColor(), fuzz: Float.random(in: 0.0..<0.1))
                } else {
                    mat = Dielectrics(refractIndex: Float.random(in: 1.5..<2.4), fuzz: 0.0)
                }
                let s = Sphere(center: center, radius: radius, mat: mat)
                root.append(s)
            }
        }
        return root
    }
    
    private var needSample = true

    @objc func renderLoop() {
        autoreleasepool {
            guard needSample else { return }
            let commandBuffer = commandQueue.makeCommandBuffer()!
            
            needSample = scene.render(metalLayer.nextDrawable()!, commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
    
    @IBAction func handlePan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)
        camera.onPan(delta: translation)
        scene.update(cameraParams: camera.getParams())
        if sender.state == .ended {
            scene.finishCameraUpdate()
        }
        // Reset so that translation is always the delta
        sender.setTranslation(.zero, in: view)
        needSample = true
    }
    
    @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
        print("jflda")
        scene.update(gemoetry: makeGeometries())
    }
}

