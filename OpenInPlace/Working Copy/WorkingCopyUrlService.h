//
//  WorkingCopyGitService.h
//  WorkingCopy
//
//  Created by Anders Borum on 13/08/2018.
//  Copyright © 2018 Applied Phasor. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WorkingCopyUrlService : NSObject

#warning "This is a experimental version of WorkingCopyUrlService that might change. Find the stable version at https://github.com/palmin/open-in-place/tree/master/OpenInPlace/Working%20Copy"

// Try to inquire and connect to WorkingCopyUrlService on the given URL.
// Note that you can get a nil-service even without a error when url is outside
// a Working Copy file provider.
// Completion block is called on main thread.
+(void)getServiceForUrl:(nonnull NSURL*)url
      completionHandler:(void (^_Nonnull)(WorkingCopyUrlService* _Nullable service,
                                          NSError* _Nullable error))completionHandler
                                                             API_AVAILABLE(ios(11.0));

// Determine deep-link for opening a the given URL inside Working Copy,
// which is something on the form:
//   working-copy://open?repo=welcome%20to%20working%20copy&path=README.md
// Completion block is called on main thread.
-(void)determineDeepLinkWithCompletionHandler:(void (^_Nonnull)(NSURL* _Nullable url,
                                                                NSError* _Nullable error))completionHandler;

// Determine path relative to Working Copy storage and app information
// that is shared by all Working Copy URLs. Completion block is called on main thread.
-(void)fetchDocumentSourceInfoWithCompletionHandler:(void (^_Nonnull)(NSString* _Nullable path,
                                                                      NSString* _Nullable appName,
                                                                      NSString* _Nullable appVersion,
                                                                      UIImage* _Nullable appIcon,
                                                                      NSError* _Nullable error))completionHandler;

// Determine the lines added or deleted for the file at the given URL compared to last commit.
// If the file is current both lines added and deleted are zero, while NSNotFound indicates
// a modified binary file.
-(void)fetchStatusWithCompletionHandler:(void (^_Nonnull)(NSUInteger linesAdded,
                                                          NSUInteger linesDeleted,
                                                          NSError* _Nullable error))completionHandler;

@end
