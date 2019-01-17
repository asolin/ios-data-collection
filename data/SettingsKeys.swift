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
        SettingsKeys.LocationEnableKey : "GPS Location",
        SettingsKeys.PointcloudEnableKey : "ARKit point cloud"
    ]
}

class SettingsDescriptions {
    static let descriptions : [String : String] = [
        SettingsKeys.GyroEnableKey: """
            (x, y, z) [rad/s]
            id: 4, file: .csv
            """,
        SettingsKeys.AccEnableKey: """
            (x, y, z) [m/s^2]
            id: 3, file: .csv
            """,
        SettingsKeys.MagnetEnableKey: """
            (x, y, z)
            id: 5, file: .csv
            """,
        SettingsKeys.BarometerEnableKey: """
            (pressure, rel. alt.) [kPa, m]
            id: 6, file: .csv
            """,
        SettingsKeys.LocationEnableKey: """
            (lat, lon, prec., alt, prec., speed)
            id: 2, file: .csv
            """,
        SettingsKeys.PointcloudEnableKey: """
            Only in ARKit mode
            id: 8, file: -pcl.csv
            """,
    ]
}
