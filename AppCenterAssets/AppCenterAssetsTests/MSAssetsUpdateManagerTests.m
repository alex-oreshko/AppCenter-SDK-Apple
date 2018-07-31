#import <XCTest/XCTest.h>
#import "MSTestFrameworks.h"
#import "MSAssetsUpdateManager.h"
#import "MSAssetsSettingManager.h"

static NSString *const kAppName = @"Assets";
static NSString *const DownloadFileName = @"download.zip";


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
    
    self.sut = [[MSAssetsUpdateManager alloc] initWithUpdateUtils:_mockUpdateUtils andBaseDir:nil andAppFolder:kAppName];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMSAssetsUpdateManagerInitialization {
    XCTAssertNotNil(self.sut);
}

- (void)testGetDownloadFilePath {
    NSString *expectedPath = [kAppName stringByAppendingPathComponent:DownloadFileName];
    NSString *path = [self.sut getDownloadFilePath];
    XCTAssertNotNil(path);
    XCTAssertEqualObjects(expectedPath, path);
}

- (void)testGetCurrentPackageHash {
    NSError *error = nil;
    NSString *hash = [self.sut getCurrentPackageHash:&error];
    XCTAssertNotNil(hash);
}


@end
