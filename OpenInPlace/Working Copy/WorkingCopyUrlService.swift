//
//  WorkingCopyUrlService.swift
//  OpenInPlace
//
//  Created by Anders Borum on 24/09/2018.
//  Copyright © 2018 Applied Phasor. All rights reserved.
//

import UIKit

@objc private protocol WorkingCopyProtocolVer1 {
    func determineDeepLinkWithCompletionHandler(_ completionHandler:
                                                @escaping ((URL?) -> Void))
    
    func fetchDocumentSourceInfoWithCompletionHandler(_ completionHandler:
                                                      @escaping ((String?, String?,
                                                                  String?, Data?) -> Void))
}

@objc private protocol WorkingCopyProtocolVer352 : WorkingCopyProtocolVer1 {
    func fetchStatusWithCompletionHandler(_ completionHandler:
                                          @escaping ((UInt, UInt, Error?) -> Void))
}

/// Retrieves information about files and directories stored in a Working Copy
/// file provider.
///
/// You initialise instances from a file URL that the user has granted your app
/// access using the document picker, document browser, drag and drop or by
/// opening a file in-place.
class WorkingCopyUrlService {
    private static let serviceNameVer1 = NSFileProviderServiceName("working-copy-v1")
    private static let serviceNameVer352 = NSFileProviderServiceName("working-copy-v3.5.2")
    
    private var connection: NSXPCConnection
    private var proxy1: WorkingCopyProtocolVer1?
    private var proxy352: WorkingCopyProtocolVer352?
    
    private var error: Error?
    private var errorHandler: ((Error) -> Void)?
    
    /// Try to inquire and connect to WorkingCopyUrlService on the given URL.
    /// 
    /// Note that you can get a nil-service even without a error when url is outside
    /// a Working Copy file provider.
    ///
    /// Completion handler is called on main thread.
    @available(iOS 11.0, *) class public func getFor(_ url: URL,
                                                     completionHandler: @escaping ((WorkingCopyUrlService?, Error?) -> ())) {
        let securityScoped = url.startAccessingSecurityScopedResource();
        FileManager.default.getFileProviderServicesForItem(at: url, completionHandler: {
            (services, error) in
            
            // check that we have provider service
            let potentialService = services?[serviceNameVer352] ?? services?[serviceNameVer1]
            
            guard let providerService = potentialService, error == nil else {
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
                return
            }
            
            // attempt connection
            providerService.getFileProviderConnection(completionHandler: {
                (connection, error) in
                
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
                
                // make sure we have connection
                guard let theConnection = connection, error == nil else {
                    DispatchQueue.main.async {
                        completionHandler(nil, error)
                    }
                    return
                }
                
                // setup proxy object
                let service = WorkingCopyUrlService(theConnection, providerService.name)
                DispatchQueue.main.async {
                    completionHandler(service, nil)
                }
            })
        })
    }
    
    /// Determine deep-link for opening a the given URL inside Working Copy.
    ///
    /// This link is something on the form:
    ///
    ///     working-copy://open?repo=welcome%20to%20working%20copy&path=README.md
    ///
    /// Completion block is called on main thread.
    public func determineDeepLink(completionHandler: @escaping ((_ url: URL?,
                                                                 Error?) -> Void)) {
        
        errorHandler = { error in
            completionHandler(nil, error)
        }
        
        proxy1?.determineDeepLinkWithCompletionHandler({ url in
            let theError = self.error
            DispatchQueue.main.async {
                completionHandler(url, theError)
            }
        })
    }
    
    /// Determine path relative to Working Copy storage and app information
    /// that is shared by all Working Copy URLs.
    ///
    /// Completion block is called on main thread.
    public func fetchDocumentSourceInfo(completionHandler: @escaping ((_ path: String?,
                                                                       _ appName: String?,
                                                                       _ appVersion: String?,
                                                                       _ icon: UIImage?,
                                                                       Error?) -> Void)) {
        
        errorHandler = { error in
            completionHandler(nil, nil, nil, nil, error)
        }

        proxy1?.fetchDocumentSourceInfoWithCompletionHandler({
            (path, appName, appVersion, iconPNG) in
            
            let theError = self.error
            var icon: UIImage?
            if let png = iconPNG {
                icon = UIImage(data: png)
            }
            
            DispatchQueue.main.async {
                completionHandler(path, appName, appVersion, icon, theError)
            }
        })
    }
    
    /// Determine the lines added or deleted for the file at the given URL compared to last commit.
    /// If the file is current both lines added and deleted are zero, while NSNotFound indicates
    /// a modified binary file.
    ///
    /// Completion block is called on main thread.
    public func fetchStatus(completionHandler: @escaping ((_ linesAdded: UInt,
                                                           _ linesDeleted: UInt,
                                                           Error?) -> Void)) {
    
        guard let proxy = proxy352 else {
            let message = NSLocalizedString("Status check requires Working Copy 3.5.2 or later.",  comment: "")
            let userInfo = [NSLocalizedDescriptionKey: message]
            let error = NSError.init(domain: "Working Copy", code: 400, userInfo: userInfo)
            completionHandler(0,0, error)
            return
        }
        
        errorHandler = { error in
            completionHandler(0,0, error)
        }
    
        proxy.fetchStatusWithCompletionHandler({
            (linesAdded, linesDeleted, error) in
            
            let theError = error ?? self.error
            DispatchQueue.main.async {
                completionHandler(linesAdded, linesDeleted,
                                  theError)
            }
        })
    }
    
    private init(_ theConnection: NSXPCConnection,
                 _ serviceName: NSFileProviderServiceName) {
        connection = theConnection
        
        var theProtocol: Protocol?
        if serviceName == WorkingCopyUrlService.serviceNameVer352 {
            theProtocol = WorkingCopyProtocolVer352.self
        } else {
            theProtocol = WorkingCopyProtocolVer1.self
        }
        
        connection.remoteObjectInterface =  NSXPCInterface(with: theProtocol!)
        connection.resume()
        
        proxy1 = connection.remoteObjectProxyWithErrorHandler({
            error in
            
            self.error = error
            self.connection.invalidate()
            
            if let handler = self.errorHandler {
                // make sure error handler is only called once
                self.errorHandler = nil
                
                DispatchQueue.main.async {
                    handler(error)
                }
            }
        }) as? WorkingCopyProtocolVer1
        
        if serviceName == WorkingCopyUrlService.serviceNameVer352 {
            proxy352 = proxy1 as? WorkingCopyProtocolVer352
        }
        
    }
    
    deinit {
        connection.invalidate()
    }
}
