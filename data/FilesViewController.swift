//
//  FilesViewController.swift
//  data
//
//  Created by Arno Solin on 25.9.2017.
//  Copyright © 2017 Arno Solin. All rights reserved.
//

import UIKit

class FilesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    /* Outlets */
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        // Add table view
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "myCell")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func listFilesFromDocumentsFolder() -> [String]? {
        let fileMngr = FileManager.default;
        let docs = fileMngr.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        let list = try? fileMngr.contentsOfDirectory(atPath:docs)
        if let l = list {
            return l.sorted{ $0 < $1 }
        }
        return list
    }

    // MARK: - Tableview Delegate & Datasource
    func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int {
        let list = listFilesFromDocumentsFolder()
        return (list?.count)!
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "myCell")!
        var list = listFilesFromDocumentsFolder()

        cell.textLabel?.text = list?[indexPath.row]
        if cell.textLabel?.text?.range(of: "mov") != nil {
            cell.imageView?.image = UIImage(named: "movie")
        }
        else if cell.textLabel?.text?.range(of: "csv") != nil {
            cell.imageView?.image = UIImage(named: "four_leaf")
        }
        else if cell.textLabel?.text?.range(of: "pcl") != nil {
            cell.imageView?.image = UIImage(named: "pointcloud")
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // All files
        let list = listFilesFromDocumentsFolder()

        // Path to file
        let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let filePath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent((list?[indexPath.row])!)

        // Present share dialog
        let activityViewController = UIActivityViewController(activityItems: [filePath!], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // All files
            let list = listFilesFromDocumentsFolder()

            // Path to file
            let documentsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let filePath = NSURL(fileURLWithPath: documentsPath.absoluteString).appendingPathComponent((list?[indexPath.row])!)

            // File Manager
            let fileManager = FileManager.default;

            // Delete file
            do {
                try fileManager.removeItem(at: filePath!);
            } catch let error as NSError {
                print("Error removing file:\n \(error)")
            }

            // Delete the table view row
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
        else if editingStyle == .insert {
            // Not used, but if you were adding a new row, this is where you would do it.
        }
    }

    @IBAction func onDelButtonPressed(_ sender: UIButton) {
        let myalert = UIAlertController(title: "Clear all files", message: "Do you realy want to delete all files?", preferredStyle: UIAlertController.Style.alert)

        myalert.addAction(UIAlertAction(title: "Delete", style: .default) { (action:UIAlertAction!) in
            let list = self.listFilesFromDocumentsFolder()
            let fileManager = FileManager.default;
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].path

            if let l = list {
                for item in l {
                    do {
                        try fileManager.removeItem(at: URL.init(fileURLWithPath: "\(docs)/\(item)"))
                    } catch let error as NSError {
                        print("Error removing file:\n \(error)")
                    }
                }
            }
            self.tableView.reloadData()
        })
        myalert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
        })

        self.present(myalert, animated: true)
    }
}
