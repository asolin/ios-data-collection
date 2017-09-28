//
//  ViewController.swift
//  Camera
//
//  Created by Cortes Reina Santiago on 26/09/2017.
//  Copyright © 2017 Cortes Reina Santiago. All rights reserved.
//

import UIKit
import CoreMedia
import CoreImage
import AVFoundation

class ViewController: UIViewController {
    // session to manage all data exchange
    let session = AVCaptureSession()
    var camera : AVCaptureDevice?
    var cameraPreviewLayer :AVCaptureVideoPreviewLayer?
    var cameraCaptureOutput : AVCapturePhotoOutput?
    
    weak var delegate: CameraCaptureHelperDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        initializeCaptureSession()
    }
    
    func initializeCaptureSession() {
        
        //initialize session with a given quality preset
        session.sessionPreset = AVCaptureSession.Preset.high
        
        //initialize the camera with the default configuration for the built in wide angle camera in the back
        camera = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.back)
        
        //initialize the camera input and output then add them to the session (catch errors initializing camera)
        do {
            let cameraCaptureInput = try AVCaptureDeviceInput(device: camera!)
            cameraCaptureOutput = AVCapturePhotoOutput()
            
            session.addInput(cameraCaptureInput)
            session.addOutput(cameraCaptureOutput!)
            
        } catch  {
            print(error.localizedDescription)
        }
        
       //initialize the parameters of the preview playes
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session:session)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer?.frame = view.bounds
        cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        //insert sublayer to render to screen
        view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
        
        //start running
        session.startRunning()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}







    
    extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate
    {
        func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
        {
            connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
            {
                return
            }
            
            DispatchQueue.main.async
                {
                    self.delegate?.newCameraImage(self,
                                                  image: CIImage(cvPixelBuffer: pixelBuffer))
            }
            
        }
    }
    
    protocol CameraCaptureHelperDelegate: class
    {
        func newCameraImage(_ cameraCaptureHelper: ViewController, image: CIImage)
    }



