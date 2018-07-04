#import "MSAssetsFileUtils.h"
#import "SSZipArchive.h"
#import "MSLogger.h"
#import "MSAssets.h"

@implementation MSAssetsFileUtils



+ (BOOL)unzipFileAtPath:(NSString *)path toDestination:(NSString *)destination {
    return [SSZipArchive unzipFileAtPath:path
                           toDestination:destination];
}


+ (BOOL)copyDirectoryContents:(NSString *)sourceDir toDestination:(NSString *)destDir {
    BOOL isDir;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (!([fileManager fileExistsAtPath:destDir isDirectory:&isDir] && isDir)) {
        if (![fileManager createDirectoryAtPath:destDir withIntermediateDirectories:NO attributes:nil error:nil]) {
            MSLogInfo([MSAssets logTag], @"Can't copy, unable to create directory: %@", destDir);
            return NO;
        }
    }

    NSArray *sourceFiles = [fileManager contentsOfDirectoryAtPath:sourceDir error:nil];
    for (NSString *currentFile in sourceFiles) {
        if ([fileManager fileExistsAtPath:currentFile isDirectory:&isDir]) {
            if (!isDir) {
                if (![fileManager copyItemAtPath:[sourceDir stringByAppendingPathComponent:currentFile] toPath:[destDir stringByAppendingPathComponent:currentFile] error:nil]) {
                    MSLogInfo([MSAssets logTag], @"Unable to copy file: %@", [sourceDir stringByAppendingPathComponent:currentFile]);
                    return NO;
                }
            } else {
                return [self copyDirectoryContents:[sourceDir stringByAppendingPathComponent:currentFile] toDestination:[destDir stringByAppendingPathComponent:currentFile]];
            }
        }
    }

    return YES;
}

+ (BOOL)moveFile:(NSString *)fileToMove toFolder:(NSString *)newFolder withNewName:(NSString*)newFileName {
    BOOL isDir;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (!([fileManager fileExistsAtPath:newFolder isDirectory:&isDir] && isDir)) {
        if (![fileManager createDirectoryAtPath:newFolder withIntermediateDirectories:NO attributes:nil error:nil]) {
            MSLogInfo([MSAssets logTag], @"Can't move file from, unable to create directory: %@", newFolder);
            return NO;
        }
    }

    NSString *newFilePath = [newFolder stringByAppendingPathComponent:newFileName];
    if (![fileManager moveItemAtPath:fileToMove toPath:newFilePath error:nil]) {
        MSLogInfo([MSAssets logTag], @"Can't move file from %@ to %@", fileToMove, newFilePath);
        return NO;
    }
    return YES;
}

+ (NSString *)readFileToString:(NSString *)filePath {
    BOOL isDir;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
        return [NSString stringWithContentsOfFile:filePath encoding:NSUnicodeStringEncoding error:nil];
    } else {
        MSLogInfo([MSAssets logTag], @"Can't read to string file %@", filePath);
        return nil;
    }
}

+ (BOOL)writeString:(NSString *)content ToFile:(NSString *)filePath
{
    BOOL succeed = [content writeToFile:filePath
                              atomically:YES encoding:NSUnicodeStringEncoding error:nil];
    if (!succeed) {
        MSLogInfo([MSAssets logTag], @"Can't write string to file %@", filePath);
    }
    return succeed;
}

+ (BOOL)fileAtPathExists:(NSString *)filePath
{
    BOOL isDir;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return ([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir);
}

+ (BOOL)deleteDirectoryAtPath:(NSString *)directoryPath
{
    if (!directoryPath)
    {
        MSLogInfo([MSAssets logTag], @"directoryPath can not be null");
        return NO;
    }
    BOOL isDir;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (!([fileManager fileExistsAtPath:directoryPath isDirectory:&isDir] && isDir)) {
        MSLogInfo([MSAssets logTag], @"Can't find folder to delete: %@", directoryPath);
            return NO;
    } else {
        return [fileManager removeItemAtPath:directoryPath error:nil];
    }
}

@end
