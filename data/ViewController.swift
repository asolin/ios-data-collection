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
    
    /* Variables */
    var isCapturing : Bool = false
    var outputStream : OutputStream!
    var filename : String = ""
    var filePath : NSURL!
    
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
                        
                        captureSession.addInput(input);

                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession);
                        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                        previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait;
                        
                        cameraView.layer.addSublayer(previewLayer);

                        // Set output stream
                        videoOutputStream = AVCaptureVideoDataOutput()
                        //videoOutputStream.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)] // 3
                        
                        //videoOutputStream.alwaysDiscardsLateVideoFrames = true // 4
                        
                        
                       
                        videoOutputStream?.setSampleBufferDelegate(self, queue: captureSessionQueue)
                        
                        //videoOutputStream?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBuffer", attributes: []))
                        
                        
                        if captureSession.canAddOutput(videoOutputStream) {
                            captureSession.addOutput(videoOutputStream)
                        }
                       
                        // Start running is blocking the main queue, start in its own
                        captureSessionQueue.async {
                            self.captureSession.startRunning()
                            //self.videoOutputStream?.setSampleBufferDelegate(self, queue: self.captureSessionQueue)
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
            
            /* Start capturing */
            isCapturing = true;
            self.toggleButton.setTitle("Stop", for: .normal);
            animateButtonRadius(toValue: toggleButton.frame.height/10.0)
            
        } else {
            
            print("Attempting to stop capture");
            
            /* Stop capturing */
            isCapturing = false
            self.toggleButton.setTitle("Start", for: .normal)
            animateButtonRadius(toValue: toggleButton.frame.height/2.0)
            
            /* Stop capture */
            motionManager.stopAccelerometerUpdates();
            motionManager.stopGyroUpdates();
            motionManager.stopMagnetometerUpdates();
            altimeter.stopRelativeAltitudeUpdates();
            
            /* Close output stream */
            outputStream.close()
            
            /* Move data file */
            let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let destinationPath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(filename)?.appendingPathExtension("csv")
            let fileManager = FileManager.default
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
    
    
    
    //func captureOutput(_ output : AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
    func captureOutput(_ output: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("dropped frame")
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer!)
        let bufferImage = UIImage(ciImage: cameraImage)
        
        print("Frame!")
        
        DispatchQueue.main.async {
            
                // send captured frame to the videoPreview
                //self.videoPreview.image = bufferImage
                
                
                // if recording is active append bufferImage to video frame
                /*
                while (recordingNow == true){
                    
                    print("OK we're recording!")
                    
                    /// Append images to video
                    while (writerInput.isReadyForMoreMediaData) {
                        
                        let lastFrameTime = CMTimeMake(Int64(frameCount), videoFPS)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                        
                        pixelBufferAdaptor.append(pixelBuffer!, withPresentationTime: presentationTime)
                        
                        
                        frameCount += 1              
                    }
                }
                */
        }
    }
    
    
    /*
    func startVideoRecording() {
        
        guard let assetWriter = createAssetWriter(path: filePath!, size: videoSize) else {
            print("Error converting images to video: AVAssetWriter not created")
            return
        }
        
        // AVAssetWriter exists so create AVAssetWriterInputPixelBufferAdaptor
        let writerInput = assetWriter.inputs.filter{ $0.mediaType == AVMediaTypeVideo }.first!
        
        
        let sourceBufferAttributes : [String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB) as AnyObject,
            kCVPixelBufferWidthKey as String : videoSize.width as AnyObject,
            kCVPixelBufferHeightKey as String : videoSize.height as AnyObject,
            ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        // Start writing session
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: kCMTimeZero)
        if (pixelBufferAdaptor.pixelBufferPool == nil) {
            print("Error converting images to video: pixelBufferPool nil after starting session")
            
            assetWriter.finishWriting{
                print("assetWritter stopped!")
            }
            recordingNow = false
            
            return
        }
        
        frameCount = 0
        
        print("Recording started!")
        
    }
    */
    
    
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


