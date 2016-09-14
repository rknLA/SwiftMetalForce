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

let kInflightCommandBuffers = 3

let kVertexDistanceInterval: CGFloat = 30

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

    private var _vertexCount: Int = 0
    private var _vertexData: [CFloat]?
    var vertexData: [CFloat] {
        get {
            if _vertexData == nil {
                _vertexData = []
                _vertexCount = 0

                // populate vertex data

                // vertex data is a 1-D array with x,y,z,w,r,g,b,a values for each vertex,
                // and organized in triangles, so three consecutive vertices should form a triangle.
                // the total size of the array is 8x the number of vertices

                // we're gonna play this game as a hex-grid, where the y offsets are consistent, 
                // but the x offsets are interleaved across rows
                //
                //  *     *     *     *
                //     *     *     *
                //  *     *     *     *
                //     *     *     *
                //  *     *     *     *
                //     *     *     *

                // to do this, we basically draw all of the trinagles between the hexagons in a


                let frameWidth = self.view.frame.width
                let frameHeight = self.view.frame.height

                let xNodeCount = Int(ceil(frameWidth / kVertexDistanceInterval)) + 1
                let yNodeCount = Int(ceil(frameHeight / kVertexDistanceInterval))

                let xStride = CFloat( kVertexDistanceInterval * 2 / frameWidth )
                let yStride = CFloat( kVertexDistanceInterval * 2 / frameHeight )

                let halfXStride = xStride / 2
                let halfYStride = yStride / 2

                // triangles are formed by adding or subtracting the yStride, and adding *and* subtracting the xStride


                // the -1.0 offset is due to the Metal coordinate space.. bottom right is -1 -1
                let startingX: CFloat = (xStride / 2) - 1.0
                let startingY: CFloat = yStride - 1.0

                var xPos: CFloat = startingX
                var yPos: CFloat = startingY

                var firstPassInRow = true
                var keepGoingX = true
                var keepGoingY = true

                while keepGoingY {
                    if yPos + yStride > 1.0 {
                        keepGoingY = false
                        // stop *after* the pass that takes us over 1.0
                    }

                    while keepGoingX {
                        if xPos + halfXStride > 1.0 {
                            keepGoingX = false
                        }

                        if firstPassInRow {
                            firstPassInRow = false

                            //first pass is special, because it must draw the full hexagon. subsequent passes in the same row only draw 4 of the triangles

                            // the upper-left triangle
                            _vertexData!.append(contentsOf: [
                                xPos,               yPos,           CFloat(0.5), CFloat(1.0), 1.0, 0.0, 0.0, 1.0,
                                xPos - halfXStride, yPos - yStride, CFloat(0.5), CFloat(1.0), 1.0, 1.0, 0.0, 1.0,
                                xPos - xStride,     yPos,           CFloat(0.5), CFloat(1.0), 0.0, 0.0, 1.0, 1.0]);
                            _vertexCount += 3

                            // the lower-left triangle
                            _vertexData!.append(contentsOf: [
                                xPos,               yPos,           CFloat(0.5), CFloat(1.0), 1.0, 0.0, 0.0, 1.0,
                                xPos - halfXStride, yPos + yStride, CFloat(0.5), CFloat(1.0), 0.0, 1.0, 0.0, 1.0,
                                xPos - xStride,     yPos,           CFloat(0.5), CFloat(1.0), 0.0, 1.0, 1.0, 1.0]);
                            _vertexCount += 3
                        }

                        // purely above triangle
                        _vertexData!.append(contentsOf: [
                            xPos,               yPos,           CFloat(0.5), CFloat(1.0), 1.0, 0.0, 0.0, 1.0,
                            xPos - halfXStride, yPos - yStride, CFloat(0.5), CFloat(1.0), 1.0, 1.0, 0.0, 1.0,
                            xPos + halfXStride, yPos - yStride, CFloat(0.5), CFloat(1.0), 0.5, 1.0, 1.0, 1.0]);
                        _vertexCount += 3

                        // upper right triangle
                        _vertexData!.append(contentsOf: [
                            xPos,               yPos,           CFloat(0.5), CFloat(1.0), 1.0, 1.0, 0.0, 1.0,
                            xPos + halfXStride, yPos - yStride, CFloat(0.5), CFloat(1.0), 1.0, 1.0, 1.0, 1.0,
                            xPos + xStride,     yPos,           CFloat(0.5), CFloat(1.0), 1.0, 0.0, 0.0, 1.0]);
                        _vertexCount += 3

                        // lower right triangle
                        _vertexData!.append(contentsOf: [
                            xPos,               yPos,           CFloat(0.5), CFloat(1.0), 1.0, 0.0, 0.0, 1.0,
                            xPos + halfXStride, yPos + yStride, CFloat(0.5), CFloat(1.0), 1.0, 1.0, 1.0, 1.0,
                            xPos + xStride,     yPos,           CFloat(0.5), CFloat(1.0), 1.0, 0.0, 0.0, 1.0]);
                        _vertexCount += 3

                        // purely below triangle
                        _vertexData!.append(contentsOf: [
                            xPos,               yPos,           CFloat(0.5), CFloat(1.0), 1.0, 0.0, 1.0, 1.0,
                            xPos - halfXStride, yPos + yStride, CFloat(0.5), CFloat(1.0), 1.0, 1.0, 0.0, 1.0,
                            xPos + halfXStride, yPos + yStride, CFloat(0.5), CFloat(1.0), 0.0, 0.0, 1.0, 1.0]);
                        _vertexCount += 3


                        xPos += xStride
                    }

                    xPos = startingX
                    yPos += (yStride * 2)
                    keepGoingX = true
                    firstPassInRow = true
                }
                print("regenerated vertex data")
            }
            return _vertexData!
        }
    }

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

        self.view.backgroundColor = UIColor.clear

        self.metalInit()
        self.setupPipeline()

        bufferSemaphor = DispatchSemaphore(value: kInflightCommandBuffers)

        timer = CADisplayLink(target: self, selector: #selector(render))
        timer!.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let parentSize = self.view.bounds.size
        let newFrame = CGRect(x: 0, y: 0, width: parentSize.width, height: parentSize.height)
        metalLayer!.frame = newFrame

        // repopulate vertex data for new size
        _vertexData = nil
        let _ = vertexData
        self.setupVertexBuffer()
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

    func setupVertexBuffer() {
        let bufferLength = MemoryLayout<CFloat>.size * vertexData.count
        let dataPtr = UnsafeRawPointer(vertexData)
        vertexBuffer = device!.makeBuffer(bytes: dataPtr, length: bufferLength, options: .cpuCacheModeWriteCombined)
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
        encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: _vertexCount)
        encoder?.endEncoding()

        commandBuffer?.addCompletedHandler({ (buf) in
            self.bufferSemaphor?.signal()
        })

        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }


    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("new touches! \(touches)")
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("moved touches! \(touches)")
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("ended touches! \(touches)")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("cancelled touches! \(touches)")
    }

}

