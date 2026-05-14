//
//  PKPlugInStateTests.m
//  PlugInKitTests
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <PlugInKit/PlugInKit.h>

@interface PKPlugInStateTests : XCTestCase
@end

@implementation PKPlugInStateTests

- (void)testInitializerPopulatesProperties {
    NSDictionary *payload = @{@"count": @42, @"name": @"alpha"};
    PKPlugInState *state = [[PKPlugInState alloc] initWithIdentifier:@"com.example.plugin"
                                                            version:@"1.2.3"
                                                            payload:payload];

    XCTAssertEqualObjects(state.identifier, @"com.example.plugin");
    XCTAssertEqualObjects(state.version, @"1.2.3");
    XCTAssertEqualObjects(state.payload, payload);
    XCTAssertNotNil(state.capturedAt);
}

- (void)testNilPayloadBecomesEmptyDictionary {
    PKPlugInState *state = [[PKPlugInState alloc] initWithIdentifier:@"id"
                                                            version:@"1.0"
                                                            payload:nil];
    XCTAssertEqualObjects(state.payload, @{});
}

- (void)testSecureCodingRoundTrip {
    NSDictionary *payload = @{
        @"int": @7,
        @"string": @"hello",
        @"array": @[@1, @2, @3],
        @"nested": @{@"key": @"value"},
    };
    PKPlugInState *original = [[PKPlugInState alloc] initWithIdentifier:@"com.example.roundtrip"
                                                               version:@"2.0.0"
                                                               payload:payload];

    NSError *encodeError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original
                                        requiringSecureCoding:YES
                                                        error:&encodeError];
    XCTAssertNil(encodeError);
    XCTAssertNotNil(data);

    NSError *decodeError = nil;
    PKPlugInState *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[PKPlugInState class]
                                                              fromData:data
                                                                 error:&decodeError];
    XCTAssertNil(decodeError);
    XCTAssertEqualObjects(decoded.identifier, original.identifier);
    XCTAssertEqualObjects(decoded.version, original.version);
    XCTAssertEqualObjects(decoded.payload, original.payload);
    XCTAssertEqualObjects(decoded, original);
}

- (void)testSupportsSecureCoding {
    XCTAssertTrue([PKPlugInState supportsSecureCoding]);
}

@end
