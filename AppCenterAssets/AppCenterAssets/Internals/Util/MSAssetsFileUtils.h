#import <Foundation/Foundation.h>

@interface MSAssetsFileUtils : NSObject


/**
 * Gets files from archive.
 *
 * @param path path to zip-archive.
 * @param destination path for the unzipped files to be saved.
 * @return A flag indicating success or fail.
 */
+ (BOOL)unzipFileAtPath:(NSString *)path toDestination:(NSString *)destination;


/**
 * Copies the contents of one directory to another. Copies all the contents recursively.
 *
 * @param sourceDir path to the directory to copy files from.
 * @param destDir   path to the directory to copy files to.
 * @return A flag indicating success or fail.
 */
+ (BOOL)copyDirectoryContents:(NSString *)sourceDir toDestination:(NSString *)destDir;


/**
 * Moves file from one folder to another.
 *
 * @param fileToMove  path to the file to be moved.
 * @param newFolder   path to be moved to.
 * @param newFileName new name for the file to be moved.
 * @return A flag indicating success or fail.
 */
+ (BOOL)moveFile:(NSString *)fileToMove toFolder:(NSString *)newFolder withNewName:(NSString*)newFileName;

/**
 * Reads the contents of file to a string.
 *
 * @param filePath path to file to be read.
 * @return string with contents of the file.
 */
+ (NSString *)readFileToString:(NSString *)filePath;

/**
 * Writes some content to a file, existing file will be overwritten.
 *
 * @param content  content to be written to a file.
 * @param filePath path to a file.
 * @return A flag indicating success or fail.
 */
+ (BOOL)writeString:(NSString *)content ToFile:(NSString *)filePath;

/**
 * Checks whether a file by the following path exists.
 *
 * @param filePath path to be checked.
 * @return <code>YES</code> if exists, <code>NO</code> otherwise.
 */
+ (BOOL)fileAtPathExists:(NSString *)filePath;

/**
 * Deletes directory located by the following path.
 *
 * @param directoryPath path to directory to be deleted. Can't be <code>null</code>.
 * @return A flag indicating success or fail.
 */
+ (BOOL)deleteDirectoryAtPath:(NSString *)directoryPath;

@end
