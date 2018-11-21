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
        // Dispose of any resources that can be recreated.
    }
    
    func listFilesFromDocumentsFolder() -> [String]? {
        let fileMngr = FileManager.default;
        
        // Full path to documents directory
        let docs = fileMngr.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        
        // List all contents of directory and return as [String] OR nil if failed
        return try? fileMngr.contentsOfDirectory(atPath:docs)
    }
    
    //MARK: - Tableview Delegate & Datasource
    func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int {
        let list = listFilesFromDocumentsFolder()
        return (list?.count)!
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "myCell")!
        let list = listFilesFromDocumentsFolder()
        cell.textLabel?.text = list?[indexPath.row]
        cell.imageView?.image = UIImage(named: "file")
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
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
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
            
        } else if editingStyle == .insert {
            // Not used, but if you were adding a new row, this is where you would do it.
        }
    }
    
}
