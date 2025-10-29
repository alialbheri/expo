// Acts as a thin adapter around the RN behaviour in `EXPerfMonitorDataSource`, hosting the
// SwiftUI overlay and keeping DevSettings state in sync so the dev menu still works.
#import "EXExpoPerfMonitor.h"

#if RCT_DEV

#import <React/RCTBridge.h>
#import <React/RCTDevSettings.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <ReactCommon/RCTHost.h>
#import <ReactCommon/RCTTurboModule.h>
#import "Expo_Go-Swift.h"

static const CGFloat EXPerfMonitorDefaultWidth = 260;
static const CGFloat EXPerfMonitorMinimumHeight = 176;

static CGFloat EXPerfMonitorTargetWidthForWindow(UIWindow *window)
{
  if (!window) {
    return EXPerfMonitorDefaultWidth;
  }
  UIEdgeInsets safeInsets = window.safeAreaInsets;
  CGFloat availableWidth = window.bounds.size.width - safeInsets.left - safeInsets.right - 16.0;
  CGFloat desiredWidth = window.bounds.size.width * 0.95;
  CGFloat maxWidth = 360.0;
  CGFloat clampedWidth = MIN(MIN(desiredWidth, availableWidth), maxWidth);
  return MAX(EXPerfMonitorDefaultWidth, clampedWidth);
}

@interface EXExpoPerfMonitor ()

@property (nonatomic, strong) EXPerfMonitorDataSource *dataSource;
@property (nonatomic, strong) EXPerfMonitorPresenter *presenter;
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, assign) CGSize latestContentSize;
@property (nonatomic, weak) RCTHost *currentHost;

@end

@implementation EXExpoPerfMonitor {
  __weak RCTBridge *_bridge;
  __weak RCTModuleRegistry *_moduleRegistry;
}

@synthesize bridge = _bridge;
@synthesize moduleRegistry = _moduleRegistry;

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)invalidate
{
  [self hide];
}

- (void)toggleFromDevMenu
{
  RCTModuleRegistry *moduleRegistry = _moduleRegistry;
  RCTDevSettings *settings = (RCTDevSettings *)[moduleRegistry moduleForName:"DevSettings"];
  if (settings.isPerfMonitorShown) {
    [self hide];
    settings.isPerfMonitorShown = NO;
  } else {
    [self show];
    settings.isPerfMonitorShown = YES;
  }
}

- (void)updateHost:(RCTHost *)host
{
  self.currentHost = host;
  if (self.dataSource) {
    self.dataSource.host = host;
  }
}

- (UIPanGestureRecognizer *)panGestureRecognizer
{
  if (!_panGestureRecognizer) {
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
  }
  return _panGestureRecognizer;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture
{
  UIView *container = self.container;
  UIView *superview = container.superview;
  if (!container || !superview) {
    return;
  }

  CGPoint translation = [gesture translationInView:superview];
  container.center = CGPointMake(container.center.x + translation.x, container.center.y + translation.y);
  [gesture setTranslation:CGPointZero inView:superview];
}

- (void)show
{
  if (!_bridge) {
    return;
  }
  
  if (!self.presenter) {
    self.presenter = [[EXPerfMonitorPresenter alloc] init];

    __weak __typeof(self) weakSelf = self;
    [self.presenter setContentSizeHandler:^(NSValue *value) {
      CGSize size = value.CGSizeValue;
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf updateContainerForContentSize:size];
      });
    }];

    [self.presenter setCloseHandler:^{
      __strong __typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
        return;
      }
      [strongSelf hide];
    }];

    self.latestContentSize = [self.presenter currentContentSizeValue].CGSizeValue;
  }
  
  if (!self.container) {
    self.container = [[UIView alloc] initWithFrame:CGRectZero];
    self.container.backgroundColor = UIColor.clearColor;
    self.container.layer.masksToBounds = NO;

    UIView *hostView = self.presenter.view;
    hostView.frame = self.container.bounds;
    hostView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.container addSubview:hostView];
    [self.container addGestureRecognizer:self.panGestureRecognizer];
  }
  
  if (!self.dataSource) {
    self.dataSource = [[EXPerfMonitorDataSource alloc] initWithBridge:_bridge host:self.currentHost];
    self.dataSource.delegate = self;
  } else {
    self.dataSource.host = self.currentHost;
  }
  
  [self attachContainerIfNeeded];
  [self.dataSource startMonitoring];
  
  RCTModuleRegistry *moduleRegistry = _moduleRegistry;
  RCTDevSettings *settings = (RCTDevSettings *)[moduleRegistry moduleForName:"DevSettings"];
  if (settings && !settings.isPerfMonitorShown) {
    settings.isPerfMonitorShown = YES;
  }
}

- (void)hide
{
  RCTModuleRegistry *moduleRegistry = _moduleRegistry;
  RCTDevSettings *settings = (RCTDevSettings *)[moduleRegistry moduleForName:"DevSettings"];
  if (settings && settings.isPerfMonitorShown) {
    settings.isPerfMonitorShown = NO;
  }

  if (self.container.superview) {
    [self.container removeFromSuperview];
  }
  self.latestContentSize = CGSizeZero;

  [self.dataSource stopMonitoring];
  self.dataSource.host = nil;
  self.dataSource.delegate = nil;
  self.dataSource = nil;

  [self.presenter clearContentSizeHandler];
  self.presenter = nil;
  self.container = nil;
  self.panGestureRecognizer = nil;
  self.currentHost = nil;
}

- (void)attachContainerIfNeeded
{
  UIWindow *window = RCTSharedApplication().delegate.window ?: RCTKeyWindow();
  if (!window) {
    return;
  }

  if (!self.container.superview) {
    CGSize initialSize = self.latestContentSize;
    if (CGSizeEqualToSize(initialSize, CGSizeZero)) {
      if (self.presenter) {
        initialSize = [self.presenter currentContentSizeValue].CGSizeValue;
      }
      if (CGSizeEqualToSize(initialSize, CGSizeZero)) {
        initialSize = CGSizeMake(EXPerfMonitorDefaultWidth, EXPerfMonitorMinimumHeight);
      }
    }
    self.container.frame = [self initialFrameForWindow:window targetSize:initialSize];
    UIView *hostView = self.presenter.view;
    hostView.frame = self.container.bounds;
    [window addSubview:self.container];
  }

  [self bringContainerToFront];
}

- (CGRect)initialFrameForWindow:(UIWindow *)window targetSize:(CGSize)size
{
  UIEdgeInsets safeInsets = window.safeAreaInsets;
  CGFloat width = size.width > 0 ? size.width : EXPerfMonitorTargetWidthForWindow(window);
  width = MIN(width, EXPerfMonitorTargetWidthForWindow(window));
  width = MAX(width, EXPerfMonitorDefaultWidth);

  CGFloat height = MAX(EXPerfMonitorMinimumHeight, size.height);
  CGFloat originX = (window.bounds.size.width - width) / 2.0;
  CGFloat originY = safeInsets.top + 12.0;

  return CGRectMake(originX, originY, width, height);
}

- (void)updateContainerForContentSize:(CGSize)contentSize
{
  if (!self.container || !self.presenter) {
    return;
  }

  CGSize adjustedSize = contentSize;
  UIWindow *window = self.container.window ?: RCTSharedApplication().delegate.window ?: RCTKeyWindow();
  CGFloat targetWidth = EXPerfMonitorTargetWidthForWindow(window);
  if (CGSizeEqualToSize(adjustedSize, CGSizeZero)) {
    adjustedSize = CGSizeMake(targetWidth, EXPerfMonitorMinimumHeight);
  } else {
    adjustedSize.width = MIN(adjustedSize.width, targetWidth);
    adjustedSize.width = MAX(adjustedSize.width, EXPerfMonitorDefaultWidth);
    adjustedSize.height = MAX(EXPerfMonitorMinimumHeight, adjustedSize.height);
  }

  self.latestContentSize = adjustedSize;

  CGRect frame = self.container.frame;
  if (CGRectEqualToRect(frame, CGRectZero)) {
    return;
  }

  frame.size = adjustedSize;
  self.container.frame = frame;
  if (self.presenter) {
    UIView *hostView = self.presenter.view;
    hostView.frame = self.container.bounds;
  }
  [self bringContainerToFront];
}

- (void)bringContainerToFront
{
  UIView *container = self.container;
  UIView *superview = container.superview;
  if (superview && superview.subviews.lastObject != container) {
    [superview bringSubviewToFront:container];
  }
}

- (void)perfMonitorDidUpdateStats:(EXPerfMonitorStatsSnapshot *)stats
{
  if (!self.presenter) {
    return;
  }
  [self.presenter updateStatsWithMemoryMB:@(stats.memoryMB)
                                   heapMB:@(stats.heapMB)
                         layoutDurationMS:@(stats.layoutDurationMS)];
  [self bringContainerToFront];
}

- (void)perfMonitorDidUpdateFPS:(EXPerfMonitorFPSState *)fpsState track:(EXPerfMonitorTrack)track
{
  if (!self.presenter) {
    return;
  }
  NSArray<NSNumber *> *history = fpsState.history;
  if (!history) {
    history = @[];
  }
  PerfMonitorTrack bridgeTrack = (track == EXPerfMonitorTrackUI) ? PerfMonitorTrackUi : PerfMonitorTrackJs;
  [self.presenter updateTrack:bridgeTrack currentFPS:@(fpsState.currentFPS) history:history];
  [self bringContainerToFront];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return nullptr;
}

@end

#else

@implementation EXExpoPerfMonitor

- (void)show {}
- (void)hide {}
- (void)updateHost:(RCTHost *)host {}

@end

#endif
