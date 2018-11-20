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
import CoreLocation
import ARKit
import Kronos

@available(iOS 11.0, *)
class ViewController: UIViewController, CLLocationManagerDelegate, ARSessionDelegate, ARSCNViewDelegate {
    
    /* Constants */
    let TIMESTAMP_ID     = 0
    let CAMERA_ID        = 1
    let LOCATION_ID      = 2
    let ACCELEROMETER_ID = 3
    let GYROSCOPE_ID     = 4
    let MAGNETOMETER_ID  = 5
    let BAROMETER_ID     = 6
    let ARKIT_ID         = 7
    let POINTCLOUD_ID    = 8;
    let GRAVITY          = -9.81
    let ACCELEROMETER_DT = 0.01
    let GYROSCOPE_DT     = 0.01
    let MAGNETOMETER_DT  = 0.01

    /* Outlets */
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var arView: ARSCNView!
    
    /* Managers for the sensor data */
    let motionManager = CMMotionManager()
    let altimeter = CMAltimeter()
    var locationManager = CLLocationManager()
    
    /* Manager for camera data */
    let captureSessionQueue: DispatchQueue = DispatchQueue(label: "sampleBuffer", attributes: [])
    var assetWriter : AVAssetWriter?
    var pixelBufferAdaptor : AVAssetWriterInputPixelBufferAdaptor?
    var videoInput : AVAssetWriterInput?

    /* Variables */
    var isCapturing : Bool = false
    var outputStream : OutputStream!
    var filename : String = ""
    var filePath : NSURL!
    var frameCount = 0
    var startTime : TimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Tap gesture for start/stop
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.toggleCapture(_:)))
        tap.numberOfTapsRequired = 1
        toggleButton.addGestureRecognizer(tap);
        
        // Sync clock
        Clock.sync()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        /* Set up locationManager */
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        /* Set up ARKit */
        arView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        arView.session.run(configuration)
        arView.session.delegate = self

    }

    override func viewDidLayoutSubviews() {
        
        toggleButton.frame = CGRect(x: (self.view.frame.size.width - 80) / 2, y: (self.view.frame.size.height - 100), width: 80, height: 80)
        toggleButton.layer.borderWidth = 2
        toggleButton.layer.cornerRadius = toggleButton.frame.height/2.0
        toggleButton.layer.masksToBounds = true
        toggleButton.layer.borderColor = UIColor.red.cgColor
        toggleButton.layer.backgroundColor = UIColor.white.cgColor
        toggleButton.layer.shadowColor = UIColor.white.cgColor
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func toggleCapture(_ sender: UITapGestureRecognizer) {
        
        if (!isCapturing) {
            
            // Sync clock
            Clock.sync()
            
            // Pause ARKit for resetting
            arView.session.pause()
            
            print("Attempting to start capture");
            
            /* Create filename for the data */
            let date = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
            
            /* Store start time */
            startTime = ProcessInfo.processInfo.systemUptime
            let str = NSString(format:"%f,%d,%f,%f,0\n",
                startTime,
                self.TIMESTAMP_ID,
                Date().timeIntervalSince1970,
                Clock.now!.timeIntervalSince1970)
            if self.outputStream.write(str as String) < 0 { print("Write timestamp failure"); }
            
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
                    if self.outputStream.write(str as String) < 0 { print("Write accelerometer failure"); }
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
                    if self.outputStream.write(str as String) < 0 { print("Write gyroscope failure"); }
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
                    if self.outputStream.write(str as String) < 0 { print("Write magnetometer failure"); }
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
                    if self.outputStream.write(str as String) < 0 { print("Write barometer failure"); }
                } as CMAltitudeHandler)
            } else {
                print("No barometer available.");
            }
            
            /* Start location updates */
            locationManager.startUpdatingLocation()
            
            /* Start video asset writing */
            let videoPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename).appendingPathExtension("mov")
            
            do {
                assetWriter = try AVAssetWriter(outputURL: videoPath, fileType: AVFileTypeQuickTimeMovie )
            } catch {
                print("Error converting images to video: asset initialization error")
                return
            }
          
            let videoOutputSettings: Dictionary<String, AnyObject> = [
                AVVideoCodecKey : AVVideoCodecType.h264 as AnyObject,
                AVVideoWidthKey : 1280 as AnyObject,
                AVVideoHeightKey : 720 as AnyObject
            ]
            
            // If grayscale: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            // If color: kCVPixelFormatType_32BGRA / kCVPixelFormatType_32ARGB
            let sourceBufferAttributes : [String : AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA) as AnyObject,
            ]
            
            videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
            videoInput?.expectsMediaDataInRealTime = true
            videoInput?.transform = CGAffineTransform.init(rotationAngle: CGFloat(Double.pi/2))
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourceBufferAttributes)
            
            // Add video input and start waiting for data
            assetWriter!.add(videoInput!)
            
            // Start ARKit
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            // Reset frame count
            frameCount = 0;
            
            /* Start capturing */
            isCapturing = true;
            self.toggleButton.setTitle("Stop", for: .normal);
            animateButtonRadius(toValue: toggleButton.frame.height/10.0)
            UIApplication.shared.isIdleTimerDisabled = true
            
            print("Recording started!")
            
        } else {
            
            print("Attempting to stop capture");
            
            /* Stop capturing */
            isCapturing = false
            self.toggleButton.setTitle("Start", for: .normal)
            animateButtonRadius(toValue: toggleButton.frame.height/2.0)
            UIApplication.shared.isIdleTimerDisabled = false
            
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
            locationManager.stopUpdatingLocation()
            
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
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (isCapturing) {
            // Time offset
            let offset = Date().timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
            
            // For each location
            for loc in locations {
                let str = NSString(format:"%f,%d,%.8f,%.8f,%f,%f,%f,%f\n",
                    loc.timestamp.timeIntervalSinceReferenceDate-offset,
                    self.LOCATION_ID,
                    loc.coordinate.latitude,
                    loc.coordinate.longitude,
                    loc.horizontalAccuracy,
                    loc.altitude,
                    loc.verticalAccuracy,
                    loc.speed)
                    if self.outputStream.write(str as String) < 0 { print("Write location failure"); }
            }
        }
    }
    
    // MARK: - Unwind action for the extra view
    
    @IBAction func unwindToMain(segue: UIStoryboardSegue) {
    }
    
    // MARK: - Animate button
    
    func animateButtonRadius(toValue: CGFloat) {
        let animation = CABasicAnimation(keyPath:"cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.fromValue = toggleButton.layer.cornerRadius
        animation.toValue = toValue
        animation.duration = 0.5
        toggleButton.layer.add(animation, forKey: "cornerRadius")
        toggleButton.layer.cornerRadius = toValue
    }
    
    // MARK: -ARSessionDelegate
    @available(iOS 11.0, *)
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        // Execute in its own thread
        captureSessionQueue.async {
            
            // Timestamp
            let timestamp = CMTimeMakeWithSeconds(frame.timestamp, 1000000)

            // Start session at first recorded frame
            if (self.isCapturing && frame.timestamp > self.startTime && self.assetWriter?.status != AVAssetWriterStatus.writing) {
                self.assetWriter!.startWriting()
                self.assetWriter!.startSession(atSourceTime: timestamp)
            }
            
            // If recording is active append bufferImage to video frame
            while (self.isCapturing && frame.timestamp > self.startTime) {
                
                // Append images to video
                if (self.videoInput!.isReadyForMoreMediaData) {
                    
                    // Append image to video
                    self.pixelBufferAdaptor?.append(frame.capturedImage, withPresentationTime: timestamp)
                    
                    let translation = frame.camera.transform.translation
                    let eulerAngles = frame.camera.eulerAngles
                    let intrinsics = frame.camera.intrinsics
                    let transform = frame.camera.transform
                    
                    // Append ARKit to csv
                    let str = NSString(format:"%f,%d,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\n",
                        frame.timestamp,
                        self.ARKIT_ID,
                        self.frameCount,
                        translation[0], translation[1], translation[2],
                        eulerAngles[0], eulerAngles[1], eulerAngles[2],
                        intrinsics[0][0], intrinsics[1][1], intrinsics[2][0], intrinsics[2][1],
                        transform[0][0],transform[1][0],transform[2][0],
                        transform[0][1],transform[1][1],transform[2][1],
                        transform[0][2],transform[1][2],transform[2][2])
                    if self.outputStream.write(str as String) < 0 { print("Write ARKit failure"); }
                    
                    // Append ARKit point cloud to csv
                    if let featurePointsArray = frame.rawFeaturePoints?.points {
                        var pstr = NSString(format:"%f,%d,%d",
                                           frame.timestamp,
                                           self.POINTCLOUD_ID,
                                           self.frameCount)
                        // Append each point to str
                        for point in featurePointsArray {
                            pstr = NSString(format:"%@,%f,%f,%f",
                                           pstr,
                                           point.x, point.y, point.z)
                        }
                        pstr = NSString(format:"%@\n", pstr)
                        if self.outputStream.write(pstr as String) < 0 { print("Write ARKit point cloud failure"); }
                    }
                    
                    // Append ARKit projection matrix to csv
                    //let projMat = frame.camera.projectionMatrix;
                    //let projMat = frame.displayTransform(for: UIInterfaceOrientation.portrait, viewportSize: frame.camera.imageResolution)
                    //let projMat = frame.camera.projectionMatrix(for: UIInterfaceOrientation.portrait, viewportSize: frame.camera.imageResolution, zNear: 0.01, zFar: 1000.0)
                    let projMat = frame.camera.viewMatrix(for: UIInterfaceOrientation.portrait)
                    let fstr = NSString(format:"%f,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\n",
                                       frame.timestamp,
                                       10,
                                       projMat[0][0],projMat[0][1],projMat[0][2],
                                       projMat[1][0],projMat[1][1],projMat[1][2],
                                       projMat[2][0],projMat[2][1],projMat[2][2],
                                       projMat[3][0],projMat[3][1],projMat[3][2])
                    if self.outputStream.write(fstr as String) < 0 { print("Write ARKit projection failure"); }
                    
                    print("Transform:",transform)
                    print(projMat)
                    
                    self.frameCount = self.frameCount + 1
                    
                    break
                }
            }
        }
    }
}

// MARK: - OutputStream: Write Strings

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

// MARK: - float4x4 extensions

extension float4x4 {
    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
     */
    var translation: float3 {
        let translation = columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

