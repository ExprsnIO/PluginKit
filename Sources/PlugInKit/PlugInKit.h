//
//  PlugInKit.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for PlugInKit.
FOUNDATION_EXPORT double PlugInKitVersionNumber;

//! Project version string for PlugInKit.
FOUNDATION_EXPORT const unsigned char PlugInKitVersionString[];

// Core
#import <PlugInKit/PKPlugInManager.h>
#import <PlugInKit/PKPlugInManager+Compatibility.h>
#import <PlugInKit/PKPlugInManager+HotReload.h>
#import <PlugInKit/PKConnection.h>
#import <PlugInKit/PKError.h>
#import <PlugInKit/PKLogger.h>

// XPC
#import <PlugInKit/PKXPCService.h>

// Introspection
#import <PlugInKit/PKIntrospector.h>

// Scripting Bridge
#import <PlugInKit/PKScriptingDefinitionGenerator.h>

// Protocols
#import <PlugInKit/PKPlugInProtocol.h>
#import <PlugInKit/PKHostProtocol.h>

// Futures
#import <PlugInKit/PKFuture.h>
#import <PlugInKit/PKFuture+Cancellation.h>
#import <PlugInKit/PKFuture+Progress.h>
#import <PlugInKit/PKCancellationToken.h>
#import <PlugInKit/PKConnection+Futures.h>
#import <PlugInKit/PKPlugInProtocol+Futures.h>
