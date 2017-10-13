# VIO Data Collection App for iOS (Swift)

This app is for collecting time-synched visual and indertial (IMU) data on Apple iOS devices (iPhones/iPads). The purpose is to dump raw sensor data in a format compatible for reconstructing online behaviour of the APIs in offline tests.

## Supported sensors:

All data observations are stored in a CSV file with the format `timestamp, type, val0, val1, ...` and the video frames in an accompanying MOV file. The `timestamp` is the one directly reported by the delegate methods in the APIs (no post-processing done). The `type` fields are according to the following:

### 0 - Initial timestamp
The first stored data item is the start time of the data collection session in both the senosor time and unix time. The timestamp of this event is received from the system uptime and `val0` corresponds to the current unix time.

### 1 - Camera frames
Data collected through AVFoundation. The actual frame timestamps are reported together with the frame number (`val0`) in the CSV. Current camera defaults are set as follows:
* Resolution: 640x480 (portrait)
* Color
* Focus locked to 1.0 (~infinity)
* ISO value locked to: 400
* Shutter speed locked to: 1/100

The video frames are appended to an H.264 encoded video file (through CoreMedia) in the order they arrive. The frame timestamps are in theory also stored in the video, but we recommend extracting the frames from the video and use the frame timestamps stored in the CSV.

### 2 - Platform location
Data collected through CoreLocation. The update rate depends on the device and its capabilities. Locations are requested with the desired accuracy of `kCLLocationAccuracyBest`. The timestamps are converted to follow the same clock as the other sensors (time interval since device boot). The stored values are
* coordinate.latitude
* coordinate.longitude
* horizontalAccuracy
* altitude
* verticalAccuracy
* speed

### 3 - Accelerometer
Data collected through CoreMotion/CMMotionManager. Acquired at 100 Hz, which is the maximum rate. CoreMotion reports the accelerations in "g"s (at standstill you expect to have 1 g in the vertical direction), and in order to have backward compatibility with our older data sets, we have chosen to scale the values by `-9.81` (the minus sign is to conform to Google Android).

### 4 - Gyroscope 
Data collected through CoreMotion/CMMotionManager. Acquired at 100 Hz, which is the maximum rate. Note that the readings are in the Apple device coordinate frame (not altered in any way here).

### 5 - Magnetometer
Data collected through CoreMotion/CMMotionManager). Acquired at 100 Hz, which is the maximum rate. Values are the three-axis magnetometer readings in uT. All values are uncalibrated.

### 6 - Barometric altimeter
Data collected through CoreMotion/CMAltimeter. Acquired at an uneven sampling rate (~1 Hz). Samples are stored as they arrive from the delegare callback. The actual barometric pressure is in `val0` and the inferred relative altutude (calculated by Apple magic) is stored in `val1`.

### 7 - ARKit output
In case of also storing the visual-inertial odometry result calculated by Apple ARKit, the control of the device camera is lost. Instead we can store the camera frames returned by ARKit (no control of setting the resolution, nor locking focus, shutter speed, white balance, etc.). ARKit seems to give video output with the following sepcification (at least on iPhone 6S):
* Resolution: 1280x720 (portrait)
* Color
* Refresh rate: 60 Hz

The stored values at each ARKit frame are
* frame number
* translation (~position)
* euler angles (~orientation)
* instrinsic parameters (camera calibration: focal lengths and prinicipal point)  
