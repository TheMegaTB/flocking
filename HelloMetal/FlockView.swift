/// Copyright (c) 2019 Razeware LLC
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
    let separationRange: Float
    let cohesionRange: Float
    let alignmentRange: Float

    let separationStrength: Float
    let cohesionStrength: Float
    let alignmentStrength: Float

    init(
        separationStrength: Float = 0.001,
        cohesionStrength: Float = 0.001,
        alignmentStrength: Float = 0.001,

        separationRange: Float = 0.01,
        cohesionRange: Float = 0.05,
        alignmentRange: Float = 0.04
    ) {
        self.separationStrength = separationStrength
        self.cohesionStrength = cohesionStrength
        self.alignmentStrength = alignmentStrength

        self.separationRange = separationRange
        self.cohesionRange = cohesionRange
        self.alignmentRange = alignmentRange
    }
}

class FlockViewController: UIViewController {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue!

    private let pipelineState: MTLRenderPipelineState!
    private let boidGeometryPipelineState: MTLComputePipelineState!
    private var boidPipelines: [MTLComputePipelineState] = []

    private let boidData: [Boid]
    private let vertexData: [Float]

    private var boidBuffer: MTLBuffer!
    private var vertexBuffer: MTLBuffer!

    private var settings: Settings {
        didSet { settingsBuffer = FlockViewController.createSettingsBuffer(from: settings, on: device) }
    }
    private var settingsBuffer: MTLBuffer

    let metalView: MTKView

    public init() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!

        boidData = FlockViewController.generateBoidData()
        vertexData = Array(repeating: 0.0, count: boidData.count * 9)

        settings = Settings()
        settingsBuffer = FlockViewController.createSettingsBuffer(from: settings, on: device)

        let boidDataSize = boidData.count * MemoryLayout.size(ofValue: boidData[0])
        boidBuffer = device.makeBuffer(bytes: boidData, length: boidDataSize, options: [])

        let vertexDataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexDataSize, options: [])

        let defaultLibrary = device.makeDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "boid_fragment")
        let vertexProgram = defaultLibrary.makeFunction(name: "boid_vertex")

        let boidGeometryFunction = defaultLibrary.makeFunction(name: "boid_to_triangles")!
        boidGeometryPipelineState = try! device.makeComputePipelineState(function: boidGeometryFunction)

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)

        metalView = MTKView(frame: .zero, device: device)
        metalView.framebufferOnly = false
        metalView.autoResizeDrawable = true

        super.init(nibName: nil, bundle: nil)

//        try! addBoidPipelineOfFunction(withName: "boid_wraparound", inLibrary: defaultLibrary)
//        try! addBoidPipelineOfFunction(withName: "boid_alignment", inLibrary: defaultLibrary)
//        try! addBoidPipelineOfFunction(withName: "boid_cohesion", inLibrary: defaultLibrary)
//        try! addBoidPipelineOfFunction(withName: "boid_separation", inLibrary: defaultLibrary)
//        try! addBoidPipelineOfFunction(withName: "boid_movement", inLibrary: defaultLibrary)
        try! addBoidPipelineOfFunction(withName: "boid_flocking", inLibrary: defaultLibrary)

        metalView.delegate = self
        metalView.preferredFramesPerSecond = 120
        metalView.clearColor = MTLClearColor(
                    red: 1.0,
                    green: 241.0 / 256.0,
                    blue: 170.0 / 256.0,
                    alpha: 1.0)

//        setupSettings()
    }

    func setupSettings() {
        let settingsView = SettingsView(settings: settings)
        settingsView.delegate = self
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsView)
        view.addConstraints([
            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            settingsView.leftAnchor.constraint(equalTo: view.leftAnchor),
            settingsView.rightAnchor.constraint(equalTo: view.rightAnchor),
            settingsView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = metalView
    }

    func addBoidPipelineOfFunction(withName name: String, inLibrary library: MTLLibrary) throws {
        let boidFunction = library.makeFunction(name: name)!
        boidPipelines.append(try device.makeComputePipelineState(function: boidFunction))
    }

    static func createSettingsBuffer(from settings: Settings, on device: MTLDevice) -> MTLBuffer {
        return device.makeBuffer(bytes: [settings], length: MemoryLayout.size(ofValue: settings), options: [])!
    }

    static func generateBoidData() -> [Boid] {
        let delta: Float = 0.01

        return (0..<10000).map { _ in
            Boid(
                position: (Float.random(in: -delta...delta), Float.random(in: -delta...delta), 0),
                velocity: (0, 0, 0),
                acceleration: (0, 0, 0)
            )
        }

//        return [
//            Boid(position: (0.05, 0, 0), velocity: (0, 0, 0), acceleration: (0, 0, 0)),
//            Boid(position: (-0.05, 0, 0), velocity: (0, 0.001, 0), acceleration: (0, 0, 0))
//        ]

        let gridSize = 50
        let densityMultiplier: Float = 20.0

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
    }
}

extension FlockViewController: SettingsViewDelegate {
    func settingsView(_ settingsView: SettingsView, didUpdateSettings newSettings: Settings) {
        self.settings = newSettings
    }
}

extension FlockViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        draw(in: view)
        return
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }

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

        // Render triangles
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "Triangle Encoder"
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: boidData.count * 3, instanceCount: 1)
        renderEncoder.endEncoding()

        // Finish up
        commandBuffer.present(drawable)
        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
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
}
