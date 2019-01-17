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
            (t, 4, x, y, z) [rad/s]
            file: .csv
            """,
        SettingsKeys.AccEnableKey: """
            (t, 3, x, y, z) [m/s^2]
            file: .csv
            """,
        SettingsKeys.MagnetEnableKey: """
            (t, 5, x, y, z)
            file: .csv
            """,
        SettingsKeys.BarometerEnableKey: """
            (t, 6, pressure, rel. alt.) [kPa, m]
            file: .csv
            """,
        SettingsKeys.LocationEnableKey: """
            (t, 2, lat, lon, prec., alt, prec., speed)
            file: .csv
            """,
        SettingsKeys.PointcloudEnableKey: """
            (t, frame num, (x, y, z,)+)
            file: -pcl.csv, only in ARKit mode
            """,
    ]
}
