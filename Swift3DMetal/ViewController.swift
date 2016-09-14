//
//  ViewController.swift
//  Swift3DMetal
//
//  Created by Kevin Nelson on 14/09/16.
//  Copyright © 2016 rknLA. All rights reserved.
//

import UIKit
import Metal
import simd
import QuartzCore.CAMetalLayer

struct Uniforms {
    var rotation_matrix: matrix_float4x4
}

var vertexData: [CFloat] = [
     1.0, -1.0, 0.5, 1.0,       1.0, 0.0, 0.0, 1.0,
    -1.0, -1.0, 0.5, 1.0,       0.0, 1.0, 0.0, 1.0,
    -1.0,  1.0, 0.5, 1.0,       0.0, 0.0, 1.0, 1.0,

     1.0,  1.0, 0.0, 1.0,       1.0, 1.0, 0.0, 1.0,
     1.0, -1.0, 0.0, 1.0,       1.0, 0.0, 0.0, 1.0,
    -1.0,  1.0, 0.0, 1.0,       0.0, 0.0, 1.0, 1.0,
]

let kInflightCommandBuffers = 3

class ViewController: UIViewController {

    var metalLayer: CAMetalLayer?
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var library: MTLLibrary?
    var pipelineState: MTLRenderPipelineState?
    var bufferSemaphor: DispatchSemaphore?

    var uniformBuffer: MTLBuffer?
    var vertexBuffer: MTLBuffer?

    var drawable: CAMetalDrawable?
    var timer: CADisplayLink?
    var layerSizeDidUpdate: Bool = false

    var activeTouches: [UITouch] = []


    deinit {
        timer?.invalidate()
    }

    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.metalInit()
        self.setupPipeline()

        bufferSemaphor = DispatchSemaphore(value: kInflightCommandBuffers)

        timer = CADisplayLink(target: self, selector: #selector(redraw))
        timer!.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layerSizeDidUpdate = true

        let parentSize = self.view.bounds.size
        let newFrame = CGRect(x: 0, y: 0, width: parentSize.width, height: parentSize.height)
        metalLayer!.frame = newFrame
    }

    func metalInit() {
        guard let d = MTLCreateSystemDefaultDevice() else {
            print("Couldn't get Metal device!")
            abort()
        }

        device = d
        metalLayer = CAMetalLayer()
        metalLayer!.device = d
        metalLayer!.pixelFormat = .bgra8Unorm
        metalLayer!.frame = self.view.bounds
        self.view.layer.addSublayer(metalLayer!)

        commandQueue = d.makeCommandQueue()
        do {
            library = try d.makeDefaultLibrary(bundle: Bundle.main)
        } catch {
            print("Couldn't get default library!")
            abort()
        }

        self.view.contentScaleFactor = UIScreen.main.scale

        print("OK initialized metal")
    }

    func setupPipeline() {
        let bufferLength = MemoryLayout<CFloat>.size * vertexData.count
        let dataPtr = UnsafeRawPointer(vertexData)
        vertexBuffer = device!.makeBuffer(bytes: dataPtr, length: bufferLength, options: .cpuCacheModeWriteCombined)

        let vertexFunction = library!.makeFunction(name: "vertex_func")
        let fragmentFunction = library!.makeFunction(name: "fragment_func")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("error making render pipeline!")
            abort()
        }

        print("OK setup pipeline")
    }

    func render() {

        bufferSemaphor?.wait()

        let commandBuffer = commandQueue?.makeCommandBuffer()
        let drawable = metalLayer!.nextDrawable()!

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        encoder?.setRenderPipelineState(pipelineState!)
        encoder?.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
        encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder?.endEncoding()

        commandBuffer?.addCompletedHandler({ (buf) in
            self.bufferSemaphor?.signal()
        })

        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }


    func redraw() {
        if layerSizeDidUpdate {
            // do we actually need to do anything here?
            layerSizeDidUpdate = false
        }
        self.render()
    }
}

