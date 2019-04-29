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

let boundaryCorners: [(Float, Float, Float)] = [
    (-1, 1, 1),
    (-1, -1, 1),
    (1, -1, 1),
    (1, 1, 1),
    (-1, 1, -1),
    (1, 1, -1),
    (-1, -1, -1),
    (1, -1, -1)
]

let boundaryEdges: [(Float, Float, Float)] = [
    boundaryCorners[0], boundaryCorners[1],
    boundaryCorners[0], boundaryCorners[3],
    boundaryCorners[0], boundaryCorners[4],

    boundaryCorners[2], boundaryCorners[1],
    boundaryCorners[2], boundaryCorners[3],
    boundaryCorners[2], boundaryCorners[7],

    boundaryCorners[6], boundaryCorners[1],
    boundaryCorners[6], boundaryCorners[4],
    boundaryCorners[6], boundaryCorners[7],

    boundaryCorners[5], boundaryCorners[3],
    boundaryCorners[5], boundaryCorners[4],
    boundaryCorners[5], boundaryCorners[7]
]

let boundaryData: [Float] = boundaryEdges.flatMap { [$0.0, $0.1, $0.2] }

enum BoidSpawnType {
    case single
    case perlin
    case centered
}

enum CursorMode: Equatable {
    case draw
    case spawn(team: UInt32)
}

struct Boid {
    let position: (Float, Float, Float)
    let velocity: (Float, Float, Float)
    let maxVelocity: Float
    let teamID: UInt32

    init(
        position: (Float, Float, Float) = (0, 0, 0),
        velocity: (Float, Float, Float) = (0, 0, 0),
        maxVelocity: Float = 2.1 + pow(Float.random(in: 0...0.75), 2),
        teamID: UInt32 = UInt32.random(in: 0...1)
    ) {
        self.position = position
        self.velocity = velocity
        self.maxVelocity = maxVelocity
        self.teamID = teamID
    }
}

struct VertexIn {
    let position: (Float, Float, Float)
    let speed: Float
    let heading: Float
    let teamID: UInt32

    static var zero: VertexIn {
        return VertexIn(position: (0, 0, 0), speed: 0, heading: 0 , teamID: 0)
    }
}

struct InteractionNode {
    var position: (Float, Float, Float)
    var repulsionStrength: Float
}

struct GlobalSettings {
    let simulationSpeed: Float

    let teamsEnabled: Bool
    let wrapEnabled: Bool

    init(teamsEnabled: Bool = false, wrapEnabled: Bool = false, simulationSpeed: Float = 1.0) {
        self.simulationSpeed = simulationSpeed

        self.teamsEnabled = teamsEnabled
        self.wrapEnabled = wrapEnabled
    }
}

struct TeamSettings {
    let separationRange: Float
    let cohesionRange: Float
    let alignmentRange: Float

    let separationStrength: Float
    let cohesionStrength: Float
    let alignmentStrength: Float
    let teamStrength: Float
    
    let maximumSpeedMultiplier: Float
    let boidSize: Float

    init(
        separationStrength: Float = 1,
        cohesionStrength: Float = 1,
        alignmentStrength: Float = 1,
        teamStrength: Float = 1,

        maximumSpeedMultiplier: Float = 1,
        boidSize: Float = 1,

        separationRange: Float = 1,
        cohesionRange: Float = 1,
        alignmentRange: Float = 1
    ) {
        self.separationStrength = separationStrength
        self.cohesionStrength = cohesionStrength
        self.alignmentStrength = alignmentStrength
        self.teamStrength = teamStrength

        self.maximumSpeedMultiplier = maximumSpeedMultiplier
        self.boidSize = boidSize

        self.separationRange = separationRange
        self.cohesionRange = cohesionRange
        self.alignmentRange = alignmentRange
    }

    static var uniformExplosion: TeamSettings {
        return TeamSettings(
            separationStrength: 2.0,
            cohesionStrength: 0.0,
            alignmentStrength: 0.0,
            teamStrength: 0.0,
            maximumSpeedMultiplier: 1.0
        )
    }

    static var pleasingExplosion: TeamSettings {
        return TeamSettings(
            separationStrength: 1.0,
            cohesionStrength: 0.8,
            alignmentStrength: 1.0,
            teamStrength: 2.9,
            maximumSpeedMultiplier: 1.0
        )
    }

    static var chase: TeamSettings {
        return TeamSettings(
            separationStrength: 2.0,
            cohesionStrength: 0.0,
            alignmentStrength: 0.0,
            teamStrength: -1.5,
            maximumSpeedMultiplier: 1.5,
            boidSize: 3.5
        )
    }

    static var flee: TeamSettings {
        return TeamSettings(
            separationStrength: 1.0,
            cohesionStrength: 1.7,
            alignmentStrength: 1.0,
            teamStrength: 2.0,
            maximumSpeedMultiplier: 1.0,
            boidSize: 0.75
        )
    }
}

class FlockViewController: UIViewController {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue!

    private let pipelineState: MTLRenderPipelineState
    private let boundaryPipelineState: MTLRenderPipelineState
    private let interactionPipelineState: MTLRenderPipelineState
    private let boidGeometryPipelineState: MTLComputePipelineState
    private var boidPipelines: [MTLComputePipelineState] = []

    private var boidData: [Boid]
    private var vertexData: [VertexIn]
    private var interactionData: [InteractionNode] {
        didSet {
            let interactionDataSize = interactionData.count * MemoryLayout.size(ofValue: interactionData[0])
            interactionBuffer = device.makeBuffer(bytes: interactionData, length: interactionDataSize, options: [])
        }
    }

    private var boidBuffer: MTLBuffer!
    private var vertexBuffer: MTLBuffer!
    private var interactionBuffer: MTLBuffer!
    private var boundaryBuffer: MTLBuffer!

    private var globalSettings: GlobalSettings {
        didSet { globalSettingsBuffer = FlockViewController.createGlobalSettingsBuffer(from: globalSettings, on: device) }
    }
    private var globalSettingsBuffer: MTLBuffer

    private var teamSettings: [TeamSettings] {
        didSet { teamSettingsBuffer = FlockViewController.createTeamSettingsBuffer(from: teamSettings, on: device) }
    }
    private var teamSettingsBuffer: MTLBuffer

    private let gpuLockSempahore = DispatchSemaphore(value: 1)

    private var projectionMatrix: Matrix4!

    let metalView: MTKView
    var spawnType: BoidSpawnType = .centered
    var cursorMode: CursorMode = .draw
    var spawnAmount: Int = 50

    public init() {

        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!

        boidData = FlockViewController.generateBoidData(spawnType: spawnType)
        print(boidData.count * 3 * 4)
        vertexData = Array(repeating: 0, count: boidData.count * 3 * 4).map { _ in VertexIn.zero }
        interactionData = [InteractionNode(position: (1, 2, 0), repulsionStrength: 1)]

        globalSettings = GlobalSettings()
        globalSettingsBuffer = FlockViewController.createGlobalSettingsBuffer(from: globalSettings, on: device)

        teamSettings = [
//            .uniformExplosion,
//            .uniformExplosion
            .flee,
            .chase
//            .flee,
//            .flee
        ]
        teamSettingsBuffer = FlockViewController.createTeamSettingsBuffer(from: teamSettings, on: device)

        let boidDataSize = boidData.count * MemoryLayout<Boid>.size
        boidBuffer = device.makeBuffer(bytes: boidData, length: boidDataSize, options: [])

        let vertexDataSize = vertexData.count * MemoryLayout<VertexIn>.size
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexDataSize, options: [])

        let interactionDataSize = interactionData.count * MemoryLayout<InteractionNode>.size
        interactionBuffer = device.makeBuffer(bytes: interactionData, length: interactionDataSize, options: [])

        let boundaryDataSize = boundaryData.count * MemoryLayout<Float>.size
        print(boundaryData.count)
        boundaryBuffer = device.makeBuffer(bytes: boundaryData, length: boundaryDataSize, options: [])

        let defaultLibrary = device.makeDefaultLibrary()!

        let boidGeometryFunction = defaultLibrary.makeFunction(name: "boid_to_triangles")!
        boidGeometryPipelineState = try! device.makeComputePipelineState(function: boidGeometryFunction)

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "boid_vertex")
        pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "boid_fragment")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)

        let interactionPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        interactionPipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "interaction_vertex")
        interactionPipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "interaction_fragment")
        interactionPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.interactionPipelineState = try! device.makeRenderPipelineState(descriptor: interactionPipelineStateDescriptor)

        let boundaryPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        boundaryPipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "boundary_vertex")
        boundaryPipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "boundary_fragment")
        boundaryPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.boundaryPipelineState = try! device.makeRenderPipelineState(descriptor: boundaryPipelineStateDescriptor)

        metalView = MTKView(frame: .zero, device: device)
        metalView.framebufferOnly = false
        metalView.autoResizeDrawable = true

        super.init(nibName: nil, bundle: nil)

        let bounds = UIScreen.main.bounds
        projectionMatrix = Matrix4.makePerspectiveViewAngle(angleRad: Matrix4.degrees(toRad: 85.0), aspectRatio: Float(bounds.size.width / bounds.size.height), nearZ: 0.01, farZ: 100.0)

        try! addBoidPipelineOfFunction(withName: "boid_flocking", inLibrary: defaultLibrary)

        metalView.delegate = self
        metalView.preferredFramesPerSecond = 120
        metalView.clearColor = MTLClearColor(
            red: 38 / 256.0,
            green: 50 / 256.0,
            blue: 56 / 256.0,
            alpha: 1.0)

        setupSettings()

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        metalView.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self

        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinchGesture))
        metalView.addGestureRecognizer(pinchGestureRecognizer)
        pinchGestureRecognizer.delegate = self

        updateWorldModelMatrix()
    }

    private var translation: (Float, Float, Float) = (0, 0, -7) { didSet { updateWorldModelMatrix() }}
    private var rotation: (Float, Float) = (0, 0) { didSet { updateWorldModelMatrix() } }
    private var scale: Float = 3 { didSet { updateWorldModelMatrix() } }
    private var worldModelMatrix = Matrix4()

    func updateWorldModelMatrix() {
        let matrix = Matrix4()
        matrix.translate(translation.0, y: translation.1, z: translation.2)
        matrix.scale(scale, y: scale, z: scale)
        matrix.rotateAroundX(Matrix4.degrees(toRad: rotation.0), y: Matrix4.degrees(toRad: rotation.1), z: 0)
        worldModelMatrix = matrix
    }

    @objc func pinchGesture(recognizer: UIPinchGestureRecognizer) {
        let scale = recognizer.scale
        recognizer.scale = 1
        let delta = (scale - 1) * 0.5
        self.scale *= Float(delta + 1)
    }

    @objc func panGesture(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self.metalView)
        recognizer.setTranslation(CGPoint.zero, in: self.metalView)

        if recognizer.numberOfTouches == 1 {
            rotation = (max(-90, min(rotation.0 + Float(translation.y) * 0.5, 90)), rotation.1 + Float(translation.x) * 0.5)
        } else if recognizer.numberOfTouches == 2 {
            self.translation.0 += Float(translation.x) * 0.01
            self.translation.1 -= Float(translation.y) * 0.01
        }
    }

    @objc func resetBoids() {
        mutateAndReloadBoids { boids in
            boids = FlockViewController.generateBoidData(spawnType: spawnType)
        }
    }

    @objc func reloadBoids() {
        mutateAndReloadBoids()
    }

    func mutateAndReloadBoids(mutator: (inout [Boid]) -> () = { _ in }) {
        // Read boids from buffer
        let boidBufferPointer = boidBuffer.contents().bindMemory(to: Boid.self, capacity: boidData.count)
        let boidBufferContent = UnsafeBufferPointer(start: boidBufferPointer, count: boidData.count)
        boidData = Array(boidBufferContent)

        // Optionally mutate boids
        mutator(&boidData)
        print("Boid count:", boidData.count)

        // Reset boids
        let boidDataSize = boidData.count * MemoryLayout.size(ofValue: boidData[0])
        boidBuffer = device.makeBuffer(bytes: boidData, length: boidDataSize, options: [])

        // Resize vertex buffer
        vertexData = Array(repeating: VertexIn.zero, count: boidData.count * 3 * 4)
        let vertexDataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexDataSize, options: [])
    }

    func spawnBoid(at location: (x: Float, y: Float), teamID: UInt32) {
        mutateAndReloadBoids { boids in
            (0..<spawnAmount).forEach { _ in
                boids.append(Boid(position: (location.x, location.y, 0), teamID: teamID))
            }
        }
    }

    var touchLocation: (x: Float, y: Float)?

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchLocation = nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchInteraction(at: touch.location(in: metalView))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchInteraction(at: touch.location(in: metalView))
    }

    func touchInteraction(at location: CGPoint) {
        let x = location.x / metalView.frame.width * 2 - 1
        let y = -(location.y / metalView.frame.height * 2 - 1)

        touchLocation = (x: Float(x), y: Float(y))

        if cursorMode == .draw {
//            interactionData.append(
//                InteractionNode(position: (Float(x), Float(y), 0), repulsionStrength: 1)
//            )
        }
    }

    func setupSettings() {
        let settingsView = SettingsView(globalSettings: globalSettings, teamSettings: teamSettings)
        settingsView.delegate = self
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsView)
        view.addConstraints([
            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            settingsView.leftAnchor.constraint(equalTo: view.leftAnchor),
            settingsView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])

        let reloadButton = UIButton(type: .system)
        reloadButton.addTarget(self, action: #selector(reloadBoids), for: .touchUpInside)
        reloadButton.setTitle("Reload boids", for: .normal)

        let resetButton = UIButton(type: .system)
        resetButton.addTarget(self, action: #selector(resetBoids), for: .touchUpInside)
        resetButton.setTitle("Respawn boids", for: .normal)

        let buttonStackView = UIStackView(arrangedSubviews: [reloadButton, resetButton])
        buttonStackView.spacing = 10

        let spawnTypeControl = UISegmentedControl(items: ["Xplosion", "Perlin", "Single"])
        spawnTypeControl.selectedSegmentIndex = 0
        spawnTypeControl.addTarget(self, action: #selector(spawnTypeChanged), for: .valueChanged)

        let cursorMode = UISegmentedControl(items: ["Draw", "Spawn #1", "Spawn #2"])
        cursorMode.selectedSegmentIndex = 0
        cursorMode.addTarget(self, action: #selector(cursorModeChanged), for: .valueChanged)

        let paused = UISwitch()
        paused.addTarget(self, action: #selector(pauseChanged), for: .valueChanged)

        let pausedLabel = UILabel()
        pausedLabel.text = "Paused"
        pausedLabel.textColor = .white

        let pauseView = UIStackView(arrangedSubviews: [pausedLabel, paused])
        pauseView.spacing = 10

        let stackView = UIStackView(arrangedSubviews: [buttonStackView, spawnTypeControl, cursorMode, pauseView])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        view.addConstraints([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 10)
        ])
    }

    @objc func pauseChanged(pauseSwitch: UISwitch) {
        metalView.isPaused = pauseSwitch.isOn
    }

    @objc func cursorModeChanged(control: UISegmentedControl) {
        switch control.selectedSegmentIndex {
        case 0:
            cursorMode = .draw
        case 1:
            cursorMode = .spawn(team: 0)
        case 2:
            cursorMode = .spawn(team: 1)
        default:
            break
        }
    }

    @objc func spawnTypeChanged(control: UISegmentedControl) {
        switch control.selectedSegmentIndex {
        case 0:
            spawnType = .centered
        case 1:
            spawnType = .perlin
        case 2:
            spawnType = .single
        default:
            break
        }
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

    static func createGlobalSettingsBuffer(from settings: GlobalSettings, on device: MTLDevice) -> MTLBuffer {
        return device.makeBuffer(bytes: [settings], length: MemoryLayout.stride(ofValue: settings), options: [])!
    }

    static func createTeamSettingsBuffer(from settings: [TeamSettings], on device: MTLDevice) -> MTLBuffer {
        return device.makeBuffer(bytes: settings, length: MemoryLayout.stride(ofValue: settings[0]) * settings.count, options: [])!
    }

    static func generateBoidData(spawnType: BoidSpawnType) -> [Boid] {
        switch spawnType {
        case .single:
            return [
                Boid(position: (0, 0.1, 0), velocity: (0, 0.001, 0)),
                Boid(position: (0, 0, 0), velocity: (0, 0.001, 0))
            ]
        case .centered:
            let delta: Float = 0.0000001 // 0.01
            let teamSizes = [8000, 5]

            let team1 = (0..<teamSizes[0]).map { _ in
                Boid(position: (Float.random(in: -delta...delta), Float.random(in: -delta...delta), Float.random(in: -delta...delta)), teamID: 0)
            }

            let team2 = (0..<teamSizes[1]).map { _ in
                Boid(position: (Float.random(in: -delta...delta), Float.random(in: -delta...delta), Float.random(in: -delta...delta)), teamID: 1)
            }

            return team1 + team2
        case .perlin:
            let gridSize = 15
            let densityMultiplier: Float = 10.0

            let maximumOffset = 2.0 / Float(gridSize) / 2 // width of 2 divide by number of cell-spaces
            let noise = PerlinGenerator()
            noise.octaves = 1
            noise.zoom = 10
            noise.persistence = 0

            var boids: [Boid] = []

            for x in 0..<gridSize {
                for y in 0..<gridSize {
                    for z in 0..<gridSize {
                        let density = abs(noise.perlinNoise(Float(x), y: Float(y), z: Float(z), t: 0))
                        let amountOfBoidsAtCurrentLocation = Int(round(density * densityMultiplier))

                        (0..<amountOfBoidsAtCurrentLocation).forEach { _ in
                            let boidX = Float(x) / Float(gridSize) * 2 - 1 + Float.random(in: -maximumOffset...maximumOffset)
                            let boidY = Float(y) / Float(gridSize) * 2 - 1 + Float.random(in: -maximumOffset...maximumOffset)
                            let boidZ = Float(z) / Float(gridSize) * 2 - 1 + Float.random(in: -maximumOffset...maximumOffset)

                            boids.append(Boid(position: (boidX, boidY, boidZ)))
                        }
                    }
                }
            }

            print("Generated \(boids.count) boids")

            return boids
        }
    }
}

extension FlockViewController: SettingsViewDelegate {
    func settingsView(_ settingsView: SettingsView, didUpdateTeamSettings newSettings: [TeamSettings]) {
        teamSettings = newSettings
    }

    func settingsView(_ settingsView: SettingsView, didUpdateGlobalSettings newSettings: GlobalSettings) {
        globalSettings = newSettings
    }
}

extension FlockViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        draw(in: view)
        return
    }

    func draw(in view: MTKView) {
        gpuLockSempahore.wait()
//        worldModelMatrix.rotateAroundX(Matrix4.degrees(toRad: 0.25), y: 0, z: 0)

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
        boidGeometryCommandEncoder.setBuffer(teamSettingsBuffer, offset: 0, index: 2)
        boidGeometryCommandEncoder.setBytes(&boidCount, length: MemoryLayout.size(ofValue: boidCount), index: 3)

        let (threadsPerGrid, threadsPerThreadgroup) = gridParams(for: boidGeometryPipelineState)
        boidGeometryCommandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        boidGeometryCommandEncoder.endEncoding()

        // Prepare for rendering
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
//        renderEncoder.setCullMode(MTLCullMode.back)
//        renderEncoder.setDepthStencilState(<#T##depthStencilState: MTLDepthStencilState?##MTLDepthStencilState?#>)

        // Render triangles
        renderEncoder.label = "Triangle Encoder"
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes([worldModelMatrix.raw()], length: MemoryLayout<Float>.size * Matrix4.numberOfElements, index: 1)
        renderEncoder.setVertexBytes([projectionMatrix.raw()], length: MemoryLayout<Float>.size * Matrix4.numberOfElements, index: 2)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: boidData.count * 3 * 4, instanceCount: 1)

        // Render interactionNodes
        renderEncoder.label = "Interaction Encoder"
        renderEncoder.setRenderPipelineState(interactionPipelineState)
        renderEncoder.setVertexBuffer(interactionBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes([worldModelMatrix.raw()], length: MemoryLayout<Float>.size * Matrix4.numberOfElements, index: 1)
        renderEncoder.setVertexBytes([projectionMatrix.raw()], length: MemoryLayout<Float>.size * Matrix4.numberOfElements, index: 2)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: interactionData.count, instanceCount: 1)

        // Render boundary
        renderEncoder.label = "Boundary Encoder"
        renderEncoder.setRenderPipelineState(boundaryPipelineState)
        renderEncoder.setVertexBuffer(boundaryBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes([worldModelMatrix.raw()], length: MemoryLayout<Float>.size * Matrix4.numberOfElements, index: 1)
        renderEncoder.setVertexBytes([projectionMatrix.raw()], length: MemoryLayout<Float>.size * Matrix4.numberOfElements, index: 2)
        renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: boundaryData.count / 3, instanceCount: 1)

        // Finish up
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { _ in
            if let touchLocation = self.touchLocation {
                switch self.cursorMode {
                case .spawn(let team):
                    self.spawnBoid(at: touchLocation, teamID: team)
                default:
                    break
                }
            }
            self.gpuLockSempahore.signal()
        }
        commandBuffer.commit()
    }

    func encodeBoidPipelines(onCommandBuffer commandBuffer: MTLCommandBuffer) {
        var boidCount: UInt = UInt(boidData.count)
        var interactionCount: UInt = UInt(interactionData.count)

        boidPipelines.forEach { boidPipeline in
            let boidFlockingCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
            boidFlockingCommandEncoder.setComputePipelineState(boidPipeline)

            boidFlockingCommandEncoder.setBuffer(boidBuffer, offset: 0, index: 0)
            boidFlockingCommandEncoder.setBytes(&boidCount, length: MemoryLayout.size(ofValue: boidCount), index: 1)
            boidFlockingCommandEncoder.setBuffer(interactionBuffer, offset: 0, index: 2)
            boidFlockingCommandEncoder.setBytes(&interactionCount, length: MemoryLayout.size(ofValue: interactionCount), index: 3)
            boidFlockingCommandEncoder.setBuffer(globalSettingsBuffer, offset: 0, index: 4)
            boidFlockingCommandEncoder.setBuffer(teamSettingsBuffer, offset: 0, index: 5)

            let (threadsPerGrid, threadsPerThreadgroup) = gridParams(for: boidPipeline)
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

extension FlockViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
