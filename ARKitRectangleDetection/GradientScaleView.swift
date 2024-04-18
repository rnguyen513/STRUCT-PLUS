//
//  GradientScaleView.swift
//  ARKitRectangleDetection
//
//  Created by ISEE Lab on 4/15/24.
//  Copyright © 2024 Mel Ludowise. All rights reserved.
//

import Foundation
import UIKit
import SceneKit
import SpriteKit

class GradientScaleView : UIView {
    let values: [Int]
    
    init(frame: CGRect, values: [Int]) {
        self.values = values
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        self.values = []
        super.init(coder: coder)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let context = UIGraphicsGetCurrentContext()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.red.cgColor, UIColor.orange.cgColor, UIColor.yellow.cgColor, UIColor.green.cgColor, UIColor.blue.cgColor, UIColor.purple.cgColor]
        let locations: [CGFloat] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
            let startPoint = CGPoint(x: rect.midX, y: rect.minY)
            let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
            context?.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let valueSpacing = rect.height / CGFloat(values.count - 1)
        
        for (index, value) in values.reversed().enumerated() {
            let stringValue = "\(value)"
            let stringRect = CGRect(x: rect.maxX + 5, y: CGFloat(index) * valueSpacing - 6, width: rect.width, height: 12)
            stringValue.draw(in: stringRect, withAttributes: attributes)
        }
    }
}

class GradientScaleNode: SCNNode {
    init(width: CGFloat, height: CGFloat, values: [Int]) {
        super.init()
        
        let gradientImage = createGradientImage(width: Int(width), height: Int(height/6), values: values)
        
        let plane = SCNPlane(width: width, height: height)
        let gradientScaleNode = SCNNode(geometry: plane)
//        plane.firstMaterial?.diffuse.contents = gradientImage
//        plane.firstMaterial?.isDoubleSided = true
        
        let material = SCNMaterial()
        let texture = SKTexture(image:gradientImage)
        
        texture.filteringMode = .nearest
        material.diffuse.contents = texture
        material.isDoubleSided = true
        
        plane.materials = [material]
        
        self.addChildNode(gradientScaleNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemted")
    }
    
    private func createGradientImage(width: Int, height: Int, values: [Int]) -> UIImage {
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: rendererFormat)
        
        let image = renderer.image { ctx in
            // Create a gradient from top to bottom
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.red.cgColor, UIColor.orange.cgColor, UIColor.yellow.cgColor, UIColor.green.cgColor, UIColor.blue.cgColor, UIColor.purple.cgColor] as CFArray
            let locations: [CGFloat] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
            let startPoint = CGPoint(x: width / 2, y: 0)
            let endPoint = CGPoint(x: width / 2, y: height)
            ctx.cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
            
            // Draw the text for the scale values
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            let attributes: [NSAttributedString.Key: Any] = [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            // Calculate the spacing for the values
            let valueSpacing = height / (values.count - 1)
            
            for (index, value) in values.enumerated() {
                let stringValue = "\(value)"
                let stringRect = CGRect(x: 0, y: height - (index + 1) * valueSpacing, width: width, height: valueSpacing)
                stringValue.draw(with: stringRect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            }
        }
        
        return image
    }

}
