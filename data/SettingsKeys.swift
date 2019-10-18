import Foundation

// On-off options that correspond to a switch on the UI and a value in UserDefaults.
enum SettingSwitch {
    case ARKitPointCloud
    case ARKitDebug
    case ARKitAutoFocus
    case Location
    case Accelerometer
    case Gyroscope
    case Magnetometer
    case Barometer
}

// Order of switches shown in the Settings tab.
let settingSwitches: [SettingSwitch] = [
    SettingSwitch.ARKitPointCloud,
    SettingSwitch.ARKitDebug,
    SettingSwitch.ARKitAutoFocus,
    SettingSwitch.Location,
    SettingSwitch.Accelerometer,
    SettingSwitch.Gyroscope,
    SettingSwitch.Magnetometer,
    SettingSwitch.Barometer,
]

// Titles shown in the UI and also keys for UserDefault values.
func settingSwitchTitle(_ s: SettingSwitch) -> String {
    switch s {
        case .ARKitPointCloud: return "ARKit point cloud"
        case .ARKitDebug: return "ARKit debug visualizations"
        case .ARKitAutoFocus: return "ARKit auto focus"
        case .Location: return "GPS Location"
        case .Accelerometer: return "Accelerometer"
        case .Gyroscope: return "Gyroscope"
        case .Magnetometer: return "Magnetometer"
        case .Barometer: return "Barometer"
    }
}

// Probably the user will prefer to get this information from project README or manual.
/*
let settingSwitchDescriptions: [SettingSwitch: String] = [
    SettingSwitch.Gyroscope: """
        (t, 4, x, y, z) [rad/s]
        file: .csv
        """,
    SettingSwitch.Accelerometer: """
        (t, 3, x, y, z) [m/s^2]
        file: .csv
        """,
    SettingSwitch.Magnetometer: """
        (t, 5, x, y, z)
        file: .csv
        """,
    SettingSwitch.Barometer: """
        (t, 6, pressure, rel. alt.) [kPa, m]
        file: .csv
        """,
    SettingSwitch.Location: """
        (t, 2, lat, lon, prec., alt, prec., speed)
        file: .csv
        """,
    SettingSwitch.ARKitPointCloud: """
        (t, frame num, (id, x, y, z,)+)
        file: -pcl.csv, only in ARKit mode
        """, ]
*/
