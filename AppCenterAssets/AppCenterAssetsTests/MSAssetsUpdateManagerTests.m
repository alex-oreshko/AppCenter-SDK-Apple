#import <XCTest/XCTest.h>
#import "MSTestFrameworks.h"
#import "MSAssetsUpdateManager.h"
#import "MSAssetsSettingManager.h"
#import "MSUtility+File.h"
#import "MSAssetsErrors.h"

#define kAppName "Assets"
#define kPreviousPackageHash "cda3a8949bedc4bd4030b6f8121d6b7dd04bbe98868528d9f3c666e3b3da7f4d"
#define kCurrentPackageHash "6e20cce89d39a58041068e1afc998ac2ea1d6f9cf866beea8d34717de8123e5e"
#define kUpdatePackageHash "dfefbba8dd9e1b651f038e9b50a0a2754b134157f2640e9a2a4d026494e11959"
#define kDeploymentKey "X0s3Jrpp7TBLmMe5x_UG0b8hf-a8SknGZWL7Q"

static NSString *const kAppFolder = @""kAppName"/"kDeploymentKey"";
static NSString *const kAssetsSampleDataZip = @"AssetsSampleData.zip";
static NSString *const DownloadFileName = @"download.zip";
static NSString *const StatusFile = @"codepush.json";
static NSString *const UpdateMetadataFile = @"app.json";
static NSString *const UnzippedFolderName = @"unzipped";
static NSString *const DiffManifestFileName = @"hotcodepush.json";


@interface MSAssetsUpdateManagerTests : XCTestCase

@property (nonatomic) MSAssetsUpdateManager *sut;
@property id mockSettingManager;
@property id mockUpdateUtils;
@property NSString *fullAssetsPath;

@end


@implementation MSAssetsUpdateManagerTests

- (void)setUp {
    [super setUp];
    
    _mockSettingManager = OCMClassMock([MSAssetsSettingManager class]);
    
    _mockUpdateUtils = OCMClassMock([MSAssetsUpdateUtilities class]);
    _mockUpdateUtils = [[MSAssetsUpdateUtilities alloc] initWithSettingManager:_mockSettingManager];
    
    self.sut = [[MSAssetsUpdateManager alloc] initWithUpdateUtils:_mockUpdateUtils andBaseDir:nil andAppFolder:kAppFolder];
    
    // Here we unzip our sample data. This is a copy of MSAssets folder for real sample app Puppet
    NSString* zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AssetsSampleData" ofType:@"zip"];
    NSData *data = [NSData dataWithContentsOfFile:zipPath];
    [self createFile:kAssetsSampleDataZip inPath:@"" withData:data];
    BOOL result = [MSUtility unzipFileAtPathComponent:kAssetsSampleDataZip toPathComponent:@""];
    if (!result)
        NSLog(@"Error during set up for MSAssetsUpdateManager tests");
    [MSUtility deleteItemForPathComponent:kAssetsSampleDataZip];
    [MSUtility deleteItemForPathComponent:@"__MACOSX"];
    if (!result)
        NSLog(@"Error during set up for MSAssetsUpdateManager tests");

}

- (void)tearDown {
    [super tearDown];
    [MSUtility deleteItemForPathComponent:@kAppName];
}

- (void)createFile:(NSString *)fileName inPath:(NSString *)path withText:(NSString *)text {
    [MSUtility createFileAtPathComponent:[path stringByAppendingPathComponent:fileName] withData:[text dataUsingEncoding:NSUTF8StringEncoding] atomically:YES forceOverwrite:YES];
}

- (void)createFile:(NSString *)fileName inPath:(NSString *)path withData:(NSData *)data {
    [MSUtility createFileAtPathComponent:[path stringByAppendingPathComponent:fileName] withData:data atomically:YES forceOverwrite:YES];
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

- (void)testUnzipPackageNoFile {
    NSError *error = nil;
    [self.sut unzipPackage:@"noSuchFile" error:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kMSACFileErrorCode);
}

- (void)testUnzipPackage {
    NSError *error = nil;
    NSString *unzippedPath = [kAppFolder stringByAppendingPathComponent:UnzippedFolderName];
    [self.sut unzipPackage:[kAppFolder stringByAppendingPathComponent:DownloadFileName] error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:unzippedPath]);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:[unzippedPath stringByAppendingPathComponent:DiffManifestFileName]]);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:[unzippedPath stringByAppendingPathComponent:@"cp_assets"]]);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:[unzippedPath stringByAppendingPathComponent:@"cp_assets/square.png"]]);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:[unzippedPath stringByAppendingPathComponent:@"cp_assets/square-.png"]]);
}

- (void)testMergeDiffWithNewUpdateWrongHash {
    // prepare data to merge
    NSError *error = nil;
    NSString *unzippedPath = [kAppFolder stringByAppendingPathComponent:UnzippedFolderName];
    [self.sut unzipPackage:[kAppFolder stringByAppendingPathComponent:DownloadFileName] error:&error];
    NSString *packageHash = @"fakeHash";
    NSString *newUpdateFolderPath = [self.sut getPackageFolderPath:packageHash];
    NSString *newUpdateMetadataPath = [newUpdateFolderPath stringByAppendingPathComponent:UpdateMetadataFile];
    
    // merging data
    NSString *entryPoint = [self.sut mergeDiffWithNewUpdateFolder:newUpdateFolderPath newUpdateMetadataPath:newUpdateMetadataPath newUpdateHash:packageHash publicKeyString:nil expectedEntryPointFileName:nil error:&error];
    
    // check results
    XCTAssertNil(entryPoint);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kMSACSignatureVerificationErrorCode);
}

- (void)testMergeDiffWithNewUpdate {
    // prepare data to merge
    NSError *error = nil;
    NSString *unzippedPath = [kAppFolder stringByAppendingPathComponent:UnzippedFolderName];
    [self.sut unzipPackage:[kAppFolder stringByAppendingPathComponent:DownloadFileName] error:&error];
    NSString *newUpdateFolderPath = [self.sut getPackageFolderPath:@kUpdatePackageHash];
    NSString *newUpdateMetadataPath = [newUpdateFolderPath stringByAppendingPathComponent:UpdateMetadataFile];
    
    // merging data
    NSString *entryPoint = [self.sut mergeDiffWithNewUpdateFolder:newUpdateFolderPath newUpdateMetadataPath:newUpdateMetadataPath newUpdateHash:@kUpdatePackageHash publicKeyString:nil expectedEntryPointFileName:nil error:&error];
    
    
    // check results
    XCTAssertNil(entryPoint);
    XCTAssertNil(error);
    NSString *updatePath = [kAppFolder stringByAppendingPathComponent:@kUpdatePackageHash];
    XCTAssertTrue([MSUtility fileExistsForPathComponent:updatePath]);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:[updatePath stringByAppendingPathComponent:@"cp_assets"]]);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:[updatePath stringByAppendingPathComponent:@"cp_assets/square.png"]]);
    XCTAssertTrue([MSUtility fileExistsForPathComponent:[updatePath stringByAppendingPathComponent:@"cp_assets/square-.png"]]);
}

- (void)testInstallPackage {
    // prepare package to install
    NSError *error = nil;
    NSString *unzippedPath = [kAppFolder stringByAppendingPathComponent:UnzippedFolderName];
    [self.sut unzipPackage:[kAppFolder stringByAppendingPathComponent:DownloadFileName] error:&error];
    NSString *newUpdateFolderPath = [self.sut getPackageFolderPath:@kUpdatePackageHash];
    NSString *newUpdateMetadataPath = [newUpdateFolderPath stringByAppendingPathComponent:UpdateMetadataFile];
    NSString *entryPoint = [self.sut mergeDiffWithNewUpdateFolder:newUpdateFolderPath newUpdateMetadataPath:newUpdateMetadataPath newUpdateHash:@kUpdatePackageHash publicKeyString:nil expectedEntryPointFileName:nil error:&error];
    
    // installing package
    error = [self.sut installPackage:@kUpdatePackageHash removePendingUpdate:NO];
    XCTAssertNil(error);
    
    // check if previous package deleted
    XCTAssertFalse([MSUtility fileExistsForPathComponent:[kAppFolder stringByAppendingPathComponent:@kPreviousPackageHash]]);
    
    // check if previous package has changed status from current to previous
    MSAssetsLocalPackage *previousPackage = [self.sut getPreviousPackage:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(previousPackage);
    XCTAssertEqualObjects(previousPackage.packageHash, @kCurrentPackageHash);
    
    // check if update package has become current package
    NSString *currentPackageHash = [self.sut getCurrentPackageHash:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(currentPackageHash, @kUpdatePackageHash);
}


@end
