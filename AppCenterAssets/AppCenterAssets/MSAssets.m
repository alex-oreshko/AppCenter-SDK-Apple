#import "MSAssets.h"
#import "MSAssetsCategory.h"
#import "MSAssetsInternal.h"
#import "MSAssetsPrivate.h"
#import "MSAssetsTransmissionTargetInternal.h"
#import "MSChannelGroupProtocol.h"
#import "MSChannelUnitConfiguration.h"
#import "MSChannelUnitProtocol.h"
#import "MSConstants+Internal.h"
#import "MSEventLog.h"
#import "MSPageLog.h"
#import "MSServiceAbstractProtected.h"

// Service name for initialization.
static NSString *const kMSServiceName = @"Assets";

// The group Id for storage.
static NSString *const kMSGroupId = @"Assets";

// Singleton
static MSAssets *sharedInstance = nil;
static dispatch_once_t onceToken;

// Events values limitations
static const int minEventNameLength = 1;
static const int maxEventNameLength = 256;

@implementation MSAssets

@synthesize autoPageTrackingEnabled = _autoPageTrackingEnabled;
@synthesize channelUnitConfiguration = _channelUnitConfiguration;

#pragma mark - Service initialization

- (instancetype)init {
  if ((self = [super init])) {

    // Set defaults.
    _autoPageTrackingEnabled = NO;

    // Init session tracker.
    _sessionTracker = [[MSSessionTracker alloc] init];
    _sessionTracker.delegate = self;

    // Init channel configuration.
    _channelUnitConfiguration = [[MSChannelUnitConfiguration alloc] initDefaultConfigurationWithGroupId:[self groupId]];

    // Set up transmission target dictionary.
    _transmissionTargets = [NSMutableDictionary new];
  }
  return self;
}

#pragma mark - MSServiceInternal

+ (instancetype)sharedInstance {
  dispatch_once(&onceToken, ^{
    if (sharedInstance == nil) {
      sharedInstance = [[self alloc] init];
    }
  });
  return sharedInstance;
}

+ (NSString *)serviceName {
  return kMSServiceName;
}

- (void)startWithChannelGroup:(id<MSChannelGroupProtocol>)channelGroup
                    appSecret:(nullable NSString *)appSecret
      transmissionTargetToken:(nullable NSString *)token {
  [super startWithChannelGroup:channelGroup appSecret:appSecret transmissionTargetToken:token];
  if (token) {
    self.defaultTransmissionTarget = [self transmissionTargetFor:(NSString *)token];
  }

  // Set up swizzling for auto page tracking.
  [MSAssetsCategory activateCategory];
  MSLogVerbose([MSAssets logTag], @"Started Assets service.");
}

+ (NSString *)logTag {
  return @"AppCenterAssets";
}

- (NSString *)groupId {
  return kMSGroupId;
}

#pragma mark - MSServiceAbstract

- (void)applyEnabledState:(BOOL)isEnabled {
  [super applyEnabledState:isEnabled];
  if (isEnabled) {

    // Start session tracker.
    [self.sessionTracker start];

    // Add delegates to log manager.
    [self.channelGroup addDelegate:self.sessionTracker];
    [self.channelGroup addDelegate:self];

    // Report current page while auto page tracking is on.
    if (self.autoPageTrackingEnabled) {

      // Track on the main queue to avoid race condition with page swizzling.
      dispatch_async(dispatch_get_main_queue(), ^{
        if ([[MSAssetsCategory missedPageViewName] length] > 0) {
          [[self class] trackPage:(NSString * _Nonnull)[MSAssetsCategory missedPageViewName]];
        }
      });
    }

    MSLogInfo([MSAssets logTag], @"Assets service has been enabled.");
  } else {
    [self.channelGroup removeDelegate:self.sessionTracker];
    [self.channelGroup removeDelegate:self];
    [self.sessionTracker stop];
    MSLogInfo([MSAssets logTag], @"Assets service has been disabled.");
  }
}

- (BOOL)isAppSecretRequired {
  return NO;
}

#pragma mark - Service methods

+ (void)trackEvent:(NSString *)eventName {
  [self trackEvent:eventName withProperties:nil];
}

+ (void)trackEvent:(NSString *)eventName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties {
  [self trackEvent:eventName withProperties:properties forTransmissionTarget:nil];
}

/**
 * Track an event.
 *
 * @param eventName  event name.
 * @param transmissionTarget  the transmission target to associate to this event.
 */
+ (void)trackEvent:(NSString *)eventName forTransmissionTarget:(MSAssetsTransmissionTarget *)transmissionTarget {
  [self trackEvent:eventName withProperties:nil forTransmissionTarget:transmissionTarget];
}

/**
 * Track an event.
 *
 * @param eventName  event name.
 * @param properties dictionary of properties.
 * @param transmissionTarget  the transmission target to associate to this event.
 */
+ (void)trackEvent:(NSString *)eventName
           withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties
    forTransmissionTarget:(nullable MSAssetsTransmissionTarget *)transmissionTarget {
  @synchronized(self) {
    if ([[self sharedInstance] canBeUsed]) {
      [[self sharedInstance] trackEvent:eventName withProperties:properties forTransmissionTarget:transmissionTarget];
    }
  }
}

+ (void)trackPage:(NSString *)pageName {
  [self trackPage:pageName withProperties:nil];
}

+ (void)trackPage:(NSString *)pageName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties {
  @synchronized(self) {
    if ([[self sharedInstance] canBeUsed]) {
      [[self sharedInstance] trackPage:pageName withProperties:properties];
    }
  }
}

+ (void)setAutoPageTrackingEnabled:(BOOL)isEnabled {
  @synchronized(self) {
    [[self sharedInstance] setAutoPageTrackingEnabled:isEnabled];
  }
}

+ (BOOL)isAutoPageTrackingEnabled {
  @synchronized(self) {
    return [[self sharedInstance] isAutoPageTrackingEnabled];
  }
}

#pragma mark - Private methods

- (nullable NSString *)validateEventName:(NSString *)eventName forLogType:(NSString *)logType {
  if (!eventName || [eventName length] < minEventNameLength) {
    MSLogError([MSAssets logTag], @"%@ name cannot be null or empty", logType);
    return nil;
  }
  if ([eventName length] > maxEventNameLength) {
    MSLogWarning([MSAssets logTag],
                 @"%@ '%@' : name length cannot be longer than %d characters. Name will be truncated.", logType,
                 eventName, maxEventNameLength);
    eventName = [eventName substringToIndex:maxEventNameLength];
  }
  return eventName;
}

- (NSDictionary<NSString *, NSString *> *)validateProperties:(NSDictionary<NSString *, NSString *> *)properties
                                                  forLogName:(NSString *)logName
                                                     andType:(NSString *)logType {

  // Keeping this method body in MSAssets to use it in unit tests.
  return [MSUtility validateProperties:properties forLogName:logName type:logType];
}

- (void)trackEvent:(NSString *)eventName
           withProperties:(NSDictionary<NSString *, NSString *> *)properties
    forTransmissionTarget:(MSAssetsTransmissionTarget *)transmissionTarget {
  if (![self isEnabled])
    return;

  // Use default transmission target if no transmission target was provided.
  if (transmissionTarget == nil) {
    transmissionTarget = self.defaultTransmissionTarget;
  }

  // Create an event log.
  MSEventLog *log = [MSEventLog new];

  // Validate event name.
  NSString *validName = [self validateEventName:eventName forLogType:log.type];
  if (!validName) {
    return;
  }

  // Set properties of the event log.
  log.name = validName;
  log.eventId = MS_UUID_STRING;
  if (properties && properties.count > 0) {

    // Send only valid properties.
    log.properties = [self validateProperties:properties forLogName:log.name andType:log.type];
  }

  // Add transmission targets.
  if (transmissionTarget) {
    [log addTransmissionTargetToken:[transmissionTarget transmissionTargetToken]];
  }

  // Send log to log manager.
  [self sendLog:log];
}

- (void)trackPage:(NSString *)pageName withProperties:(NSDictionary<NSString *, NSString *> *)properties {
  if (![self isEnabled])
    return;

  // Create an event log.
  MSPageLog *log = [MSPageLog new];

  // Validate event name.
  NSString *validName = [self validateEventName:pageName forLogType:log.type];
  if (!validName) {
    return;
  }

  // Set properties of the event log.
  log.name = validName;
  if (properties && properties.count > 0) {

    // Send only valid properties.
    log.properties = [self validateProperties:properties forLogName:log.name andType:log.type];
  }

  // Send log to log manager.
  [self sendLog:log];
}

- (void)setAutoPageTrackingEnabled:(BOOL)isEnabled {
  _autoPageTrackingEnabled = isEnabled;
}

- (BOOL)isAutoPageTrackingEnabled {
  return self.autoPageTrackingEnabled;
}

- (void)sendLog:(id<MSLog>)log {

  // Send log to log manager.
  [self.channelUnit enqueueItem:log];
}

/**
 * Get a transmission target.
 *
 * @param transmissionTargetToken token of the transmission target to retrieve.
 *
 * @returns The transmission target object.
 */
- (MSAssetsTransmissionTarget *)transmissionTargetFor:(NSString *)transmissionTargetToken {
  MSAssetsTransmissionTarget *transmissionTarget = [self.transmissionTargets objectForKey:transmissionTargetToken];
  if (transmissionTarget) {
    MSLogDebug([MSAssets logTag], @"Returning transmission target found with id %@.", transmissionTargetToken);
    return transmissionTarget;
  }
  transmissionTarget = [[MSAssetsTransmissionTarget alloc] initWithTransmissionTargetToken:transmissionTargetToken];
  MSLogDebug([MSAssets logTag], @"Created transmission target with id %@.", transmissionTargetToken);
  [self.transmissionTargets setObject:transmissionTarget forKey:transmissionTargetToken];
  
  // TODO: Start service if not already.
  // Scenario: getTransmissionTarget gets called before App Center has an app secret or transmission target but start
  // has been called for this service.
  return transmissionTarget;
}

+ (void)resetSharedInstance {

  // resets the once_token so dispatch_once will run again.
  onceToken = 0;
  sharedInstance = nil;
}

#pragma mark - MSSessionTracker

- (void)sessionTracker:(id)sessionTracker processLog:(id<MSLog>)log {
  (void)sessionTracker;
  [self sendLog:log];
}

+ (void)setDelegate:(nullable id<MSAssetsDelegate>)delegate {
  [[self sharedInstance] setDelegate:delegate];
}

#pragma mark - MSChannelDelegate

- (void)channel:(id<MSChannelProtocol>)channel willSendLog:(id<MSLog>)log {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSEventLog class]] &&
      [self.delegate respondsToSelector:@selector(Assets:willSendEventLog:)]) {
    MSEventLog *eventLog = (MSEventLog *)log;
    [self.delegate Assets:self willSendEventLog:eventLog];
  } else if ([logObject isKindOfClass:[MSPageLog class]] &&
             [self.delegate respondsToSelector:@selector(Assets:willSendPageLog:)]) {
    MSPageLog *pageLog = (MSPageLog *)log;
    [self.delegate Assets:self willSendPageLog:pageLog];
  }
}

- (void)channel:(id<MSChannelProtocol>)channel didSucceedSendingLog:(id<MSLog>)log {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSEventLog class]] &&
      [self.delegate respondsToSelector:@selector(Assets:didSucceedSendingEventLog:)]) {
    MSEventLog *eventLog = (MSEventLog *)log;
    [self.delegate Assets:self didSucceedSendingEventLog:eventLog];
  } else if ([logObject isKindOfClass:[MSPageLog class]] &&
             [self.delegate respondsToSelector:@selector(Assets:didSucceedSendingPageLog:)]) {
    MSPageLog *pageLog = (MSPageLog *)log;
    [self.delegate Assets:self didSucceedSendingPageLog:pageLog];
  }
}

- (void)channel:(id<MSChannelProtocol>)channel didFailSendingLog:(id<MSLog>)log withError:(NSError *)error {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSEventLog class]] &&
      [self.delegate respondsToSelector:@selector(Assets:didFailSendingEventLog:withError:)]) {
    MSEventLog *eventLog = (MSEventLog *)log;
    [self.delegate Assets:self didFailSendingEventLog:eventLog withError:error];
  } else if ([logObject isKindOfClass:[MSPageLog class]] &&
             [self.delegate respondsToSelector:@selector(Assets:didFailSendingPageLog:withError:)]) {
    MSPageLog *pageLog = (MSPageLog *)log;
    [self.delegate Assets:self didFailSendingPageLog:pageLog withError:error];
  }
}

#pragma mark Transmission Target

/**
 * Get a transmission target.
 *
 * @param transmissionTargetToken token of the transmission target to retrieve.
 *
 * @returns The transmissionTarget object.
 */
+ (MSAssetsTransmissionTarget *)transmissionTargetForToken:(NSString *)transmissionTargetToken {
  return [[self sharedInstance] transmissionTargetFor:transmissionTargetToken];
}

@end
