#import <XCTest/XCTest.h>
#import "MSTestFrameworks.h"
#import "MSAssetsUpdateManager.h"
#import "MSAssetsSettingManager.h"
#import "MSUtility+File.h"

#define kCurrentPackageHash "cda3a8949bedc4bd4030b6f8121d6b7dd04bbe98868528d9f3c666e3b3da7f4d"
#define kPreviousPackageHash "6e20cce89d39a58041068e1afc998ac2ea1d6f9cf866beea8d34717de8123e5e"
#define kDeploymentKey "X0s3Jrpp7TBLmMe5x_UG0b8hf-a8SknGZWL7Q"

static NSString *const kAppFolder = @"Assets/"kDeploymentKey"";
static NSString *const DownloadFileName = @"download.zip";
static NSString *const StatusFile = @"codepush.json";
static NSString *const UpdateMetadataFile = @"app.json";


@interface MSAssetsUpdateManagerTests : XCTestCase

@property (nonatomic) MSAssetsUpdateManager *sut;
@property id mockSettingManager;
@property id mockUpdateUtils;

@end

@implementation MSAssetsUpdateManagerTests

- (void)setUp {
    [super setUp];
    
    _mockSettingManager = OCMClassMock([MSAssetsSettingManager class]);
    
    _mockUpdateUtils = OCMClassMock([MSAssetsUpdateUtilities class]);
    _mockUpdateUtils = [[MSAssetsUpdateUtilities alloc] initWithSettingManager:_mockSettingManager];
    
    self.sut = [[MSAssetsUpdateManager alloc] initWithUpdateUtils:_mockUpdateUtils andBaseDir:nil andAppFolder:kAppFolder];
    
    const char *strStatusFile = "{\n  \"currentPackage\" : \""kCurrentPackageHash"\",\n  \"previousPackage\" : \""kPreviousPackageHash"\"\n}";
    NSString *statusFileText = [[NSString alloc] initWithCString:strStatusFile encoding:NSUTF8StringEncoding];
    [self createFile:StatusFile inPath:kAppFolder withText:statusFileText];
    
    const char *strCurrentUpdateMetadata = "{\n  \"_isDebugOnly\" : false,\n  \"appVersion\" : \"1.6.2\",\n  \"binaryModifiedTime\" : \"1533114348351\",\n  \"packageHash\" :  \""kCurrentPackageHash"\",\n  \"isPending\" : true,\n  \"deploymentKey\" : \""kDeploymentKey"\",\n  \"label\" : \"v33\",\n  \"isFirstRun\" : false,\n  \"failedInstall\" : false,\n  \"isMandatory\" : false\n}";
    NSString *currentUpdateMetadata = [[NSString alloc] initWithCString:strCurrentUpdateMetadata encoding:NSUTF8StringEncoding];
    [self createFile:UpdateMetadataFile inPath:[kAppFolder stringByAppendingPathComponent:@kCurrentPackageHash] withText:currentUpdateMetadata];
    
    const char *strPreviousUpdateMetadata = "{\n  \"_isDebugOnly\" : false,\n  \"appVersion\" : \"1.6.2\",\n  \"binaryModifiedTime\" : \"1533042551596\",\n  \"packageHash\" :  \""kPreviousPackageHash"\",\n  \"isPending\" : true,\n  \"deploymentKey\" : \""kDeploymentKey"\",\n  \"label\" : \"v32\",\n  \"isFirstRun\" : false,\n  \"failedInstall\" : false,\n  \"isMandatory\" : false\n}";
    NSString *previousUpdateMetadata = [[NSString alloc] initWithCString:strPreviousUpdateMetadata encoding:NSUTF8StringEncoding];
    [self createFile:UpdateMetadataFile inPath:[kAppFolder stringByAppendingPathComponent:@kPreviousPackageHash] withText:previousUpdateMetadata];
    
}

- (void)tearDown {
    [super tearDown];
    [MSUtility deleteItemForPathComponent:kAppFolder];
}

- (void)createFile:(NSString *)fileName inPath:(NSString *)path withText:(NSString *)text {
    [MSUtility createFileAtPathComponent:[path stringByAppendingPathComponent:fileName] withData:[text dataUsingEncoding:NSUTF8StringEncoding] atomically:YES forceOverwrite:YES];
}

- (void)testMSAssetsUpdateManagerInitialization {
    XCTAssertNotNil(self.sut);
}

- (void)testGetDownloadFilePath {
    NSString *expectedPath = [kAppFolder stringByAppendingPathComponent:DownloadFileName];
    NSString *path = [self.sut getDownloadFilePath];
    XCTAssertNotNil(path);
    XCTAssertEqualObjects(expectedPath, path);
}

- (void)testGetCurrentPackage {
    NSError *error = nil;
    MSAssetsLocalPackage *currentPackage = [self.sut getCurrentPackage:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(currentPackage);
    XCTAssertEqualObjects(currentPackage.deploymentKey, @kDeploymentKey);
    XCTAssertEqualObjects(currentPackage.packageHash, @kCurrentPackageHash);
}

- (void)testGetPreviousPackage {
    NSError *error = nil;
    MSAssetsLocalPackage *previousPackage = [self.sut getPreviousPackage:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(previousPackage);
    XCTAssertEqualObjects(previousPackage.deploymentKey, @kDeploymentKey);
    XCTAssertEqualObjects(previousPackage.packageHash, @kPreviousPackageHash);
}

- (void)testGetCurrentPackageHash {
    NSError *error = nil;
    NSString *hash = [self.sut getCurrentPackageHash:&error];
    XCTAssertEqualObjects(hash, @kCurrentPackageHash);
    XCTAssertNil(error);
}

-(void)testGetPackageWithWrongHash {
    NSError *error = nil;
    MSAssetsLocalPackage *package = [self.sut getPackage:@"wrongHash" error:&error];
    XCTAssertNil(package);
    XCTAssertNil(error); // Should we create error if package not found?
}

-(void)testGetPackageWithCurrentPackageHash {
    NSError *error = nil;
    MSAssetsLocalPackage *package = [self.sut getPackage:@kCurrentPackageHash error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(package);
    XCTAssertEqualObjects(package.deploymentKey, @kDeploymentKey);
    XCTAssertEqualObjects(package.packageHash, @kCurrentPackageHash);
}

-(void)testGetPackageWithPreviousPackageHash {
    NSError *error = nil;
    MSAssetsLocalPackage *package = [self.sut getPackage:@kPreviousPackageHash error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(package);
    XCTAssertEqualObjects(package.deploymentKey, @kDeploymentKey);
    XCTAssertEqualObjects(package.packageHash, @kPreviousPackageHash);
}

- (void)testGetPackageFolderPath {
    NSString *expectedPath = [kAppFolder stringByAppendingPathComponent:@kCurrentPackageHash];
    NSString *path = [self.sut getPackageFolderPath:@kCurrentPackageHash];
    XCTAssertEqualObjects(path, expectedPath);
}


@end
