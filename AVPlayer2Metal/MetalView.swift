//
//  MetalView.swift
//  AVPlayer2Metal
//
//  Created by lisyunn on 2020/12/05.
//

import MetalKit
import CoreVideo
 
final class MetalView: MTKView {
     
    var pixelBuffer: CVPixelBuffer? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private struct VertexData {
        let pos: simd_float4
        let texCoords: simd_float2
    }
     
    private var textureCache: CVMetalTextureCache?
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState
    private var verticesBuffer: MTLBuffer!
    
    required init(coder: NSCoder) {
     
        // Get the default metal device.
        let metalDevice = MTLCreateSystemDefaultDevice()!
     
        // Create a command queue.
        self.commandQueue = metalDevice.makeCommandQueue()!
     
        // Create the metal library containing the shaders
        let bundle = Bundle.main
        let url = bundle.url(forResource: "default", withExtension: "metallib")
        let library = try! metalDevice.makeLibrary(filepath: url!.path)
     
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "DisplayRenderPass Pipeline"
        // Create a function with a specific name.
        pipelineDescriptor.vertexFunction =  library.makeFunction(name: "defaultVertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "defaultFragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Create a  pipeline with the above function.
        self.renderPipelineState = try! metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
      
        
        let vertices: [VertexData] = [
            VertexData(pos: simd_float4(x: -1, y: -1, z: 0, w: 1),
                       texCoords: simd_float2(x: 0, y: 1)),
            VertexData(pos: simd_float4(x: 1, y: -1, z: 0, w: 1),
                       texCoords: simd_float2(x: 1, y: 1)),
            VertexData(pos: simd_float4(x: -1, y: 1, z: 0, w: 1),
                       texCoords: simd_float2(x: 0, y: 0)),
            VertexData(pos: simd_float4(x: 1, y: 1, z: 0, w: 1),
                       texCoords: simd_float2(x: 1, y: 0)),
            ]
        self.verticesBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<VertexData>.stride * vertices.count,
            options: [])
        
        
        // Initialize the cache to convert the pixel buffer into a Metal texture.
        var textCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textCache) != kCVReturnSuccess {
            fatalError("Unable to allocate texture cache.")
        }
        else {
            self.textureCache = textCache
        }
     
        // Initialize super.
        super.init(coder: coder)
     
        // Assign the metal device to this view.
        self.device = metalDevice
     
        // Enable the current drawable texture read/write.
        self.framebufferOnly = false
     
        // Disable drawable auto-resize.
        self.autoResizeDrawable = false
     
        // Set the content mode to aspect fit.
        self.contentMode = .scaleAspectFit
     
        // Change drawing mode based on setNeedsDisplay().
        self.enableSetNeedsDisplay = true
        self.isPaused = true
     
        // Set the content scale factor to the screen scale.
        self.contentScaleFactor = UIScreen.main.scale
     
        // Set the size of the drawable.
        self.drawableSize = CGSize(width: 1920, height: 1080)
    }
    

    private func render(_ view: MTKView) {
     
        // Check if the pixel buffer exists
        guard let pixelBuffer = self.pixelBuffer else { return }
     
        // Get width and height for the pixel buffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
     
        // Converts the pixel buffer in a Metal texture.
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache!, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to create metal texture")
            return
        }
     
        // Check if Core Animation provided a drawable.
        guard let drawable: CAMetalDrawable = self.currentDrawable else { return }
     
        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
//        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
//        renderPassDescriptor.colorAttachments[0].storeAction = .store
//        renderPassDescriptor.colorAttachments[0].clearColor =
//            MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        
        // Create a render command encoder.
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0.0, originY: 0.0,
            width: Double(drawableSize.width), height: Double(drawableSize.height),
            znear: -1.0, zfar: 1.0))
        
        do {
            var texCoordsScales = simd_float2(x: 1, y: 1)
            var scaleFactor = drawableSize.width / CGFloat(inputTexture.width)
            let textureFitHeight = CGFloat(inputTexture.height) * scaleFactor
            if textureFitHeight > drawableSize.height {
                scaleFactor = drawableSize.height / CGFloat(inputTexture.height)
                let textureFitWidth = CGFloat(inputTexture.width) * scaleFactor
                let texCoordsScaleX = textureFitWidth / drawableSize.width
                texCoordsScales.x = Float(texCoordsScaleX)
            } else {
                let texCoordsScaleY = textureFitHeight / drawableSize.height
                texCoordsScales.y = Float(texCoordsScaleY)
            }
            
            renderCommandEncoder.setFragmentBytes(&texCoordsScales,
                                                  length: MemoryLayout<simd_float2>.stride,
                                                  index: 0)
            
            renderCommandEncoder.setFragmentTexture(inputTexture, index: 0)
        }
        
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(self.verticesBuffer, offset: 0, index: 0)
        renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
     
        // End the encoding of the command.
        renderCommandEncoder.endEncoding()
     
        // Register the current drawable for rendering.
        commandBuffer.present(drawable)
     
        // Commit the command buffer for execution.
        commandBuffer.commit()
    }
    
    override func draw(_ rect: CGRect) {
        autoreleasepool {
            if rect.width > 0 && rect.height > 0 {
                self.render(self)
            }
        }
    }
 
}
