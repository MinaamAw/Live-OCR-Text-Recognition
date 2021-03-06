/*
 CameraViewController.swift
 Live OCR Text Recognition

 Created by Minaam Ahmed Awan on 01/07/2021.
 
 Abstract:
    Camera View Controller: Handles Camera, OCR ROI and Bounding Box.
*/


import AVFoundation
import UIKit
import Vision


class SecondViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // IBOutlets:
    @IBOutlet weak var previewCamera: UIView!
    @IBOutlet weak var focusView: UIView!
    
    
    // Bouding Area & ROI:
    var maskLayer = CAShapeLayer()
    private var boundLayer = CAShapeLayer()
    var regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    
    // Orientation:
    var currentOrientation = UIDeviceOrientation.portrait
    var textOrientation = CGImagePropertyOrientation.up
    var bufferAspectRatio: Double!
    var uiRotationTransform = CGAffineTransform.identity
    var bottomToTopTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
    var roiToGlobalTransform = CGAffineTransform.identity
    var visionToAVFTransform = CGAffineTransform.identity
    
    
    // Capture Session & Output Preview:
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    
    // Initialize:
    private var textRequest = VNRecognizeTextRequest()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup View Controllers:
        focusView.backgroundColor = UIColor.gray.withAlphaComponent(0.7)
        maskLayer.backgroundColor = UIColor.clear.cgColor
        maskLayer.fillRule = .evenOdd
        focusView.layer.mask = maskLayer
        
        
        // AVFoundation Framework
        self.addCameraInput()
        self.addPreviewLayer()
        self.addVideoOutput()
        self.captureSession.startRunning()
        
        
        // Calculate ROI:
        self.calculateRegionOfInterest()
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.previewCamera.frame
        self.updateFocusView()
    }
    
    
    // Clean Up Function:
    override func viewDidDisappear(_ animated: Bool) {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.captureSession.stopRunning()
    }
    
    
    // Capture Input:
    private func addCameraInput() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        bufferAspectRatio = 1920.0 / 1080.0
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        self.captureSession.addInput(deviceInput)
    }
    
    
    // Preview Layer:
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        
        return preview
    }()
    
    
    // Add Preview to ViewController:
    private func addPreviewLayer() {
        self.previewCamera.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.previewCamera.frame
    }
    
    
    // Display Video Output:
    private func addVideoOutput() {
        self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        self.captureSession.addOutput(self.videoOutput)
        
        // Portrait Mode Only
        guard let connection = self.videoOutput.connection(with: AVMediaType.video),
                connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    
    // Capture Frames:
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // Debug for Checking Frames Recieved:
        //print("Frame Received", Date())
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Unable to Get Frames")
            return
        }
        
        
        // Detect Object:
        self.detectRectangle(in: pixelBuffer)
        
        
        // OCR Text Request:
        textRequest = VNRecognizeTextRequest { textRequest, error in
                   guard let observations = textRequest.results as? [VNRecognizedTextObservation],
                         error == nil else {
                       return
                   }
                   let text = observations.compactMap({
                       $0.topCandidates(1).first?.string
                   }).joined(separator: "\n")
                   
                   DispatchQueue.main.async {
                    
                    // Print Text Read:
                    print(text)
                   }
               }
        
        
        // OCR Properties & Request:
        textRequest.regionOfInterest = regionOfInterest
        textRequest.recognitionLevel = .accurate
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([textRequest])
    }

    
    // Detect Card:
    private func detectRectangle(in image: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest(completionHandler: { (request: VNRequest, error: Error?) in
            
            DispatchQueue.main.async {
                guard let results = request.results as? [VNRectangleObservation] else { return }
                self.removeMask()
                
                guard let rect = results.first else { return }
                    self.drawBoundingBox(rect: rect)
            }
        })
                
                request.minimumAspectRatio = VNAspectRatio(1.3)
                request.maximumAspectRatio = VNAspectRatio(1.6)
                request.minimumSize = Float(0.5)
                request.maximumObservations = 1
                request.minimumConfidence = 1.0

                
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
                try? imageRequestHandler.perform([request])
    }
    
    
    func drawBoundingBox(rect : VNRectangleObservation) {
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.previewLayer.frame.height)
        let scale = CGAffineTransform.identity.scaledBy(x: self.previewLayer.frame.width, y: self.previewLayer.frame.height)

        let bounds = rect.boundingBox.applying(scale).applying(transform)
        createLayer(in: bounds)

    }

    
    private func createLayer(in rect: CGRect) {
        boundLayer = CAShapeLayer()
        boundLayer.frame = rect
        boundLayer.cornerRadius = 10
        boundLayer.opacity = 0.5
        boundLayer.borderColor = UIColor.green.cgColor
        boundLayer.borderWidth = 5.0
        
        previewLayer.insertSublayer(boundLayer, at: 1)
    }
    
    
    // Remove Mask:
    func removeMask() {
            boundLayer.removeFromSuperlayer()
    }

    
    func calculateRegionOfInterest() {
        // Desired Ratios
        let desiredHeightRatio = 0.6
        let desiredWidthRatio = 0.7
        let maxPortraitWidth = 0.9
        
        
        // Figure out size of ROI.
        let size: CGSize
        if currentOrientation.isPortrait || currentOrientation == .unknown {
            size = CGSize(width: min(desiredWidthRatio * bufferAspectRatio, maxPortraitWidth), height: desiredHeightRatio / bufferAspectRatio)
        } else {
            size = CGSize(width: desiredWidthRatio, height: desiredHeightRatio)
        }
        
        
        // Make it centered.
        regionOfInterest.origin = CGPoint(x: (1 - size.width) / 2, y: (1 - size.height) / 2)
        regionOfInterest.size = size
        
        
        // Update ViewController.
        let ROI = regionOfInterest
        roiToGlobalTransform = CGAffineTransform(translationX: ROI.origin.x, y: ROI.origin.y).scaledBy(x: ROI.width, y: ROI.height)
        //textOrientation = CGImagePropertyOrientation.right
        uiRotationTransform = CGAffineTransform(translationX: 0, y: 1).rotated(by: -CGFloat.pi / 2)
        
        
        // Update FocusView:
        DispatchQueue.main.async {
            self.updateFocusView()
        }
    }
    
        
    // Update focusView UIView:
    func updateFocusView() {
        let roiRectTransform = bottomToTopTransform.concatenating(uiRotationTransform)
        let focus = previewLayer.layerRectConverted(fromMetadataOutputRect: regionOfInterest.applying(roiRectTransform))
        
        // Create the mask.
        let path = UIBezierPath(rect: focusView.frame)
        path.append(UIBezierPath(rect: focus))
        maskLayer.path = path.cgPath
    }
}
