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
    
    public func coordinatedDelete(_ coordinator : NSFileCoordinator,
                                  callback: @escaping ((Error?) -> ())) {

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
                                callback: @escaping (([URL]?, Error?) -> ())) {
        
        let error: NSErrorPointer = nil
        coordinator.coordinate(readingItemAt: self, options: [],
                               error: error, byAccessor: { url in
            do {
                let urls = try FileManager.default.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [])
                    
                    // sometimes placeholder files are not resolved and we do this manually as a work-around
                    let resolved = urls.map({ url -> URL in
                        let filename = url.lastPathComponent
                        if filename.hasPrefix(".") && filename.hasSuffix(".icloud") {
                            let fixed = String(filename.dropFirst().dropLast(7)) // drop leading . and trailing  .icloud
                            let directory = url.deletingLastPathComponent()
                            return directory.appendingPathComponent(fixed, isDirectory: url.isDirectory)
                        }
                        
                        return url
                    })
                
                    callback(resolved, nil)
                                    
                } catch {
                    callback(nil, error)
                }
        })
        
        // only do callback if there is error, as it will be made during coordination
        if error != nil { callback(nil, error!.pointee! as NSError) }
    }
    
    public func coordinatedRead(_ coordinator : NSFileCoordinator,
                                callback: @escaping ((String?, Error?) -> ())) {
        
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
                                callback: @escaping ((Error?) -> ())) {
        
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

    // this will trigger a call to file provider changing lastUseDate to the value it had previously,
    // as a sort of no-operation giving the file provider a chance to do work
    func coordinatedUpdateLastUseDate(_ coordinator : NSFileCoordinator,
                                      callback: @escaping ((Error?) -> ())) {
        let error: NSErrorPointer = nil
        coordinator.coordinate(writingItemAt: self,
                               options: [.contentIndependentMetadataOnly],
                               error: error, byAccessor: { url in
            callback(nil)
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
