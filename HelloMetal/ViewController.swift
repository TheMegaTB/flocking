///// Copyright (c) 2018 Razeware LLC
/////
///// Permission is hereby granted, free of charge, to any person obtaining a copy
///// of this software and associated documentation files (the "Software"), to deal
///// in the Software without restriction, including without limitation the rights
///// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
///// copies of the Software, and to permit persons to whom the Software is
///// furnished to do so, subject to the following conditions:
/////
///// The above copyright notice and this permission notice shall be included in
///// all copies or substantial portions of the Software.
/////
///// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
///// distribute, sublicense, create a derivative work, and/or sell copies of the
///// Software in any work that is designed, intended, or marketed for pedagogical or
///// instructional purposes related to programming, coding, application development,
///// or information technology.  Permission for such use, copying, modification,
///// merger, publication, distribution, sublicensing, creation of derivative works,
///// or sale is expressly withheld.
/////
///// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
///// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
///// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
///// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
///// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
///// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
///// THE SOFTWARE.
//
//import UIKit
//import Metal
//import MetalKit
//
////let boidData = Array.init(repeating: 0, count: 15000).map { _ in Boid.random() }
////let boidData = [
////    Boid(position: (0.24, 0.0, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0)),
////    Boid(position: (-0.24, 0.0, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0)),
////    Boid(position: (0, 0.4, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0)),
////    Boid(position: (0, -0.4, 0.0), velocity: (0, 0, 0), acceleration: (0, 0, 0))
////]
////
////let vertexData: [Float] = Array(repeating: 0.0, count: boidData.count * 9)
//
//class ViewController: UIViewController {
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        let flockViewController = FlockViewController()
//        let flockView = flockViewController.view!
//        flockView.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(flockView)
//        view.addConstraints([
//            flockView.topAnchor.constraint(equalTo: view.topAnchor),
//            flockView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            flockView.leftAnchor.constraint(equalTo: view.leftAnchor),
//            flockView.rightAnchor.constraint(equalTo: view.rightAnchor)
//        ])
//
//        let settingsView = SettingsView()
//        settingsView.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(settingsView)
//        view.addConstraints([
//            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            settingsView.leftAnchor.constraint(equalTo: view.leftAnchor),
//            settingsView.rightAnchor.constraint(equalTo: view.rightAnchor),
//            settingsView.heightAnchor.constraint(equalToConstant: 200)
//        ])
//    }
//}
//
//
////import UIKit
////import Metal
////
////let vertexData: [Float] = [
////    0.0,  1.0, 0.0,
////    -1.0, -1.0, 0.0,
////    1.0, -1.0, 0.0
////]
////
////let otherData: [Float] = [
////    0.0, -0.001, 0.0,
////    0.001, 0.0, 0.0,
////    -0.001, 0.0, 0.0
////]
////
////class ViewController: UIViewController {
////    var device: MTLDevice!
////    var metalLayer: CAMetalLayer!
////    var vertexBuffer: MTLBuffer!
////
////    var otherBuffer: MTLBuffer!
////
////    var pipelineState: MTLRenderPipelineState!
////    var computePipelineState: MTLComputePipelineState!
////    var commandQueue: MTLCommandQueue!
////
////    var timer: CADisplayLink!
////
////    override func viewDidLoad() {
////        super.viewDidLoad()
////
////        device = MTLCreateSystemDefaultDevice()
////
////        metalLayer = CAMetalLayer()
////        metalLayer.device = device
////        metalLayer.pixelFormat = .bgra8Unorm
////        metalLayer.framebufferOnly = true
////        metalLayer.frame = view.layer.frame
////        view.layer.addSublayer(metalLayer)
////
////        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
////        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
////
////
////
////        let defaultLibrary = device.makeDefaultLibrary()!
////        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
////        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
////
////        //-- derp
////        let otherDataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
////        otherBuffer = device.makeBuffer(bytes: otherData, length: otherDataSize, options: [])
////
////        let adjustmentFunction = defaultLibrary.makeFunction(name: "adjustment_func")!
////        computePipelineState = try! device.makeComputePipelineState(function: adjustmentFunction)
////        //---
////
////        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
////        pipelineStateDescriptor.vertexFunction = vertexProgram
////        pipelineStateDescriptor.fragmentFunction = fragmentProgram
////        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
////
////        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
////        commandQueue = device.makeCommandQueue()
////
////        timer = CADisplayLink(target: self, selector: #selector(gameloop))
////        timer.add(to: RunLoop.main, forMode: .default)
////    }
////
////    func render() {
////        guard let drawable = metalLayer?.nextDrawable() else { return }
////        let renderPassDescriptor = MTLRenderPassDescriptor()
////        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
////        renderPassDescriptor.colorAttachments[0].loadAction = .clear
////        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
////            red: 0.0,
////            green: 104.0/255.0,
////            blue: 55.0/255.0,
////            alpha: 1.0)
////
////        let commandBuffer = commandQueue.makeCommandBuffer()!
////
////
////        // --derp
////        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
////        computeCommandEncoder.setComputePipelineState(computePipelineState)
////        computeCommandEncoder.setBuffer(vertexBuffer, offset: 0, index: 0)
////        computeCommandEncoder.setBuffer(otherBuffer, offset: 0, index: 1)
////
//////        TODO This may be used to push in user-interaction data e.g. direction of movement
//////        computeCommandEncoder.setBytes(<#T##bytes: UnsafeRawPointer##UnsafeRawPointer#>, length: <#T##Int#>, index: <#T##Int#>)
////
////        computeCommandEncoder.dispatchThreadgroups(MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 3, depth: 1))
////        computeCommandEncoder.endEncoding()
////        // ---
////
////        let renderEncoder = commandBuffer
////            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
////        renderEncoder.label = "Triangle Encoder"
////        renderEncoder.setRenderPipelineState(pipelineState)
////        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
////        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
////        renderEncoder.endEncoding()
////
////        commandBuffer.present(drawable)
////        commandBuffer.commit()
////    }
////
////    @objc func gameloop() {
////        autoreleasepool {
////            self.render()
////        }
////    }
////}
