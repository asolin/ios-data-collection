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
    func getAVCaptureSession() -> AVCaptureSession
    func setARSession(_ arSession: ARSession)
    func startCamera(_ cameraMode: CameraMode)
    func getRecTime() -> Optional<TimeInterval>
    func startCapture()
    func stopCapture()
}

class CaptureController: NSObject {
    // Other sensors.
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var locationManager = CLLocationManager()

    private let captureSessionQueue: DispatchQueue = DispatchQueue(label: "captureSession", attributes: [])
    private var opQueue: OperationQueue!

    // Camera and video.
    private var arSession: ARSession!
    private var assetWriter : AVAssetWriter?
    private var pixelBufferAdaptor : AVAssetWriterInputPixelBufferAdaptor?
    private var videoInput : AVAssetWriterInput?

    private var cameraMode: CameraMode!
    // ViewController assumes the captureSession remains valid.
    private let captureSession = AVCaptureSession()
    private var cameraInput: AVCaptureDeviceInput?
    private var camera: AVCaptureDevice!
    private let preset = AVCaptureSession.Preset.high

    private var isCapturing : Bool = false
    private var outputStream : OutputStream!
    //private var pointcloudStream : OutputStream!
    private var filename : String = ""
    private var filePath : NSURL!
    private var frameCount = 0
    private var startTime : TimeInterval = 0
    private var firstFrame : Bool = true
    private var firstFrameTimestamp : TimeInterval = 0.0
    private var lastTimestamp : TimeInterval = 0.0

    func start() {
        opQueue = OperationQueue()
        opQueue.underlyingQueue = captureSessionQueue

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        Clock.sync()
    }

    func startAVCamera() {
        func configureCaptureDevice() throws {
            if captureSession.canSetSessionPreset(preset) {
                captureSession.sessionPreset = preset
            }
            else {
                throw CameraControllerError.unsupportedPreset
            }

            // Use WideAngle, the device type with shortest focal length. The rest are fallbacks.
            let deviceTypes = [
                AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                AVCaptureDevice.DeviceType.builtInDualCamera,
                AVCaptureDevice.DeviceType.builtInTelephotoCamera,
                ]
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType.video, position: .back)

            let cameras = session.devices.compactMap { $0 }
            guard let camera = cameras.first else { throw CameraControllerError.backCameraNotAvailable }
            self.cameraInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(self.cameraInput!) {
                captureSession.addInput(self.cameraInput!)
            }

            // The remaining configuration must come after setting any session presets.
            try camera.lockForConfiguration()

            // Lock focus to the maximum value 1.0.
            /*
            if camera.isLockingFocusWithCustomLensPositionSupported {
                camera.setFocusModeLocked(lensPosition: 1.0, completionHandler: nil)
            }
            */

            // Example of setting exposure.
            /*
            if camera.isExposureModeSupported(AVCaptureDevice.ExposureMode.custom) {
                camera.setExposureModeCustom(duration: CMTimeMake(value: 1, timescale: 100), iso: Float(400), completionHandler: nil)
            }
            */

            // According to Apple docs changing exposure can change frame duration settings, so set fps last.
            let r = camera.activeFormat.videoSupportedFrameRateRanges.first!
            // TODO Using ARKit seems to give better FPS than this. Investigate?
            var frameDur = r.minFrameDuration
            // var frameDur = CMTimeMake(value: 1, timescale: 60)

            if frameDur > r.maxFrameDuration { frameDur = r.maxFrameDuration }
            if frameDur < r.minFrameDuration { frameDur = r.minFrameDuration }
            camera.activeVideoMinFrameDuration = frameDur
            camera.activeVideoMaxFrameDuration = frameDur

            // No zoom by cropping.
            camera.videoZoomFactor = 1.0

            // Example of locking white balance.
            /*
            var gains = camera.deviceWhiteBalanceGains
            gains.blueGain = 0.5 * camera.maxWhiteBalanceGain
            gains.greenGain = 1.0
            gains.redGain = 1.0
            camera.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
            */

            camera.unlockForConfiguration()
            self.camera = camera

            // Note that it may take some time for the sensors to physically adjust,
            // so querying some of the values here might not give expected results
            // (that's what the `completionHandler` callbacks are for).
        }

        func configureVideoOutput() throws {
            let videoOutput = AVCaptureVideoDataOutput()

            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]

            //videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: captureSessionQueue)

            let outputs = captureSession.outputs
            for output in outputs {
                captureSession.removeOutput(output)
            }
            guard captureSession.canAddOutput(videoOutput) else { throw CameraControllerError.cannotAddOutput }
            captureSession.addOutput(videoOutput)

            guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { throw CameraControllerError.noConnection }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isCameraIntrinsicMatrixDeliverySupported {
                // Inserts the intrinsic matrix in each sample buffer.
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }

        do {
            try configureCaptureDevice()
            try configureVideoOutput()
            self.captureSession.startRunning()
        }
        catch {
            print("StartAVCamera() error: \(error)")
        }
    }

    private func setupAssetWriter(_ pixelBuffer: CVPixelBuffer, _ timestamp: CMTime) {
        let videoPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename).appendingPathExtension("mov")
        do {
            assetWriter = try AVAssetWriter(outputURL: videoPath, fileType: AVFileType.mov )
        } catch {
            print("Error converting images to video: asset initialization error")
            return
        }

        // The width and height must match the input or the system will silently
        // stretch the frames.
        let videoOutputSettings: Dictionary<String, AnyObject> = [
            AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
            AVVideoWidthKey: CVPixelBufferGetWidth(pixelBuffer) as AnyObject,
            AVVideoHeightKey: CVPixelBufferGetHeight(pixelBuffer) as AnyObject
        ]

        // If grayscale: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        // If color: kCVPixelFormatType_32BGRA / kCVPixelFormatType_32ARGB
        let sourceBufferAttributes : [String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA) as AnyObject,
            ]

        videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
        videoInput?.expectsMediaDataInRealTime = true
        // Rotate by 90 degrees to get portrait orientation. Do not use initializer parameter `rotationAngle: CGFloat(Double.pi/2))`
        // because it gives inexact values for the transform matrix entries.
        videoInput?.transform = CGAffineTransform.init(a: 0.0, b: 1.0, c: -1.0, d: 0.0, tx: 0.0, ty: 0.0);
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourceBufferAttributes)

        assetWriter!.add(videoInput!)
        assetWriter!.startWriting()

        assetWriter!.startSession(atSourceTime: timestamp)
    }

    private func runLocation() {
        if (UserDefaults.standard.bool(forKey: SettingsKeys.LocationEnableKey)){
            locationManager.startUpdatingLocation()
        }
    }
}

extension CaptureController: CaptureControllerDelegate {
    func capturing() -> Bool {
        return isCapturing
    }

    func getAVCaptureSession() -> AVCaptureSession {
        return captureSession
    }

    func setARSession(_ arSession: ARSession) {
        arSession.delegate = self
        arSession.delegateQueue = captureSessionQueue
        self.arSession = arSession
    }

    func startCamera(_ cameraMode: CameraMode) {
        if self.cameraMode == cameraMode {
            return
        }
        self.cameraMode = cameraMode

        captureSession.stopRunning()
        arSession.pause()

        switch cameraMode {
        case .AV:
            startAVCamera()
        case .ARKit:
            let configuration = ARWorldTrackingConfiguration()
            // Resolution can be set starting from iOS 11.3. Default seems to be the best one.
            /*
            if #available(iOS 11.3, *) {
                print(configuration.videoFormat)
                for f in ARWorldTrackingConfiguration.supportedVideoFormats {
                    print(f)
                }
            }
            */
            arSession.run(configuration)
        }
    }

    func getRecTime() -> Optional<TimeInterval> {
        if self.isCapturing {
            return Optional.some(lastTimestamp - firstFrameTimestamp)
        }
        else {
            return Optional.none
        }
    }

    func startCapture() {
        Clock.sync()

        // Filename from date.
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        filename = "data-" + formatter.string(from: date)

        // Setup sensor data csv.
        filePath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)!.appendingPathExtension("csv") as NSURL
        outputStream = OutputStream(url: filePath as URL, append: false)
        if outputStream != nil {
            outputStream.open()
        } else {
            print("Unable to open csv output file.")
            return
        }

        /*
        filePath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)!.appendingPathExtension("pcl") as NSURL
            pointcloudStream = OutputStream(url: filePath as URL, append: false)
        if pointcloudStream != nil {
            pointcloudStream.open()
        } else {
            print("Unable to open pointcloud output file.")
                return
        }
        */

        // Store start time.
        // There is no longer guarantee this is smaller than frame timestamps.
        startTime = ProcessInfo.processInfo.systemUptime
        let str = NSString(format:"%f,%d,%f,%f,0\n",
            startTime,
            TIMESTAMP_ID,
            Date().timeIntervalSince1970,
            Clock.now?.timeIntervalSince1970 ?? 0)
        if self.outputStream.write(str as String) < 0 {
            print("Failure writing timestamp to output csv.")
        }
        firstFrameTimestamp = 0.0
        lastTimestamp = 0.0

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
        runLocation()

        // Setup AV camera or ARKit for capturing.
        switch cameraMode! {
        case .AV:
            break
        case .ARKit:
            //if !UserDefaults.standard.bool(forKey: SettingsKeys.VideoARKitEnableKey) { }
            arSession.pause()
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
        frameCount = 0;
        firstFrame = true

        isCapturing = true
        print("Recording started!")
    }

    func stopCapture() {
        isCapturing = false

        // Stop video capture.
        // Use the captureSession queue in case writing and stopping the writer could interfere.
        captureSessionQueue.async {
            if let assetWriter = self.assetWriter {
                if assetWriter.status != AVAssetWriter.Status.writing {
                    print("Expected assetWriter to be writing.")
                    return
                }
                assetWriter.finishWriting(completionHandler: {
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

        // Stop other sensor capture.
        if (motionManager.isAccelerometerActive) {motionManager.stopAccelerometerUpdates(); }
        if (motionManager.isGyroActive) { motionManager.stopGyroUpdates(); }
        if (motionManager.isMagnetometerActive) { motionManager.stopMagnetometerUpdates(); }
        altimeter.stopRelativeAltitudeUpdates();
        locationManager.stopUpdatingLocation()

        outputStream.close()
        //pointcloudStream.close()

        // Move data files.
        let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileManager = FileManager.default
        let destinationPath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(filename)?.appendingPathExtension("csv")
        do {
            try fileManager.moveItem(at: filePath as URL, to: destinationPath!)
        } catch let error as NSError {
            print("Error occurred while moving data file:\n \(error)")
        }

        /*
        if (UserDefaults.standard.bool(forKey: SettingsKeys.PointcloudEnableKey)) {
            let pclDestinationFile = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(filename)?.appendingPathExtension("pcl")
            do {
                try fileManager.moveItem(at: filePath as URL, to: pclDestinationFile!)
            } catch let error as NSError {
                print("Error occurred while moving pointcloud file:\n \(error)")
            }
        }
        */
        print("Recording stopped.")
    }
}

extension CaptureController: ARSessionDelegate {
    @available(iOS 11.0, *)
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if !UserDefaults.standard.bool(forKey: SettingsKeys.VideoARKitEnableKey) {
            return
        }

        if !isCapturing {
            return
        }

        let timestamp = CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 1000000)
        lastTimestamp = frame.timestamp

        // Initialization.
        if (firstFrame) {
            // Setup assetWriter here because this seems to be the only place where
            // we have certain information about the input video resolution, a required
            // parameter to video output.
            setupAssetWriter(frame.capturedImage, timestamp)
            firstFrameTimestamp = frame.timestamp
            firstFrame = false
        }

        if (UserDefaults.standard.bool(forKey: SettingsKeys.PointcloudEnableKey)) {
            // Append ARKit point cloud to csv.
            if let featurePointsArray = frame.rawFeaturePoints?.points {
                var pstr = NSString(format:"%f,%d,%d",
                                    frame.timestamp,
                                    POINTCLOUD_ID,
                                    self.frameCount)
                for point in featurePointsArray {
                    pstr = NSString(format:"%@,%f,%f,%f",
                                    pstr,
                                    point.x, point.y, point.z)
                }
                pstr = NSString(format:"%@\n", pstr)
                if self.outputStream.write(pstr as String) < 0 {
                    print("Failure writing ARKit point cloud.")
                }
            }
        }

        if (self.videoInput!.isReadyForMoreMediaData) {
            // Append image to the video.
            self.pixelBufferAdaptor?.append(frame.capturedImage, withPresentationTime: timestamp)

            let translation = frame.camera.transform.translation
            let eulerAngles = frame.camera.eulerAngles
            let intrinsics = frame.camera.intrinsics
            let transform = frame.camera.transform

            // Append ARKit data to csv.
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
            if self.outputStream.write(str as String) < 0 {
                print("Failure writing ARKit to output csv.")
                }

            self.frameCount = self.frameCount + 1
        }
        else {
            print("videoInput not ready.")
        }
    }
}

extension CaptureController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (!isCapturing) {
            return
        }
        let offset = Date().timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime

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
            if self.outputStream.write(str as String) < 0 {
                print("Failure writing location to output csv.")
            }
        }
    }
}

extension CaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection:
            AVCaptureConnection) {
        if !isCapturing {
            return
        }
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Initialization.
        if (firstFrame) {
            setupAssetWriter(imageBuffer, timestamp)
            // TODO
            // firstFrameTimestamp = timestamp
            firstFrame = false
        }

        if (self.videoInput!.isReadyForMoreMediaData) {
            // Append image to the video.
            self.pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: timestamp)
        }
        else {
            print("captureOutput(): videoInput not ready.")
        }

        // Camera intrinsic matrix (focal lengths and principal point).
        // <https://stackoverflow.com/a/48159895>
        /*
        var intrinsics = matrix_float3x3()
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) as? Data {
            intrinsics = camData.withUnsafeBytes { $0.pointee }
            // Note that it may be necessary to scale the focal lengths depending on resolution.
        }
        */
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection:
            AVCaptureConnection) {
        print("Dropped frame in captureOutput().")
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

private enum CameraControllerError: Swift.Error {
    case backCameraNotAvailable
    case unsupportedPreset
    case cannotAddOutput
    case noConnection
}

enum CameraMode {
    case AV
    case ARKit
}
