//
//  SettingsViewController.swift
//  data
//
//  Created by Adash Ligocki on 20/11/2018.
//  Copyright © 2018 Arno Solin. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITableViewDataSource, SettingsTableViewProtocol {
    @IBOutlet weak var settingsTable: UITableView!

    var cellList : [SettingsTableViewCell] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        settingsTable.dataSource = self
        settingsTable.separatorStyle = UITableViewCell.SeparatorStyle.none
    }

    func isKeyInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    func setupSwitchWithUserDefaultsValue(button: UISwitch, key: String) {
        if isKeyInUserDefaults(key: key) {
            let isEnabled = UserDefaults.standard.bool(forKey: key)
            button.setOn(isEnabled, animated: false)
        }
        else {
            UserDefaults.standard.set(true, forKey: key)
            button.setOn(true, animated: false)
        }
    }

    // MARK: - Table view data source

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

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cellList = []
        return SettingsKeys.keys.count
    }

    func settingsTableViewCell(cell: SettingsTableViewCell, newSwitchValue: Bool, cellTag: String) {
        UserDefaults.standard.set(newSwitchValue, forKey: cellTag)

        if (cellTag == SettingsKeys.PointcloudEnableKey && newSwitchValue == true) {

            UserDefaults.standard.set(true, forKey: SettingsKeys.VideoARKitEnableKey)
            for cell in cellList {
                if (cell.cellTag == SettingsKeys.VideoARKitEnableKey){
                    cell.settingsSwitch.setOn(true, animated: true)
                }
            }
        }

        if (cellTag == SettingsKeys.VideoARKitEnableKey && newSwitchValue == false) {

            UserDefaults.standard.set(false, forKey: SettingsKeys.PointcloudEnableKey)
            for cell in cellList {
                if (cell.cellTag == SettingsKeys.PointcloudEnableKey){
                    cell.settingsSwitch.setOn(false, animated: true)
                }
            }
        }
    }
}
