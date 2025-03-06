//
//  ListController.swift
//  OpenInPlace
//
//  This view controller shows how to
//   1) open directories from iCloud Drive and other document providers as security scoped URLs:
//    pickURLs() and the UIDocumentPickerDelegate delegate methods.
//
//   2) drag in-place references to files and directories from other applications as security scoped URLs:
//      UITableViewDropDelegate methods
//
//   3) persist security scoped URLs:
//     saveUrlBookmarks() and restoreUrlBookmarks() converts arrays of security scoped URL objects into
//     arrays of bookmark Data.
//
//   4) list contents of directories accessed through document providers in file coordinated manner:
//    reloadContent() does this but not for the root list.
//
//   5) delete files in other document providers with file coordination:
//    happens in tableView(tableView,editingStyle,forRowAt) but not for the root list where a bookmark
//    is deleted.
//
//   6) how to watch a directory for changes:
//    appMovedToBackground(), appMovedToForeground() and NSFilePresenter delegate methods
//
//   7) use WorkingCopyUrlService file-provider SDK to get app icon and file information for
//    entries inside the Working Copy Location:
//    tableView(_ tableView, cellForRowAt)
//
//  Created by Anders Borum on 21/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import UIKit
import MobileCoreServices

class ListController: UITableViewController, UIDocumentPickerDelegate, NSFilePresenter, UITableViewDropDelegate {
    var detailViewController: EditController? = nil
    
    public var baseURL: URL? = nil
    
    // security scoped URL's are shown when baseURL is nil, otherwise the contents of directory
    var urls = [URL]()
    
    private func reloadContent() {
        guard baseURL != nil else { return }
        
        let coordinator = NSFileCoordinator(filePresenter: self)
        baseURL!.coordinatedList(coordinator, callback: { (newUrls, error) in
            
            DispatchQueue.main.async {
                if(error != nil) {
                    self.showError(error!)
                }
                if(newUrls != nil) {
                    self.urls = newUrls!
                    self.tableView.reloadData()
                }
            }
        })
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let notifications = NotificationCenter.default
        notifications.addObserver(self, selector: #selector(appMovedToBackground),
                                  name: UIApplication.willResignActiveNotification, object: nil)
        notifications.addObserver(self, selector: #selector(appMovedToForeground),
                                  name: UIApplication.didBecomeActiveNotification, object: nil)
        
        restoreUrlBookmarks()
        
        if #available(iOS 11.0, *) {
            // enable items dropped on tableView
            tableView.dropDelegate = self
        }
        
        // we only have edit button for root list, as we want to be able to go back
        let isRoot = baseURL == nil
        if(isRoot) {
            navigationItem.leftBarButtonItem = editButtonItem
            
            let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
            navigationItem.rightBarButtonItems = [addButton]
            
        } else {
            // read contents of directory
            let _ = baseURL!.startAccessingSecurityScopedResource()
            self.navigationItem.title = baseURL?.lastPathComponent
            
            reloadContent()

            NSFileCoordinator.addFilePresenter(self)
            isFilePresenting = true
        }
        
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? EditController
        }
    }
    
    @objc func addTapped(_ sender: UIBarButtonItem) {
        if #available(iOS 13.0, *) {
            // on iOS 13 we cannot ask for both files and directories when showing the document picker
            // and we need to ask the user what they want to pick first
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

            sheet.addAction(UIAlertAction(title: NSLocalizedString("Pick Directory", comment: ""),
                                          style: .default, handler: { _ in
                self.pickURLs(types: [kUTTypeFolder as String], sender)
            }))

            sheet.addAction(UIAlertAction(title: NSLocalizedString("Pick File", comment: ""),
                                          style: .default, handler: { _ in
                self.pickURLs(types: [kUTTypeText as String], sender)
            }))

            sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),
                                          style: .cancel, handler: nil))
            
            sheet.popoverPresentationController?.barButtonItem = sender
            self.present(sheet, animated: true)
            
        } else {

            // we can ask for either files or directories on iOS 12 and before
            pickURLs(types: [kUTTypeText as String, kUTTypeDirectory as String], sender)
        }

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // make sure we only remove file presenter and stop security scope once
        // and only when list is being removed fully from view hierarchy
        if self.isMovingFromParent {
            if(isFilePresenting) {
                NSFileCoordinator.removeFilePresenter(self)
                isFilePresenting = false
            }
            
            if baseURL != nil {
                baseURL!.stopAccessingSecurityScopedResource()
                baseURL = nil
            }
        }
    }
    
    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "subdir" {
            if let indexPath = tableView.indexPathForSelectedRow {
                
                let controller = segue.destination as! ListController
                controller.baseURL = urls[indexPath.row]
            }
        }
        
        if segue.identifier == "edit" {
            if let indexPath = tableView.indexPathForSelectedRow,
               let nav = segue.destination as? UINavigationController,
               let controller = nav.topViewController as? EditController {
                
                controller.url = urls[indexPath.row]
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }
    
    // MARK: - UITableViewDropDelegate
    
    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        let canOpenInPlace = baseURL == nil
        return canOpenInPlace
    }
    
    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        // root list can open in-place and the other lists import copies, but we do not yet support this
        let canOpenInPlace = baseURL == nil
        guard canOpenInPlace else { return }
        
        for dropItem in coordinator.items {
            let itemProvider = dropItem.dragItem.itemProvider
            let uti = itemProvider.registeredTypeIdentifiers.first ?? "public.data"
            itemProvider.loadInPlaceFileRepresentation(forTypeIdentifier: uti,
                                                       completionHandler: {(url, inPlace, error) in
                if error != nil { self.showError(error!) }
                guard inPlace else { return }

                guard let url = url else { return }
                                                        
                // remember this url
                self.urls.append(url)
                self.saveUrlBookmarks()

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            })
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
        
        let url = urls[indexPath.row]
        let _ = url.startAccessingSecurityScopedResource()
        
        let identifier = url.isDirectory ? "dir" : "file"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.textLabel!.text = url.lastPathComponent
        
        if #available(iOS 11.0, *) {
            // Try to get file provider icon from x-document-source-2 or Working Copy service.
            //
            // A real app wouldn't do this every time the cell was loaded, as there is
            // some communication overhead betweenn file-provider and app.
            
            url.fetchDocumentInfo(pixelSize: 120, completionHandler: { (path, appName, appVersion, icon) in
                if path != nil {
                    cell.detailTextLabel?.text = path
                    cell.imageView?.image = icon
                    cell.setNeedsLayout()
                    return
                }
            })
        }
        
        url.stopAccessingSecurityScopedResource()

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            if(baseURL != nil) {
                
                let url = urls[indexPath.row]
                let coordinator = NSFileCoordinator(filePresenter: self)
                
                url.coordinatedDelete(coordinator, callback: { error in
                    if error != nil { self.showError(error!) }
                })
            }
            
            urls.remove(at: indexPath.row)
            saveUrlBookmarks()
            
            tableView.deleteRows(at: [indexPath], with: .fade)
        } 
    }
    
    // MARK: -
    
    private let bookmarksDefaultsKey = "bookmarks"
    
    // to be able to save and restore security scoped URL's these must be stored as bookmarks
    func saveUrlBookmarks() {
        guard baseURL == nil else { return }
        
        var bookmarks = [Data]()
        
        for url in urls {
            let _ = url.startAccessingSecurityScopedResource()
            do {
                let bookmark = try url.bookmarkData(options: [],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
                bookmarks.append(bookmark)
                
            } catch {
                self.showError(error, title: "saveUrlBookmarks")
            }
            url.stopAccessingSecurityScopedResource()
        }
        
        // store in user defaults, since this is just a demo
        UserDefaults.standard.set(bookmarks, forKey: bookmarksDefaultsKey)
    }
    
    func restoreUrlBookmarks() {
        guard baseURL == nil else { return }
        
        var newUrls = [URL]()
        var anyStale = false
        
        let bookmarks = UserDefaults.standard.object(forKey: bookmarksDefaultsKey) as? [Data]
        if(bookmarks != nil) {
            for bookmark in bookmarks! {
                
                do {
                    var stale = false
                    let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
                    
                    anyStale = anyStale || stale
                    newUrls.append(url)
                    
                } catch {
                    print("\(error)")
                }
            }
            
        }
        urls = newUrls
        
        // stale bookmarks need to be recreated and we just recreate all of them where
        // a proper application would want to be smarter about this
        if anyStale { saveUrlBookmarks() }
    }
    
    func pickURLs(types: [String], _ sender: Any) {
        let picker = UIDocumentPickerViewController(documentTypes: types, in: .open)
        if #available(iOS 11.0, *) {
            let _ = picker.view // force loading of view, since allowsMultipleSelection does not stick otherwise
            picker.allowsMultipleSelection = true
        }
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    public func addURL(_ url: URL) {
        urls.append(url)
        saveUrlBookmarks()
        
        tableView.reloadData()
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
    
    //MARK: - NSFilePresenter
    var presentedItemURL: URL? {
        return baseURL
    }
    
    private var presenterQueue : OperationQueue?
    var presentedItemOperationQueue: OperationQueue {
        if(presenterQueue == nil) {
            presenterQueue = OperationQueue()
        }
        return presenterQueue!
    }
    
    func presentedItemDidChange() {
        reloadContent()
    }
    
    func presentedSubitemDidAppear(at url: URL) {
        reloadContent()
    }
    
    private var isFilePresenting = false
    
    @objc func appMovedToBackground() {
        // it can lead to deadlocks to present files in the background and we back off
        if(isFilePresenting) {
            NSFileCoordinator.removeFilePresenter(self)
            isFilePresenting = false
        }
    }
    
    @objc func appMovedToForeground() {
        // we are back after being in the background and listen again and refresh from file
        if(!isFilePresenting && baseURL != nil) {
            NSFileCoordinator.addFilePresenter(self)
            isFilePresenting = true
        }
        
        reloadContent()
    }
    
    //MARK: -
}


