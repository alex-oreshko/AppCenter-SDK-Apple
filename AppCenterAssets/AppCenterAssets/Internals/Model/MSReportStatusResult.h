#import <Foundation/Foundation.h>
#import "MSSerializableObject.h"

@interface MSReportStatusResult : NSObject <MSSerializableObject>

/**
 * The result string from server.
 */
@property(nonatomic, copy) NSString *result;

/**
 * Creates an instance of the {@link MSReportStatusResult} that has been successful.
 *
 * @param result result string from server.
 * @return instance of the class.
 */
+ (MSReportStatusResult *)createSuccessful:(NSString *)result;

@end
