#import "MSAssetsUpdateUtilities+JWT.h"
#import "MSAssetsUpdateManager.h"
#import "MSAssetsDelegate.h"
#import "MSAssetsLocalPackage.h"
#import "MSAssetsDeploymentInstanceState.h"
#import "MSAssetsDownloadHandler.h"
#import "MSAssetsAcquisitionManager.h"
#import "MSAssetsSettingManager.h"
#import "MSAssetsTelemetryManager.h"
#import "MSAssetsInstallMode.h"
#import "MSAssetsRestartManager.h"
#import "MSAssetsSyncOptions.h"
#import "MSAssetsiOSSpecificImplementation.h"

typedef void(^MSAssetsSyncBlock)();
typedef void(^MSAssetsInstallCompleteBlock)();
typedef void(^MSAssetsDownloadSuccessBlock)(NSError*, NSDictionary*);
typedef void(^MSAssetsDownloadFailBlock)(NSError*);

NS_ASSUME_NONNULL_BEGIN

/**
 * A handler for delivering the download results.
 *
 * @param downloadedPackage an instance of downloaded `MSAssetsLocalPackage`.
 * Can be `nil` in case of download error.
 * @param error download error, if occurred.
 */
typedef void (^MSAssetsPackageDownloadHandler)(MSAssetsLocalPackage * _Nullable downloadedPackage, NSError * _Nullable error);


/**
 * A handler to deliver error that occured during downloading+installing a package.
 *
 * @param error error or `nil`.
 */
typedef void (^MSAssetsDownloadInstallHandler)(NSError * _Nullable error);

@interface MSAssetsDeploymentInstance: NSObject

/**
 * Asks the Assets service whether the configured app deployment has an update available
 * using specified deployment key.
 *
 * @param deploymentKey deployment key to use.
 * @see `MSAssetsDelegate->didReceiveRemotePackageOnCheckForUpdate`.
 */
- (void)checkForUpdate:(nullable NSString *)deploymentKey;

/**
 * Performs just the restart itself.
 *
 * @param onlyIfUpdateIsPending restart only if update is pending or unconditionally.
 * @param assetsRestartListener listener to notify that the application has restarted.
 * @return `true` if restarted successfully.
 */
- (BOOL)restartInternal:(MSAssetsRestartListener)assetsRestartListener onlyIfUpdateIsPending:(BOOL)onlyIfUpdateIsPending;

/**
 * Creates instance of `MSAssetsDeploymentInstance`. Default constructor.
 *
 * @param deploymentKey      deployment key.
 * @param isDebugMode        indicates whether application is running in debug mode.
 * @param serverUrl          CodePush server url.
 * @param publicKey  public key string.
 * @param entryPoint path to update contents/bundles.
 * @param platformInstance  instance of a class conforming to `MSAssetsPlatformSpecificImplementation`
 * and containing platform-specific methods.
 * @see `MSAssetsiOSSpecificImplementation`.
 * @param error initialization error.
 */
- (instancetype)initWithEntryPoint:(NSString *)entryPoint
                         publicKey:(NSString *)publicKey
                     deploymentKey:(NSString *)deploymentKey
                       inDebugMode:(BOOL)isDebugMode
                         serverUrl:(NSString *)serverUrl
                  platformInstance:(id<MSAssetsPlatformSpecificImplementation>)platformInstance
                         withError:(NSError *__autoreleasing *)error;

- (void) doDownloadAndInstall:(MSAssetsRemotePackage *)remotePackage
                  syncOptions:(MSAssetsSyncOptions *)syncOptions
                configuration:(MSAssetsConfiguration *)configuration
                      handler:(MSAssetsDownloadInstallHandler)handler;

/**
 * Gets native Assets configuration.
 *
 * @return native Assets configuration.
 */
- (MSAssetsConfiguration *)getConfigurationWithError:(NSError * __autoreleasing*)error;

- (NSString *)getCurrentUpdateEntryPoint;
- (void) notifyApplicationReady;
- (void)sync:(MSAssetsSyncOptions *)syncOptions;

@property (nonatomic, copy, nonnull) NSString *deploymentKey;
@property (nonatomic, copy, nonnull) NSString *serverUrl;
//@property (nonatomic, copy, nullable) NSString *updateSubFolder;
@property (nonatomic, nullable) MSAssetsDeploymentInstanceState *instanceState;

@property (nonatomic) id<MSAssetsDelegate> delegate;

@property (nonatomic, nonnull) id<MSAssetsPlatformSpecificImplementation> platformInstance;
@property (nonatomic, copy, readonly) MSAssetsTelemetryManager *telemetryManager;
@property (nonatomic, nullable) MSAssetsDownloadHandler *downloadHandler;
@property (nonatomic, readonly, nullable) MSAssetsUpdateUtilities *updateUtilities;
@property (nonatomic, readonly) MSAssetsUpdateManager *updateManager;
@property (nonatomic, readonly) MSAssetsAcquisitionManager *acquisitionManager;
@property (nonatomic, readonly) MSAssetsSettingManager *settingManager;
@property (nonatomic, readonly) MSAssetsRestartManager *restartManager;

@end

NS_ASSUME_NONNULL_END
