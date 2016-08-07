//
//  ViewController.swift
//  ios-camera-video-preview-glkview
//
//  Created by Zhaonan Li on 8/6/16.
//  Copyright © 2016 Zhaonan Li. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var cameraView: UIView!

    lazy var glContext: EAGLContext = {
        let glContext = EAGLContext(API: .OpenGLES2)
        return glContext
    }()
    
    lazy var glView: GLKView = {
        let glView = GLKView(
            frame: CGRect(
                x: 0,
                y: 0,
                width:  self.cameraView.bounds.width,
                height: self.cameraView.bounds.height),
            context: self.glContext)
        
        glView.bindDrawable() // This method is very important, if we miss this method, the app may crash.
        return glView
    }()
    
    lazy var ciContext: CIContext = {
        let ciContext = CIContext(EAGLContext: self.glContext)
        return ciContext
    }()
    
    lazy var cameraSession: AVCaptureSession = {
        let s = AVCaptureSession()
        // The high quality processing will use more CPU, but not more memory.
        s.sessionPreset = AVCaptureSessionPresetPhoto
        //s.sessionPreset = AVCaptureSessionPresetHigh
        return s
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        setupCameraSession()
    }
    
    override func viewDidAppear(animated: Bool) {
        self.cameraView.addSubview(glView)
        cameraSession.startRunning()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setupCameraSession() {
        let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo) as AVCaptureDevice
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            cameraSession.beginConfiguration()
            
            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            
            dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(unsignedInt: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if cameraSession.canAddOutput(dataOutput) == true {
                cameraSession.addOutput(dataOutput)
            }
            
            cameraSession.commitConfiguration()
            
            let queue = dispatch_queue_create("com.somedomain.videoQueue", DISPATCH_QUEUE_SERIAL)
            dataOutput.setSampleBufferDelegate(self, queue: queue)
            
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    // Implement the delegate method
    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here you collect each frame and process it
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(CVPixelBuffer: pixelBuffer!)
        
        // Rotate image 90 degree to right
        var tx = CGAffineTransformMakeTranslation(
            image.extent.width / 2,
            image.extent.height / 2)
        
        tx = CGAffineTransformRotate(
            tx,
            CGFloat(-1 * M_PI_2))
        
        tx = CGAffineTransformTranslate(
            tx,
            -image.extent.width / 2,
            -image.extent.height / 2)
        
        let transformImage = CIFilter(
            name: "CIAffineTransform",
            withInputParameters: [
                kCIInputImageKey: image,
                kCIInputTransformKey: NSValue(CGAffineTransform: tx)])!.outputImage!
        
        let scale = UIScreen.mainScreen().scale
        let newFrame = CGRectMake(0, 0, self.cameraView.frame.width * scale, self.cameraView.frame.height * scale)
        
        if glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(glContext)
        }
        self.glView.bindDrawable()
        self.ciContext.drawImage(transformImage, inRect: newFrame, fromRect: transformImage.extent)
        self.glView.display()
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here you can count how many frames are dopped
    }
}
