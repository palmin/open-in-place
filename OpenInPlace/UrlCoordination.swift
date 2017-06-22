//
//  UrlCoordination.swift
//  OpenInPlace
//
//  These helper methods do file coordinated operations on URL objects.
//  The callbacks are not guaranteed to happen on any particular thread.
//
//  Created by Anders Borum on 22/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import Foundation

extension URL {
    
    public func coordinatedDelete(_ coordinator : NSFileCoordinator, callback: ((Error?) -> ())) {
        let error: NSErrorPointer = nil
        coordinator.coordinate(writingItemAt: self,
                               options: NSFileCoordinator.WritingOptions.forDeleting,
                               error: error, byAccessor: { url in
                                do {
                                    try FileManager.default.removeItem(at: url)
                                    callback(nil)
                                    
                                } catch {
                                    callback(error)
                                }
        })
        
        // only do callback if there is error, as it will be made during coordination
        if error != nil { callback(error!.pointee! as NSError) }
    }
    
    public func coordinatedList(_ coordinator : NSFileCoordinator,
                                callback: (([URL]?, Error?) -> ())) {
        let error: NSErrorPointer = nil
        coordinator.coordinate(readingItemAt: self, options: [],
                               error: error, byAccessor: { url in
                                do {
                                    let urls = try FileManager.default.contentsOfDirectory(at: url,
                                                                                           includingPropertiesForKeys: nil,
                                                                                           options: [])
                                    callback(urls, nil)
                                    
                                } catch {
                                    callback(nil, error)
                                }
        })
        
        // only do callback if there is error, as it will be made during coordination
        if error != nil { callback(nil, error!.pointee! as NSError) }
    }
    
    public func coordinatedRead(_ coordinator : NSFileCoordinator,
                                callback: ((String?, Error?) -> ())) {
        let error: NSErrorPointer = nil
        coordinator.coordinate(readingItemAt: self, options: [],
                               error: error, byAccessor: { url in
                                do {
                                    let text = try String.init(contentsOf: url)
                                    callback(text, nil)
                                    
                                } catch {
                                    callback(nil, error)
                                }
        })
        
        // only do callback if there is error, as it will be made during coordination
        if error != nil { callback(nil, error!.pointee! as NSError) }
    }
    
    public func coordinatedWrite(_ text : String, _ coordinator : NSFileCoordinator,
                                callback: ((Error?) -> ())) {
        let error: NSErrorPointer = nil
        coordinator.coordinate(writingItemAt: self, options: [],
                               error: error, byAccessor: { url in
                                do {
                                    try text.write(to: url, atomically: false, encoding: .utf8)
                                    callback(nil)
                                    
                                } catch {
                                    callback(error)
                                }
        })
        
        // only do callback if there is error, as it will be made during coordination
        if error != nil { callback(error!.pointee! as NSError) }
    }
    
    // shorthand to check if URL is directory
    public var isDirectory: Bool {
        let keys = Set<URLResourceKey>([URLResourceKey.isDirectoryKey])
        let value = try? self.resourceValues(forKeys: keys)
        switch value?.isDirectory {
        case .some(true):
            return true
            
        default:
            return false
        }
    }
}
