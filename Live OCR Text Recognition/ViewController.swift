//
//  ViewController.swift
//  Live OCR Text Recognition
//
//  Created by Minaam Ahmed Awan on 30/06/2021.
//


import AVFoundation
import UIKit
import Vision


class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func scanBtn(_ sender: UIBarButtonItem) {
        let documentCameraViewController = storyboard?.instantiateViewController(identifier: "secondVC") as! SecondViewController
        navigationController?.pushViewController(documentCameraViewController, animated: true)
    }
}


class SecondViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // Object Types:
    static let objectCreditCard = "objectCreditCard"
    static let objectCNIC = "objectCNIC"
    
    // Capture Session & Output Preview:
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    // OCR Text Request
    private var textRequest: VNRecognizeTextRequest!
    
    
    enum ScanMode: Int {
        case creditCard
        case cnic
    }
    
    // Initialize:
    var scanMode: ScanMode = .creditCard
    var resultsViewController: (UIViewController & RecognizedTextDataSource)?
    var textRecognitionRequest = VNRecognizeTextRequest()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addCameraInput()
        self.addPreviewLayer()
        self.captureSession.startRunning()
        self.addVideoOutput()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.bounds
    }
    
    // Clean Up Function:
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    // Capture Input:
    private func addCameraInput() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        self.captureSession.addInput(deviceInput)
    }
    
    
    // Display Preview On Screen:
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        
        return preview
    }()
    
    
    // Add Preview to ViewController:
    private func addPreviewLayer() {
        self.view.layer.addSublayer(self.previewLayer)
    }
    
    
    //
    private func addVideoOutput() {
        self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        self.captureSession.addOutput(self.videoOutput)
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // Debug for Checking Frames Recieved:
        //print("Frame Received", Date())
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                return
            }
            
            let text = observations.compactMap({
                $0.topCandidates(1).first?.string
            }).joined(separator: "\n")
            
            DispatchQueue.main.async {
                print(text)
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
}
