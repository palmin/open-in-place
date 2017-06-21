//
//  MasterViewController.swift
//  OpenInPlace
//
//  Created by Anders Borum on 21/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import UIKit
import MobileCoreServices

class ListController: UITableViewController, UIDocumentPickerDelegate {
    var detailViewController: EditController? = nil
    
    // security scoped URL's are shown when nil, otherwise the contents of directory
    public var baseURL: URL? = nil
    
    var urls = [URL]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        restoreUrlBookmarks()
        
        // we only have edit button for root list, as we want to be able to go back
        let isRoot = baseURL == nil
        if(isRoot) {
            navigationItem.leftBarButtonItem = editButtonItem
        } else {
            // read contents of directory
            baseURL!.startAccessingSecurityScopedResource()
            self.navigationItem.title = baseURL!.lastPathComponent
            
            baseURL!.stopAccessingSecurityScopedResource()
        }
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(pickURLs(_:)))
        navigationItem.rightBarButtonItem = addButton
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? EditController
        }
    }
    
    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let url = urls[indexPath.row]
                
                
                
                //let controller = (segue.destination as! UINavigationController).topViewController as! EditController
                //controller.detailItem = object
                //controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                //controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return urls.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let url = urls[indexPath.row]
        if(url.startAccessingSecurityScopedResource()) {
            cell.textLabel!.text = url.lastPathComponent
            url.stopAccessingSecurityScopedResource()
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            urls.remove(at: indexPath.row)
            saveUrlBookmarks()
            
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let url = urls[indexPath.row]
        if(url.startAccessingSecurityScopedResource()) {
            
            let keys = Set<URLResourceKey>([URLResourceKey.isDirectoryKey])
            let value = try? url.resourceValues(forKeys: keys)
            switch value?.isDirectory {
                
            case .some(true):
                // directories are opened as a list
                let sublist = ListController(style: .plain)
                sublist.baseURL = url
                self.navigationController?.pushViewController(sublist, animated: true)
                
            default:
                // other files are opened with text editor
                let cell = tableView.cellForRow(at: indexPath)
                self.performSegue(withIdentifier: "showDetail", sender: cell)
            }
            
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    // MARK: -
    
    private let bookmarksDefaultsKey = "bookmarks"
    
    // to be able to save and restore security scoped URL's these must be stored as bookmarks
    func saveUrlBookmarks() {
        guard baseURL == nil else {
            return
        }
        
        var bookmarks = [Data]()
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource()
            else { continue }
            
            do {
                let bookmark = try url.bookmarkData(options: [.suitableForBookmarkFile],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
                bookmarks.append(bookmark)
                
            } catch {
                print("\(error)")
            }
            
            url.stopAccessingSecurityScopedResource()
        }
        
        // store in user defaults, since this is just a demo
        UserDefaults.standard.set(bookmarks, forKey: bookmarksDefaultsKey)
    }
    
    func restoreUrlBookmarks() {
        guard baseURL == nil else { return }
        
        var newUrls = [URL]()
        
        let bookmarks = UserDefaults.standard.object(forKey: bookmarksDefaultsKey) as? [Data]
        if(bookmarks != nil) {
            for bookmark in bookmarks! {
                
                do {
                    var stale = false
                    let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
                    if(url != nil) {
                        newUrls.append(url!)
                    }
                    
                } catch {
                    print("\(error)")
                }
                
            }
        }
        urls = newUrls
    }
    
    @objc func pickURLs(_ sender: Any) {
        
        let types = [kUTTypeText as String, kUTTypeDirectory as String]
        let picker = UIDocumentPickerViewController(documentTypes: types, in: .open)
        
        if #available(iOS 11.0, *) {
            picker.allowsMultipleSelection = true
        }
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    //MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt newUrls: [URL]) {
        urls.append(contentsOf: newUrls)
        saveUrlBookmarks()
        
        tableView.reloadData()
    }
    
    // this is called on iOS versions before 11 and we just pass URL along in array
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        documentPicker(controller, didPickDocumentsAt: [url])
    }
    
    //MARK: -
}

