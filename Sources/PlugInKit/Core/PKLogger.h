//
//  PKLogger.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <os/log.h>

NS_ASSUME_NONNULL_BEGIN

/// Log levels for PlugInKit logging
typedef NS_ENUM(NSInteger, PKLogLevel) {
    PKLogLevelError   = 0,  ///< Critical errors only
    PKLogLevelWarning = 1,  ///< Warnings and errors
    PKLogLevelInfo    = 2,  ///< Informational messages (default)
    PKLogLevelDebug   = 3,  ///< Debug information
    PKLogLevelTrace   = 4   ///< Verbose tracing
};

/// Custom log handler block
typedef void (^PKLogHandler)(PKLogLevel level, NSString *subsystem, NSString *category, NSString *message);

/// Centralized logging system for PlugInKit
@interface PKLogger : NSObject

/// Current global log level (default: PKLogLevelInfo)
@property (class, nonatomic, assign) PKLogLevel logLevel;

/// Whether to use unified logging (os_log) - default: YES
@property (class, nonatomic, assign) BOOL usesUnifiedLogging;

/// Whether to also log to stderr - default: NO
@property (class, nonatomic, assign) BOOL logsToStderr;

/// Custom log handler for intercepting log messages
@property (class, nonatomic, copy, nullable) PKLogHandler customLogHandler;

// MARK: - Logging Methods

/// Log an error message
/// @param format Format string with optional arguments
+ (void)logError:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log a warning message
/// @param format Format string with optional arguments
+ (void)logWarning:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log an info message
/// @param format Format string with optional arguments
+ (void)logInfo:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log a debug message
/// @param format Format string with optional arguments
+ (void)logDebug:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log a trace message
/// @param format Format string with optional arguments
+ (void)logTrace:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

// MARK: - Categorized Logging

/// Log with specific level and category
/// @param level Log level
/// @param category Log category (e.g., "Connection", "Discovery")
/// @param format Format string with optional arguments
+ (void)log:(PKLogLevel)level category:(NSString *)category format:(NSString *)format, ... NS_FORMAT_FUNCTION(3,4);

/// Log with specific level, category, and arguments
/// @param level Log level
/// @param category Log category
/// @param format Format string
/// @param args Variable argument list
+ (void)log:(PKLogLevel)level category:(NSString *)category format:(NSString *)format args:(va_list)args;

// MARK: - Scoped Loggers

/// Create a scoped logger for a specific category
/// @param category Category name
+ (instancetype)loggerWithCategory:(NSString *)category;

/// Log an error in this logger's category
- (void)error:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log a warning in this logger's category
- (void)warning:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log an info message in this logger's category
- (void)info:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log a debug message in this logger's category
- (void)debug:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/// Log a trace message in this logger's category
- (void)trace:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end

// MARK: - Convenience Macros

#define PKLogError(fmt, ...)   [PKLogger logError:fmt, ##__VA_ARGS__]
#define PKLogWarning(fmt, ...) [PKLogger logWarning:fmt, ##__VA_ARGS__]
#define PKLogInfo(fmt, ...)    [PKLogger logInfo:fmt, ##__VA_ARGS__]
#define PKLogDebug(fmt, ...)   [PKLogger logDebug:fmt, ##__VA_ARGS__]
#define PKLogTrace(fmt, ...)   [PKLogger logTrace:fmt, ##__VA_ARGS__]

NS_ASSUME_NONNULL_END
