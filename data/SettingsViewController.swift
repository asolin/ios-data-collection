import UIKit

protocol SettingsTableViewDelegate {
    func settingsTableViewCell(cell: SettingsTableViewCell, newSwitchValue: Bool, cellTag : String)
}

private let cameraModeKey = "cameraMode"

class SettingsViewController: UIViewController {
    @IBOutlet weak private var settingsTable: UITableView!
    @IBOutlet weak var cameraModeControl: UISegmentedControl!

    weak var captureControllerDelegate: CaptureControllerDelegate!
    weak var viewControllerDelegate: ViewControllerDelegate!
    var captureSessionQueue: DispatchQueue!

    private var cellList : [SettingsTableViewCell] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Construct the segmented control manually so that we know which
        // button index corresponds to which mode. So that we can't for example
        // accidentally change the order of buttons in the storyboard and
        // break the code.
        cameraModeControl.removeAllSegments()
        for (i, mode) in cameraModeOptions.enumerated() {
            cameraModeControl.insertSegment(withTitle: mode.0, at: i, animated: true)
        }
        // Returns 0 is key not set.
        cameraModeControl.selectedSegmentIndex = UserDefaults.standard.integer(forKey: cameraModeKey)

        settingsTable.dataSource = self
        settingsTable.allowsSelection = false
        settingsTable.bounces = false
        settingsTable.separatorStyle = UITableViewCell.SeparatorStyle.none
    }

    private func isKeyInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    private func setupSettingsSwitch(settingsSwitch: UISwitch, key: String) {
        if isKeyInUserDefaults(key: key) {
            let isEnabled = UserDefaults.standard.bool(forKey: key)
            settingsSwitch.setOn(isEnabled, animated: false)
        }
        else {
            UserDefaults.standard.set(true, forKey: key)
            settingsSwitch.setOn(true, animated: false)
        }

        if key == settingSwitchTitle(.ARKitPointCloud) {
            let cameraMode = getCameraMode()
            settingsSwitch.isEnabled = cameraMode == CameraMode.ARKit
        }
    }

    @IBAction func cameraModeControlValueChanged(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(cameraModeControl.selectedSegmentIndex, forKey: cameraModeKey)

        if captureControllerDelegate!.capturing() {
            print("Attempted to change camera mode while capturing.")
            return
        }

        // Change camera mode on change of the setting (or exit from the settings view) so that the
        // camera preview view updates and that the start capture button won't stall to setup camera.
        let cameraMode = getCameraMode()
        viewControllerDelegate.updateCameraMode(cameraMode)
        for cell in cellList {
            if cell.cellTag == settingSwitchTitle(.ARKitPointCloud) {
                cell.settingsSwitch.isEnabled = cameraMode == CameraMode.ARKit
                break
            }
        }

        captureSessionQueue.async {
            self.captureControllerDelegate.startCamera(cameraMode)
        }
    }
}

extension SettingsViewController: SettingsTableViewDelegate {
    func settingsTableViewCell(cell: SettingsTableViewCell, newSwitchValue: Bool, cellTag: String) {
        UserDefaults.standard.set(newSwitchValue, forKey: cellTag)

        if captureControllerDelegate!.capturing() {
            print("Changing switch while capturing.")
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as! SettingsTableViewCell

        if indexPath.item < settingSwitches.count {
            let setting = settingSwitches[indexPath.item]
            let title = settingSwitchTitle(setting)

            cell.titleLabel.text = title
            cell.cellTag = title
            // cell.descriptionLabel.text = settingSwitchDescriptions[setting]
            cell.delegate = self

            setupSettingsSwitch(settingsSwitch: cell.settingsSwitch, key: title)
        }
        else {
            print("Error: unexpected index path for settings table cell! \(indexPath.item)")
        }

        cellList.append(cell)

        return cell
    }

    private func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cellList = []
        return settingSwitches.count
    }
}

// Ordered list of segmented control options.
private let cameraModeOptions = [
    ("AV Camera", CameraMode.AV),
    ("ARKit", CameraMode.ARKit),
]

func getCameraMode() -> CameraMode {
    return cameraModeOptions[UserDefaults.standard.integer(forKey: cameraModeKey)].1
}
