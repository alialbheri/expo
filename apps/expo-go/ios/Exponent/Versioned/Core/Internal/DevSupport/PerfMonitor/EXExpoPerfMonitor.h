#import <Foundation/Foundation.h>

#import <React/RCTBridgeModule.h>
#import <React/RCTInvalidating.h>
#import <ReactCommon/RCTHost.h>
#import <ReactCommon/RCTTurboModule.h>
#import "EXPerfMonitorDataSource.h"

#if RCT_DEV
@interface EXExpoPerfMonitor : NSObject <RCTBridgeModule, RCTTurboModule, RCTInvalidating, EXPerfMonitorDataSourceDelegate>
#else
@interface EXExpoPerfMonitor : NSObject
#endif

- (void)show;
- (void)hide;
- (void)updateHost:(nullable RCTHost *)host;

@end
