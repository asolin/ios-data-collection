# iOS Data Collection App

A simple and lightweight iOS app for collecting/dumping sensor data from the device in a time-synched manner on Apple iOS devices (iPhones/iPads). Supported sensors include the IMU (accelerometer, gyroscope, magnetometer), the RGB camera(s), etc. The app itself does minimal processing of the data. This app is simply to get your hands dirty with the real data from a device that can be used for research and tinkering.

## Xcode setup

* Install cocoapods, eg `brew install cocoapods`.
* In the root folder run `pod install`.
* Open the project in Xcode by selecting the generated `.xcworkspace` file, *not* `.xcodeproj`.
* In Xcode, setup developer profile, bundle id, etc. (preferably do not commit changes to git.)
* Connect device and hit the run button.

## Using the app

* Press "Settings" to choose what camera mode (ARKit, AVCamera) to use and what sensors to record.
* Press "Start" and record your data. End the session by pressing "Stop".
* Press "Files" to see all the data recorded. Click individual files to open file transfer menu. AirDrop may be convenient for a few files. To setup it on Mac, in Finder "Choose Go > AirDrop from the menu bar in the Finder", and choose "Allow me to be discovered by Everyone". To move larger quantities of files more easily, use iTunes: Connect the device with a cable and in the iTunes program click the tiny button near top left to show data about the device. Choose File Sharing, then in the Apps list choose the data collection app. It may be necessary to enable some kind of developer options or trusted connection setting for the "File Sharing" to appear. On the iOS app you can delete all the files by pressing the trashcan icon.

## Format of data

For now, see the descriptions on the "Settings" tab or read the source code.

## License

This software is provided under the [MIT License](LICENSE).
