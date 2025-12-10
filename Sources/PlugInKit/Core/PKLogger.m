//
//  PKLogger.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKLogger.h"

static PKLogLevel _globalLogLevel = PKLogLevelInfo;
static BOOL _usesUnifiedLogging = YES;
static BOOL _logsToStderr = NO;
static PKLogHandler _customLogHandler = nil;
static os_log_t _defaultLog = nil;
static NSString *const PKLogSubsystem = @"com.pluginkit";

@interface PKLogger ()
@property (nonatomic, copy) NSString *category;
@property (nonatomic, strong) os_log_t osLog;
@end

@implementation PKLogger

+ (void)initialize {
    if (self == [PKLogger class]) {
        _defaultLog = os_log_create(PKLogSubsystem.UTF8String, "default");
    }
}

// MARK: - Class Properties

+ (PKLogLevel)logLevel {
    return _globalLogLevel;
}

+ (void)setLogLevel:(PKLogLevel)logLevel {
    _globalLogLevel = logLevel;
}

+ (BOOL)usesUnifiedLogging {
    return _usesUnifiedLogging;
}

+ (void)setUsesUnifiedLogging:(BOOL)usesUnifiedLogging {
    _usesUnifiedLogging = usesUnifiedLogging;
}

+ (BOOL)logsToStderr {
    return _logsToStderr;
}

+ (void)setLogsToStderr:(BOOL)logsToStderr {
    _logsToStderr = logsToStderr;
}

+ (PKLogHandler)customLogHandler {
    return _customLogHandler;
}

+ (void)setCustomLogHandler:(PKLogHandler)customLogHandler {
    _customLogHandler = [customLogHandler copy];
}

// MARK: - Global Logging Methods

+ (void)logError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:PKLogLevelError category:@"General" format:format args:args];
    va_end(args);
}

+ (void)logWarning:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:PKLogLevelWarning category:@"General" format:format args:args];
    va_end(args);
}

+ (void)logInfo:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:PKLogLevelInfo category:@"General" format:format args:args];
    va_end(args);
}

+ (void)logDebug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:PKLogLevelDebug category:@"General" format:format args:args];
    va_end(args);
}

+ (void)logTrace:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:PKLogLevelTrace category:@"General" format:format args:args];
    va_end(args);
}

+ (void)log:(PKLogLevel)level category:(NSString *)category format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:level category:category format:format args:args];
    va_end(args);
}

+ (void)log:(PKLogLevel)level
   category:(NSString *)category
     format:(NSString *)format
       args:(va_list)args {

    // Check if we should log at this level
    if (level > _globalLogLevel) {
        return;
    }

    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];

    // Custom handler
    if (_customLogHandler) {
        _customLogHandler(level, PKLogSubsystem, category, message);
    }

    // Unified logging
    if (_usesUnifiedLogging) {
        os_log_t log = os_log_create(PKLogSubsystem.UTF8String, category.UTF8String);
        os_log_type_t osLogType = [self osLogTypeForLevel:level];
        os_log_with_type(log, osLogType, "%{public}s", message.UTF8String);
    }

    // stderr logging
    if (_logsToStderr) {
        NSString *levelString = [self stringForLevel:level];
        NSString *timestamp = [self currentTimestamp];
        fprintf(stderr, "[%s] [%s] [%s] %s\n",
                timestamp.UTF8String,
                levelString.UTF8String,
                category.UTF8String,
                message.UTF8String);
    }
}

// MARK: - Scoped Loggers

+ (instancetype)loggerWithCategory:(NSString *)category {
    PKLogger *logger = [[PKLogger alloc] init];
    logger.category = category;
    logger.osLog = os_log_create(PKLogSubsystem.UTF8String, category.UTF8String);
    return logger;
}

- (void)error:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self class] log:PKLogLevelError category:self.category format:format args:args];
    va_end(args);
}

- (void)warning:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self class] log:PKLogLevelWarning category:self.category format:format args:args];
    va_end(args);
}

- (void)info:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self class] log:PKLogLevelInfo category:self.category format:format args:args];
    va_end(args);
}

- (void)debug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self class] log:PKLogLevelDebug category:self.category format:format args:args];
    va_end(args);
}

- (void)trace:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self class] log:PKLogLevelTrace category:self.category format:format args:args];
    va_end(args);
}

// MARK: - Helpers

+ (os_log_type_t)osLogTypeForLevel:(PKLogLevel)level {
    switch (level) {
        case PKLogLevelError:
            return OS_LOG_TYPE_ERROR;
        case PKLogLevelWarning:
            return OS_LOG_TYPE_DEFAULT;
        case PKLogLevelInfo:
            return OS_LOG_TYPE_INFO;
        case PKLogLevelDebug:
            return OS_LOG_TYPE_DEBUG;
        case PKLogLevelTrace:
            return OS_LOG_TYPE_DEBUG;
    }
}

+ (NSString *)stringForLevel:(PKLogLevel)level {
    switch (level) {
        case PKLogLevelError:   return @"ERROR";
        case PKLogLevelWarning: return @"WARN ";
        case PKLogLevelInfo:    return @"INFO ";
        case PKLogLevelDebug:   return @"DEBUG";
        case PKLogLevelTrace:   return @"TRACE";
    }
}

+ (NSString *)currentTimestamp {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });
    return [formatter stringFromDate:[NSDate date]];
}

@end
