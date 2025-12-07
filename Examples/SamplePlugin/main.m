//
//  main.m
//  SamplePlugin XPC Service
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SamplePlugin.h"

@interface PlugInServiceDelegate : NSObject <NSXPCListenerDelegate>

@end

@implementation PlugInServiceDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    NSLog(@"[SamplePlugin XPC] Accepting new connection");

    // Configure the connection
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PKPlugInProtocol)];

    // Configure allowed classes for method metadata
    NSSet *metadataClasses = [NSSet setWithObjects:[NSArray class], [PKMethodMetadata class], nil];
    [newConnection.exportedInterface setClasses:metadataClasses
                                    forSelector:@selector(exposedMethodsWithReply:)
                                  argumentIndex:0
                                        ofReply:YES];

    SamplePlugin *plugin = [[SamplePlugin alloc] init];
    newConnection.exportedObject = plugin;

    newConnection.invalidationHandler = ^{
        NSLog(@"[SamplePlugin XPC] Connection invalidated");
    };

    newConnection.interruptionHandler = ^{
        NSLog(@"[SamplePlugin XPC] Connection interrupted");
    };

    [newConnection resume];

    return YES;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        PlugInServiceDelegate *delegate = [[PlugInServiceDelegate alloc] init];

        NSXPCListener *listener = [NSXPCListener serviceListener];
        listener.delegate = delegate;

        NSLog(@"[SamplePlugin XPC] Starting service listener");
        [listener resume];

        [[NSRunLoop currentRunLoop] run];
    }

    return 0;
}
