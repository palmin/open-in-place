//
//  WorkingCopyGitService.m
//  WorkingCopy
//
//  Created by Anders Borum on 13/08/2018.
//  Copyright © 2018 Applied Phasor. All rights reserved.
//

#import "WorkingCopyUrlService.h"

@protocol WorkingCopyProtocolVer1

-(void)determineDeepLinkWithCompletionHandler:(void (^)(NSURL* url))completionHandler;

-(void)fetchDocumentSourceInfoWithCompletionHandler:(void (^)(NSString* path,
                                                              NSString* appName,
                                                              NSString* appVersion,
                                                              NSData* appIconPNG))completionHandler;

@end

@interface WorkingCopyUrlService () {
    NSXPCConnection* connection;
    id<WorkingCopyProtocolVer1> proxy;

    NSError* error;
    void (^errorHandler)(NSError* error);
}

@end

@implementation WorkingCopyUrlService

-(void)determineDeepLinkWithCompletionHandler:(void (^_Nonnull)(NSURL* _Nullable url,
                                                                NSError* _Nullable error))completionHandler {
    errorHandler = ^(NSError* error) {
        completionHandler(nil, error);
    };
    
    [proxy determineDeepLinkWithCompletionHandler:^(NSURL* url) {
        NSError* theError = [self->error copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(url, theError);
        });
    }];
}

-(void)fetchDocumentSourceInfoWithCompletionHandler:(void (^_Nonnull)(NSString* _Nullable path,
                                                                      NSString* _Nullable appName,
                                                                      NSString* _Nullable appVersion,
                                                                      UIImage* _Nullable appIcon,
                                                                      NSError* _Nullable error))completionHandler {
    errorHandler = ^(NSError* error) {
        completionHandler(nil, nil, nil, nil, error);
    };
    
    [proxy fetchDocumentSourceInfoWithCompletionHandler:^(NSString* path,
                                                          NSString* appName,
                                                          NSString* appVersion,
                                                          NSData* iconPNG) {
        NSError* theError = [self->error copy];
        UIImage* icon = iconPNG == nil ? nil : [UIImage imageWithData:iconPNG];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(path, appName, appVersion, icon, theError);
        });
    }];
}

-(instancetype)initWithConnection:(NSXPCConnection*)theConnection {
    self = [super init];
    if(self != nil) {
        connection = theConnection;

        connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(WorkingCopyProtocolVer1)];
        [connection resume];
        
        proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError* theError) {
            self->error = theError;
            [self->connection invalidate];
            
            if(self->errorHandler) {
                // make sure error handler is only called once
                void (^copy)(NSError* error) = [self->errorHandler copy];
                self->errorHandler = nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    copy(theError);
                });
            }

        }];
    }
    return self;
}

-(void)dealloc {
    [connection invalidate];
}

+(void)getServiceForUrl:(nonnull NSURL*)url
      completionHandler:(void (^_Nonnull)(WorkingCopyUrlService* _Nullable service,
                                          NSError* _Nullable error))completionHandler {
    
    BOOL securityScoped = [url startAccessingSecurityScopedResource];
    
    [[NSFileManager defaultManager] getFileProviderServicesForItemAtURL:url
                                                      completionHandler:^(NSDictionary* services,
                                                                          NSError* error) {
          // check that we have provider service
          NSFileProviderService* providerService = services[@"working-copy-v1"];
          if(error != nil || providerService == nil) {
              dispatch_async(dispatch_get_main_queue(), ^{
                  completionHandler(nil, error);
              });
              if(securityScoped) {
                  [url stopAccessingSecurityScopedResource];
              }
              return;
          }
                                                          
          // attempt connection
          [providerService getFileProviderConnectionWithCompletionHandler:^(NSXPCConnection* connection,
                                                                            NSError* error) {
              
              if(securityScoped) {
                  [url stopAccessingSecurityScopedResource];
              }
              
              // make sure we have connection
              if(error != nil || connection == nil) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                      completionHandler(nil, error);
                  });
                  return;
              }
             
              // setup proxy object
              WorkingCopyUrlService* service = [[WorkingCopyUrlService alloc] initWithConnection:connection];
              dispatch_async(dispatch_get_main_queue(), ^{
                  completionHandler(service, nil);
              });
        }];
    }];
}

@end
