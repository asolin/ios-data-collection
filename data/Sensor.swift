import Foundation
import CoreMotion

let TIMESTAMP_ID     = 0
let CAMERA_ID        = 1
let LOCATION_ID      = 2
let ACCELEROMETER_ID = 3
let GYROSCOPE_ID     = 4
let MAGNETOMETER_ID  = 5
let BAROMETER_ID     = 6
let ARKIT_ID         = 7
let POINTCLOUD_ID    = 8

private let ACCELEROMETER_DT = 0.01
private let GYROSCOPE_DT     = 0.01
private let MAGNETOMETER_DT  = 0.01
private let GRAVITY          = -9.81

func runAccDataAcquisition(_ motionManager: CMMotionManager, _ opQueue: OperationQueue, _ outputStream: OutputStream) {
    if motionManager.isAccelerometerAvailable && !motionManager.isAccelerometerActive {
        motionManager.accelerometerUpdateInterval = ACCELEROMETER_DT
        motionManager.startAccelerometerUpdates(to: opQueue, withHandler: {(accelerometerData: CMAccelerometerData!, error: Error!) in
            if (error != nil){
                print("\(String(describing: error))");
            }
            let str = NSString(format:"%f,%d,%f,%f,%f\n",
                               accelerometerData.timestamp,
                               ACCELEROMETER_ID,
                               accelerometerData.acceleration.x * GRAVITY,
                               accelerometerData.acceleration.y * GRAVITY,
                               accelerometerData.acceleration.z * GRAVITY)
            if outputStream.write(str as String) < 0 {
                print("Write accelerometer failure")
            }
        } as CMAccelerometerHandler)
    }
    else {
        print("No accelerometer available.");
    }
}

func runGyroDataAcquisition(_ motionManager: CMMotionManager, _ opQueue: OperationQueue, _ outputStream: OutputStream) {
    if motionManager.isGyroAvailable && !motionManager.isGyroActive {
        motionManager.gyroUpdateInterval = GYROSCOPE_DT
        motionManager.startGyroUpdates(to: opQueue, withHandler: {(gyroData: CMGyroData!, error: Error!) in
            let str = NSString(format:"%f,%d,%f,%f,%f\n",
                               gyroData.timestamp,
                               GYROSCOPE_ID,
                               gyroData.rotationRate.x,
                               gyroData.rotationRate.y,
                               gyroData.rotationRate.z)
            if outputStream.write(str as String) < 0 {
                print("Write gyroscope failure")
            }
        } as CMGyroHandler)
    }
    else {
        print("No gyroscope available.");
    }
}

func runMagnetometerDataAcquisition(_ motionManager: CMMotionManager, _ opQueue: OperationQueue, _ outputStream: OutputStream) {
    if motionManager.isMagnetometerAvailable && !motionManager.isMagnetometerActive {
        motionManager.magnetometerUpdateInterval = MAGNETOMETER_DT
        motionManager.startMagnetometerUpdates(to: opQueue, withHandler: {(magnetometerData: CMMagnetometerData!, error: Error!) in
            if (error != nil){
                print("\(String(describing: error))");
            }
            let str = NSString(format:"%f,%d,%f,%f,%f\n",
                               magnetometerData.timestamp,
                               MAGNETOMETER_ID,
                               magnetometerData.magneticField.x,
                               magnetometerData.magneticField.y,
                               magnetometerData.magneticField.z)
            if outputStream.write(str as String) < 0 {
                print("Write magnetometer failure")
            }
        } as CMMagnetometerHandler)
    }
    else {
        print("No magnetometer available.");
    }
}

func runBarometerDataAcquisition(_ altimeter: CMAltimeter, _ opQueue: OperationQueue, _ outputStream: OutputStream) {
    if CMAltimeter.isRelativeAltitudeAvailable() {
        altimeter.startRelativeAltitudeUpdates(to: opQueue, withHandler: {(altitudeData: CMAltitudeData!, error: Error!) in
            if (error != nil){
                print("\(String(describing: error))");
            }

            let str = NSString(format:"%f,%d,%f,%f,0\n",
                               altitudeData.timestamp,
                               BAROMETER_ID,
                               altitudeData.pressure.doubleValue,
                               altitudeData.relativeAltitude.doubleValue)
            if outputStream.write(str as String) < 0 {
                print("Write barometer failure")
            }
        } as CMAltitudeHandler)
    }
    else {
        print("No barometer available.");
    }
}
