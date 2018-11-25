//
//  AboutViewController.swift
//  data
//
//  Created by Adash Ligocki on 21/11/2018.
//  Copyright © 2018 Arno Solin. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var authorsLabel: UILabel!
    
    static let descriptionText : String = "A B C"
    static let authorsText : String = "A\nB\nC"
    
    override func viewDidLoad() {

        super.viewDidLoad()

        descriptionLabel.text = AboutViewController.descriptionText
        
        authorsLabel.text = AboutViewController.authorsText
    }
    
}
