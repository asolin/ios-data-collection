import UIKit

protocol SettingsTableViewDelegate {
    func settingsTableViewCell(cell: SettingsTableViewCell, newSwitchValue: Bool, cellTag : String)
}

class SettingsViewController: UIViewController {
    @IBOutlet weak private var settingsTable: UITableView!
    @IBOutlet weak var cameraModeControl: UISegmentedControl!

    weak var captureControllerDelegate: CaptureControllerDelegate!
    private var cellList : [SettingsTableViewCell] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        settingsTable.dataSource = self
        settingsTable.separatorStyle = UITableViewCell.SeparatorStyle.none
    }

    private func isKeyInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    private func setupSwitchWithUserDefaultsValue(button: UISwitch, key: String) {
        if isKeyInUserDefaults(key: key) {
            let isEnabled = UserDefaults.standard.bool(forKey: key)
            button.setOn(isEnabled, animated: false)
        }
        else {
            UserDefaults.standard.set(true, forKey: key)
            button.setOn(true, animated: false)
        }
    }

    @IBAction func cameraModeControlValueChanged(_ sender: UISegmentedControl) {
        // Change camera mode on change of the setting (or exit from the settings view) so that the
        // camera preview view updates and that the start capture button won't stall to setup camera.
        // TODO
        // captureControllerDelegate.startCamera()
    }
}

extension SettingsViewController: SettingsTableViewDelegate {
    func settingsTableViewCell(cell: SettingsTableViewCell, newSwitchValue: Bool, cellTag: String) {
        UserDefaults.standard.set(newSwitchValue, forKey: cellTag)

        // Coordinate switch changes.
        if cellTag == SettingsKeys.PointcloudEnableKey && newSwitchValue {
            UserDefaults.standard.set(true, forKey: SettingsKeys.VideoARKitEnableKey)
            for cell in cellList {
                if cell.cellTag == SettingsKeys.VideoARKitEnableKey {
                    cell.settingsSwitch.setOn(true, animated: true)
                }
            }
        }
        else if cellTag == SettingsKeys.VideoARKitEnableKey && !newSwitchValue {
            UserDefaults.standard.set(false, forKey: SettingsKeys.PointcloudEnableKey)
            for cell in cellList {
                if cell.cellTag == SettingsKeys.PointcloudEnableKey {
                    cell.settingsSwitch.setOn(false, animated: true)
                }
            }
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as! SettingsTableViewCell

        if indexPath.item < SettingsKeys.keys.count {
            let key = SettingsKeys.keys[indexPath.item]
            let title = SettingsCellTitles.titles[key]

            cell.titleLabel.text = "\(title!):"
            cell.cellTag = key
            cell.descriptionLabel.text = SettingsDescriptions.descriptions[key]
            cell.delegate = self

            setupSwitchWithUserDefaultsValue(button: cell.settingsSwitch, key: key)
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
        return SettingsKeys.keys.count
    }
}
