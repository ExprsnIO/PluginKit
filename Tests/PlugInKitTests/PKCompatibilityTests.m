//
//  PKCompatibilityTests.m
//  PlugInKitTests
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <PlugInKit/PlugInKit.h>

@interface PKCompatibilityTests : XCTestCase
@end

@implementation PKCompatibilityTests

- (void)testCompareVersionEqual {
    XCTAssertEqual([PKPlugInManager compareVersion:@"1.2.3" toVersion:@"1.2.3"], NSOrderedSame);
}

- (void)testCompareVersionAscending {
    XCTAssertEqual([PKPlugInManager compareVersion:@"1.2.0" toVersion:@"1.2.3"], NSOrderedAscending);
    XCTAssertEqual([PKPlugInManager compareVersion:@"1.0.0" toVersion:@"2.0.0"], NSOrderedAscending);
}

- (void)testCompareVersionDescending {
    XCTAssertEqual([PKPlugInManager compareVersion:@"2.0.0" toVersion:@"1.9.9"], NSOrderedDescending);
    XCTAssertEqual([PKPlugInManager compareVersion:@"1.2.10" toVersion:@"1.2.9"], NSOrderedDescending);
}

- (void)testCompareVersionDifferentComponentCounts {
    XCTAssertEqual([PKPlugInManager compareVersion:@"1.2" toVersion:@"1.2.0"], NSOrderedSame);
    XCTAssertEqual([PKPlugInManager compareVersion:@"1.2" toVersion:@"1.2.1"], NSOrderedAscending);
}

- (void)testVersionCompatibleWithinRange {
    XCTAssertTrue([PKPlugInManager isVersion:@"1.5.0" compatibleWithMinimum:@"1.0.0" maximum:@"2.0.0"]);
    XCTAssertTrue([PKPlugInManager isVersion:@"1.0.0" compatibleWithMinimum:@"1.0.0" maximum:nil]);
}

- (void)testVersionBelowMinimumIsIncompatible {
    XCTAssertFalse([PKPlugInManager isVersion:@"0.9.0" compatibleWithMinimum:@"1.0.0" maximum:nil]);
}

- (void)testVersionAboveMaximumIsIncompatible {
    XCTAssertFalse([PKPlugInManager isVersion:@"2.1.0" compatibleWithMinimum:nil maximum:@"2.0.0"]);
}

@end
