//
//  SettingsTableViewCell.swift
//  data
//
//  Created by Adash Ligocki on 25/11/2018.
//  Copyright © 2018 Arno Solin. All rights reserved.
//

import UIKit

protocol SettingsTableViewProtocol {
    func settingsTableViewCell(cell: SettingsTableViewCell, newSwitchValue: Bool, cellTag : String)
}

class SettingsTableViewCell: UITableViewCell, SettingsTableViewProtocol {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var settingsSwitch: UISwitch!
    @IBOutlet weak var descriptionLabel: UILabel!

    var cellTag : String = ""
    var delegate : SettingsTableViewProtocol?

    private func setTitle(title: String) {
        titleLabel.text = title
    }

    private func setSettingsSwitch(isOn: Bool){
        settingsSwitch.setOn(isOn, animated: false)
    }

    private func getSettingsSwitch() -> Bool {
        return settingsSwitch.isOn
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }

    @IBAction private func onSwitchValueChanged(_ sender: UISwitch) {
        if delegate != nil {
            delegate!.settingsTableViewCell(cell: self, newSwitchValue: sender.isOn, cellTag: cellTag)
        }
    }

    func settingsTableViewCell(cell: SettingsTableViewCell, newSwitchValue: Bool, cellTag: String) {
    }
}
