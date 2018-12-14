//
//  ResolutionTableViewCell.swift
//  data
//
//  Created by Adash Ligocki on 04/12/2018.
//  Copyright © 2018 Arno Solin. All rights reserved.
//

import UIKit

class ResolutionTableViewCell: UITableViewCell, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var resolutionPicker: UIPickerView!
    
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        resolutionPicker.delegate = self
        resolutionPicker.dataSource = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
        let selectedResolution = UserDefaults.standard.integer(forKey: SettingsResolutions.userDefaultResolutionKey)
        
        resolutionPicker.selectRow(selectedResolution, inComponent: 0, animated: false)
    }
    
    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return SettingsResolutions.resolutionsStrings.count
    }
    
    // The data to return fopr the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return SettingsResolutions.resolutionsStrings[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        print(SettingsResolutions.resolutionsStrings[row])
        UserDefaults.standard.set(row, forKey: SettingsResolutions.userDefaultResolutionKey)
    }

    
    @objc(pickerView:viewForRow:forComponent:reusingView:) func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,forComponent component: Int, reusing view: UIView?) -> UIView {
        
        var pickerLabel = view as? UILabel;
        if (pickerLabel == nil)
        {
            pickerLabel = UILabel()
            pickerLabel?.font = UIFont(name: "Helvetica", size: 17)
            pickerLabel?.textAlignment = NSTextAlignment.center
        }
        
        pickerLabel?.text = SettingsResolutions.resolutionsStrings[row]
        
        return pickerLabel!;
    }
    
}
