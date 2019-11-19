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
    func getCaptureStartTimestamp() -> Optional<TimeInterval>
    func setARSession(_ arSession: ARSession)
    func startCamera(_ cameraMode: CameraMode)
    func startCapture()
    func stopCapture()
}

class CaptureController: NSObject {
    // Other sensors.
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var locationManager = CLLocationManager()

    private var captureSessionQueue: DispatchQueue!
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

    // Files.
    private var baseFilename: String = ""
    private var sensorURL: URL!
    private var pointCloudURL: URL!
    private var sensorOutputStream: OutputStream!
    private var pointCloudOutputStream: OutputStream!

    private var isCapturing : Bool = false
    private var captureStartTimestamp: Optional<TimeInterval> = Optional.none
    private var frameCount = 0
    private var firstFrame: Bool = true

    private var arConfiguration: ARWorldTrackingConfiguration!

    func start(_ captureSessionQueue: DispatchQueue) {
        self.captureSessionQueue = captureSessionQueue
        opQueue = OperationQueue()
        opQueue.underlyingQueue = captureSessionQueue

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        arConfiguration = ARWorldTrackingConfiguration()

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
            // TODO This works, but is probably a poor default because it makes the recording sharpness so much
            //      worse. The settings tab should have a switch for this if locking focus is a desired feature.
            // if camera.isLockingFocusWithCustomLensPositionSupported {
            //     camera.setFocusModeLocked(lensPosition: 1.0, completionHandler: nil)
            // }

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
        let videoURL = dataPath(baseFilename, Storage.temporary, "mov")
        do {
            assetWriter = try AVAssetWriter(outputURL: videoURL, fileType: AVFileType.mov)
        } catch {
            print("Failed to initialize AVAssetWriter")
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
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourceBufferAttributes)

        assetWriter!.add(videoInput!)
        assetWriter!.startWriting()

        assetWriter!.startSession(atSourceTime: timestamp)
    }

    private func runLocation() {
        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.Location)) {
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

    func getCaptureStartTimestamp() -> Optional<TimeInterval> {
        return captureStartTimestamp
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
            arSession.run(arConfiguration)
        }
    }

    func startCapture() {
        Clock.sync()

        if #available(iOS 11.3, *) {
            arConfiguration.isAutoFocusEnabled = UserDefaults.standard.bool(forKey: settingSwitchTitle(.ARKitAutoFocus))
        }

        // Filename from date.
        let date = Date()
        let formatter = DateFormatter()
        // The filename will be unique if two recordings cannot start on the same second.
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        // formatter.timeZone = TimeZone(secondsFromGMT: 0)
        baseFilename = "data-" + formatter.string(from: date)

        // Open text output files.
        sensorURL = dataPath(baseFilename, Storage.temporary, "csv")
        sensorOutputStream = OutputStream(url: sensorURL, append: false)
        sensorOutputStream!.open()
        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.ARKitPointCloud)) {
            pointCloudURL = dataPath(baseFilename + "-pcl", Storage.temporary, "csv")
            pointCloudOutputStream = OutputStream(url: pointCloudURL, append: false)
            pointCloudOutputStream!.open()
        }

        // Store start time.
        let str = NSString(format:"%f,%d,%f,%f\n",
            ProcessInfo.processInfo.systemUptime,
            TIMESTAMP_ID,
            Date().timeIntervalSince1970,
            Clock.now?.timeIntervalSince1970 ?? 0)
        if sensorOutputStream.write(str as String) < 0 {
            print("Failure writing timestamp to output csv.")
        }
        captureStartTimestamp = Optional.some(ProcessInfo.processInfo.systemUptime)

        // Setup data acquisition.
        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.Accelerometer)) {
            runAccDataAcquisition(motionManager, opQueue, sensorOutputStream)
        }
        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.Gyroscope)) {
            runGyroDataAcquisition(motionManager, opQueue, sensorOutputStream)
        }
        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.Magnetometer)) {
            runMagnetometerDataAcquisition(motionManager, opQueue, sensorOutputStream)
        }
        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.Barometer)) {
            runBarometerDataAcquisition(altimeter, opQueue, sensorOutputStream)
        }
        runLocation()

        // Setup AV camera or ARKit for capturing.
        switch cameraMode! {
        case .AV:
            break
        case .ARKit:
            arSession.pause()
            arSession.run(arConfiguration, options: [.resetTracking, .removeExistingAnchors])
        }
        frameCount = 0;
        firstFrame = true

        isCapturing = true
        print("Recording started!")
    }

    func stopCapture() {
        isCapturing = false
        captureStartTimestamp = Optional.none

        // Stop video capture.
        if self.assetWriter?.status != AVAssetWriter.Status.writing {
            print("Expected assetWriter to be writing.")
            return
        }
        self.assetWriter?.finishWriting(completionHandler: {
            // Move video file after assetWriter is finished.
            moveDataFileToDocuments(self.assetWriter!.outputURL)
        })

        // Stop other sensor capture.
        if (motionManager.isAccelerometerActive) {motionManager.stopAccelerometerUpdates(); }
        if (motionManager.isGyroActive) { motionManager.stopGyroUpdates(); }
        if (motionManager.isMagnetometerActive) { motionManager.stopMagnetometerUpdates(); }
        altimeter.stopRelativeAltitudeUpdates();
        locationManager.stopUpdatingLocation()

        // Handle data files.
        sensorOutputStream.close()
        moveDataFileToDocuments(sensorURL)
        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.ARKitPointCloud)) {
            pointCloudOutputStream.close()
            moveDataFileToDocuments(pointCloudURL)
        }

        print("Recording stopped.")
    }
}

extension CaptureController: ARSessionDelegate {
    @available(iOS 11.0, *)
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if !isCapturing {
            return
        }

        let timestamp = CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 1000000)

        // Initialization.
        if (firstFrame) {
            // Setup assetWriter here because this seems to be the only place where
            // we have certain information about the input video resolution, a required
            // parameter to video output.
            setupAssetWriter(frame.capturedImage, timestamp)
            firstFrame = false
        }

        if UserDefaults.standard.bool(forKey: settingSwitchTitle(.ARKitPointCloud)) {
            // Append ARKit point cloud to csv.
            var ok = true;
            if let rawFeaturePoints = frame.rawFeaturePoints {
                if pointCloudOutputStream.write(String(format: "%f,%d", frame.timestamp, self.frameCount)) < 0 { ok = false }
                for (i, point) in rawFeaturePoints.points.enumerated() {
                    let id = rawFeaturePoints.identifiers[i]
                    if pointCloudOutputStream.write(String(format: ",%d,%f,%f,%f", id, point.x, point.y, point.z)) < 0 { ok = false }
                }
                if pointCloudOutputStream.write("\n") < 0 { ok = false }
            }
            if !ok {
                print("Failure writing ARKit point cloud.")
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
            if sensorOutputStream.write(str as String) < 0 {
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
            if sensorOutputStream.write(str as String) < 0 {
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
        var intrinsics = matrix_float3x3()
        if #available(iOS 11.0, *) {
            if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data {
                intrinsics = camData.withUnsafeBytes { $0.pointee }
            }
        }
        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let px = intrinsics.columns.2.x
        let py = intrinsics.columns.2.y

        // Append frame data to csv.
        let str = NSString(format: "%f,%d,%d,%f,%f,%f,%f\n",
            CMTimeGetSeconds(timestamp),
            CAMERA_ID,
            self.frameCount,
            fx, fy, px, py
            )
        if sensorOutputStream.write(str as String) < 0 {
            print("Failure writing camera frame to output csv.")
        }

        self.frameCount = self.frameCount + 1
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

// The temporary paths might change between calls so store the results that need to be reused.
func dataPath(_ base: String, _ storage: Storage, _ ext: String) -> URL {
    let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var path: String
    switch storage {
    case .temporary:
        path = NSTemporaryDirectory()
    case .documents:
        path = documentsPath.absoluteString
    }
    return NSURL(fileURLWithPath: path).appendingPathComponent(base)!.appendingPathExtension(ext)
}

func moveDataFileToDocuments(_ source: URL) {
    let component = source.lastPathComponent
    let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let destination = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent(component)!
    do {
        try FileManager.default.moveItem(at: source, to: destination)
    }
    catch let error as NSError {
        print("Error occurred while moving data file:\n\(error)")
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

enum Storage {
    case temporary
    case documents
}
