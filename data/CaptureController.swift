import Foundation
import CoreMotion
import CoreMedia
import CoreImage
import AVFoundation
import CoreLocation
import ARKit
import Kronos

protocol CaptureControllerDelegate: class {
    func capturing() -> Bool
    func setARSession(_ arSession: ARSession)
    func startCapture()
    func stopCapture()
}

class CaptureController: NSObject {
    var arSession: ARSession!

    /* Managers for the sensor data */
    let motionManager = CMMotionManager()
    let altimeter = CMAltimeter()
    var locationManager = CLLocationManager()

    let captureSessionQueue: DispatchQueue = DispatchQueue(label: "captureSession", attributes: [])
    var opQueue: OperationQueue!

    /* Manager for camera data */
    var assetWriter : AVAssetWriter?
    var pixelBufferAdaptor : AVAssetWriterInputPixelBufferAdaptor?
    var videoInput : AVAssetWriterInput?

    var isCapturing : Bool = false
    var outputStream : OutputStream!
    //var pointcloudStream : OutputStream!
    var filename : String = ""
    var filePath : NSURL!
    var frameCount = 0
    var startTime : TimeInterval = 0
    var firstArFrame : Bool = true
    var firstFrameTimestamp : TimeInterval = 0.0

    func start() {
        opQueue = OperationQueue()
        opQueue.underlyingQueue = captureSessionQueue

        /* Set up locationManager */
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        Clock.sync()
    }

    func runVideoAndARKitRecording() {
        if !UserDefaults.standard.bool(forKey: SettingsKeys.VideoARKitEnableKey) {
            return
        }

        let videoPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename).appendingPathExtension("mov")

        do {
            assetWriter = try AVAssetWriter(outputURL: videoPath, fileType: AVFileType.mov )
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

        videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
        videoInput?.expectsMediaDataInRealTime = true
        videoInput?.transform = CGAffineTransform.init(rotationAngle: CGFloat(Double.pi/2))
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourceBufferAttributes)

        // Add video input and start waiting for data
        assetWriter!.add(videoInput!)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func runLocation() {
        if (UserDefaults.standard.bool(forKey: SettingsKeys.LocationEnableKey)){
            locationManager.startUpdatingLocation()
        }
    }
}

extension CaptureController: CaptureControllerDelegate {
    func capturing() -> Bool {
        return isCapturing
    }

    func setARSession(_ arSession: ARSession) {
        let configuration = ARWorldTrackingConfiguration()
        arSession.run(configuration)
        arSession.delegate = self
        arSession.delegateQueue = captureSessionQueue
        self.arSession = arSession
    }

    func startCapture() {
        Clock.sync()

        // Pause ARKit for resetting
        arSession.pause()

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

        /*
        filePath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)!.appendingPathExtension("pcl") as NSURL
            pointcloudStream = OutputStream(url: filePath as URL, append: false)
        if pointcloudStream != nil {
            pointcloudStream.open()
        } else {
            print("Unable to open pointcloud file.")
                return
        }
        */

        /* Store start time */
        startTime = ProcessInfo.processInfo.systemUptime
        let str = NSString(format:"%f,%d,%f,%f,0\n",
            startTime,
            TIMESTAMP_ID,
            Date().timeIntervalSince1970,
            Clock.now?.timeIntervalSince1970 ?? 0)
        if self.outputStream.write(str as String) < 0 { print("Write timestamp failure"); }

        // Setup data acquisition.
        if UserDefaults.standard.bool(forKey: SettingsKeys.AccEnableKey) {
            runAccDataAcquisition(motionManager, opQueue, outputStream)
        }
        if UserDefaults.standard.bool(forKey: SettingsKeys.GyroEnableKey) {
            runGyroDataAcquisition(motionManager, opQueue, outputStream)
        }
        if UserDefaults.standard.bool(forKey: SettingsKeys.MagnetEnableKey) {
            runMagnetometerDataAcquisition(motionManager, opQueue, outputStream)
        }
        if UserDefaults.standard.bool(forKey: SettingsKeys.BarometerEnableKey) {
            runBarometerDataAcquisition(altimeter, opQueue, outputStream)
        }
        runLocation();
        // Start ARKit and Video
        runVideoAndARKitRecording()

        // Reset frame count
        frameCount = 0;
        firstArFrame = true

        /* Start capturing */
        isCapturing = true;

        print("Recording started!")
    }

    func stopCapture() {
        print("Attempting to stop capture");

        /* Stop capturing */
        isCapturing = false

        // Stop video capture.
        // Use the captureSession queue in case writing and stopping the writer could interfere.
        captureSessionQueue.async {
            if let assetWriter = self.assetWriter {
                if assetWriter.status != AVAssetWriter.Status.writing {
                    return
                }
                assetWriter.finishWriting(completionHandler: {
                    print("Asset writer stopped.")

                    // Move video file after assetWriter is finished.
                    let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let fileManager = FileManager.default
                    if UserDefaults.standard.bool(forKey: SettingsKeys.VideoARKitEnableKey) {
                        let destinationVideoPath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(self.filename)?.appendingPathExtension("mov")

                        do {
                            try fileManager.moveItem(at: assetWriter.outputURL, to: destinationVideoPath!)
                        } catch let error as NSError {
                            print("Error occurred while moving video file:\n \(error)")
                        }
                    }
                })
            }
        }

        // Stop sensor capture.
        if (motionManager.isAccelerometerActive) {motionManager.stopAccelerometerUpdates(); }
        if (motionManager.isGyroActive) { motionManager.stopGyroUpdates(); }
        if (motionManager.isMagnetometerActive) { motionManager.stopMagnetometerUpdates(); }
        altimeter.stopRelativeAltitudeUpdates();
        locationManager.stopUpdatingLocation()

        /* Close output stream */
        outputStream.close()
        //pointcloudStream.close()

        /* Move data file */
        let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileManager = FileManager.default
        let destinationPath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(filename)?.appendingPathExtension("csv")
        do {
            try fileManager.moveItem(at: filePath as URL, to: destinationPath!)
        } catch let error as NSError {
            print("Error occurred while moving data file:\n \(error)")
        }

        if (UserDefaults.standard.bool(forKey: SettingsKeys.PointcloudEnableKey)) {
            let pclDestinationFile = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(filename)?.appendingPathExtension("pcl")
            do {
                try fileManager.moveItem(at: filePath as URL, to: pclDestinationFile!)
            } catch let error as NSError {
                print("Error occurred while moving pointcloud file:\n \(error)")
            }
        }
    }
}

extension CaptureController: ARSessionDelegate {
    @available(iOS 11.0, *)
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if !UserDefaults.standard.bool(forKey: SettingsKeys.VideoARKitEnableKey) {
            return
        }

        // Timestamp
        let timestamp = CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 1000000)

        // Start session at first recorded frame
        if (self.isCapturing && frame.timestamp > self.startTime && self.assetWriter?.status != AVAssetWriter.Status.writing) {
            self.assetWriter!.startWriting()
            self.assetWriter!.startSession(atSourceTime: timestamp)
        }

        // If recording is active append bufferImage to video frame
        while (self.isCapturing && frame.timestamp > self.startTime) {
            if (self.firstArFrame) {
                self.firstFrameTimestamp = frame.timestamp
                self.firstArFrame = false
            }
            else {
                // TODO Make this functional again.
                /*
                DispatchQueue.main.async {
                    self.timeLabel.text =  String(format: "Rec Time: %.02f s", frame.timestamp - self.firstFrameTimestamp)
                }
                */
            }

            if (UserDefaults.standard.bool(forKey: SettingsKeys.PointcloudEnableKey)) {
                // Append ARKit point cloud to csv
                if let featurePointsArray = frame.rawFeaturePoints?.points {
                    var pstr = NSString(format:"%f,%d,%d",
                                        frame.timestamp,
                                        POINTCLOUD_ID,
                                        self.frameCount)
                    // Append each point to str
                    for point in featurePointsArray {
                        pstr = NSString(format:"%@,%f,%f,%f",
                                        pstr,
                                        point.x, point.y, point.z)
                    }
                    pstr = NSString(format:"%@\n", pstr)
                    if self.outputStream.write(pstr as String) < 0 {
                        print("Write ARKit point cloud failure");
                    }
                }
            }

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
                    ARKIT_ID,
                    self.frameCount,
                    translation[0], translation[1], translation[2],
                    eulerAngles[0], eulerAngles[1], eulerAngles[2],
                    intrinsics[0][0], intrinsics[1][1], intrinsics[2][0], intrinsics[2][1],
                    transform[0][0],transform[1][0],transform[2][0],
                    transform[0][1],transform[1][1],transform[2][1],
                    transform[0][2],transform[1][2],transform[2][2])
                if self.outputStream.write(str as String) < 0 { print("Write ARKit failure"); }

                self.frameCount = self.frameCount + 1

                break
            }
        }
    }
}

extension CaptureController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (!isCapturing) {
            return
        }
        // Time offset
        let offset = Date().timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime

        // For each location
        for loc in locations {
            let str = NSString(format:"%f,%d,%.8f,%.8f,%f,%f,%f,%f\n",
                loc.timestamp.timeIntervalSinceReferenceDate-offset,
                LOCATION_ID,
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
