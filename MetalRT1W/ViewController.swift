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

class ViewController: UIViewController {
    var viewSize: SIMD2<Int> = .zero
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var metalLayer: CAMetalLayer!
    var timer: CADisplayLink!
    
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
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)
    }
    
    
}

