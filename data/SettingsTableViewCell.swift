import UIKit

class SettingsTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var settingsSwitch: UISwitch!
    @IBOutlet weak var descriptionLabel: UILabel!

    var cellTag: String = ""
    var delegate: SettingsTableViewDelegate?

    private func setTitle(title: String) {
        titleLabel.text = title
    }

    private func setSettingsSwitch(isOn: Bool){
        settingsSwitch.setOn(isOn, animated: false)
    }

    private func getSettingsSwitch() -> Bool {
        return settingsSwitch.isOn
    }

    @IBAction private func onSwitchValueChanged(_ sender: UISwitch) {
        if delegate != nil {
            delegate!.settingsTableViewCell(cell: self, newSwitchValue: sender.isOn, cellTag: cellTag)
        }
    }
}
