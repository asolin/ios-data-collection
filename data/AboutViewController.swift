//
//  AboutViewController.swift
//  data
//
//  Created by Adash Ligocki on 21/11/2018.
//  Copyright © 2018 Arno Solin. All rights reserved.
//

import UIKit

private let descriptionText: String = """
    ADVIO Data app is a simple to use recording tool for Camera-IMU mapping. It allows you to quickly record and share all iPhone's sensors that can be used for localization purposes.

    For more details see the GitHub page.
    """

// Sorted alphabetically by last name.
private let authorsText: String = """
    Santiago Cortés *
    Juho Kannala *
    Adam Ligocki **
    Esa Rahtu **
    Pekka Rantalankila *
    Arno Solin *

    *\t-  Aalto University
    **\t-  Tampere University of Technology
    """

class AboutViewController: UIViewController {
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var authorsLabel: UILabel!
    @IBOutlet weak private var githubButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.text = descriptionText
        authorsLabel.text = authorsText
    }

    @IBAction func onButtonPressed(_ sender: UIButton) {
        if sender == githubButton {
            if let link = URL(string: "https://github.com/AaltoVision/ADVIO") {
                UIApplication.shared.open(link)
            }
        }
    }
}
