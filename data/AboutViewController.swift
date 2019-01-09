//
//  AboutViewController.swift
//  data
//
//  Created by Adash Ligocki on 21/11/2018.
//  Copyright © 2018 Arno Solin. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var authorsLabel: UILabel!
    @IBOutlet weak private var githubButton: UIButton!

    static private let descriptionText : String = "ADVIO Data app works as a simple to use\nrecording tool for Camera-IMU mapping.\nIt allows you to quickly recordand share\nall iPhone's sensorsthat can be used\nfor localization purpose.\n\nFor more details see GitHub page."

    static private let authorsText : String = "Santiago Cortés *\nArno Solin *\nEsa Rahtu **\nJuho Kannala *\nAdam Ligocki **\n\n *\t-  Aalto University\n **\t-  Tampere University of Technology"

    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.text = AboutViewController.descriptionText
        authorsLabel.text = AboutViewController.authorsText
    }

    @IBAction func onButtonPressed(_ sender: UIButton) {
        if sender == githubButton {
            if let link = URL(string: "https://github.com/AaltoVision/ADVIO") {
                UIApplication.shared.open(link)
            }
        }
    }
}
