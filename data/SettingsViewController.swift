//
//  SettingsViewController.swift
//  data
//
//  Created by Adash Ligocki on 20/11/2018.
//  Copyright © 2018 Arno Solin. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITableViewDataSource, SettingsTableViewProtocol {
    
    

    @IBOutlet weak var VideoARKitSwitch: UISwitch!
    @IBOutlet weak var GyroSwitch: UISwitch!
    @IBOutlet weak var AccSwitch: UISwitch!
    @IBOutlet weak var MagnetSwitch: UISwitch!
    @IBOutlet weak var BaroSwitch: UISwitch!
    @IBOutlet weak var LocationSwitch: UISwitch!
    @IBOutlet weak var PointcloudSwitch: UISwitch!
    
    @IBOutlet weak var settingsTable: UITableView!
    
    var cellList : [SettingsTableViewCell] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

//        setupSwitchWithUserDefaultsValue(button: VideoARKitSwitch, key: SettingsKeys.VideoARKitEnableKey)
//        setupSwitchWithUserDefaultsValue(button: GyroSwitch, key: SettingsKeys.GyroEnableKey)
//        setupSwitchWithUserDefaultsValue(button: AccSwitch, key: SettingsKeys.AccEnableKey)
//        setupSwitchWithUserDefaultsValue(button: MagnetSwitch, key: SettingsKeys.MagnetEnableKey)
//        setupSwitchWithUserDefaultsValue(button: BaroSwitch, key: SettingsKeys.BarometerEnableKey)
//        setupSwitchWithUserDefaultsValue(button: LocationSwitch, key: SettingsKeys.LocationEnableKey)
//        setupSwitchWithUserDefaultsValue(button: PointcloudSwitch, key: SettingsKeys.PointcloudEnableKey)
//
        // Do any additional setup after loading the view.
        settingsTable.dataSource = self
        settingsTable.separatorStyle = UITableViewCellSeparatorStyle.none
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
//    @IBAction func onSwitchChanged(_ sender: UISwitch) {
//
//        let isOn = sender.isOn
//
//        if (sender == VideoARKitSwitch) {
//            UserDefaults.standard.set(isOn, forKey: SettingsKeys.VideoARKitEnableKey)
//        }else if (sender == GyroSwitch) {
//            UserDefaults.standard.set(isOn, forKey: SettingsKeys.GyroEnableKey)
//        }else if (sender == AccSwitch) {
//            UserDefaults.standard.set(isOn, forKey: SettingsKeys.AccEnableKey)
//        }else if (sender == MagnetSwitch) {
//            UserDefaults.standard.set(isOn, forKey: SettingsKeys.MagnetEnableKey)
//        }else if (sender == BaroSwitch) {
//            UserDefaults.standard.set(isOn, forKey: SettingsKeys.BarometerEnableKey)
//        }else if (sender == LocationSwitch) {
//            UserDefaults.standard.set(isOn, forKey: SettingsKeys.LocationEnableKey)
//        }else if (sender == PointcloudSwitch) {
//            UserDefaults.standard.set(isOn, forKey: SettingsKeys.PointcloudEnableKey)
//        }else {
//            print("Error: Unexpected switch setting sender!")
//        }
//    }
    
    func isKeyInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    
    
    func setupSwitchWithUserDefaultsValue(button: UISwitch, key: String) {
        
        if (isKeyInUserDefaults(key: key)) {
            let isEnabled = UserDefaults.standard.bool(forKey: key)
            button.setOn(isEnabled, animated: false)
            
        } else {
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
            
        } else {
            
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
    }
    
    
}
