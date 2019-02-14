//
//  XDocumentSource2.swift
//  OpenInPlace
//
//  Created by Anders Borum on 14/02/2019.
//  Copyright © 2019 Applied Phasor. All rights reserved.
//

import UIKit

@available(iOS 11.0, *)
extension URL {
    func fetchDocumentInfo(pixelSize: UInt = 0,
                           completionHandler: @escaping ((_ path: String?,
                                                          _ appName: String?,
                                                          _ appVersion: String?,
                                                          _ icon: UIImage?) -> Void)) {
        
        let securityScoped = startAccessingSecurityScopedResource()
        FileManager.default.getFileProviderServicesForItem(at: self, completionHandler: {
            (services, error) in
            
            // check that we have provider service
            let name = NSFileProviderServiceName("x-document-source-2")
            guard let service = services?[name] else {
                if securityScoped { self.stopAccessingSecurityScopedResource() }
                
                DispatchQueue.main.async {
                    completionHandler(nil, nil, nil, nil)
                }
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
                    DispatchQueue.main.async {
                        completionHandler(nil, nil, nil, nil)
                    }
                    return
                }
                
                // setup proxy object
                connection.remoteObjectInterface =  NSXPCInterface(with: XDocumentSource2Protocol.self)
                connection.resume()
                let proxy = connection.remoteObjectProxy as! XDocumentSource2Protocol
                
                // make remote call
                proxy.fetchDocumentSourceInfoPixelSize(pixelSize,
                            completionHandler: { (path, appName, appVersion, iconPNG) in
                    var image: UIImage?
                    if let data = iconPNG {
                        image = UIImage(data: data)
                    }
                    
                    DispatchQueue.main.async {
                        completionHandler(path, appName, appVersion, image)
                    }
                })
            })
        })
    }
}

@objc fileprivate protocol XDocumentSource2Protocol {
    
    func fetchDocumentSourceInfoPixelSize(_ pixelSize: UInt, // use pixelSize=0 to not get icon back
                                          completionHandler: ((String?, String?, String?, Data?) -> Void)!)
}
