//
//  EditController.swift
//  OpenInPlace
//
//  This view controller shows how to
//   1) read contents in coordinated manner from a remote file from iCloud Drive
//      or another document providers:
//    loadContent()
//
//   2) write back content in coordinated manner:
//     writeContentIfNeeded() and writeContentUpdatingUI()
//
//   3) observe changes and coordinate with other processes accessing file:
//    appMovedToBackground(), appMovedToForeground() and NSFilePresenter delegate methods
//
//   4) auto-save changes:
//    textViewDidChange() and appMovedToBackground()
//
//   5) use WorkingCopyUrlService file-provider SDK to get file status and compose
//      x-callback-url for initiating commit:
//    loadStatusWithService() and statusTapped()
//
//  If you are using UIDocument you mostly get all this for free.
//
//
//  Created by Anders Borum on 21/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import UIKit

class EditController: UIViewController, UITextViewDelegate, NSFilePresenter {
    
    @IBOutlet var textView: UITextView!
    @IBOutlet var statusButton: UIBarButtonItem!
    @IBOutlet var detailsItem: UIBarButtonItem!
    
    private func configureDetailMenu() {
        let notify = UIAction(title: NSLocalizedString("Send didAccess notification", comment: "")) { _ in
            self.url?.xDocumentNotifyDidAccess { error in
                if let error = error {
                    self.showError(error)
                }
            }
        }
        if #available(iOS 15.0, *) {
            notify.subtitle = "dk.andersborum.document-notify"
        }
        
        detailsItem.menu = UIMenu(children: [notify])
    }
    
    private func loadContent() {
        // do not load unless we have both url and view loaded
        guard isViewLoaded else { return }
        guard url != nil else {
            self.navigationItem.title = "<DELETED>"
            self.textView.text = ""
            return
        }
        
        navigationItem.title = _url?.lastPathComponent
        
        let coordinator = NSFileCoordinator(filePresenter: self)
        url!.coordinatedRead(coordinator, callback: { (text, error) in
            
            DispatchQueue.main.async {
                if(error != nil) {
                    self.showError(error!)
                } else {
                    self.textView.text = text
                }
            }
        })
    }
    
    private var urlService: WorkingCopyUrlService?
    
    private func loadStatusWithService(_ service: WorkingCopyUrlService) {
        service.fetchStatus(completionHandler: {
          (linesAdded, linesDeleted, error) in
            
            self.statusButton.isEnabled = true
            
            switch (linesAdded, linesDeleted) {

            case (UInt(NSNotFound), _):
                // modified binary file
                self.statusButton.title = "binary"
                
            case (0,0):
                // file is current
                self.statusButton.title = ""
                self.statusButton.isEnabled = false
                
            case (0, _):
                // modified text file
                self.statusButton.title = "-\(linesDeleted)"

            case (_, 0):
                // modified text file
                self.statusButton.title = "+\(linesAdded)"

            default:
                // modified text file
                self.statusButton.title = "-\(linesDeleted)+\(linesAdded)"
            }
        })
    }
    
    @IBAction func statusTapped(_ sender: Any) {
        guard let service = urlService else { return }
        
        // request deep link
        service.determineDeepLink(completionHandler: { (url, error) in
            if let error = error {
                self.showError(error)
            }
            
            guard let url = url else { return }
            
            // we escape everything outside urlQueryAllowed but also & that starts next url parameter
            let allowChars = CharacterSet.urlQueryAllowed.intersection(CharacterSet(charactersIn: "&").inverted)
            guard let escaped = url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowChars) else { return }
            guard let callbackUrl = URL(string: "working-copy://x-callback-url/commit?url=\(escaped)&x-cancel=open-in-place://&x-success=open-in-place://") else { return }

            UIApplication.shared.open(callbackUrl)
        })
    }
    
    private func loadStatus() {
        guard isViewLoaded else { return }
        guard let url = url else { return }
        
        if #available(iOS 11.0, *) {
            
            // try to use existing service instance
            if let service = urlService {
                loadStatusWithService(service)
                return
            }
            
            // Try to get file provider icon from Working Copy service.
            WorkingCopyUrlService.getFor(url, completionHandler: { (service, error) in
                // the service might very well be missing if you are picking from some other
                // Location than Working Copy or the version of Working Copy isn't new enough
                guard let service = service else { return }
                self.urlService = service

                self.loadStatusWithService(service)
            })
        }
    }
    
    private var unwrittenChanges = false
    private func writeContentIfNeeded(callback: @escaping ((Error?) -> ())) {

        guard unwrittenChanges else {
            callback(nil)
            return
            
        }
        unwrittenChanges = false
        
        guard url != nil else {
            callback(nil)
            return
        }
        
        let coordinator = NSFileCoordinator(filePresenter: self)
        url!.coordinatedWrite(textView.text, coordinator, callback: callback)
    }
    
    // calls writeContentIfNeeded(callback:) showing errors
    @objc private func writeContentUpdatingUI() {
        
        writeContentIfNeeded(callback: { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError(error)
                } else {
                    self.loadStatus()
                }
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadContent()
        loadStatus()
        configureDetailMenu()
        
        let notifications = NotificationCenter.default
        notifications.addObserver(self, selector: #selector(appMovedToBackground),
                                  name: UIApplication.willResignActiveNotification, object: nil)
        notifications.addObserver(self, selector: #selector(appMovedToForeground),
                                  name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // clean up when removed
        if url != nil && self.isMovingFromParent {
            url = nil
        }
    }
    
    private var securityScoped = false
    private var _url: URL?
    private var isFilePresenting = false
    
    public var url: URL? {
        set {
            if(_url != nil) {
                if securityScoped {
                    _url!.stopAccessingSecurityScopedResource()
                    securityScoped = false
                }
                if(isFilePresenting) {
                    NSFileCoordinator.removeFilePresenter(self)
                    isFilePresenting = false
                }
            }
            
            _url = newValue
            urlService = nil
            
            if(_url != nil) {
                securityScoped = _url!.startAccessingSecurityScopedResource()
                NSFileCoordinator.addFilePresenter(self)
                isFilePresenting = true
            }
            loadContent()
            loadStatus()
        }
        get {
            return _url
        }
    }

    //MARK: - NSFilePresenter
    var presentedItemURL: URL? {
        return url
    }
    
    private var presenterQueue : OperationQueue?
    var presentedItemOperationQueue: OperationQueue {
        if(presenterQueue == nil) {
            presenterQueue = OperationQueue()
        }
        return presenterQueue!
    }
    
    // file was changed by someone else and we want to reload
    func presentedItemDidChange() {
        DispatchQueue.main.async {
            self.loadContent()
        }
    }
    
    // someone wants to read the file and we make sure pending changes are written
    func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void) {
        writeContentIfNeeded(callback: { error in
            reader(nil)
        })
    }
    
    // someone wants to write the file and we make sure pending changes are written
    func relinquishPresentedItem(toWriter writer: @escaping ((() -> Void)?) -> Void) {
        writeContentIfNeeded(callback: { error in
            writer(nil)
        })
    }
    
    // file is being renamed by someone else and we keep work in new file location
    func presentedItemDidMove(to newURL: URL) {
        url = newURL
    }
    
    // file is being deleted and we stop tracking it
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        url = nil
        completionHandler(nil)
    }
    
    @objc func appMovedToBackground() {
        // it can lead to deadlocks to present files in the background and we back off
        if(isFilePresenting) {
            NSFileCoordinator.removeFilePresenter(self)
            isFilePresenting = false
        }
        
        // write if anything is pending
        writeContentUpdatingUI()
        
    }
    
    @objc func appMovedToForeground() {
        // we are back after being in the background and listen again and refresh from file
        if(!isFilePresenting && url != nil) {
            NSFileCoordinator.addFilePresenter(self)
            isFilePresenting = true
        }
        
        loadContent()
        loadStatus()
    }
    
    //MARK: - UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        // we want to write changes, but not after every keystroke and wait for a
        // whole second without changes
        unwrittenChanges = true
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(writeContentUpdatingUI), object: nil)
        perform(#selector(writeContentUpdatingUI), with: nil, afterDelay: 1.0)
    }
    
    //MARK: -
}

