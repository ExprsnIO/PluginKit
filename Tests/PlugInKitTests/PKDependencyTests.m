//
//  PKDependencyTests.m
//  PlugInKitTests
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <PlugInKit/PlugInKit.h>

@interface PKDependencyTests : XCTestCase
@property (nonatomic, copy) NSString *tempDir;
@end

@implementation PKDependencyTests

- (void)setUp {
    [super setUp];
    self.tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"PKDepTests-%@", [NSUUID UUID].UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.tempDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:self.tempDir error:NULL];
    [super tearDown];
}

/// Create a minimal plugin bundle on disk with the given dependency entries.
- (void)makeBundleWithIdentifier:(NSString *)identifier
                         version:(NSString *)version
                    requiredPlugins:(nullable NSArray<NSDictionary *> *)requiredPlugins {
    NSString *bundlePath = [self.tempDir stringByAppendingPathComponent:
                            [identifier stringByAppendingPathExtension:@"bundle"]];
    NSString *contentsPath = [bundlePath stringByAppendingPathComponent:@"Contents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:contentsPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    NSMutableDictionary *infoPlist = [@{
        @"CFBundleIdentifier": identifier,
        @"CFBundleName": identifier,
        @"CFBundleShortVersionString": version,
        @"PKXPCServiceName": [identifier stringByAppendingString:@".xpc"],
    } mutableCopy];
    if (requiredPlugins) {
        infoPlist[@"PKRequiredPlugins"] = requiredPlugins;
    }

    NSString *infoPath = [contentsPath stringByAppendingPathComponent:@"Info.plist"];
    [infoPlist writeToFile:infoPath atomically:YES];
}

- (NSArray<PKPlugInInfo *> *)discoverWithManager:(PKPlugInManager *)manager {
    XCTestExpectation *discovered = [self expectationWithDescription:@"discovery"];
    __block NSArray<PKPlugInInfo *> *result = nil;
    [manager discoverPlugInsAtURL:[NSURL fileURLWithPath:self.tempDir]
                       completion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *error) {
        result = plugIns;
        [discovered fulfill];
    }];
    [self waitForExpectations:@[discovered] timeout:5.0];
    return result;
}

- (void)testLinearDependencyChainOrder {
    // A depends on B, B depends on C.
    [self makeBundleWithIdentifier:@"com.test.C" version:@"1.0.0" requiredPlugins:nil];
    [self makeBundleWithIdentifier:@"com.test.B" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.C"}]];
    [self makeBundleWithIdentifier:@"com.test.A" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.B"}]];

    PKPlugInManager *manager = [[PKPlugInManager alloc] init];
    [self discoverWithManager:manager];

    NSError *error = nil;
    NSArray<NSString *> *order = [manager loadOrderForPlugIns:@[@"com.test.A", @"com.test.B", @"com.test.C"]
                                                        error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(order);
    NSUInteger indexA = [order indexOfObject:@"com.test.A"];
    NSUInteger indexB = [order indexOfObject:@"com.test.B"];
    NSUInteger indexC = [order indexOfObject:@"com.test.C"];
    XCTAssertLessThan(indexC, indexB);
    XCTAssertLessThan(indexB, indexA);
}

- (void)testTransitiveDependencyIsIncludedFromSingleRoot {
    [self makeBundleWithIdentifier:@"com.test.C" version:@"1.0.0" requiredPlugins:nil];
    [self makeBundleWithIdentifier:@"com.test.B" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.C"}]];
    [self makeBundleWithIdentifier:@"com.test.A" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.B"}]];

    PKPlugInManager *manager = [[PKPlugInManager alloc] init];
    [self discoverWithManager:manager];

    NSError *error = nil;
    NSArray<NSString *> *order = [manager loadOrderForPlugIns:@[@"com.test.A"] error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(order.count, 3, @"Transitive dependencies should be included");
}

- (void)testCircularDependencyIsDetected {
    [self makeBundleWithIdentifier:@"com.test.A" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.B"}]];
    [self makeBundleWithIdentifier:@"com.test.B" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.A"}]];

    PKPlugInManager *manager = [[PKPlugInManager alloc] init];
    [self discoverWithManager:manager];

    NSError *error = nil;
    NSArray<NSString *> *order = [manager loadOrderForPlugIns:@[@"com.test.A", @"com.test.B"]
                                                        error:&error];
    XCTAssertNil(order);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, PKErrorCircularDependency);
    XCTAssertNotNil(error.userInfo[PKErrorDependencyChainKey]);
}

- (void)testMissingRequiredDependencyFailsResolution {
    [self makeBundleWithIdentifier:@"com.test.A" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.Missing"}]];

    PKPlugInManager *manager = [[PKPlugInManager alloc] init];
    [self discoverWithManager:manager];

    NSError *error = nil;
    NSArray<NSString *> *order = [manager loadOrderForPlugIns:@[@"com.test.A"] error:&error];
    XCTAssertNil(order);
    XCTAssertEqual(error.code, PKErrorMissingDependency);
}

- (void)testMissingOptionalDependencyIsSkipped {
    [self makeBundleWithIdentifier:@"com.test.A" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.Missing", @"optional": @YES}]];

    PKPlugInManager *manager = [[PKPlugInManager alloc] init];
    [self discoverWithManager:manager];

    NSError *error = nil;
    NSArray<NSString *> *order = [manager loadOrderForPlugIns:@[@"com.test.A"] error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(order, @[@"com.test.A"]);
}

- (void)testVersionMismatchFailsRequiredDependency {
    [self makeBundleWithIdentifier:@"com.test.C" version:@"1.0.0" requiredPlugins:nil];
    [self makeBundleWithIdentifier:@"com.test.A" version:@"1.0.0"
                   requiredPlugins:@[@{@"identifier": @"com.test.C", @"minimumVersion": @"2.0.0"}]];

    PKPlugInManager *manager = [[PKPlugInManager alloc] init];
    [self discoverWithManager:manager];

    NSError *error = nil;
    NSArray<NSString *> *order = [manager loadOrderForPlugIns:@[@"com.test.A"] error:&error];
    XCTAssertNil(order);
    XCTAssertEqual(error.code, PKErrorDependencyVersionMismatch);
}

- (void)testDependencyParsedFromInfoPlist {
    [self makeBundleWithIdentifier:@"com.test.C" version:@"1.0.0" requiredPlugins:nil];
    [self makeBundleWithIdentifier:@"com.test.A" version:@"1.0.0"
                   requiredPlugins:@[@{
                       @"identifier": @"com.test.C",
                       @"minimumVersion": @"1.0.0",
                       @"optional": @NO,
                   }]];

    PKPlugInManager *manager = [[PKPlugInManager alloc] init];
    [self discoverWithManager:manager];

    PKPlugInInfo *infoA = [manager plugInInfoForIdentifier:@"com.test.A"];
    XCTAssertEqual(infoA.requiredPlugins.count, 1);
    PKPlugInDependency *dependency = infoA.requiredPlugins.firstObject;
    XCTAssertEqualObjects(dependency.identifier, @"com.test.C");
    XCTAssertEqualObjects(dependency.minimumVersion, @"1.0.0");
    XCTAssertFalse(dependency.isOptional);
}

@end
