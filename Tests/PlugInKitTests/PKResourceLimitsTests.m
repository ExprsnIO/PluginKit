//
//  PKResourceLimitsTests.m
//  PlugInKitTests
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <PlugInKit/PlugInKit.h>

@interface PKResourceLimitsTests : XCTestCase
@end

@implementation PKResourceLimitsTests

- (PKConnection *)makeConnection {
    NSXPCInterface *interface = [NSXPCInterface interfaceWithProtocol:@protocol(PKPlugInProtocol)];
    return [[PKConnection alloc] initWithPlugInIdentifier:@"com.test.resourcelimits"
                                             serviceName:@"com.test.nonexistent.xpc"
                                               interface:interface];
}

- (void)testDefaultLimitsAreUnbounded {
    PKConnection *connection = [self makeConnection];
    XCTAssertEqual(connection.maxConcurrentOperations, NSUIntegerMax);
    XCTAssertEqual(connection.maxQueuedMessages, NSUIntegerMax);
    XCTAssertEqual(connection.operationTimeout, 0.0);
    XCTAssertEqual(connection.currentQueueDepth, 0);
}

- (void)testLimitsAreClampedToAtLeastOne {
    PKConnection *connection = [self makeConnection];
    connection.maxConcurrentOperations = 0;
    connection.maxQueuedMessages = 0;
    XCTAssertEqual(connection.maxConcurrentOperations, 1);
    XCTAssertEqual(connection.maxQueuedMessages, 1);
}

- (void)testQueueFullRejectsOperationsOverCapacity {
    PKConnection *connection = [self makeConnection];
    connection.maxConcurrentOperations = 1;
    connection.maxQueuedMessages = 1;  // total capacity = 2

    // Operation 1 occupies the single concurrency slot and never finishes.
    [connection performGovernedOperation:^(id<PKPlugInProtocol> plugin, void (^done)(void)) {
        // Intentionally hold the slot for the duration of the test.
    } completion:^(NSError * _Nullable error) {}];

    // Operation 2 occupies the single queue slot.
    [connection performGovernedOperation:^(id<PKPlugInProtocol> plugin, void (^done)(void)) {
        // Intentionally never finishes.
    } completion:^(NSError * _Nullable error) {}];

    // Operation 3 exceeds capacity and must be rejected synchronously.
    XCTestExpectation *rejected = [self expectationWithDescription:@"queue full rejection"];
    [connection performGovernedOperation:^(id<PKPlugInProtocol> plugin, void (^done)(void)) {
        XCTFail(@"Operation 3 should not run");
    } completion:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, PKErrorDomain);
        XCTAssertEqual(error.code, PKErrorQueueFull);
        [rejected fulfill];
    }];

    [self waitForExpectations:@[rejected] timeout:2.0];
}

- (void)testNilOperationBlockReturnsInvalidArgument {
    PKConnection *connection = [self makeConnection];
    XCTestExpectation *rejected = [self expectationWithDescription:@"invalid argument"];
    [connection performGovernedOperation:nil completion:^(NSError * _Nullable error) {
        XCTAssertEqual(error.code, PKErrorInvalidArgument);
        [rejected fulfill];
    }];
    [self waitForExpectations:@[rejected] timeout:1.0];
}

@end
