/// Copyright (c) 2018 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Metal
import MetalKit

struct Boid {
    let position: (Float, Float, Float)
    let velocity: (Float, Float, Float)
    let acceleration: (Float, Float, Float)

    static func random() -> Boid {
        return Boid(
            position: (Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1)),
            velocity: (0, 0, 0), // (Float.random(in: -0.01...0.01), Float.random(in: -0.01...0.01), Float.random(in: -0.01...0.01)),
            acceleration: (0, 0, 0)
        )
    }
}

struct Settings {
    let separationRange: Float = 0.1
    let cohesionRange: Float = 0.1
    let alignmentRange: Float = 0.1

    let separationStrength: Float = 0.001
    let cohesionStrength: Float = 0.001
    let alignmentStrength: Float = 0.001
}

//let boidData = Array.init(repeating: 0, count: 15000).map { _ in Boid.random() }
//let boidData = [
//    Boid(position: (0.24, 0.0, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0)),
//    Boid(position: (-0.24, 0.0, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0)),
//    Boid(position: (0, 0.4, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0)),
//    Boid(position: (0, -0.4, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0))
//]
//
//let vertexData: [Float] = Array(repeating: 0.0, count: boidData.count * 9)

class ViewController: UIViewController {
    lazy var boidData: [Boid] = {
        let gridSize = 50
        let densityMultiplier: Float = 10.0

        let maximumOffset = 2.0 / Float(gridSize) / 2 // width of 2 divide by number of cell-spaces
        let noise = PerlinGenerator()
        noise.octaves = 1
        noise.zoom = 10
        noise.persistence = 0

        var boids: [Boid] = []

        for x in 0..<gridSize {
            for y in 0..<gridSize {
                let density = abs(noise.perlinNoise(Float(x), y: Float(y), z: 0, t: 0))
                let amountOfBoidsAtCurrentLocation = Int(round(density * densityMultiplier))

                (0..<amountOfBoidsAtCurrentLocation).forEach { _ in
                    let boidX = Float(x) / Float(gridSize) * 2 - 1 + Float.random(in: -maximumOffset...maximumOffset)
                    let boidY = Float(y) / Float(gridSize) * 2 - 1 + Float.random(in: -maximumOffset...maximumOffset)

                    boids.append(
                        Boid(
                            position: (boidX, boidY, 0),
                            velocity: (0, 0, 0),
                            acceleration: (0, 0, 0)
                        )
                    )
                }
            }
        }

        print("Generated \(boids.count) boids")

        return boids
    }()

    lazy var vertexData: [Float] = {
        return Array(repeating: 0.0, count: boidData.count * 9)
    }()

    var device: MTLDevice!
    var metalLayer: CAMetalLayer!

    var boidBuffer: MTLBuffer!
    var vertexBuffer: MTLBuffer!

    var pipelineState: MTLRenderPipelineState!
    var boidGeometryPipelineState: MTLComputePipelineState!

    var boidPipelines: [MTLComputePipelineState] = []

    var commandQueue: MTLCommandQueue!

    var timer: CADisplayLink!

    var settings = Settings() {
        didSet {
            settingsBuffer = createSettingsBuffer(from: settings)
        }
    }

    lazy var settingsBuffer: MTLBuffer = {
        return createSettingsBuffer(from: settings)
    }()

    func createSettingsBuffer(from settings: Settings) -> MTLBuffer {
        return device.makeBuffer(bytes: [settings], length: MemoryLayout.size(ofValue: settings), options: [])!
    }

    func addBoidPipelineOfFunction(withName name: String, inLibrary library: MTLLibrary) throws {
        let boidFunction = library.makeFunction(name: name)!
        boidPipelines.append(try device.makeComputePipelineState(function: boidFunction))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let settingsView = SettingsView()
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsView)
        view.addConstraints([
            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            settingsView.leftAnchor.constraint(equalTo: view.leftAnchor),
            settingsView.rightAnchor.constraint(equalTo: view.rightAnchor),
            settingsView.heightAnchor.constraint(equalToConstant: 200)
        ])

        device = MTLCreateSystemDefaultDevice()

        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)

        let boidDataSize = boidData.count * MemoryLayout.size(ofValue: boidData[0])
        boidBuffer = device.makeBuffer(bytes: boidData, length: boidDataSize, options: [])

        let vertexDataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexDataSize, options: [])

        let defaultLibrary = device.makeDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "boid_fragment")
        let vertexProgram = defaultLibrary.makeFunction(name: "boid_vertex")

        //-- derp

        let boidGeometryFunction = defaultLibrary.makeFunction(name: "boid_to_triangles")!
        boidGeometryPipelineState = try! device.makeComputePipelineState(function: boidGeometryFunction)

        try! addBoidPipelineOfFunction(withName: "boid_wraparound", inLibrary: defaultLibrary)
        try! addBoidPipelineOfFunction(withName: "boid_alignment", inLibrary: defaultLibrary)
        try! addBoidPipelineOfFunction(withName: "boid_cohesion", inLibrary: defaultLibrary)
        try! addBoidPipelineOfFunction(withName: "boid_separation", inLibrary: defaultLibrary)
        try! addBoidPipelineOfFunction(withName: "boid_movement", inLibrary: defaultLibrary)
        //---

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        commandQueue = device.makeCommandQueue()

        timer = CADisplayLink(target: self, selector: #selector(gameloop))
        timer.add(to: RunLoop.main, forMode: .default)
    }

    func gridParams(for pipelineState: MTLComputePipelineState) -> (threadsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize) {
        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)

        let sideLength = Int(ceil(sqrt(Float(boidData.count))))
        let threadsPerGrid = MTLSize(width: sideLength,
                                     height: sideLength,
                                     depth: 1)

        return (threadsPerGrid: threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    func render() {
        guard let drawable = metalLayer?.nextDrawable() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 1.0,
            green: 241.0 / 256.0,
            blue: 170.0 / 256.0,
            alpha: 1.0)

        let commandBuffer = commandQueue.makeCommandBuffer()!

        // Boid flocking
        encodeBoidPipelines(onCommandBuffer: commandBuffer)

        // Boid geometry
        var boidCount: UInt = UInt(boidData.count)
        let boidGeometryCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        boidGeometryCommandEncoder.setComputePipelineState(boidGeometryPipelineState)
        boidGeometryCommandEncoder.setBuffer(vertexBuffer, offset: 0, index: 0)
        boidGeometryCommandEncoder.setBuffer(boidBuffer, offset: 0, index: 1)
        boidGeometryCommandEncoder.setBytes(&boidCount, length: MemoryLayout.size(ofValue: boidCount), index: 2)

        let (threadsPerGrid, threadsPerThreadgroup) = gridParams(for: boidGeometryPipelineState)
        boidGeometryCommandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        boidGeometryCommandEncoder.endEncoding()

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "Triangle Encoder"
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: boidData.count * 3, instanceCount: 1)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func encodeBoidPipelines(onCommandBuffer commandBuffer: MTLCommandBuffer) {
        var boidCount: UInt = UInt(boidData.count)

        boidPipelines.forEach { boidPipeline in
            let boidFlockingCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
            boidFlockingCommandEncoder.setComputePipelineState(boidPipeline)

            boidFlockingCommandEncoder.setBuffer(boidBuffer, offset: 0, index: 0)
            boidFlockingCommandEncoder.setBytes(&boidCount, length: MemoryLayout.size(ofValue: boidCount), index: 1)
            boidFlockingCommandEncoder.setBuffer(settingsBuffer, offset: 0, index: 2)

            let (threadsPerGrid, threadsPerThreadgroup) = gridParams(for: boidGeometryPipelineState)
            boidFlockingCommandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            boidFlockingCommandEncoder.endEncoding()
        }
    }

    @objc func gameloop() {
        autoreleasepool {
            self.render()
        }
    }
}


//import UIKit
//import Metal
//
//let vertexData: [Float] = [
//    0.0,  1.0, 0.0,
//    -1.0, -1.0, 0.0,
//    1.0, -1.0, 0.0
//]
//
//let otherData: [Float] = [
//    0.0, -0.001, 0.0,
//    0.001, 0.0, 0.0,
//    -0.001, 0.0, 0.0
//]
//
//class ViewController: UIViewController {
//    var device: MTLDevice!
//    var metalLayer: CAMetalLayer!
//    var vertexBuffer: MTLBuffer!
//
//    var otherBuffer: MTLBuffer!
//
//    var pipelineState: MTLRenderPipelineState!
//    var computePipelineState: MTLComputePipelineState!
//    var commandQueue: MTLCommandQueue!
//
//    var timer: CADisplayLink!
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        device = MTLCreateSystemDefaultDevice()
//
//        metalLayer = CAMetalLayer()
//        metalLayer.device = device
//        metalLayer.pixelFormat = .bgra8Unorm
//        metalLayer.framebufferOnly = true
//        metalLayer.frame = view.layer.frame
//        view.layer.addSublayer(metalLayer)
//
//        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
//        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
//
//
//
//        let defaultLibrary = device.makeDefaultLibrary()!
//        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
//        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
//
//        //-- derp
//        let otherDataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
//        otherBuffer = device.makeBuffer(bytes: otherData, length: otherDataSize, options: [])
//
//        let adjustmentFunction = defaultLibrary.makeFunction(name: "adjustment_func")!
//        computePipelineState = try! device.makeComputePipelineState(function: adjustmentFunction)
//        //---
//
//        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
//        pipelineStateDescriptor.vertexFunction = vertexProgram
//        pipelineStateDescriptor.fragmentFunction = fragmentProgram
//        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
//
//        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
//        commandQueue = device.makeCommandQueue()
//
//        timer = CADisplayLink(target: self, selector: #selector(gameloop))
//        timer.add(to: RunLoop.main, forMode: .default)
//    }
//
//    func render() {
//        guard let drawable = metalLayer?.nextDrawable() else { return }
//        let renderPassDescriptor = MTLRenderPassDescriptor()
//        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
//        renderPassDescriptor.colorAttachments[0].loadAction = .clear
//        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
//            red: 0.0,
//            green: 104.0/255.0,
//            blue: 55.0/255.0,
//            alpha: 1.0)
//
//        let commandBuffer = commandQueue.makeCommandBuffer()!
//
//
//        // --derp
//        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
//        computeCommandEncoder.setComputePipelineState(computePipelineState)
//        computeCommandEncoder.setBuffer(vertexBuffer, offset: 0, index: 0)
//        computeCommandEncoder.setBuffer(otherBuffer, offset: 0, index: 1)
//
////        TODO This may be used to push in user-interaction data e.g. direction of movement
////        computeCommandEncoder.setBytes(<#T##bytes: UnsafeRawPointer##UnsafeRawPointer#>, length: <#T##Int#>, index: <#T##Int#>)
//
//        computeCommandEncoder.dispatchThreadgroups(MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 3, depth: 1))
//        computeCommandEncoder.endEncoding()
//        // ---
//
//        let renderEncoder = commandBuffer
//            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
//        renderEncoder.label = "Triangle Encoder"
//        renderEncoder.setRenderPipelineState(pipelineState)
//        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
//        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
//        renderEncoder.endEncoding()
//
//        commandBuffer.present(drawable)
//        commandBuffer.commit()
//    }
//
//    @objc func gameloop() {
//        autoreleasepool {
//            self.render()
//        }
//    }
//}
