import Foundation
import AppKit
import CoreGraphics

/// Tool for composing images from components (images, color blocks, text)
public struct ImageComposerTool: AgentTool {
    public static let toolName = "image_composer"
    public static let toolDescription = "Compose images by combining multiple elements: images, color blocks, text, and shapes"
    
    public static let inputSchema: ToolInputSchema = ToolInputSchema(
        properties: [
            "canvas": PropertySchema(
                type: "object",
                description: "Canvas dimensions and background"
            ),
            "layers": PropertySchema(
                type: "array",
                description: "Array of layers to compose (bottom to top)",
                items: PropertySchema(type: "object")
            ),
            "output_format": PropertySchema(
                type: "string",
                description: "Output format: png, jpeg, tiff",
                defaultValue: "png"
            ),
            "output_path": PropertySchema(
                type: "string",
                description: "Path to save the composed image (optional, will use temp if not provided)"
            )
        ],
        required: ["canvas", "layers"],
        description: "Compose an image from multiple layers"
    )
    
    public static let outputSchema: ToolOutputSchema = ToolOutputSchema(
        properties: [
            "success": PropertySchema(type: "boolean"),
            "output_path": PropertySchema(type: "string", description: "Path to the composed image file"),
            "width": PropertySchema(type: "integer"),
            "height": PropertySchema(type: "integer")
        ],
        description: "Result of image composition"
    )
    
    public init() {}
    
    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        // Parse input
        guard let inputData = input.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
            throw ToolError.invalidInput("Could not parse input JSON")
        }
        
        // Validate canvas
        guard let canvasDict = params["canvas"] as? [String: Any],
              let width = canvasDict["width"] as? Int,
              let height = canvasDict["height"] as? Int else {
            throw ToolError.missingRequiredParameter("canvas.width and canvas.height")
        }
        
        // Get layers
        guard let layersArray = params["layers"] as? [[String: Any]] else {
            throw ToolError.missingRequiredParameter("layers")
        }
        
        let outputFormat = params["output_format"] as? String ?? "png"
        let customOutputPath = params["output_path"] as? String
        
        // Report starting
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .starting,
            message: "Starting image composition: \(width)x\(height) with \(layersArray.count) layers"
        ))
        
        // Create canvas
        let canvasSize = NSSize(width: width, height: height)
        let canvas = NSImage(size: canvasSize)
        
        canvas.lockFocus()
        defer { canvas.unlockFocus() }
        
        // Draw background
        if let backgroundColor = canvasDict["background_color"] as? String {
            let color = parseColor(backgroundColor) ?? NSColor.white
            color.setFill()
            NSRect(origin: .zero, size: canvasSize).fill()
        } else {
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: canvasSize).fill()
        }
        
        // Draw each layer
        for (index, layerDict) in layersArray.enumerated() {
            try? await context.statusReporter.reportProgress(
                fractionCompleted: Double(index) / Double(layersArray.count),
                message: "Processing layer \(index + 1) of \(layersArray.count)"
            )
            
            try await drawLayer(layerDict, on: canvasSize, context: context)
        }
        
        // Save output
        let outputPath: String
        if let customPath = customOutputPath {
            outputPath = customPath
        } else {
            let tempFile = try await context.serviceProvider.getFileManager()
                .createTempFile(prefix: "composed_", suffix: ".\(outputFormat)")
            outputPath = tempFile.path
        }
        
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Convert to bitmap representation and save
        guard let tiffData = canvas.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ToolError.executionFailed("Failed to create bitmap representation")
        }
        
        let imageData: Data?
        switch outputFormat.lowercased() {
        case "png":
            imageData = bitmap.representation(using: .png, properties: [:])
        case "jpeg", "jpg":
            let compression = (params["jpeg_quality"] as? CGFloat) ?? 0.9
            imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
        case "tiff":
            imageData = bitmap.representation(using: .tiff, properties: [:])
        default:
            imageData = bitmap.representation(using: .png, properties: [:])
        }
        
        guard let finalData = imageData else {
            throw ToolError.executionFailed("Failed to encode image to \(outputFormat)")
        }
        
        try await context.serviceProvider.getFileManager().write(data: finalData, to: outputURL)
        
        // Report completion
        try? await context.statusReporter.report(status: ToolExecutionStatus(
            executionId: context.executionId,
            state: .completed,
            message: "Image composed and saved to \(outputPath)"
        ))
        
        try? await context.statusReporter.reportIntermediateResult(IntermediateResult(
            type: "image",
            filePath: outputPath,
            metadata: ["width": "\(width)", "height": "\(height)", "layers": "\(layersArray.count)"]
        ))
        
        // Return result
        let result: [String: Any] = [
            "success": true,
            "output_path": outputPath,
            "width": width,
            "height": height,
            "format": outputFormat
        ]
        
        let resultData = try JSONSerialization.data(withJSONObject: result)
        return String(data: resultData, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Private Drawing Methods
    
    private func drawLayer(_ layer: [String: Any], on canvasSize: NSSize, context: ToolExecutionContext) async throws {
        guard let type = layer["type"] as? String else {
            throw ToolError.invalidInput("Layer missing 'type' field")
        }
        
        let x = (layer["x"] as? CGFloat) ?? 0
        let y = (layer["y"] as? CGFloat) ?? 0
        let rect = NSRect(x: x, y: y, width: canvasSize.width, height: canvasSize.height)
        
        switch type {
        case "image":
            try await drawImageLayer(layer, in: rect, context: context)
            
        case "color_block", "rectangle":
            drawColorBlockLayer(layer, in: rect)
            
        case "text":
            drawTextLayer(layer, in: rect)
            
        case "gradient":
            drawGradientLayer(layer, in: rect)
            
        default:
            throw ToolError.invalidInput("Unknown layer type: \(type)")
        }
    }
    
    private func drawImageLayer(_ layer: [String: Any], in rect: NSRect, context: ToolExecutionContext) async throws {
        guard let imagePath = layer["path"] as? String else {
            throw ToolError.missingRequiredParameter("layer.path for image layer")
        }
        
        let imageURL = URL(fileURLWithPath: imagePath)
        let fileManager = context.serviceProvider.getFileManager()
        
        guard await fileManager.exists(at: imageURL) else {
            throw ToolError.fileError(NSError(domain: "ImageComposerTool", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Image not found at \(imagePath)"
            ]))
        }
        
        let imageData = try await fileManager.read(from: imageURL)
        guard let image = NSImage(data: imageData) else {
            throw ToolError.executionFailed("Could not load image from \(imagePath)")
        }
        
        // Calculate target rect
        let targetWidth = (layer["width"] as? CGFloat) ?? rect.width
        let targetHeight = (layer["height"] as? CGFloat) ?? rect.height
        
        let contentMode = layer["content_mode"] as? String ?? "aspectFit" // aspectFit, aspectFill, stretch, center
        let targetRect = calculateContentRect(
            contentSize: image.size,
            containerRect: NSRect(x: rect.minX, y: rect.minY, width: targetWidth, height: targetHeight),
            contentMode: contentMode
        )
        
        // Draw image
        image.draw(in: targetRect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
    }
    
    private func drawColorBlockLayer(_ layer: [String: Any], in rect: NSRect) {
        guard let colorString = layer["color"] as? String else {
            return
        }
        
        let color = parseColor(colorString) ?? NSColor.black
        
        let width = (layer["width"] as? CGFloat) ?? rect.width
        let height = (layer["height"] as? CGFloat) ?? rect.height
        let blockRect = NSRect(x: rect.minX, y: rect.minY, width: width, height: height)
        
        // Handle corner radius
        if let cornerRadius = layer["corner_radius"] as? CGFloat, cornerRadius > 0 {
            let path = NSBezierPath(roundedRect: blockRect, xRadius: cornerRadius, yRadius: cornerRadius)
            color.setFill()
            path.fill()
        } else {
            color.setFill()
            blockRect.fill()
        }
    }
    
    private func drawTextLayer(_ layer: [String: Any], in rect: NSRect) {
        guard let text = layer["text"] as? String else {
            return
        }
        
        let color: NSColor
        if let colorString = layer["color"] as? String {
            color = parseColor(colorString) ?? NSColor.black
        } else {
            color = NSColor.black
        }
        let fontSize = (layer["font_size"] as? CGFloat) ?? 24.0
        let fontName = layer["font"] as? String ?? "Helvetica"
        
        let font: NSFont
        if let customFont = NSFont(name: fontName, size: fontSize) {
            font = customFont
        } else {
            font = NSFont.systemFont(ofSize: fontSize)
        }
        
        let width = (layer["width"] as? CGFloat) ?? rect.width
        let height = (layer["height"] as? CGFloat) ?? rect.height
        let textRect = NSRect(x: rect.minX, y: rect.minY, width: width, height: height)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = parseTextAlignment(layer["alignment"] as? String)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(in: textRect)
    }
    
    private func drawGradientLayer(_ layer: [String: Any], in rect: NSRect) {
        guard let colors = layer["colors"] as? [String], colors.count >= 2 else {
            return
        }
        
        let nsColors = colors.compactMap { parseColor($0) }
        guard nsColors.count >= 2 else { return }
        
        let direction = layer["direction"] as? String ?? "vertical" // vertical, horizontal, diagonal
        
        let gradient = NSGradient(colors: nsColors)
        
        let startPoint: NSPoint
        let endPoint: NSPoint
        
        switch direction {
        case "horizontal":
            startPoint = NSPoint(x: rect.minX, y: rect.midY)
            endPoint = NSPoint(x: rect.maxX, y: rect.midY)
        case "diagonal":
            startPoint = NSPoint(x: rect.minX, y: rect.minY)
            endPoint = NSPoint(x: rect.maxX, y: rect.maxY)
        default: // vertical
            startPoint = NSPoint(x: rect.midX, y: rect.minY)
            endPoint = NSPoint(x: rect.midX, y: rect.maxY)
        }
        
        gradient?.draw(from: startPoint, to: endPoint, options: .drawsBeforeStartingLocation)
    }
    
    // MARK: - Helper Methods
    
    private func parseColor(_ string: String) -> NSColor? {
        // Handle hex colors (#RRGGBB or #RRGGBBAA)
        if string.hasPrefix("#") {
            let hex = String(string.dropFirst())
            var rgb: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgb)
            
            let r, g, b, a: CGFloat
            switch hex.count {
            case 6:
                r = CGFloat((rgb >> 16) & 0xFF) / 255.0
                g = CGFloat((rgb >> 8) & 0xFF) / 255.0
                b = CGFloat(rgb & 0xFF) / 255.0
                a = 1.0
            case 8:
                r = CGFloat((rgb >> 24) & 0xFF) / 255.0
                g = CGFloat((rgb >> 16) & 0xFF) / 255.0
                b = CGFloat((rgb >> 8) & 0xFF) / 255.0
                a = CGFloat(rgb & 0xFF) / 255.0
            default:
                return nil
            }
            
            return NSColor(red: r, green: g, blue: b, alpha: a)
        }
        
        // Handle named colors
        switch string.lowercased() {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "magenta": return .magenta
        case "orange": return .orange
        case "purple": return .purple
        case "gray", "grey": return .gray
        case "clear", "transparent": return .clear
        default: return nil
        }
    }
    
    private func parseTextAlignment(_ string: String?) -> NSTextAlignment {
        switch string?.lowercased() {
        case "center": return .center
        case "right": return .right
        case "justified": return .justified
        default: return .left
        }
    }
    
    private func calculateContentRect(contentSize: NSSize, containerRect: NSRect, contentMode: String) -> NSRect {
        switch contentMode {
        case "stretch":
            return containerRect
            
        case "aspectFit":
            let scale = min(containerRect.width / contentSize.width, containerRect.height / contentSize.height)
            let newWidth = contentSize.width * scale
            let newHeight = contentSize.height * scale
            let x = containerRect.midX - newWidth / 2
            let y = containerRect.midY - newHeight / 2
            return NSRect(x: x, y: y, width: newWidth, height: newHeight)
            
        case "aspectFill":
            let scale = max(containerRect.width / contentSize.width, containerRect.height / contentSize.height)
            let newWidth = contentSize.width * scale
            let newHeight = contentSize.height * scale
            let x = containerRect.midX - newWidth / 2
            let y = containerRect.midY - newHeight / 2
            return NSRect(x: x, y: y, width: newWidth, height: newHeight)
            
        case "center":
            let x = containerRect.midX - contentSize.width / 2
            let y = containerRect.midY - contentSize.height / 2
            return NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)
            
        default:
            return containerRect
        }
    }
}

