#import "MPKitLocalytics.h"
#import <CoreLocation/CoreLocation.h>
#ifdef COCOAPODS
    #import "MPEvent.h"
    #import "MPCommerceEvent.h"
    #import "MPCommerceEvent+Dictionary.h"
    #import "MPCommerceEventInstruction.h"
    #import "MPTransactionAttributes.h"
    #import "MPTransactionAttributes+Dictionary.h"
    #import "MPProduct.h"
    #import "MPProduct+Dictionary.h"
    #import "mParticle.h"
    #import "MPKitRegister.h"
#endif

#import <Localytics/Localytics.h>

#if TARGET_OS_IOS == 1 && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    #import <UserNotifications/UserNotifications.h>
    #import <UserNotifications/UNUserNotificationCenter.h>
#endif

@interface MPKitLocalytics() {
    BOOL multiplyByOneHundred;
}

@property (nonatomic, strong) NSMutableDictionary *customDimensions;

@end


@implementation MPKitLocalytics

+ (NSNumber *)kitCode {
    return @84;
}

+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Localytics" className:@"MPKitLocalytics"];
    [MParticle registerExtension:kitRegister];
}

- (NSMutableDictionary *)customDimensions {
    if (_customDimensions) {
        return _customDimensions;
    }

    _customDimensions = [[NSMutableDictionary alloc] initWithCapacity:1];
    return _customDimensions;
}

#pragma mark MPKitInstanceProtocol methods
- (MPKitExecStatus *)didFinishLaunchingWithConfiguration:(NSDictionary *)configuration {
    MPKitExecStatus *execStatus = nil;
    if (!configuration[@"appKey"]) {
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeRequirementsNotMet];
        return execStatus;
    }

    NSString *customDimensions = configuration[@"customDimensions"];
    if (customDimensions && (NSNull *)customDimensions != [NSNull null] && customDimensions.length > 2) {
        NSError *error = nil;
        NSArray *dimensionsMapping = [NSJSONSerialization JSONObjectWithData:[customDimensions dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];

        if (dimensionsMapping && !error) {
            for (NSDictionary *dimensionMap in dimensionsMapping) {
                NSRange dimensionRange = [dimensionMap[@"value"] rangeOfString:@"Dimension "];

                if (dimensionRange.location != NSNotFound) {
                    NSString *key = dimensionMap[@"map"];
                    NSNumber *value = @([[dimensionMap[@"value"] substringFromIndex:NSMaxRange(dimensionRange)] integerValue]);

                    if (key && value) {
                        self.customDimensions[key] = value;
                    }
                }
            }
        } else {
            NSLog(@"mParticle -> Invalid 'customDimensions' configuration.");
        }
    }

    multiplyByOneHundred = [configuration[@"trackClvAsRawValue"] caseInsensitiveCompare:@"true"] != NSOrderedSame;

    _configuration = configuration;
    _started = YES;

    [self start];

    execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (void)dealloc {
    if (_started) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
}

- (void)start {
#if TARGET_OS_IOS==1
    [Localytics integrate:self.configuration[@"appKey"] withLocalyticsOptions:nil];
#elif TARGET_OS_TV==1
    [Localytics integrate:self.configuration[@"appKey"]];
#endif
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        [Localytics openSession];
    }

    _started = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{mParticleKitInstanceKey:[[self class] kitCode]};

        [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification
                                                            object:nil
                                                          userInfo:userInfo];
    });
}

- (MPKitExecStatus *)beginSession {
    [Localytics openSession];
    [Localytics upload];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)logCommerceEvent:(MPCommerceEvent *)commerceEvent {
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess forwardCount:0];

    switch (commerceEvent.action) {
        case MPCommerceEventActionRefund:
        case MPCommerceEventActionPurchase: {
            NSDictionary *commerceEventAttributes = [commerceEvent beautifiedAttributes];
            NSString *eventName = [NSString stringWithFormat:@"eCommerce - %@", [[commerceEvent actionNameForAction:commerceEvent.action] capitalizedString]];
            long revenue = lround([commerceEvent.transactionAttributes.revenue doubleValue] * (multiplyByOneHundred ? 100 : 1));
            revenue = commerceEvent.action == MPCommerceEventActionPurchase ? revenue : labs(revenue) * -1;

            [Localytics tagEvent:eventName attributes:commerceEventAttributes customerValueIncrease:@(revenue)];
            [execStatus incrementForwardCount];
        }
            break;

        default: {
            NSArray *expandedInstructions = [commerceEvent expandedInstructions];

            for (MPCommerceEventInstruction *commerceEventInstruction in expandedInstructions) {
                [self logEvent:commerceEventInstruction.event];
                [execStatus incrementForwardCount];
            }
        }
            break;
    }

    return execStatus;
}

- (MPKitExecStatus *)logEvent:(MPEvent *)event {
    BOOL hasDuration = event.duration && ![event.duration isEqualToNumber:@0];
    
    if (!hasDuration) {
        if (event.info) {
            [Localytics tagEvent:event.name attributes:event.info];
        }
        else {
            [Localytics tagEvent:event.name];
        }
    } else {
        NSMutableDictionary<NSString *, id> *info = [event.info mutableCopy] ?: [NSMutableDictionary dictionary];
        info[@"event_duration"] = event.duration;
        [Localytics tagEvent:event.name attributes:[info copy]];
    }

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)logLTVIncrease:(double)increaseAmount event:(MPEvent *)event {
    long amount = lround(increaseAmount * (multiplyByOneHundred ? 100 : 1));
    [Localytics tagEvent:event.name attributes:event.info customerValueIncrease:@(amount)];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)logScreen:(MPEvent *)event {
    [Localytics tagScreen:event.name];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)setDebugMode:(BOOL)debugMode {
    [Localytics setLoggingEnabled:debugMode];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

#if TARGET_OS_IOS == 1
- (MPKitExecStatus *)setDeviceToken:(NSData *)deviceToken {
    [Localytics setPushToken:deviceToken];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)receivedUserNotification:(NSDictionary *)userInfo {
    [Localytics handleNotification:userInfo];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}
#endif

#if TARGET_OS_IOS == 1 && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (nonnull MPKitExecStatus *)userNotificationCenter:(nonnull UNUserNotificationCenter *)center didReceiveNotificationResponse:(nonnull UNNotificationResponse *)response  API_AVAILABLE(ios(10.0)){
    [Localytics didReceiveNotificationResponseWithUserInfo:response.notification.request.content.userInfo];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}
#endif

- (MPKitExecStatus *)setLocation:(CLLocation *)location {
    [Localytics setLocation:location.coordinate];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)setOptOut:(BOOL)optOut {
    [Localytics setOptedOut:optOut];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)setUserAttribute:(NSString *)key value:(NSString *)value {
    NSNumber *customDimensionValue = self.customDimensions[key];

    if (customDimensionValue) {
        [Localytics setValue:value forCustomDimension:[customDimensionValue integerValue]];
    } else {
        if ([key isEqualToString:mParticleUserAttributeFirstName]) {
            [Localytics setCustomerFirstName:value];
        } else if ([key isEqualToString:mParticleUserAttributeLastName]) {
            [Localytics setCustomerLastName:value];
        }
    }
    
    [Localytics setValue:value forProfileAttribute:key];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)setUserAttribute:(NSString *)key values:(NSArray<NSString *> *)values {
    [Localytics setValue:values forProfileAttribute:key];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)incrementUserAttribute:(NSString *)key byValue:(NSNumber *)value {
    MPKitExecStatus *execStatus;
    NSNumber *customDimensionValue = self.customDimensions[key];

    if (customDimensionValue) {
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeCannotExecute];
        return execStatus;
    }

    [Localytics incrementValueBy:[value integerValue] forProfileAttribute:key];

    execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)removeUserAttribute:(NSString *)key {
    [Localytics deleteProfileAttribute:key];

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)setUserIdentity:(NSString *)identityString identityType:(MPUserIdentity)identityType {
    switch (identityType) {
        case MPUserIdentityCustomerId:
            [Localytics setCustomerId:identityString];
            break;

        case MPUserIdentityEmail:
            [Localytics setCustomerEmail:identityString];
            break;

        default: {
            NSArray *identifierStrings = @[@"Other", @"CustomerId", @"Facebook", @"Twitter", @"Google", @"Microsoft", @"Yahoo", @"Email", @"Alias", @"FacebookCustomAudienceId"];
            NSString *identifier = identifierStrings[(NSInteger)identityType];
            [Localytics setValue:identityString forIdentifier:identifier];
        }
            break;
    }

    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

#if TARGET_OS_IOS == 1
- (MPKitExecStatus *)openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options {
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLocalytics) returnCode:MPKitReturnCodeSuccess];
    [Localytics handleTestModeURL:url];
    return execStatus;
}
#endif

- (void)didEnterBackground:(NSNotification *)notification {
#if TARGET_OS_IOS == 1
    [Localytics dismissCurrentInAppMessage];
#endif
    [Localytics closeSession];
    [Localytics upload];
}

@end
