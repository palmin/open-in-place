//
//  SchemeOpener.swift
//  OpenInPlace
//
//  Created by Anders Borum on 02/01/2023.
//  Copyright © 2023 Applied Phasor. All rights reserved.
//

import UIKit
import MobileCoreServices

// Helps manage programmatically opening of files from other apps once
// user has granted access to directory files reside in. You need to set
// feed URLs opened with app to didHandleUrl and to implemenent file
// opening in openCallback.
//
// The other app would open URLs on the form:
//   open-in-place://x-callback-url/open-in-place?root=/ShellFishRootFolder&path=InnerDir/README.md
// and the first time the user would be asked to pick the root folder before the file was opened
// but after this any files inside root folder can be opened without showing the document picker.
//
// You need to set XCallbackOpener.shared.openCallback to open the file similarly to what you
// would do when users trigerred opening of URLs with document picker or document browser.
//
// You probably want to change XCallbackOpener.shared.handleError to report errors in a nicer
// way when there is no way to report the error back to source app triggering x-callback-url.
// Currently it will show a system alert.
class XCallbackOpener {
    public var openCallback: (URL, UIViewController) -> Void = { _, _ in }

    // default error handler shows alert
    public var handleError: (Error, UIViewController) -> Void = { error, vc in
        let title = NSLocalizedString("Error", comment: "")
        let message = error.localizedDescription
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        vc.present(alert, animated: true)
    }

    private init() {}
    
    public static var shared: XCallbackOpener = { XCallbackOpener() }()
    
    public func couldHandleUrl(_ url: URL) -> Bool {
        return url.host == "x-callback-url" && url.path == "/open-in-place"
    }
    
    // vc is used if we need to prompt the user to pick root folder
    //
    // false is returned for URLs that don't make sense
    // exception is thrown if there are errors and no "on-error" handler
    // to pass that error back on
    public func didHandleUrl(_ url: URL, _ vc: UIViewController) throws -> Bool {
        guard couldHandleUrl(url) else {
            return false
        }
        
        // decode url parameters
        var parameters = [String: String]()
        let query = url.query ?? ""
        for keyval in query.components(separatedBy: "&") {
            let parts = keyval.components(separatedBy: "=")
            if parts.count == 2,
               let key = parts[0].removingPercentEncoding,
               let val = parts[1].removingPercentEncoding {
                
                parameters[key] = val
            }
        }
        
        let request = XCallbackOpenerRequest(vc, parameters)
        request.work()

        return true
    }
    
    // we need to retain requests during folder picking
    fileprivate var retainedRequest = Set<XCallbackOpenerRequest>()
            
    fileprivate lazy var appName: String? = {
        let infoDictionary = Bundle.main.infoDictionary
        return infoDictionary?["CFBundleDisplayName"] as? String ??
               infoDictionary?["CFBundleName"] as? String
    }()
    
    private let bookmarkDefaultsKey = "open-in-place.bookmarks"
    
    fileprivate func urlWithRoot(_ root: String) -> URL? {
        guard let array = UserDefaults.standard.array(forKey: bookmarkDefaultsKey)  as? [Data] else {
            return nil
        }
        
        // we write back fixed version of array as needed
        var modified: [Data]?
        defer {
            if let modified = modified {
                UserDefaults.standard.set(modified, forKey: bookmarkDefaultsKey)
            }
        }
        
        for bookmark in array {
            var stale = false
            let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)

            let securityScoped = url?.startAccessingSecurityScopedResource() ?? false
            defer {
                if securityScoped {
                    url?.stopAccessingSecurityScopedResource()
                }
            }
            
            // modify array to refresh stale and remove missing url
            if url == nil || stale {
                if modified == nil {
                    modified = array
                }
                modified?.removeAll(where: { $0 == bookmark })
                if stale, let newBookmark = try? url?.bookmarkData() {
                    modified?.append(newBookmark)
                }
            }
            
            // check if url matches
            if let path = url?.path, path.hasPrefix(root) {
                return url
            }
        }
        
        return nil
    }
    
    fileprivate func rememberUrlForRoot(_ url: URL) throws {
        let securityScoped = url.startAccessingSecurityScopedResource()
        let bookmark = try url.bookmarkData()
        if securityScoped {
            url.stopAccessingSecurityScopedResource()
        }
        
        var array = UserDefaults.standard.array(forKey: bookmarkDefaultsKey)  as? [Data] ?? []
        array.append(bookmark)
        UserDefaults.standard.set(array, forKey: bookmarkDefaultsKey)
    }
}

fileprivate class XCallbackOpenerRequest : NSObject, UIDocumentPickerDelegate {
    let vc: UIViewController
    let parameters: [String: String]
    let shared: XCallbackOpener
    
    var path = ""
    var root = ""
        
    init(_ vc: UIViewController, _ parameters: [String: String]) {
        self.vc = vc
        self.parameters = parameters
        shared = XCallbackOpener.shared
        
        super.init()
    }
    
    func work() {
        // we need root directory and path to proceed
        guard let root = parameters["root"],
              var path = parameters["path"] else {
            
            let message = NSLocalizedString("root and path parameters required", comment: "")
            callbackErrorMessage(message);
            return
        }
                
        // path is supposed to be relative to root, but to be helpful we allow it to be a full path
        if path.hasPrefix(root) {
            path = String(path.suffix(path.count - root.count))
        }
        if path.hasPrefix("/") {
            path = String(path.suffix(path.count - 1))
        }

        self.root = root
        self.path = path
                
        if let rootUrl = XCallbackOpener.shared.urlWithRoot(root) {
            // we already have permission
            deliverUrlFromRoot(rootUrl)
        } else {
            // we need user to pick folder
            shared.retainedRequest.insert(self)
            let picker = UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String],
                                                        in: .open)
            picker.directoryURL = URL(fileURLWithPath: root)
            picker.delegate = self
            vc.present(picker, animated: true)
        }
    }
    
    private func deliverUrlFromRoot(_ rootUrl: URL) {
        let securityScoped = rootUrl.startAccessingSecurityScopedResource()
        let url = rootUrl.appendingPathComponent(path)
        shared.openCallback(url, vc)
        if securityScoped {
            rootUrl.stopAccessingSecurityScopedResource()
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        shared.retainedRequest.remove(self)
        do {
            try shared.rememberUrlForRoot(url)
            deliverUrlFromRoot(url)
        } catch {
            callbackError(error)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        callbackError(cancelError)
        
        shared.retainedRequest.remove(self)
    }
    
    private func didMakeCallback(_ key: String,
                                 _ result: [String: String]) -> Bool {
        guard var callback = parameters[key] else {
            return false
        }
        
        // first delimiter is ? if there are no other parameters
        callback.append(callback.contains("?") ? "&" : "?")
        
        // add app name if possible
        if let appName = XCallbackOpener.shared.appName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            callback.append("x-source=")
            callback.append(appName)
            callback.append("&")
        }
        
        for (key, val) in result {
            guard let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let escapedVal = val.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return false
            }
            
            callback += "\(escapedKey)=\(escapedVal)&"
        }
        
        guard let url = URL(string: callback) else {
            return false
        }
        
        UIApplication.shared.open(url)
        return true
    }
    
    // do error callback if possible otherwise throw as exception
    private func callbackError(_ error: Error) {
        let result = ["errorCode": "\((error as NSError).code)",
                      "errorMessage": error.localizedDescription]
        if !didMakeCallback("on-error", result) {
            // show error internally when not able to callback to source app
            shared.handleError(error, vc)
        }
    }
    
    private func callbackErrorMessage(_ message: String) {
        let userInfo = [NSLocalizedDescriptionKey: message]
        let error = NSError(domain: "XCallbackOpener", code: 0, userInfo: userInfo)
        callbackError(error)
    }
}
