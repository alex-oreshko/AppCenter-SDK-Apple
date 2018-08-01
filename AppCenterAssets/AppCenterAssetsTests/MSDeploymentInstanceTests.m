#import "MSAssetsDeploymentInstance.h"
#import "MSTestFrameworks.h"
#import "MSAssets.h"
#import "MSLogger.h"
#import "MSAssetsLocalPackage.h"
#import "MSAssetsDelegate.h"
#import "MSDeploymentInstanceTests.h"

@implementation MSDeploymentInstanceTests

- (void)setUp {
    NSError *error = nil;
    self.sut = [[MSAssetsDeploymentInstance alloc]
                initWithEntryPoint:nil
                publicKey:nil
                deploymentKey:kMSDeploymentKey
                inDebugMode:NO
                serverUrl:nil
                baseDir:nil
                appName:nil
                appVersion:nil
                platformInstance:[[MSAssetsiOSSpecificImplementation alloc] init]
                withError:&error];
    id serviceMock = OCMClassMock([MSAssets class]);
    OCMStub(ClassMethod([serviceMock isEnabled])).andReturn(YES);
    if (error) {
        NSLog(@"MSAssetsDeploymentInstance set up for testing failed: %@", [error localizedDescription]);
    }
}

//#pragma MARK: CheckForUpdate tests
- (void)testCheckForUpdateNotCalled {   
    
    // If
    id serviceMock = OCMClassMock([MSAssets class]);
    OCMStub(ClassMethod([serviceMock isEnabled])).andReturn(NO);
    id assetsMock = OCMPartialMock(self.sut);
    OCMReject([assetsMock checkForUpdate:OCMOCK_ANY withCompletionHandler:OCMOCK_ANY]);
    
    // When
    [assetsMock checkForUpdate:kMSDeploymentKey];
    
    // Then
    OCMVerifyAll(assetsMock);
    [assetsMock stopMocking];
}

/**
 * A helper method to test `MSAssetsDeploymentInstance#checkForUpdate`.
 *
 * @param deploymentKey deployment key which will be passed to `checkForUpdate` method.
 * @param localPackage `MSAssetsLocalPackage` instance which, if passed, will be returned in a `getCurrentPackage` method.
 * @param configuration `MSAssetsConfiguration` instance which, if passed, will be returned in a `getConfigurationWithError` method.
 * @param rmPackage `MSAssetsRemotePackage` instance to be returned in a `queryUpdateWithCurrentPackage` callback.
 * @param remoteError error to be returned in a `queryUpdateWithCurrentPackage` callback.
 * @param delegate mocked delegate.
 * Note that if you pass *nonnull* handler below, a `checkForUpdate:withCompletionHandler` call will be made.
 * If you want to verify interactions with the delegate in a simple `checkForUpdate` method, leave handler parameter equal `nil`.
 * @param handler method containing assertions to be made after `checkForUpdate:withCompletionHandler` called its handler.
 */
- (void)checkForUpdateCallWithDeploymentKey: (nullable NSString *)deploymentKey
                            andLocalPackage: (nullable MSAssetsLocalPackage *)localPackage
                                  andConfig: (nullable MSAssetsConfiguration *)configuration
                           andRemotePackage: (nullable MSAssetsRemotePackage *)rmPackage
                             andRemoteError: (nullable NSError *)remoteError
                                andDelegate: (nullable id<MSAssetsDelegate>)delegate
                      andCallbackCompletion: (nullable MSCheckForUpdateCompletionHandler)handler {
    
    // If
    id assetsMock = OCMPartialMock(self.sut);
    if (localPackage == nil) {
        id localMock = OCMClassMock([MSAssetsLocalPackage class]);
        OCMStub(ClassMethod([localMock createLocalPackageWithAppVersion:OCMOCK_ANY])).andReturn(nil);
    }
    OCMStub([assetsMock getCurrentPackage]).andReturn(localPackage);
    OCMStub([assetsMock getConfigurationWithError:(NSError * __autoreleasing *)[OCMArg anyPointer]]).andReturn(configuration);
    id mockSettingManager = OCMClassMock([MSAssetsSettingManager class]);
    OCMStub([mockSettingManager existsFailedUpdate:kMSPackageHash]).andReturn(YES);
    id mockAcquisitionManager = OCMClassMock([MSAssetsAcquisitionManager class]);
    OCMStub([mockAcquisitionManager queryUpdateWithCurrentPackage:localPackage withConfiguration:configuration andCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        MSCheckForUpdateCompletionHandler loadCallback;
        [invocation getArgument:&loadCallback atIndex:4];
        loadCallback(rmPackage, remoteError);
    });
    if (delegate != nil) {
        [assetsMock setDelegate:delegate];
    }
    [assetsMock setAcquisitionManager:mockAcquisitionManager];
    [assetsMock setSettingManager:mockSettingManager];
    XCTestExpectation *expectation = nil;
    if (delegate == nil) {
        expectation = [self expectationWithDescription:@"Completion called"];
    }
    
    // When
    if (delegate != nil && handler == nil) {
        [assetsMock checkForUpdate:deploymentKey];
    } else {
        [assetsMock checkForUpdate:deploymentKey withCompletionHandler:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
            handler(remotePackage, error);
            [expectation fulfill];
        }];
    }
    
    // Then
    if (deploymentKey != nil) {
        OCMVerify([assetsMock setDeploymentKey:deploymentKey]);
    }
    OCMVerify([assetsMock getCurrentPackage]);
    OCMVerify([mockAcquisitionManager queryUpdateWithCurrentPackage:localPackage withConfiguration:configuration andCompletionHandler:OCMOCK_ANY]);
    if (delegate == nil ) {
        [self waitForExpectationsWithTimeout:1 handler:nil];
    }
    [assetsMock stopMocking];
    [mockAcquisitionManager stopMocking];
}

- (void)testCheckForUpdate {
    
    //If
    MSAssetsRemotePackage *rmPackage = [[MSAssetsRemotePackage alloc] init];
    [rmPackage setPackageHash:kMSPackageHash];
    MSAssetsLocalPackage *localPackage = [MSAssetsLocalPackage createLocalPackageWithAppVersion:@"1.6.2"];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    
    [self checkForUpdateCallWithDeploymentKey:kMSDeploymentKey
                              andLocalPackage:localPackage
                                    andConfig:configuration
                             andRemotePackage:rmPackage
                               andRemoteError:nil
                                  andDelegate:nil
                        andCallbackCompletion:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
                            XCTAssertEqualObjects(rmPackage, remotePackage);
                            XCTAssertTrue([remotePackage failedInstall]);
                            XCTAssertNil(error);
                        }];
}

- (void)testCheckForUpdateDelegateOnSuccess {
    
    //If
    MSAssetsRemotePackage *rmPackage = [[MSAssetsRemotePackage alloc] init];
    [rmPackage setPackageHash:kMSPackageHash];
    MSAssetsLocalPackage *localPackage = [MSAssetsLocalPackage createLocalPackageWithAppVersion:@"1.6.2"];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    
    id delegateMock = OCMProtocolMock(@protocol(MSAssetsDelegate));
    OCMStub([delegateMock didReceiveRemotePackageOnCheckForUpdate:rmPackage]);
    
    [self checkForUpdateCallWithDeploymentKey:kMSDeploymentKey
                              andLocalPackage:localPackage
                                    andConfig:configuration
                             andRemotePackage:rmPackage
                               andRemoteError:nil
                                  andDelegate:delegateMock
                        andCallbackCompletion:nil];
    
    //Then
    OCMVerify([delegateMock didReceiveRemotePackageOnCheckForUpdate:rmPackage]);
}

- (void)testCheckForUpdateDelegateOnError {
    
    // If
    NSError *mainError = [[NSError alloc] init];
    MSAssetsLocalPackage *localPackage = [MSAssetsLocalPackage createLocalPackageWithAppVersion:@"1.6.2"];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    
    id delegateMock = OCMProtocolMock(@protocol(MSAssetsDelegate));
    OCMStub([delegateMock didFailToQueryRemotePackageOnCheckForUpdate:OCMOCK_ANY]);
    
    [self checkForUpdateCallWithDeploymentKey:kMSDeploymentKey
                              andLocalPackage:localPackage
                                    andConfig:configuration
                             andRemotePackage:nil
                               andRemoteError:mainError
                                  andDelegate:delegateMock
                        andCallbackCompletion:nil];
    
    //Then
    OCMVerify([delegateMock didFailToQueryRemotePackageOnCheckForUpdate:OCMOCK_ANY]);
}

- (void)testCheckForUpdateDelegateOnBinaryMismatch {
    
    // If
    MSAssetsRemotePackage *rmPackage = [[MSAssetsRemotePackage alloc] init];
    [rmPackage setPackageHash:kMSPackageHash];
    [rmPackage setUpdateAppVersion:YES];
    
    MSAssetsLocalPackage *localPackage = [MSAssetsLocalPackage createLocalPackageWithAppVersion:@"1.6.2"];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    
    id delegateMock = OCMProtocolMock(@protocol(MSAssetsDelegate));
    OCMStub([delegateMock handleBinaryVersionMismatchCallback]);
    
    [self checkForUpdateCallWithDeploymentKey:kMSDeploymentKey
                              andLocalPackage:localPackage
                                    andConfig:configuration
                             andRemotePackage:rmPackage
                               andRemoteError:nil
                                  andDelegate:delegateMock
                        andCallbackCompletion:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
                            XCTAssertNil(error);
                            XCTAssertNil(remotePackage);
                            OCMVerify([delegateMock handleBinaryVersionMismatchCallback]);
                        }];
}

- (void)testCheckForUpdateWithNoLocalPackage {
    
    // If
    MSAssetsRemotePackage *rmPackage = [[MSAssetsRemotePackage alloc] init];
    [rmPackage setPackageHash:kMSPackageHash];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    [configuration setPackageHash:kMSPackageHash];
    
    [self checkForUpdateCallWithDeploymentKey:kMSDeploymentKey
                              andLocalPackage:nil
                                    andConfig:configuration
                             andRemotePackage:rmPackage
                               andRemoteError:nil
                                  andDelegate:nil
                        andCallbackCompletion:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
                            XCTAssertNil(error);
                            XCTAssertNil(remotePackage);
                        }];
    
}

- (void)testCheckForUpdateNoDeploymentKey {
    
    // If
    MSAssetsRemotePackage *rmPackage = [[MSAssetsRemotePackage alloc] init];
    [rmPackage setPackageHash:kMSPackageHash];
    
    MSAssetsLocalPackage *localPackage = [MSAssetsLocalPackage createLocalPackageWithAppVersion:@"1.6.2"];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    [configuration setDeploymentKey:kMSDeploymentKey];
    
    [self checkForUpdateCallWithDeploymentKey:nil
                              andLocalPackage:localPackage
                                    andConfig:configuration
                             andRemotePackage:rmPackage
                               andRemoteError:nil
                                  andDelegate:nil
                        andCallbackCompletion:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
                            XCTAssertEqualObjects(rmPackage, remotePackage);
                            XCTAssertEqualObjects(kMSDeploymentKey, [remotePackage deploymentKey]);
                            XCTAssertTrue([remotePackage failedInstall]);
                            XCTAssertNil(error);
                        }];
}

- (void)testCheckForUpdateQueryCallbackError {
    
    // If
    NSError *mainError = [[NSError alloc] init];
    MSAssetsLocalPackage *localPackage = [MSAssetsLocalPackage createLocalPackageWithAppVersion:@"1.6.2"];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    
    [self checkForUpdateCallWithDeploymentKey:kMSDeploymentKey
                              andLocalPackage:localPackage
                                    andConfig:configuration
                             andRemotePackage:nil
                               andRemoteError:mainError
                                  andDelegate:nil
                        andCallbackCompletion:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
                            XCTAssertEqualObjects(mainError, error);
                            XCTAssertNil(remotePackage);
                        }];
}

- (void)testCheckForUpdateQueryCallbackNil {
    
    // If
    MSAssetsLocalPackage *localPackage = [MSAssetsLocalPackage createLocalPackageWithAppVersion:@"1.6.2"];
    MSAssetsConfiguration *configuration = [[MSAssetsConfiguration alloc] init];
    
    [self checkForUpdateCallWithDeploymentKey:kMSDeploymentKey
                              andLocalPackage:localPackage
                                    andConfig:configuration
                             andRemotePackage:nil
                               andRemoteError:nil
                                  andDelegate:nil
                        andCallbackCompletion:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
                            XCTAssertNil(error);
                            XCTAssertNil(remotePackage);
                        }];
}

- (void)testCheckForUpdateFailsOnConfig {
    
    // If
    id assetsMock = OCMPartialMock(self.sut);
    NSError *configError = [[NSError alloc] init];
    OCMStub([assetsMock getConfigurationWithError:(NSError * __autoreleasing *)[OCMArg setTo:configError]]).andReturn(nil);
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion called"];
    // When
    [assetsMock checkForUpdate:kMSDeploymentKey withCompletionHandler:^(MSAssetsRemotePackage * _Nullable remotePackage, NSError * _Nullable error) {
        XCTAssertNil(remotePackage);
        XCTAssertEqualObjects(configError, error);
        [expectation fulfill];
    }];
    
    // Then
    OCMVerify([assetsMock setDeploymentKey:kMSDeploymentKey]);
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [assetsMock stopMocking];
}

- (void)testInitializeUpdateAfterRestartUpdateStateIsLoading {
    id assetsMock = OCMPartialMock(self.sut);
    
    NSDictionary *dictUpdate = [[NSDictionary alloc] initWithObjectsAndKeys:
                            @YES, @"isLoading",
                            @"hashInfo", @"hash",
                            nil];
    MSAssetsPendingUpdate *pendingUpdate = [[MSAssetsPendingUpdate alloc] initWithDictionary:dictUpdate];
    
    id mockSettingManager = OCMClassMock([MSAssetsSettingManager class]);
    OCMStub([mockSettingManager getPendingUpdate]).andReturn(pendingUpdate);
    [assetsMock setSettingManager:mockSettingManager];
    
    NSDictionary *dictLocalPackage = [[NSDictionary alloc] initWithObjectsAndKeys:
                            @NO, @"isPending",
                            @"entryPointData", @"entryPoint",
                            @NO, @"isFirstRun",
                            @NO, @"_isDebugOnly",
                            @"binaryModifiedTimeData", @"binaryModifiedTime",
                            nil];
    MSAssetsLocalPackage *localPackage = [[MSAssetsLocalPackage alloc] initWithDictionary:dictLocalPackage];
    
    id mockUpdateManager = OCMClassMock([MSAssetsUpdateManager class]);
    OCMStub([mockUpdateManager getCurrentPackage:(NSError * __autoreleasing *)[OCMArg anyPointer]]).andReturn(localPackage);
    OCMStub([assetsMock updateManager]).andReturn(mockUpdateManager);
    
    NSError *error = nil;
    [assetsMock initializeUpdateAfterRestartWithError:&error];
    
    OCMVerify([assetsMock rollbackPackage]);
}

- (void)testInitializeUpdateAfterRestartUpdateStateLoaded {
    id assetsMock = OCMPartialMock(self.sut);
    
    NSDictionary *dictUpdate = [[NSDictionary alloc] initWithObjectsAndKeys:
                                @NO, @"isLoading",
                                @"hashInfo", @"hash",
                                nil];
    MSAssetsPendingUpdate *pendingUpdate = [[MSAssetsPendingUpdate alloc] initWithDictionary:dictUpdate];
    
    id mockSettingManager = OCMClassMock([MSAssetsSettingManager class]);
    OCMStub([mockSettingManager getPendingUpdate]).andReturn(pendingUpdate);
    [assetsMock setSettingManager:mockSettingManager];
    
    NSDictionary *dictLocalPackage = [[NSDictionary alloc] initWithObjectsAndKeys:
                                      @NO, @"isPending",
                                      @"entryPointData", @"entryPoint",
                                      @NO, @"isFirstRun",
                                      @NO, @"_isDebugOnly",
                                      @"binaryModifiedTimeData", @"binaryModifiedTime",
                                      nil];
    MSAssetsLocalPackage *localPackage = [[MSAssetsLocalPackage alloc] initWithDictionary:dictLocalPackage];
    
    id mockUpdateManager = OCMClassMock([MSAssetsUpdateManager class]);
    OCMStub([mockUpdateManager getCurrentPackage:(NSError * __autoreleasing *)[OCMArg anyPointer]]).andReturn(localPackage);
    OCMStub([assetsMock updateManager]).andReturn(mockUpdateManager);
    
    NSError *error = nil;
    [assetsMock initializeUpdateAfterRestartWithError:&error];
    
    XCTAssertTrue([[assetsMock instanceState] didUpdate]);
    OCMVerify([mockSettingManager savePendingUpdate:pendingUpdate]);
}

- (void)testRestartInternal {
    BOOL result = [self.sut restartInternal:^(void){
        XCTAssertTrue(false);
    } onlyIfUpdateIsPending:YES];
    XCTAssertFalse(result);
    
    result = [self.sut restartInternal:^(void){
    } onlyIfUpdateIsPending:NO];
    XCTAssertTrue(result);
    
    id mockSettingManager = OCMClassMock([MSAssetsSettingManager class]);
    OCMStub([mockSettingManager isPendingUpdate:nil]).andReturn(YES);
    [self.sut setSettingManager:mockSettingManager];
    result = [self.sut restartInternal:^(void){
    } onlyIfUpdateIsPending:YES];
    XCTAssertTrue(result);
}


- (void)testGetConfigurationWithError {

    NSString *fakeHash = @"fakeHash";
    
    id assetsMock = OCMPartialMock(self.sut);
    id mockUpdateManager = OCMClassMock([MSAssetsUpdateManager class]);
    OCMStub([mockUpdateManager getCurrentPackageHash:(NSError * __autoreleasing *)[OCMArg anyPointer]]).andReturn(fakeHash);
    OCMStub([assetsMock updateManager]).andReturn(mockUpdateManager);
    
    NSDictionary *infoDictionary = [[NSBundle bundleForClass:[self class]] infoDictionary];
    NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    
    NSError *error;
    MSAssetsConfiguration *configuration = [assetsMock getConfigurationWithError:&error];
    XCTAssertEqualObjects(configuration.appVersion, appVersion);
    XCTAssertEqualObjects(configuration.deploymentKey, kMSDeploymentKey);
    XCTAssertEqualObjects(configuration.packageHash, fakeHash);
    XCTAssertNil(error);
}

- (NSDictionary *)getAssetsPackageDictionary {
    NSDictionary *packageDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 @"1.0", @"appVersion",
                                 @"X0s3Jrpp7TBLmMe5x_UG0b8hf-a8SknGZWL7Q", @"deploymentKey",
                                 @"descriptionText", @"description",
                                 @NO, @"failedInstall",
                                 @NO, @"isMandatory",
                                 @"labelText", @"label",
                                 @"packageHashData", @"packageHash",
                                 nil];
    return packageDict;
}

- (void)testNotifyApplicationReadyNeedToRollback {
    MSAssetsPackage *failedPackage = [[MSAssetsPackage alloc] initWithDictionary:[self getAssetsPackageDictionary]];
    NSMutableArray<MSAssetsPackage *> *failedPackages = [NSMutableArray<MSAssetsPackage *> new];
    [failedPackages addObject:failedPackage];
    id mockSettingManager = OCMClassMock([MSAssetsSettingManager class]);
    OCMStub([mockSettingManager getFailedUpdates]).andReturn(failedPackages);
    id assetsMock = OCMPartialMock(self.sut);
    [assetsMock setSettingManager:mockSettingManager];
    [[assetsMock instanceState] setNeedToReportRollback:YES];
    [assetsMock notifyApplicationReady];
    OCMVerify([assetsMock reportStatus:[OCMArg checkWithBlock:^BOOL(id value) {
        return ([value status] == MSAssetsDeploymentStatusFailed) ? YES : NO;
    }]]);
}

- (void)testNotifyApplicationReadyDidUpdate {
    MSAssetsPackage *package = [[MSAssetsPackage alloc] initWithDictionary:[self getAssetsPackageDictionary]];    id mockUpdateManager = OCMClassMock([MSAssetsUpdateManager class]);
    OCMStub([mockUpdateManager getCurrentPackage:(NSError * __autoreleasing *)[OCMArg anyPointer]]).andReturn(package);
    id assetsMock = OCMPartialMock(self.sut);
    OCMStub([assetsMock updateManager]).andReturn(mockUpdateManager);
    [[assetsMock instanceState] setDidUpdate:YES];
    [assetsMock notifyApplicationReady];
    OCMVerify([assetsMock reportStatus:[OCMArg checkWithBlock:^BOOL(id value) {
        return ([value status] == MSAssetsDeploymentStatusSucceeded) ? YES : NO;
    }]]);
}

- (void)testNotifyApplicationIsRunningBinaryVersion {
    id assetsMock = OCMPartialMock(self.sut);
    [[assetsMock instanceState] setIsRunningBinaryVersion:YES];
    
    NSDictionary *assetsPackage = [self getAssetsPackageDictionary];
    NSDictionary *dictIn = [[NSDictionary alloc] initWithObjectsAndKeys:
                            @"clientUniqueIdData", @"clientUniqueId",
                            @"deploymentKeyData", @"deploymentKey",
                            @"labelData", @"label",
                            @"1.0", @"appVersion",
                            @"previousDeploymentKeyData", @"previousDeploymentKey",
                            @"previousLabelOrAppVersionData", @"previousLabelOrAppVersion",
                            @"DeploymentSucceeded", @"status",
                            assetsPackage, @"package",
                            nil];
        MSAssetsDeploymentStatusReport *deploymentStatusReport = [[MSAssetsDeploymentStatusReport alloc] initWithDictionary:dictIn];
    id mockTelemetryManager = OCMClassMock([MSAssetsTelemetryManager class]);
    OCMStub([mockTelemetryManager buildBinaryUpdateReportWithAppVersion:OCMOCK_ANY]).andReturn(deploymentStatusReport);
    OCMStub([assetsMock telemetryManager]).andReturn(mockTelemetryManager);
    [assetsMock notifyApplicationReady];
    OCMVerify([assetsMock reportStatus:[OCMArg checkWithBlock:^BOOL(id value) {
        return ([[value previousDeploymentKey] isEqualToString:deploymentStatusReport.previousDeploymentKey]) ? YES : NO;
    }]]);}
@end
