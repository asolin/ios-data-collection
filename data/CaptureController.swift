import Foundation
import CoreMotion
import CoreMedia
import CoreImage
import AVFoundation
import CoreLocation
import ARKit
import Kronos
import UIKit
import Accelerate

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
    private let preset = AVCaptureSession.Preset.hd1920x1080
    private let stillImageOutput = AVCapturePhotoOutput()

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
    
    var cgImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)
    
    private var converter: vImageConverter?
    private var sourceBuffers = [vImage_Buffer]()
    private var destinationBuffer = vImage_Buffer()

    private var arConfiguration: ARWorldTrackingConfiguration!

    func start(_ captureSessionQueue: DispatchQueue) {
        self.captureSessionQueue = captureSessionQueue
        opQueue = OperationQueue()
        opQueue.underlyingQueue = captureSessionQueue

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        arConfiguration = ARWorldTrackingConfiguration()
        // arConfiguration.planeDetection = .horizontal
        // Resolution and autofocus can be set starting from iOS 11.3.
        // The default is best resolution and auto focus enabled.
        if #available(iOS 11.3, *) {
            arConfiguration.isAutoFocusEnabled = false
            // for f in ARWorldTrackingConfiguration.supportedVideoFormats {
            //     if f.imageResolution.height == 1080 {
            //         // With default resolution 1920x1440, the 1920x1080 resulting video with this setting seems to be stretched.
            //         arConfiguration.videoFormat = f
            //         print("set video format")
            //     }
            //     print(f)
            // }
            // print(arConfiguration.videoFormat)
        }

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

            //let cameras = session.devices.compactMap { $0 }
            //guard let camera = cameras.first else { throw CameraControllerError.backCameraNotAvailable }
            
            // Override the choosing of the camera
            guard let camera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) else { throw CameraControllerError.backCameraNotAvailable }
            
            //let captureSession = AVCaptureSession()
            
            captureSession.beginConfiguration()
            captureSession.sessionPreset = AVCaptureSession.Preset.photo
            
            let captureDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            } else {
                print("Failed to add cameraInput")
            }
            if captureSession.canAddOutput(stillImageOutput) {
                captureSession.addOutput(stillImageOutput)
            } else {
                print("Failed to add stillImageOutput")
            }
            stillImageOutput.isHighResolutionCaptureEnabled = true
            stillImageOutput.isDualCameraDualPhotoDeliveryEnabled = true
            stillImageOutput.isDepthDataDeliveryEnabled = true
            
            captureSession.commitConfiguration()
            
            /*
            
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
 
            */

            // Note that it may take some time for the sensors to physically adjust,
            // so querying some of the values here might not give expected results
            // (that's what the `completionHandler` callbacks are for).
        }
        /*
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
        */
        do {
            try configureCaptureDevice()
            //try configureVideoOutput()
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
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB) as AnyObject,
            ]
        
        // Check if the settings are ok on this device!
        guard (assetWriter!.canApply(outputSettings: videoOutputSettings, forMediaType: AVMediaType.video)) else {
            fatalError("Negative : Can't apply the Output settings...")
        }
        
        videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
        videoInput?.expectsMediaDataInRealTime = true
        // Rotate by 90 degrees to get portrait orientation. Do not use initializer parameter `rotationAngle: CGFloat(Double.pi/2))`
        // because it gives inexact values for the transform matrix entries.
        videoInput?.transform = CGAffineTransform.init(a: 0.0, b: 1.0, c: -1.0, d: 0.0, tx: 0.0, ty: 0.0);
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourceBufferAttributes)

        if assetWriter!.canAdd(videoInput!) {
            assetWriter!.add(videoInput!)
        } else {
            print("Failed to add video writing input!")
        }
        if assetWriter!.startWriting() {
            print("Started writing!")
        } else {
            print("Cannot start writing!")
        }

        assetWriter!.startSession(atSourceTime: timestamp)
        
        //guard assetWriter!.status == .writing else { print("Not writing."); return }
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
        if UserDefaults.standard.bool(forKey: SettingsKeys.PointcloudEnableKey) {
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
        if UserDefaults.standard.bool(forKey: SettingsKeys.AccEnableKey) {
            runAccDataAcquisition(motionManager, opQueue, sensorOutputStream)
        }
        if UserDefaults.standard.bool(forKey: SettingsKeys.GyroEnableKey) {
            runGyroDataAcquisition(motionManager, opQueue, sensorOutputStream)
        }
        if UserDefaults.standard.bool(forKey: SettingsKeys.MagnetEnableKey) {
            runMagnetometerDataAcquisition(motionManager, opQueue, sensorOutputStream)
        }
        if UserDefaults.standard.bool(forKey: SettingsKeys.BarometerEnableKey) {
            runBarometerDataAcquisition(altimeter, opQueue, sensorOutputStream)
        }
        runLocation()

        // Setup AV camera or ARKit for capturing.
        switch cameraMode! {
        case .AV:
            break
        case .ARKit:
            //if !UserDefaults.standard.bool(forKey: SettingsKeys.VideoARKitEnableKey) { }
            arSession.pause()
            arSession.run(arConfiguration, options: [.resetTracking, .removeExistingAnchors])
        }
        frameCount = 0;
        firstFrame = true
        
        isCapturing = true
        print("Recording started!")
        
        //let photoSettings = AVCapturePhotoSettings()
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoSettings.isAutoStillImageStabilizationEnabled = false
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.isAutoDualCameraFusionEnabled = false
        photoSettings.isDualCameraDualPhotoDeliveryEnabled = true
        photoSettings.isCameraCalibrationDataDeliveryEnabled = true
        photoSettings.embedsDepthDataInPhoto = false
        photoSettings.isDepthDataDeliveryEnabled = true
        stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
        
    }

    func stopCapture() {
        isCapturing = false
        captureStartTimestamp = Optional.none

        // Stop video capture.
        if self.assetWriter?.status != AVAssetWriter.Status.writing {
            print("Expected assetWriter to be writing.")
            print(self.assetWriter?.error!)
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
        if UserDefaults.standard.bool(forKey: SettingsKeys.PointcloudEnableKey) {
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

        if UserDefaults.standard.bool(forKey: SettingsKeys.PointcloudEnableKey) {
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




extension CaptureController: AVCapturePhotoCaptureDelegate {
    
    //func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        if !isCapturing {
            return
        }
        
        /* For debugging */
        //print(photo.sourceDeviceType!)
        //print(photo.cameraCalibrationData!)
        //print(photo.cameraCalibrationData!.extrinsicMatrix)
        
        /*
        // Documents the bug in the Apple API -> We must take a detour
        guard let photoPixelBuffer = photo.pixelBuffer else {
           print("Error occurred while capturing photo: Missing pixel buffer (\(String(describing: error)))")
           return
       }
       */
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Convert image data
        let imageData = photo.fileDataRepresentation()
        
        let dataProvider = CGDataProvider(data: imageData! as CFData)
        //let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.absoluteColorimetric)
        let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.absoluteColorimetric)
 
        // Resize
        let size = CGSize(width: 1920.0, height: 1440.0)
        //let size = CGSize(width: 1280.0, height: 720.0)
        var uiImg = UIImage(cgImage: cgImageRef!)
        uiImg = uiImg.resizeImage(targetSize: size)
        let cgImageRefSmall = uiImg.cgImage
        
        // Continue
        var imageBuffer = cgImageRefSmall!.pixelBuffer(width: cgImageRefSmall!.width, height: cgImageRefSmall!.height, orientation: .up)
        //let imageBuffer = cgImageRefSmall!.pixelBuffer(width: cgImageRefSmall!.width, height: cgImageRefSmall!.height, pixelFormatType: kCVPixelFormatType_32ARGB, colorSpace: CGColorSpaceCreateDeviceRGB(), alphaInfo: .noneSkipFirst, orientation: .up)
        
        // This is true
        //print(CVPixelBufferGetPixelFormatType(imageBuffer!)==kCVPixelFormatType_32ARGB)
        //print(CVPixelBufferGetWidth(imageBuffer!))
        //print(cgImageRefSmall!.colorSpace!) // kCGColorSpaceICCBased; kCGColorSpaceModelRGB; sRGB IEC61966-2.1)
        
        
        /* Note: The lengthy code here is for manipulating the image coding from the photo format into a format that is supported by AVAssetWriter on the iPhone X. This is unnecessary on iPhone XS, but required on X. TL;DR: Use Accelerate to manipulate the frame data */ :
        // See https://developer.apple.com/documentation/accelerate/vimage/applying_vimage_operations_to_video_sample_buffers
        
        // Lock
        CVPixelBufferLockBaseAddress(imageBuffer!,
                                     CVPixelBufferLockFlags.readOnly)

        // Format
        let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(imageBuffer!).takeRetainedValue()
        
        var error = kvImageNoError
        
        if converter == nil {
            let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(imageBuffer!).takeRetainedValue()
            
            vImageCVImageFormat_SetColorSpace(cvImageFormat,
                                              CGColorSpaceCreateDeviceRGB())
            
            vImageCVImageFormat_SetChromaSiting(cvImageFormat,
                                                kCVImageBufferChromaLocation_Center)
            
            guard
                let unmanagedConverter = vImageConverter_CreateForCVToCGImageFormat(
                    cvImageFormat,
                    &cgImageFormat,
                    nil,
                    vImage_Flags(kvImagePrintDiagnosticsToConsole),
                    &error),
                error == kvImageNoError else {
                    print("vImageConverter_CreateForCVToCGImageFormat error:", error)
                    return
            }
            
            converter = unmanagedConverter.takeRetainedValue()
        }
        
        // Init source buffers
        if sourceBuffers.isEmpty {
            let numberOfSourceBuffers = Int(vImageConverter_GetNumberOfSourceBuffers(converter!))
            sourceBuffers = [vImage_Buffer](repeating: vImage_Buffer(),
                                            count: numberOfSourceBuffers)
        }
        
        // Set source
        vImageBuffer_InitForCopyFromCVPixelBuffer(
            &sourceBuffers,
            converter!,
            imageBuffer!,
            vImage_Flags(kvImageNoAllocate))
        
        // Allocate destination buffer only once for performance
        if destinationBuffer.data == nil {
            error = vImageBuffer_Init(&destinationBuffer,
                                          UInt(CVPixelBufferGetHeightOfPlane(imageBuffer!, 0)),
                                          UInt(CVPixelBufferGetWidthOfPlane(imageBuffer!, 0)),
                                          cgImageFormat.bitsPerPixel,
                                          vImage_Flags(kvImageNoFlags))
        }
        
        error = vImageConvert_AnyToAny(converter!,
                                       &sourceBuffers,
                                       &destinationBuffer,
                                       nil,
                                       vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            return
        }
        
        vImageBuffer_CopyToCVPixelBuffer(&destinationBuffer,
                                        &cgImageFormat,
                                        imageBuffer!,
                                        nil,
                                        nil,
                                        vImage_Flags(kvImageNoFlags));

        
        // Unlock
        CVPixelBufferUnlockBaseAddress(imageBuffer!,
                                       CVPixelBufferLockFlags.readOnly)

        
        
        //vImageConvert_ARGB8888toRGB888(UnsafeRawPointer(imageBuffer), UnsafeRawPointer(imageBuffer), kvImageNoFlags)
        
        //vImageConvert_AnyToAny(<#T##converter: vImageConverter##vImageConverter#>, <#T##srcs: UnsafePointer<vImage_Buffer>##UnsafePointer<vImage_Buffer>#>, <#T##dests: UnsafePointer<vImage_Buffer>##UnsafePointer<vImage_Buffer>#>, <#T##tempBuffer: UnsafeMutableRawPointer!##UnsafeMutableRawPointer!#>, <#T##flags: vImage_Flags##vImage_Flags#>)
        
        
        //vImageConvert_Planar8toRGB888
        
        // Timestamp
        let timestamp = photo.timestamp
        
        // Initialization.
        if (firstFrame) {
            setupAssetWriter(imageBuffer!, timestamp)
            firstFrame = false
        }
        
        if (self.videoInput!.isReadyForMoreMediaData) {
            // Append image to the video.
            self.pixelBufferAdaptor?.append(imageBuffer!, withPresentationTime: timestamp)
        }
        else {
            print("captureOutput(): videoInput not ready.")
            return
        }
        
        // Depth data
        var depthData = photo.depthData
        
        /*
        
        if (depthData!.depthDataMap != nil) {
        
        if depthData!.depthDataType != kCVPixelFormatType_DisparityFloat32 {
            depthData = depthData!.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        }
        
        if (self.videoInput!.isReadyForMoreMediaData) {
            // Append image to the video.
            self.pixelBufferAdaptor?.append(depthData!.depthDataMap, withPresentationTime: timestamp)
        }
        else {
            print("captureOutput(): videoInput not ready.")
            return
        }
        }
 
        */
        
        // Data to push to csv
        let intrinsics = photo.cameraCalibrationData!.intrinsicMatrix
        let extrinsics = photo.cameraCalibrationData!.extrinsicMatrix
        
        // Append frame data to csv.
        /*
        let str = NSString(format: "%f,%d,%d\n",
                           CMTimeGetSeconds(timestamp),
                           CAMERA_ID,
                           self.frameCount
        )
        */
        // Append frame data to csv.
        let str = NSString(format:"%f,%d,%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%d,%d\n",
                           CMTimeGetSeconds(timestamp),
                           CAMERA_ID,
                           self.frameCount,
                           intrinsics[0][0], intrinsics[1][1], intrinsics[2][0], intrinsics[2][1],
                           extrinsics[0][0],extrinsics[1][0],extrinsics[2][0],extrinsics[3][0],
                           extrinsics[0][1],extrinsics[1][1],extrinsics[2][1],extrinsics[3][1],
                           extrinsics[0][2],extrinsics[1][2],extrinsics[2][2],extrinsics[3][2],
                           cgImageRef!.width,cgImageRef!.height)
        if sensorOutputStream.write(str as String) < 0 {
            print("Failure writing camera frame to output csv.")
        }
        
        self.frameCount = self.frameCount + 1
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed for image storage: \(timeElapsed) s.")
        
        // Capture next (or DeviceType.builtInWideAngleCamera )
        if photo.sourceDeviceType == AVCaptureDevice.DeviceType.builtInTelephotoCamera {
            //let photoSettings = AVCapturePhotoSettings()
            let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            photoSettings.isAutoStillImageStabilizationEnabled = false
            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.isAutoDualCameraFusionEnabled = false
            photoSettings.isDualCameraDualPhotoDeliveryEnabled = true
            photoSettings.isCameraCalibrationDataDeliveryEnabled = true
            photoSettings.embedsDepthDataInPhoto = false
            photoSettings.isDepthDataDeliveryEnabled = true
            stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

/*
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

        // Append frame data to csv.
        let str = NSString(format: "%f,%d,%d\n",
            CMTimeGetSeconds(timestamp),
            CAMERA_ID,
            self.frameCount
            )
        if sensorOutputStream.write(str as String) < 0 {
            print("Failure writing camera frame to output csv.")
        }

        self.frameCount = self.frameCount + 1

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
*/

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

extension UIImage {
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let newSize = widthRatio > heightRatio ?  CGSize(width: size.width * heightRatio, height: size.height * heightRatio) : CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}

