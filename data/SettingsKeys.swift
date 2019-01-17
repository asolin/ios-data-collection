import Foundation

class SettingsKeys {
    static let PointcloudEnableKey = "pointcloudEnableKey"
    static let GyroEnableKey = "gyroEnableKey"
    static let AccEnableKey = "accEnableKey"
    static let MagnetEnableKey = "magnetEnableKey"
    static let BarometerEnableKey = "baroEnableKey"
    static let LocationEnableKey = "locationEnableKey"

    static let keys: [String] = [PointcloudEnableKey, LocationEnableKey, AccEnableKey, GyroEnableKey, MagnetEnableKey, BarometerEnableKey]
}

class SettingsCellTitles {
    static let titles : [String : String] = [
        SettingsKeys.GyroEnableKey : "Gyroscope",
        SettingsKeys.AccEnableKey : "Accelerometer",
        SettingsKeys.MagnetEnableKey : "Magnetometer",
        SettingsKeys.BarometerEnableKey : "Barometer",
        SettingsKeys.LocationEnableKey : "Location",
        SettingsKeys.PointcloudEnableKey : "ARKit point cloud"
    ]
}

class SettingsDescriptions {
    static let descriptions : [String : String] = [
        SettingsKeys.GyroEnableKey : "Data from iphone's gyroscope (x,y,z) [rad/s]\nID: 4, file: .csv",
        SettingsKeys.AccEnableKey : "Data from iphone's accelerometer (x,y,z) [m/s^2]\nID:3: file: .csv",
        SettingsKeys.MagnetEnableKey : "Data from iphone's magnetometer (x,y,z)\nID:5: file: .csv",
        SettingsKeys.BarometerEnableKey : "Barometer's data (pressure, rel. alt.) [kPa, m]\nID:6 file: .csv",
        SettingsKeys.LocationEnableKey : "GPS location (lat, lon, prec., alt, prec., speed)\nID:2 file: .csv",
        SettingsKeys.PointcloudEnableKey : "ARKit's pointcloud log, ARKit must be activated\nID: 8, file: .pcl"
    ]
}
