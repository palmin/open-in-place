//
//  WorkingCopyGitService.m
//  WorkingCopy
//
//  Created by Anders Borum on 13/08/2018.
//  Copyright © 2018 Applied Phasor. All rights reserved.
//

#import "WorkingCopyUrlService.h"

#define ServiceNameVer1 @"working-copy-v1"
#define ServiceNameVer2 @"working-copy-v2"

@protocol WorkingCopyProtocolVer1

-(void)determineDeepLinkWithCompletionHandler:(void (^)(NSURL* url))completionHandler;

-(void)fetchDocumentSourceInfoWithCompletionHandler:(void (^)(NSString* path,
                                                              NSString* appName,
                                                              NSString* appVersion,
                                                              NSData* appIconPNG))completionHandler;

@end

@protocol WorkingCopyProtocolVer2 <WorkingCopyProtocolVer1>

-(void)fetchStatusAvatarLength:(NSUInteger)length // 0 to not get back avatar
             completionHandler:(void (^)(NSUInteger linesAdded,
                                         NSUInteger linesDeleted,
                                         NSString* commitIdentifier,
                                         NSString* commitAuthor,
                                         NSData* commitAvatarPng,
                                         NSDate* commitDate,
                                         NSError* error))completionHandler;

-(void)fetchBlameAtLocation:(NSUInteger)location // NSNotFound to not check blame for location
               avatarLength:(NSUInteger)length // 0 to not get back avatar
          completionHandler:(void (^)(NSString* commitIdentifier,
                                      NSString* commitAuthor,
                                      NSData* commitAvatarPng,
                                      NSDate* commitDate,
                                      NSError* error))completionHandler;

@end

@interface WorkingCopyUrlService () {
    NSXPCConnection* connection;
    id<WorkingCopyProtocolVer1> proxy1;
    id<WorkingCopyProtocolVer2> proxy2;

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
    
    [proxy1 determineDeepLinkWithCompletionHandler:^(NSURL* url) {
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
    
    [proxy1 fetchDocumentSourceInfoWithCompletionHandler:^(NSString* path,
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

-(void)fetchStatusWithCompletionHandler:(void (^_Nonnull)(NSUInteger linesAdded, NSUInteger linesDeleted,
                                                          NSError* _Nullable error))completionHandler {
    if(proxy2 == nil) {
        NSString* message = NSLocalizedString(@"Status check requires Working Copy 3.5.0 or later.", nil);
        NSDictionary* userInfo = @{NSLocalizedDescriptionKey: message};
        NSError* error = [NSError errorWithDomain:@"Working Copy" code:400 userInfo:userInfo];
        completionHandler(0,0, error);
        return;
    }
    
    errorHandler = ^(NSError* error) {
        completionHandler(0,0, error);
    };
    
    [proxy2 fetchStatusAvatarLength:100
                  completionHandler:^(NSUInteger linesAdded,
                                      NSUInteger linesDeleted,
                                      NSString* commitIdentifier,
                                      NSString* commitAuthor,
                                      NSData* commitAvatarPng,
                                      NSDate* commitDate,
                                      NSError* error) {
                    
        NSError* theError = error ?: [self->error copy];
                      
        UIImage* avatar = commitAvatarPng == nil ? nil : [UIImage imageWithData:commitAvatarPng];
                    
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(linesAdded, linesDeleted, theError);
        });
    }];
}

-(instancetype)initWithConnection:(NSXPCConnection*)theConnection
                      serviceName:(NSString*)serviceName {
    self = [super init];
    if(self != nil) {
        connection = theConnection;

        Protocol* protocol = nil;
        if([serviceName isEqualToString:ServiceNameVer2]) {
            protocol = @protocol(WorkingCopyProtocolVer2);
        } else {
            protocol = @protocol(WorkingCopyProtocolVer1);
        }
        
        connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:protocol];
        [connection resume];
        
        proxy1 = [connection remoteObjectProxyWithErrorHandler:^(NSError* theError) {
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
        
        if([serviceName isEqualToString:ServiceNameVer2]) {
            proxy2 = (id<WorkingCopyProtocolVer2>)proxy1;
        }
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
          NSFileProviderService* providerService = services[ServiceNameVer2];
          if(providerService == nil) providerService = services[ServiceNameVer1];
                                                          
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
              WorkingCopyUrlService* service = [[WorkingCopyUrlService alloc] initWithConnection:connection
                                                                                     serviceName:providerService.name];
              dispatch_async(dispatch_get_main_queue(), ^{
                  completionHandler(service, nil);
              });
        }];
    }];
}

@end
