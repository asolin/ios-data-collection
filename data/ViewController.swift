//
//  ViewController.swift
//  data
//
//  Created by Arno Solin on 23.9.2017.
//  Copyright © 2017 Arno Solin. All rights reserved.
//

import UIKit
import CoreMotion
import CoreMedia
import CoreImage
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /* Constants */
    let ACCELEROMETER_ID = 3
    let GYROSCOPE_ID     = 4
    let MAGNETOMETER_ID  = 5
    let BAROMETER_ID     = 6
    let CAMERA_ID        = 1
    let GRAVITY          = 9.81
    let ACCELEROMETER_DT = 0.01
    let GYROSCOPE_DT     = 0.01
    let MAGNETOMETER_DT  = 0.01

    /* Outlets */
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var cameraView: UIImageView!
    
    /* Managers for the sensor data */
    let motionManager = CMMotionManager()
    let altimeter = CMAltimeter()
    
    /* Manager for camera data */
    let captureSession = AVCaptureSession()
    var previewLayer = AVCaptureVideoPreviewLayer()
    var videoOutputStream : AVCaptureVideoDataOutput?
    let captureSessionQueue: DispatchQueue = DispatchQueue(label: "sampleBuffer", attributes: [])
    var assetWriter : AVAssetWriter?
    var pixelBufferAdaptor : AVAssetWriterInputPixelBufferAdaptor?
    var videoInput : AVAssetWriterInput?
    
    /* Variables */
    var isCapturing : Bool = false
    var outputStream : OutputStream!
    var filename : String = ""
    var filePath : NSURL!
    var frameCount = 0;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Tap gesture for start/stop
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.toggleCapture(_:)))
        tap.numberOfTapsRequired = 1
        toggleButton.addGestureRecognizer(tap);
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        let deviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInDuoCamera, AVCaptureDeviceType.builtInWideAngleCamera,AVCaptureDeviceType.builtInTelephotoCamera], mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.unspecified)
        
        for device in (deviceDiscoverySession?.devices)! {
            if(device.position == AVCaptureDevicePosition.back){
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if (captureSession.canAddInput(input)) {
                        
                        // Add input
                        captureSession.addInput(input);
                        
                        // Set resolution
                        if (captureSession.canSetSessionPreset(AVCaptureSessionPreset640x480)) {
                            captureSession.sessionPreset = AVCaptureSessionPreset640x480
                        }
                        
                        // Set frame rate
                        do {
                            try device.lockForConfiguration()
                            device.activeVideoMinFrameDuration = CMTimeMake(1,10)
                            device.activeVideoMaxFrameDuration = CMTimeMake(1,10)
                            device.unlockForConfiguration()
                        } catch {
                            print("Could not lock camera for configuration.")
                        }
                        
                        // TODO Lock focus
                        
                        
                        // TODO Lock exposure
                        

                        // Show preview
                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession);
                        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                        previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait;
                        cameraView.layer.addSublayer(previewLayer);

                        // Add output
                        videoOutputStream = AVCaptureVideoDataOutput()
                        videoOutputStream?.setSampleBufferDelegate(self, queue: captureSessionQueue)
                        if captureSession.canAddOutput(videoOutputStream) {
                            captureSession.addOutput(videoOutputStream)
                        }
                        
                        // Save in portrait orientation
                        let connection = videoOutputStream?.connection(withMediaType: AVFoundation.AVMediaTypeVideo)
                        connection?.videoOrientation = .portrait
                       
                        // startRunning is blocking the main queue, start in its own
                        captureSessionQueue.async {
                            self.captureSession.startRunning()
                        }
                        
                        break
                    }
                } catch let error as Error! {
                    print("Problem starting camera: \n \(error)")
                }
            }
        }
    }

    override func viewDidLayoutSubviews() {
        
        toggleButton.frame = CGRect(x: (self.view.frame.size.width - 80) / 2, y: (self.view.frame.size.height - 100), width: 80, height: 80)
        toggleButton.layer.borderWidth = 6
        toggleButton.layer.cornerRadius = toggleButton.frame.height/2.0
        toggleButton.layer.masksToBounds = true
        toggleButton.layer.borderColor = UIColor.red.cgColor
        toggleButton.layer.backgroundColor = UIColor.white.cgColor
        toggleButton.layer.shadowColor = UIColor.white.cgColor
        
        previewLayer.frame = cameraView.bounds
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func toggleCapture(_ sender: UITapGestureRecognizer) {
        
        if (!isCapturing) {
            
            print("Attempting to start capture");
            
            /* Create filename for the data */
            let date = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            filename = "data-" + formatter.string(from: date)
            print(filename)
            
            /* Create output stream */
            filePath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)!.appendingPathExtension("csv") as NSURL
            outputStream = OutputStream(url: filePath as URL, append: false)
            if outputStream != nil {
                outputStream.open()
            } else {
                print("Unable to open file.")
                return
            }
            
            /* Start accelerometer updates */
            if motionManager.isAccelerometerAvailable && !motionManager.isAccelerometerActive {
                motionManager.accelerometerUpdateInterval = self.ACCELEROMETER_DT
                motionManager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: {(accelerometerData: CMAccelerometerData!, error: Error!) in
                    if (error != nil){
                        print("\(error)");
                    }
                    let str = NSString(format:"%f,%d,%f,%f,%f\n",
                        accelerometerData.timestamp,
                        self.ACCELEROMETER_ID,
                        accelerometerData.acceleration.x * self.GRAVITY,
                        accelerometerData.acceleration.y * self.GRAVITY,
                        accelerometerData.acceleration.z * self.GRAVITY)
                    if self.outputStream.write(str as String) < 0 { print("Write failure"); }
                    } as CMAccelerometerHandler)
            } else {
                print("No accelerometer available.");
            }
            
            /* Start gyroscope updates */
            if motionManager.isGyroAvailable && !motionManager.isGyroActive {
                motionManager.gyroUpdateInterval = self.GYROSCOPE_DT
                motionManager.startGyroUpdates(to: OperationQueue.current!, withHandler: {(gyroData: CMGyroData!, error: Error!) in
                    let str = NSString(format:"%f,%d,%f,%f,%f\n",
                        gyroData.timestamp,
                        self.GYROSCOPE_ID,
                        gyroData.rotationRate.x,
                        gyroData.rotationRate.y,
                        gyroData.rotationRate.z)
                    if self.outputStream.write(str as String) < 0 { print("Write failure"); }
                } as CMGyroHandler)
            } else {
                print("No gyroscope available.");
            }
            
            /* Start magnetometer updates */
            if motionManager.isMagnetometerAvailable && !motionManager.isMagnetometerActive {
                motionManager.magnetometerUpdateInterval = self.MAGNETOMETER_DT
                motionManager.startMagnetometerUpdates(to: OperationQueue.current!, withHandler: {(magnetometerData: CMMagnetometerData!, error: Error!) in
                    if (error != nil){
                        print("\(error)");
                    }
                    let str = NSString(format:"%f,%d,%f,%f,%f\n",
                        magnetometerData.timestamp,
                        self.MAGNETOMETER_ID,
                        magnetometerData.magneticField.x,
                        magnetometerData.magneticField.y,
                        magnetometerData.magneticField.z)
                    if self.outputStream.write(str as String) < 0 { print("Write failure"); }
                } as CMMagnetometerHandler)
            } else {
                print("No magnetometer available.");
            }
            
            /* Start barometer updates */
            if CMAltimeter.isRelativeAltitudeAvailable() {
                altimeter.startRelativeAltitudeUpdates(to: OperationQueue.current!, withHandler: {(altitudeData: CMAltitudeData!, error: Error!)in
                    if (error != nil){
                        print("\(error)");
                    }
                    let str = NSString(format:"%f,%d,%f,%f,0\n",
                        altitudeData.timestamp,
                        self.BAROMETER_ID,
                        altitudeData.pressure.doubleValue,
                        altitudeData.relativeAltitude.doubleValue)
                    if self.outputStream.write(str as String) < 0 { print("Write failure"); }
                } as CMAltitudeHandler)
            } else {
                print("No barometer available.");
            }
            
            /* Start platform location updates */
            // TODO
            
            
            
            /* Start video asset writing */
            let videoPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename).appendingPathExtension("mov")
            
            do {
                assetWriter = try AVAssetWriter(outputURL: videoPath, fileType: AVFileTypeQuickTimeMovie )
            } catch {
                print("Error converting images to video: asset initialization error")
                return
            }
          
            let videoOutputSettings: Dictionary<String, AnyObject> = [
                AVVideoCodecKey : AVVideoCodecH264 as AnyObject,
                AVVideoWidthKey : 480 as AnyObject,
                AVVideoHeightKey : 640 as AnyObject
            ]
            
            // If grayscale: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            // If color: kCVPixelFormatType_32BGRA / kCVPixelFormatType_32ARGB
            let sourceBufferAttributes : [String : AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA) as AnyObject,
            ]
            
            videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
            videoInput?.expectsMediaDataInRealTime = true
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourceBufferAttributes)
            
            // Add video input and start waiting for data
            assetWriter!.add(videoInput!)
            
            // Reset frame count
            frameCount = 0;
            
            /* Start capturing */
            isCapturing = true;
            self.toggleButton.setTitle("Stop", for: .normal);
            animateButtonRadius(toValue: toggleButton.frame.height/10.0)
            
            print("Recording started!")
            
        } else {
            
            print("Attempting to stop capture");
            
            /* Stop capturing */
            isCapturing = false
            self.toggleButton.setTitle("Start", for: .normal)
            animateButtonRadius(toValue: toggleButton.frame.height/2.0)
            
            /* Stop asset writer */
            assetWriter!.finishWriting{
                print("Asset writer stopped.")
            }
            
            /* Move video file */
            let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let destinationVideoPath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(filename)?.appendingPathExtension("mov")
            let fileManager = FileManager.default
            do {
                try fileManager.moveItem(at: assetWriter!.outputURL, to: destinationVideoPath!)
            } catch let error as NSError {
                print("Error occurred while moving video file:\n \(error)")
            }
            
            /* Stop capture */
            motionManager.stopAccelerometerUpdates();
            motionManager.stopGyroUpdates();
            motionManager.stopMagnetometerUpdates();
            altimeter.stopRelativeAltitudeUpdates();
            
            /* Close output stream */
            outputStream.close()
            
            /* Move data file */
            let destinationPath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(filename)?.appendingPathExtension("csv")
            do {
                try fileManager.moveItem(at: filePath as URL, to: destinationPath!)
            } catch let error as NSError {
                print("Error occurred while moving data file:\n \(error)")
            }
            
        }
        
    }
    
    @IBAction func unwindToMain(segue: UIStoryboardSegue) {
    }
    
    func animateButtonRadius(toValue: CGFloat) {
        let animation = CABasicAnimation(keyPath:"cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.fromValue = toggleButton.layer.cornerRadius
        animation.toValue = toValue
        animation.duration = 1.0
        toggleButton.layer.add(animation, forKey: "cornerRadius")
        toggleButton.layer.cornerRadius = toValue
    }
    
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped frame.")
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
    {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        //let cameraImage = CIImage(cvPixelBuffer: pixelBuffer!)
        //let bufferImage = UIImage(ciImage: cameraImage)
        
       captureSessionQueue.async {

            // Start session at first recorded frame
            if (self.isCapturing && self.assetWriter?.status != AVAssetWriterStatus.writing) {
                self.assetWriter!.startWriting()
                self.assetWriter!.startSession(atSourceTime: timestamp)
            }
        
            // If recording is active append bufferImage to video frame
            while (self.isCapturing) {
                // Append images to video
                if (self.videoInput!.isReadyForMoreMediaData) {
                    
                    // Append image to video
                    self.pixelBufferAdaptor?.append(pixelBuffer!, withPresentationTime: timestamp)
                    
                    // Append frame to csv
                    let str = NSString(format:"%f,%d,%d,0,0\n",
                        CMTimeGetSeconds(timestamp),
                        self.CAMERA_ID,
                        self.frameCount)
                    if self.outputStream.write(str as String) < 0 { print("Write failure"); }
                    
                    break
                }
            }
        }
    }
}

// Extension to OutputStream: Write Strings
extension OutputStream {
    
    func write(_ string: String, encoding: String.Encoding = .utf8, allowLossyConversion: Bool = false) -> Int {
        
        if let data = string.data(using: encoding, allowLossyConversion: allowLossyConversion) {
            return data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Int in
                var pointer = bytes
                var bytesRemaining = data.count
                var totalBytesWritten = 0
                
                while bytesRemaining > 0 {
                    let bytesWritten = self.write(pointer, maxLength: bytesRemaining)
                    if bytesWritten < 0 {
                        return -1
                    }
                    
                    bytesRemaining -= bytesWritten
                    pointer += bytesWritten
                    totalBytesWritten += bytesWritten
                }
                
                return totalBytesWritten
            }
        }
        
        return -1
    }
    
}


