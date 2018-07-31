#import "MSAssetsLocalPackage.h"
#import "MSAssetsUpdateUtilities+JWT.h"

/**
 * Manager responsible for update read/write actions.
 */
@interface MSAssetsUpdateManager : NSObject

@property (nonatomic, readonly, nullable) MSAssetsUpdateUtilities *updateUtilities;

/**
 * Initializes the manager with the necessary set of utils.
 *
 * @param updateUtilities instance of `MSAssetsUpdateUtilities`.
 * @return manager instance.
 */
- (instancetype)initWithUpdateUtils:(MSAssetsUpdateUtilities *)updateUtilities andBaseDir:(NSString *)baseDir andAppFolder:(NSString *)appName;

/**
 * Gets current package json object.
 *
 * @return current package json object.
*/
- (MSAssetsLocalPackage *)getCurrentPackage:(NSError **)error;

/**
 * Gets previous package json object.
 *
 * @return previous package json object.
*/
- (MSAssetsLocalPackage *)getPreviousPackage:(NSError **)error;

/**
 * Gets the identifier of the current package (hash).
 * @param error read/write error occurred while accessing the file system.
 *
 * @return the identifier of the current package.
 */
- (NSString *)getCurrentPackageHash:(NSError **)error;

/**
 * Gets package object by its hash.
 *
 * @param packageHash package identifier (hash).
 *
 * @return previous package json object.
*/
- (MSAssetsLocalPackage *)getPackage:(NSString *)packageHash
                          error:(NSError **)error;

/**
 * Gets folder for the package by the package hash.
 *
 * @param packageHash current package identifier (hash).
 * @return path to package folder.
 */
- (NSString *)getPackageFolderPath:(NSString *)packageHash;


/**
 * Gets the path for the download file.
 *
 * @return path for the download.
 */
- (NSString *)getDownloadFilePath;

/**
 * Unzips the following package file.
 *
 * @param filePath package file.
 * @param error an error if occurred during unzipping.
 */
- (void)unzipPackage:(NSString *)filePath
               error:(NSError * __autoreleasing *)error;

/**
 * Merges contents with the current update based on the manifest.
 *
 * @param newUpdateFolderPath        directory for new update.
 * @param newUpdateMetadataPath      path to update metadata file for new update.
 * @param newUpdateHash              hash of the new update package.
 * @param publicKeyString            public key used to verify signature.
 *                                   Can be `null` if code signing is not enabled.
 * @param expectedEntryPointFileName file name of the update entry point.
 * @param error error occurred during merging process (can be verification error, file error etc.).
 * @return actual new update entry point.
 */
- (NSString *)mergeDiffWithNewUpdateFolder:(NSString *)newUpdateFolderPath
                     newUpdateMetadataPath:(NSString *)newUpdateMetadataPath
                             newUpdateHash:(NSString *)newUpdateHash
                           publicKeyString:(NSString *)publicKeyString
                expectedEntryPointFileName:(NSString *)expectedEntryPointFileName
                                     error:(NSError * __autoreleasing *)error;

/**
 * Verifies package signature if code signing is enabled.
 *
 * @param newUpdateFolderPath path to the current update.
 * @param publicKey public key used to verify signature.
 *                        Can be `null` if code signing is not enabled.
 * @param newUpdateHash   hash of the update package.
 * @param isDiffUpdate    `true` if this is a diff update, `false` if this is a full update.
 * @return signature verification error (in case signature is invalid or the update didn't pass the verification in any other way).
 */
- (NSError *)verifySignatureForPath:(NSString *)newUpdateFolderPath
                 withPublicKey:(NSString *)publicKey
                 newUpdateHash:(NSString *)newUpdateHash
                    diffUpdate:(BOOL)isDiffUpdate;

/**
 * Installs the new package.
 *
 * @param packageHash         package hash to install.
 * @param removePendingUpdate whether to remove pending updates data.
 * @return error, if occurred, or `nil`.
 */
- (NSError *)installPackage:(NSString *)packageHash
   removePendingUpdate:(BOOL)removePendingUpdate;

/**
 * Gets the path to current update contents.
 * @param updateEntryPath path to the update in package contents, if provided.
 * @return path to current update contents.
 */
-(NSString *)getCurrentUpdatePath:(NSString *)updateEntryPath;

@end
