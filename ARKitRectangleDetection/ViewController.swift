//
//  ViewController.swift
//  ARKitRectangleDetection

import UIKit
import SceneKit
import ARKit
import Vision
import SwiftUI
import TensorFlowLite
import Foundation

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - IBOutlets
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var restartButton: UIButton!
    @IBOutlet weak var debugButton: UIButton!
    @IBOutlet weak var planeButton: UIButton!
    
    @IBOutlet weak var slidersContainerView: UIView!
    @IBOutlet weak var xInputSlider: UISlider!
    @IBOutlet weak var yInputSlider: UISlider!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var xLabel: UILabel!
    @IBOutlet weak var yLabel: UILabel!
    
    @IBAction func toggleSlidersVisibility(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3) {
            self.slidersContainerView.isHidden = !self.slidersContainerView.isHidden
            self.toggleButton.setTitle(self.slidersContainerView.isHidden ? "Simulation Settings" : "Close", for: .normal)
        }
    }
    
    @IBAction func xSliderValueChanged(_ sender: UISlider) {
        self.sliderValues.xValue = sender.value
        self.xLabel.text = "X LOAD: \(sender.value) N"
    }
    
    @IBAction func ySliderValueChanged(_ sender: UISlider) {
        self.sliderValues.yValue = sender.value
        self.yLabel.text = "Y LOAD: \(sender.value) N"
    }
    
    // MARK: - Internal properties used to identify the rectangle the user is selecting

    private var identifiedRectangleOutlineLayers: [CAShapeLayer] = []
    
    // Displayed rectangle outline
    private var selectedRectangleOutlineLayer: CAShapeLayer?
    
    // Observed rectangle currently being touched
    private var selectedRectangleObservation: VNRectangleObservation?

    private var cameraTransform: CGAffineTransform = .identity
    
    // The time the current rectangle selection was last updated
    private var selectedRectangleLastUpdated: Date?
    
    // Current touch location
    private var currTouchLocation: CGPoint?
    
    // Gets set to true when actively searching for rectangles in the current frame
    private var searchingForRectangles = false
    
    //heatmapData
    private var heatmapData: [Float] = (0..<768).map { _ in Float.random(in: 0...200)}
    
    var slidersViewController: UIHostingController<SlidersView>?
    var sliderValues = SliderValues()
    
    // MARK: - Rendered items
    
    // RectangleNodes with keys for rectangleObservation.uuid
    private var rectangleNodes = [VNRectangleObservation:RectangleNode]()
    
    // Used to lookup SurfaceNodes by planeAnchor and update them
    private var surfaceNodes = [ARPlaneAnchor:SurfaceNode]()
    
    func toggleSurfaceVisibility() {
        for (_, surfaceNode) in surfaceNodes {
            surfaceNode.isHidden = !surfaceNode.isHidden
        }
    }
    
    // MARK: - Debug properties
    
    var showDebugOptions = false {
        didSet {
            if showDebugOptions {
                sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
            } else {
              sceneView.debugOptions = []
            }
        }
    }
    
    
    // MARK: - Message displayed to the user
    
    private var message: Message? {
        didSet {
            DispatchQueue.main.async {
                if let message = self.message {
                    self.messageView.isHidden = false
                    self.messageLabel.text = message.localizedString
                    self.messageLabel.numberOfLines = 0
                    self.messageLabel.sizeToFit()
                    self.messageLabel.superview?.setNeedsLayout()
                } else {
                    self.messageView.isHidden = true
                }
            }
        }
    }
    
    
    // MARK: - UIViewController
    
    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sliderValues.xValue = 65.0 //default
        
        // Set the view's delegates
        sceneView.delegate = self
        
        // Comment out to disable rectangle tracking
        sceneView.session.delegate = self
        
        // Show world origin and feature points if desired
        if showDebugOptions {
            sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        }

        // Enable default lighting
        sceneView.autoenablesDefaultLighting = true
        
        // Create a new scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Don't display message
        message = nil
        
        // Style clear button
        styleButton(clearButton, localizedTitle: NSLocalizedString("Clear Rects", comment: ""))
        styleButton(restartButton, localizedTitle: NSLocalizedString("RESTART", comment: ""))
        styleButton(debugButton, localizedTitle: NSLocalizedString("Debug", comment: ""))
        styleButton(planeButton, localizedTitle: NSLocalizedString("Toggle Plane", comment: ""))
        debugButton.isSelected = showDebugOptions
        
        
//        let scaleValues = Array(stride(from: 0, to: 200, by: 25))
//        let scaleView = GradientScaleView(frame: CGRect(x: view.bounds.width - 60, y: 100, width: 50, height: 300), values: scaleValues)
//        view.addSubview(scaleView)
        
        //////////////now obsolete
//        let slidersView = SlidersView(sliderValues: sliderValues, onValueChange: self.handleSliderChange)
//        slidersViewController = UIHostingController(rootView: slidersView)
//        guard let slidersVC = slidersViewController else { return }
//        addChild(slidersVC)
//        
//        //slidersVC.view.backgroundColor = UIColor.red
//        slidersVC.view.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
//        slidersVC.view.backgroundColor = UIColor.clear
//        slidersVC.view.isOpaque = false
//        
//        slidersVC.modalPresentationStyle = .overFullScreen
//        slidersVC.modalTransitionStyle = .crossDissolve
//        
//        slidersVC.didMove(toParent: self)
        
        //self.view.addSubview(slidersVC.view)
        //self.present(slidersVC, animated: true, completion: nil)
    }
    
//    func handleSliderChange(x: SliderValues) {
//        DispatchQueue.main.async {
//            self.sliderValues = x
//            print("new values:", self.sliderValues.xValue, self.sliderValues.yValue)
//        }
//    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        //configuration.planeDetection = [.horizontal, .vertical] //horizontal AND vertical
        configuration.planeDetection = [.horizontal]
        //configuration.planeDetection = [.vertical]
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Tell user to find the a surface if we don't know of any
        if surfaceNodes.isEmpty {
            message = .helpFindSurface
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
            let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        currTouchLocation = touch.location(in: sceneView)
        findRectangle(locationInScene: currTouchLocation!, frame: currentFrame)
        message = .helpTapReleaseRect
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Ignore if we're currently searching for a rect
        if searchingForRectangles {
            return
        }
        
        guard let touch = touches.first,
            let currentFrame = sceneView.session.currentFrame else {
                return
        }
        
        currTouchLocation = touch.location(in: sceneView)
        findRectangle(locationInScene: currTouchLocation!, frame: currentFrame)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        currTouchLocation = nil
        message = .helpTapHoldRect

        guard let selectedRect = selectedRectangleObservation else {
            return
        }
        
        // Create a planeRect and add a RectangleNode
        addPlaneRect(for: selectedRect, transform: cameraTransform)
        //addHeatmapLayer(for: selectedRect, transform: cameraTransform, stressData: heatmapData)
    }
    
    // MARK: - IBOutlets
    
    //toggle horizontal/vertical detection
    @IBAction func onPlaneButton(_ sender: Any) {
//        sceneView.session.pause()
        
//        let currentConfig = sceneView.session.configuration
//        
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.vertical]
//        sceneView.session.run(configuration, options:[.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
//        
//        // Run the view's session
//        sceneView.session.run(configuration)
//        
//        // Tell user to find the a surface if we don't know of any
//        if surfaceNodes.isEmpty {
//            message = .helpFindSurface
//        }
        toggleSurfaceVisibility()
        print("plane button pressed")
    }
    
    @IBAction func onClearButton(_ sender: Any) {
        rectangleNodes.forEach({ $1.removeFromParentNode() })
        rectangleNodes.removeAll()
    }
    
    @IBAction func onRestartButton(_ sender: Any) {
        // Remove all rectangles
        rectangleNodes.forEach({ $1.removeFromParentNode() })
        rectangleNodes.removeAll()
        
        // Remove all surfaces and tell session to forget about anchors
        surfaceNodes.forEach { (anchor, surfaceNode) in
            sceneView.session.remove(anchor: anchor)
            surfaceNode.removeFromParentNode()
        }
        surfaceNodes.removeAll()
        
        // Update message
        message = .helpFindSurface
    }
    
    @IBAction func onDebugButton(_ sender: Any) {
        showDebugOptions = !showDebugOptions
        debugButton.isSelected = showDebugOptions
        
        if showDebugOptions {
            debugButton.layer.backgroundColor = UIColor.yellow.cgColor
            debugButton.layer.borderColor = UIColor.yellow.cgColor
        } else {
            debugButton.layer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
            debugButton.layer.borderColor = UIColor.white.cgColor
        }
    }
    
    // MARK: - ARSessionDelegate
    
    // Update selected rectangle if it's been more than 1 second and the screen is still being touched
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if searchingForRectangles {
            return
        }
        
        guard let currTouchLocation = currTouchLocation,
            let currentFrame = sceneView.session.currentFrame else {
                return
        }
        
        if selectedRectangleLastUpdated?.timeIntervalSinceNow ?? 0 < 1 {
            return
        }
        
        findRectangle(locationInScene: currTouchLocation, frame: currentFrame)
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let surface = SurfaceNode(anchor: anchor)
        surfaceNodes[anchor] = surface
        node.addChildNode(surface)
        
        if message == .helpFindSurface {
            message = .helpTapHoldRect
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // See if this is a plane we are currently rendering
        guard let anchor = anchor as? ARPlaneAnchor,
            let surface = surfaceNodes[anchor] else {
                return
        }
        
        surface.update(anchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor,
            let surface = surfaceNodes[anchor] else {
                return
        }

        surface.removeFromParentNode()
        
        surfaceNodes.removeValue(forKey: anchor)
    }
    
    // MARK: - Helper Methods
    
    // Updates selectedRectangleObservation with the the rectangle found in the given ARFrame at the given location
    private func findRectangle(locationInScene location: CGPoint, frame currentFrame: ARFrame) {
        // Note that we're actively searching for rectangles
        searchingForRectangles = true
        selectedRectangleObservation = nil

        let interfaceOrientation = UIApplication.shared.statusBarOrientation
        let imageOrientation = interfaceOrientation.imageOrientation
        let sceneSize = sceneView.frame.size

        let fromCameraImageToViewTransform = currentFrame.displayTransformCorrected(
          for: interfaceOrientation,
          viewportSize: sceneSize
        )

        // Perform request on background thread
        DispatchQueue.global(qos: .background).async {
            let request = VNDetectRectanglesRequest(completionHandler: { (request, error) in
                
                // Jump back onto the main thread
                DispatchQueue.main.async {
                    
                    // Mark that we've finished searching for rectangles
                    self.searchingForRectangles = false
                    
                    // Access the first result in the array after casting the array as a VNClassificationObservation array
                    guard let observations = request.results as? [VNRectangleObservation],
                        let _ = observations.first else {
                            print ("No results")
                            self.message = .errNoRect
                            return
                    }
                    
                    print("\(observations.count) rectangles found")
                    print("rectangleNodes: ", self.rectangleNodes)

                    // Remove outline for selected rectangle
                    if let layer = self.selectedRectangleOutlineLayer {
                        layer.removeFromSuperlayer()
                        self.selectedRectangleOutlineLayer = nil
                    }
                    self.identifiedRectangleOutlineLayers.forEach { $0.removeFromSuperlayer() }

                    // Draw outline for all detected rectangles
                    self.identifiedRectangleOutlineLayers = observations.map({ observation in
                        let normalizedPoints = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
                        let convertedPoints = normalizedPoints.map { $0.applying(fromCameraImageToViewTransform) }
                        let layer = self.drawPolygon(convertedPoints, color: .yellow)
                        self.sceneView.layer.addSublayer(layer)
                        
                        return layer
                    })

                    // Find the rect that overlaps with the given location in sceneView
                    guard let selectedRect = observations.filter({ (result) -> Bool in
                        let convertedRect = result.boundingBox.applying(fromCameraImageToViewTransform)
                        return convertedRect.contains(location)
                    }).first else {
                        print("No results at touch location")
                        self.message = .errNoRect
                        return
                    }
                    
                    // Outline selected rectangle
                    let points = [selectedRect.topLeft, selectedRect.topRight, selectedRect.bottomRight, selectedRect.bottomLeft]
                    let convertedPoints = points.map { $0.applying(fromCameraImageToViewTransform) }
                    self.selectedRectangleOutlineLayer = self.drawPolygon(convertedPoints, color: UIColor.red)
                    self.sceneView.layer.addSublayer(self.selectedRectangleOutlineLayer!)
                    
                    // Track the selected rectangle and when it was found
                    self.selectedRectangleObservation = selectedRect
                    self.selectedRectangleLastUpdated = Date()
                    self.cameraTransform = fromCameraImageToViewTransform
                    
                    // Check if the user stopped touching the screen while we were in the background.
                    // If so, then we should add the planeRect here instead of waiting for touches to end.
                    if self.currTouchLocation == nil {
                        // Create a planeRect and add a RectangleNode
                        self.addPlaneRect(for: selectedRect, transform: fromCameraImageToViewTransform)
                        //self.addHeatmapLayer(for: selectedRect, transform: fromCameraImageToViewTransform, stressData: self.heatmapData)
                    }
                    self.identifiedRectangleOutlineLayers.forEach { $0.removeFromSuperlayer() }
                }
            })
            
            // Don't limit resulting number of observations
            request.maximumObservations = 10
            
            // MAX SENSITIVITY
            request.minimumAspectRatio = 0.1
            request.quadratureTolerance = 30
            request.minimumSize = 0.01
            request.minimumConfidence = 0.4 // detect everything pretty much
            
            // Perform request
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage,
                                                orientation: imageOrientation,
                                                options: [:])
            try? handler.perform([request])
        }
    }
    
    private func addPlaneRect(for observedRect: VNRectangleObservation, transform: CGAffineTransform) {
        // Remove old outline of selected rectangle
        if let layer = selectedRectangleOutlineLayer {
            layer.removeFromSuperlayer()
            selectedRectangleOutlineLayer = nil
        }
        
        // Convert to 3D coordinates
        guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView, with: transform) else {
            print("No plane for this rectangle")
            message = .errNoPlaneForRect
            return
        }
        
        //let rectangleNode = RectangleNode(planeRectangle, stressData: heatmapData)
        let rectangleNode = RectangleNode(planeRectangle, stressData: stressNet())
        rectangleNodes[observedRect] = rectangleNode
        sceneView.scene.rootNode.addChildNode(rectangleNode)
        
//        print("THE POSITION IS: \(rectangleNode.position.x), \(rectangleNode.position.y)")
//        
//        //round dimensions to 2 decimals (DIMENSIONS/POSITION IS IN M)
//        let roundedHeight = round(planeRectangle.size.height*100*100)/100.0
//        let roundedWidth = round(planeRectangle.size.width*100*100)/100.0
//        
//        //create text object
//        let someText =  SCNText(string:"H: \(roundedHeight)cm X W: \(roundedWidth)cm",extrusionDepth: 2)
//        let material = SCNMaterial()
//        material.diffuse.contents = UIColor.random()
//        someText.materials = [material]
//        
//        //append text object to new scene node
//        let newNode = SCNNode()
//        //newNode.position = rectangleNode.position
//        //newNode.position = SCNVector3(x:rectangleNode.position.x, y:rectangleNode.position.y, z:rectangleNode.position.z)
//        newNode.scale = SCNVector3(x:0.002, y:0.002, z:0.002)
//        newNode.geometry = someText
//        
//        
//        //TRY THIS!!! MORE EFFICIENT TO APPEND INSTEAD OF APPENDING TO GENERAL WORKSPACE NODE
//        rectangleNode.addChildNode(newNode)
        
        //append scene node to sceneView (OLD, SEE ABOVE^)
        //self.sceneView.scene.rootNode.addChildNode(newNode)
        //self.sceneView.autoenablesDefaultLighting = true
    }
    
    private func addHeatmapLayer(for observedRect: VNRectangleObservation, transform: CGAffineTransform, stressData: [Float]) {
        guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView, with: transform) else {
            print("No plane for this rectangle!!!")
            message = .errNoPlaneForRect
            return
        }
        
        // Correct the position calculations
        let rectWidth = planeRectangle.size.width
        let rectHeight = planeRectangle.size.height
        let cellWidth = rectWidth / 32
        let cellHeight = rectHeight / 24

        // Create a layer to hold the heatmap
        let heatmapLayer = CALayer()
        heatmapLayer.frame = CGRect(x: 0, y: 0, width: rectWidth, height: rectHeight)  // Set to zero here, position adjusted below
        
        // Start image context to draw the heatmap
        UIGraphicsBeginImageContextWithOptions(heatmapLayer.frame.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            print("Failed to create graphics context")
            return
        }

        for row in 0..<24 {
            for col in 0..<32 {
                let cellFrame = CGRect(x: CGFloat(col) * cellWidth, y: CGFloat(row) * cellHeight, width: cellWidth, height: cellHeight)
                let colorIndex = row * 32 + col
                let cellColor = stressDataToColors(data: stressData, min: 0, max: 200)[colorIndex]
                context.setFillColor(cellColor.cgColor)
                context.fill(cellFrame)
            }
        }

        // Extract the drawn image
        guard let heatmapImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            print("Failed to extract heatmap image from context")
            return
        }
        UIGraphicsEndImageContext()

        // Set the image as the contents of the heatmap layer
        heatmapLayer.contents = heatmapImage.cgImage

        // Position the heatmap layer correctly
        heatmapLayer.position = CGPoint(x: CGFloat(planeRectangle.position.x) - rectWidth / 2,
                                        y: CGFloat(planeRectangle.position.y) - rectHeight / 2)

        // Add the heatmap layer to the scene's root layer
        DispatchQueue.main.async {
            self.sceneView.layer.addSublayer(heatmapLayer)
        }
        print("Heatmap added to the scene with data from the stress array.")
    }
    
    private func drawPolygon(_ points: [CGPoint], color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = color.cgColor
        layer.lineWidth = 2
        let path = UIBezierPath()
        path.move(to: points.last!)
        points.forEach { point in
            path.addLine(to: point)
        }
        layer.path = path.cgPath

        layer.addSublayer(drawPoint(points[0], color: .red))
        layer.addSublayer(drawPoint(points[1], color: .green))
        layer.addSublayer(drawPoint(points[2], color: .blue))
        layer.addSublayer(drawPoint(points[3], color: .yellow))

        return layer
    }

    private func drawPoint(_ point: CGPoint, color: UIColor, radius: CGFloat = 5) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = color.cgColor
        let path = UIBezierPath(ovalIn: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        layer.path = path.cgPath
        return layer
    }
    
    private func styleButton(_ button: UIButton, localizedTitle: String?) {
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 5
        button.layer.cornerRadius = 10
        button.setTitle(localizedTitle, for: .normal)
    }
    
    private func valueToRainbowColor(value: Double, minValue: Double, maxValue: Double) -> Color {
        // Normalize the value
        let normalizedValue = (value - minValue) / (maxValue - minValue)
        
        if (minValue == maxValue) {
            return Color(hue: 1.0, saturation: 1.0, brightness: 1.0)
        } else if value.isInfinite || value.isNaN || minValue.isInfinite || minValue.isNaN || maxValue.isInfinite || maxValue.isNaN {
            return Color.gray
        }

        // Calculate hue, saturation, and brightness
        var hue = (1.0 - normalizedValue) * 0.666  // Rainbow from red to blue (0 to 0.666 of the hue spectrum)
        let saturation: Double = 1.0  // Full color saturation
        let brightness: Double = 1.0  // Full brightness

        // Create and return a Color from HSV
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    func stressDataToColors(data: [Float], min: Float, max: Float) -> [UIColor] {
        return data.map { value in
            let normalized = CGFloat((value - min) / (max - min))
            return UIColor(hue: (1.0 - normalized) * (5.0 / 6.0), saturation: 1.0, brightness: 1.0, alpha: 1.0)
        }
    }
    
    func stressNet() -> [Float32] {
        guard let modelPath = Bundle.main.path(forResource: "converted_single_input", ofType: "tflite") else {
            fatalError("couldn't find model")
        }
        
//        guard let inputPath = Bundle.main.path(forResource: "Geo_q_str_known_SCS.npy", ofType: "npy") else {
//            fatalError("couldn't find .npy input")
//        }
        
        guard let npyPath = Bundle.main.path(forResource: "Geo_q_str_known_SCS", ofType: "npy") else {
            print("error: couldn't find path to Geo_q_str_known_SCS.npy")
            return [0.0]
        }
        
        guard let npyData = FileManager.default.contents(atPath: npyPath) else {
            print("error: couldn't read file at \(npyPath)")
            return [0.0]
        }
        
//        let _data = readCSV(from: "output.csv")
//
//        print("\ndata[14][770..<1000]: \(_data[14][770..<1000])")
        
//        let bytes: Data = npyData.withUnsafeBytes { pointer in
//            return Data(bytes: pointer, count: npyData.count)
//        }
        
        do {
            let interpreter = try Interpreter(modelPath: modelPath)
            
            try interpreter.allocateTensors()
            
//            let bytes = npyData.withUnsafeBytes { buffer in
//                return buffer.baseAddress!
//                //let pointer = buffer.baseAddress!
//                //return Data(bytes: pointer, count: buffer.count)
//            }
            
            guard npyData.count % MemoryLayout<Float32>.size == 0 else {
                print("error: data size isn't a multiple of Float32 size; the data is not Float32")
                return [0.0]
            }
            
            //let floatData = bytes.bindMemory(to: Float32.self, capacity: npyData.count / MemoryLayout<Float32>.size)
            
//            var floatArr: [Float32] = []
//            outputTensor_data.withUnsafeBytes { pointer in
//                floatArr.append(contentsOf: pointer.bindMemory(to: Float32.self))
//            }
            
//            let floatArray: [Float32] = npyData.withUnsafeBytes { buffer -> [Float32] in
//                let pointer = buffer.baseAddress!.bindMemory(to:Float32.self, capacity: npyData.count / MemoryLayout<Float32>.size)
//                return Array(unsafeUninitializedCapacity: npyData.count / MemoryLayout<Float32>.size, initializingWith: { buffer, initializedCount in
//                    memcpy(buffer.baseAddress!, pointer, npyData.count)
//                    initializedCount = npyData.count / MemoryLayout<Float32>.size
//                })
//            }
            
            let floatArray2: [Float64] = npyData.withUnsafeBytes { buffer -> [Float64] in
                let pointer = buffer.baseAddress!.bindMemory(to:Float64.self, capacity: npyData.count / MemoryLayout<Float64>.size)
                return Array(unsafeUninitializedCapacity: npyData.count / MemoryLayout<Float64>.size, initializingWith: { buffer, initializedCount in
                    memcpy(buffer.baseAddress!, pointer, npyData.count)
                    initializedCount = npyData.count / MemoryLayout<Float64>.size
                })
            }
            
            var casted_floatArray2: [Float32] = []
            
            for value in floatArray2 {
                casted_floatArray2.append(Float32(value))
            }
            
            var truncated_casted_floatArray2 = Array(casted_floatArray2[16...])
            
            var reshapedArray: [[Float32]] = convertArrayShape(data: truncated_casted_floatArray2, col: 1538)
            
            let inputData1 = Array(reshapedArray[13][0..<768])
            ///////////////let inputData2 = Array(reshapedArray[13][768..<770])
            let inputData2 = Array([sliderValues.xValue, sliderValues.yValue])
            
            let inputData1_data = inputData1.withUnsafeBufferPointer { Data(buffer: $0) }
            let inputData2_data = inputData2.withUnsafeBufferPointer { Data(buffer: $0) }
            
//            let groundTruth: [Float32] = Array(reshapedArray[13][770..<1538])
//            
//            let groundTruth_heatMap: [[Float32]] = convertArrayShape(data:groundTruth,col:32)
            
            //groundTruth_state = groundTruth_heatMap
            
            ///load data
            try interpreter.copy(inputData2_data, toInputAt:0)
            try interpreter.copy(inputData1_data, toInputAt:1)

            ///call model inference
            try interpreter.invoke()
            
            ///handle output
            let outputTensor = try interpreter.output(at: 0)
            let count = outputTensor.data.count / MemoryLayout<Float32>.stride
            var outputData = [Float32](repeating: 0, count: count)
            _ = outputData.withUnsafeMutableBytes { outputTensor.data.copyBytes(to: $0) }
            
            let floatArr = outputData
            
//            print("\nOUTPUTDATA - floatArr: \(floatArr)")
//            print("\nOUTPUTDATA - floatArr.count: \(floatArr.count)")
            
            return outputData
            
        } catch let error {
            print("error: \(error)")
            return [0.0]
        }
    }
    
    func convertRawDataToFloat32Array(data: Data) -> [Float32] {
        guard data.count == 3072 else {
            fatalError("not 3072 bytes")
        }
        
        var buffer = [Float32](repeating: 0, count: 768)
        
        data.withUnsafeBytes { rawPtr in
            let bytePtr = rawPtr.baseAddress!
            memcpy(&buffer, bytePtr, MemoryLayout<Float32>.size*768)
        }
        
        return buffer
    }
    
    let minValue: Float = 0.0
    let maxValue: Float = 1.0
    
    func randomFloat(in range: ClosedRange<Float>) -> Float {
        let random = Float(arc4random()) / Float(UInt32.max)
        return random * (maxValue - minValue) + minValue
    }
    
    func generateRandomData(shape:[Int]) -> [Float] {
        var data = [Float]()
        for _ in 0..<shape.reduce(1, *) {
            data.append(randomFloat(in: minValue...maxValue))
        }
        return data
    }
    
    func convertArrayShape(data:[Float32], col: Int) -> [[Float32]] {
        return stride(from: 0, to: data.count, by: col).map { startIndex in
            return Array(data[startIndex..<startIndex+col])
        }
    }
}
