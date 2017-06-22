//
//  DetailViewController.swift
//  OpenInPlace
//
//  Created by Anders Borum on 21/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import UIKit

class EditController: UIViewController, UITextViewDelegate, NSFilePresenter {
    
    private var securityScoped = false
    
    @IBOutlet var textView: UITextView!
    private func loadContent() {
        // do not load unless we have both url and view loaded
        guard isViewLoaded && url != nil else {
            return
        }
        
        let coordinator = NSFileCoordinator(filePresenter: self)
        url!.coordinatedRead(coordinator, callback: { (text, error) in
            
            if(error != nil) {
                self.showError(error!)
            } else {
                self.textView.text = text
            }
            
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadContent()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // clean up when removed
        if url != nil && self.isMovingFromParentViewController {
            url = nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private var _url: URL?
    public var url: URL? {
        set {
            if(_url != nil) {
                if securityScoped {
                    _url!.stopAccessingSecurityScopedResource()
                    securityScoped = false
                }
                NSFileCoordinator.removeFilePresenter(self)
            }
            
            _url = newValue
            
            if(_url != nil) {
                securityScoped = _url!.startAccessingSecurityScopedResource()
                NSFileCoordinator.addFilePresenter(self)
                loadContent()
            }
            navigationItem.title = _url?.lastPathComponent
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
    
    func presentedItemDidChange() {
        loadContent()
    }
    
    //MARK: -
    
}

