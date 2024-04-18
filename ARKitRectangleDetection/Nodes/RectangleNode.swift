import UIKit
import SceneKit
import ARKit

private let meters2inches = CGFloat(39.3701)

class RectangleNode: SCNNode {
    
    convenience init(_ planeRectangle: PlaneRectangle, stressData: [Float]) {
        self.init(center: planeRectangle.position,
                  width: planeRectangle.size.width,
                  height: planeRectangle.size.height,
                  orientation: planeRectangle.orientation,
                  stressData: stressData)
    }
    
    init(center position: SCNVector3, width: CGFloat, height: CGFloat, orientation: Float, stressData: [Float]) {
        super.init()
        
        // Debug
        print("position: \(position) width: \(width) (\(width * meters2inches) inches) height: \(height) (\(height * meters2inches) inches)")
        
        // Create the 3D plane geometry with the dimensions calculated from corners
        let planeGeometry = SCNPlane(width: width, height: height)
        let rectNode = SCNNode(geometry: planeGeometry)

        // Set rotation to make the plane horizontal
        var transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        transform = SCNMatrix4Rotate(transform, orientation, 0, 0, 1)
        rectNode.transform = transform
        
//        // Create heatmap texture from stress data
        let material = SCNMaterial()
        let texture = SKTexture(image: createHeatmapTexture(width: Int(width * meters2inches), height: Int(height * meters2inches), data: stressData))
        texture.filteringMode = .nearest
        material.diffuse.contents = texture
        material.isDoubleSided = true
        material.transparency = CGFloat(0.9)
        
        
        planeGeometry.materials = [material]
        
        self.addChildNode(rectNode)
        self.position = position
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createHeatmapTexture(width: Int, height: Int, data: [Float]) -> UIImage {
        let cols = 32
        let rows = 24

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1  // Ensures one-to-one pixel rendering
        rendererFormat.opaque = true
        
        let rendererSize = CGSize(width: cols, height: rows)
        let renderer = UIGraphicsImageRenderer(size: rendererSize, format: rendererFormat)
        
        let image = renderer.image { ctx in
            let context = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let index = row * cols + col
                    let value = data.safeIndex(index) ?? 0
                    let color = valueToColor(value: value, minValue: 0, maxValue: 200)
                    let x = CGFloat(col) * rendererSize.width / CGFloat(cols)
                    let y = CGFloat(row) * rendererSize.height / CGFloat(rows)
                    let cellWidth = rendererSize.width / CGFloat(cols)
                    let cellHeight = rendererSize.height / CGFloat(rows)
                    let cellFrame = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                    context.setFillColor(color.cgColor)
                    context.fill(cellFrame)
                }
            }
        }
        
        return image
    }

    private func valueToColor(value: Float, minValue: Float, maxValue: Float) -> UIColor {
        let normalizedValue = (value - minValue) / (maxValue - minValue)
        return UIColor(hue: CGFloat(1.0 - normalizedValue) * (5.0 / 6.0), saturation: 1.0, brightness: 1.0, alpha: 1.0)
    }
}
