//
//  XDocumentSource2.swift
//  OpenInPlace
//
//  Created by Anders Borum on 14/02/2019.
//  Copyright © 2019 Applied Phasor. All rights reserved.
//

import Foundation

@available(iOS 11.0, *)
extension URL {
    // Call didAccess on dk.andersborum.document-notify if available.
    //
    // Callback is always made on main thread if dk.andersborum.document-notify service
    // is missing the result is NSCocoaDomain, NSFeatureUnsupportedError.
    func xDocumentNotifyDidAccess(_ completion: @escaping (_ error: Error?) -> Void) {
        
        func done(_ error: Error?) {
            DispatchQueue.main.async {
                completion(error)
            }
        }
        
        let securityScoped = startAccessingSecurityScopedResource()
        FileManager.default.getFileProviderServicesForItem(at: self, completionHandler: {
            (services, error) in
            
            // check that we have provider service
            let name = NSFileProviderServiceName("dk.andersborum.document-notify")
            guard let service = services?[name] else {
                if securityScoped { self.stopAccessingSecurityScopedResource() }
                
                done(NSError(domain: NSCocoaErrorDomain,
                             code: NSFeatureUnsupportedError))
                return
            }
            
            // attempt connection
            service.getFileProviderConnection(completionHandler: {
                (connection, error) in
                
                if securityScoped {
                    self.stopAccessingSecurityScopedResource()
                }
                
                // make sure we have connection
                guard let connection = connection, error == nil else {
                    done(error)
                    return
                }
                
                // setup proxy object
                connection.remoteObjectInterface =  NSXPCInterface(with: XDocumentNotifyProtocol.self)
                connection.resume()
                let proxy = connection.remoteObjectProxy as! XDocumentNotifyProtocol
                
                // make remote call
                proxy.didAccess(completionHandler: done)
            })
        })
    }
}

@objc fileprivate protocol XDocumentNotifyProtocol {
    func didAccess(completionHandler: (((any Error)?) -> Void)!)
}
