//
//  PPScrollListViewControllerViewController.m
//
//  Created by Torin Nguyen on 25/4/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import "PPPepperContants.h"
#import "PPPepperViewController.h"
#import "PPPageViewContentWrapper.h"
#import "PPPageViewDetailWrapper.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "PPPageViewDetailController.h"

//Used to be public contants
//These are only default values at compile time, can be changed on-the-fly at runtime
#define HIDE_FIRST_PAGE               NO          //hide the first page
#define FIRST_PAGE_BOOK_COVER         YES         //background of the first page uses book cover image
#define ENABLE_BORDERLESS_GRAPHIC     NO          //combine with HIDE_FIRST_PAGE to create a 'stack of paper' application
#define ENABLE_HIGH_SPEED_SCROLLING   YES         //in 3D mode only
#define ENABLE_BOOK_SCALE             YES         //other book not in center will be smaller
#define ENABLE_BOOK_SHADOW            YES         //dynamic shadow below books
#define ENABLE_BOOK_ROTATE            NO          //other book not in center will be slightly rotated (carousel effect)
#define ENABLE_ONE_SIDE_ZOOM          NO          //zoom into one side, instead of side-by-side like Paper
#define ENABLE_ONE_SIDE_MIDDLE_ZOOM   NO          //zoom into one side, anchor at middle of the page
#define ENABLE_PAGE_URL               YES         //iOS5 page curl effect
#define SMALLER_FRAME_FOR_PORTRAIT    YES         //resize everything smaller when device is in portrait mode

//Graphics
#define BOOK_BG_IMAGE                @"book_bg"
#define PAGE_BG_IMAGE                @"page_bg"
#define PAGE_BG_BORDERLESS_IMAGE     @"page_bg_borderless"

//Don't mess with these
#define OPEN_BOOK_DURATION           0.5
#define TIMER_INTERVAL               0.016666667  //60fps
#define PEPPER_PAGE_SPACING          32.0f        //gap between edges of pages in 3D/Pepper mode
#define THRESHOLD_FULL_ANGLE         10
#define THRESHOLD_HALF_ANGLE         25
#define THRESHOLD_CLOSE_ANGLE        80
#define LEFT_RIGHT_ANGLE_DIFF        9.9          //should be perfect 10, but we cheated
#define MAXIMUM_ANGLE                89.0         //near 90, but cannot be 90
#define MINIMUM_SCALE                0.3
#define MINIMUM_SCALE_PAGES          6
#define NUM_REUSE_BOOK_LANDSCAPE     7            //we can have different number of reusable book views
#define NUM_REUSE_BOOK_PORTRAIT      7            //for portrait and landscape if needed
#define NUM_REUSE_DETAIL_VIEW        3
#define NUM_REUSE_3D_VIEW            12           //12 is minimum
#define NUM_VISIBLE_PAGE_ONE_SIDE    4            //depends on the SCALE_ATTENUATION & also edge limit
#define MIN_CONTROL_INDEX            0.5
#define MINOR_X_ADJUSTMENT_14        0
#define SCALE_ATTENUATION            0.03
#define SCALE_INDEX_DIFF             2.5
#define CONTROL_INDEX_USE_TIMER      YES
#define M34_IPAD                     (-1.0 / 1300.0)    //0:flat, more negative: more perspective
#define M34_IPHONE                   (-1.0 / 600.0)     //0:flat, more negative: more perspective
#define INVALID_NUMBER               999999
#define PI_DIV_BY_180                0.01745329251994   // M_PI / 180.0f  conversion from degree to radian


@interface PPPepperViewController()
<
 UIGestureRecognizerDelegate,
 UIScrollViewDelegate,
 PPPageViewWrapperDelegate,
 UIPageViewControllerDelegate,
 UIPageViewControllerDataSource
>

//Op flags
@property (nonatomic, assign) float frameWidth;
@property (nonatomic, assign) float frameHeight;
@property (nonatomic, assign) float aspectRatioLandscape;
@property (nonatomic, assign) float aspectRatioPortrait;
@property (nonatomic, assign) float edgePaddingPercentage;    //percentage of EDGE_PADDING compared to background graphic height
@property (nonatomic, assign) float bookSpacing;
@property (nonatomic, assign) float pepperPageSpacing;
@property (nonatomic, assign) float m34;
@property (nonatomic, assign) int numBooks;
@property (nonatomic, assign) int numPages;
@property (nonatomic, assign) float currenPageContentOffsetY;
@property (nonatomic, strong) UIImage *bookCoverImage;
@property (nonatomic, strong) UIImage *pageBackgroundImage;

@property (nonatomic, assign) BOOL zoomOnLeft;
@property (nonatomic, assign) BOOL isBookView;
@property (nonatomic, assign) BOOL isDetailView;
@property (nonatomic, assign) int currentBookIndex;
@property (nonatomic, assign) float currentPageIndex;

//Control
@property (nonatomic, assign) float controlAngle;
@property (nonatomic, assign) float controlFlipAngle;
@property (nonatomic, assign) float touchDownControlAngle;
@property (nonatomic, assign) float touchDownControlIndex;
@property (nonatomic, assign) float previousSpecialControlIndex;

//Timers
@property (nonatomic, assign) float controlIndexTimerTarget;
@property (nonatomic, assign) float controlIndexTimerDx;
@property (nonatomic, strong) NSDate *controlIndexTimerLastTime;
@property (nonatomic, strong) NSTimer *controlIndexTimer;
@property (nonatomic, assign) float controlAngleTimerTarget;
@property (nonatomic, assign) float controlAngleTimerDx;
@property (nonatomic, strong) NSDate *controlAngleTimerLastTime;
@property (nonatomic, strong) NSTimer *controlAngleTimer;

//Book scrollview
@property (nonatomic, strong) UIScrollView *bookScrollView;
@property (nonatomic, strong) NSMutableArray *reuseBookViewArray;
@property (nonatomic, strong) NSMutableArray *visibleBookViewArray;
@property (nonatomic, strong) PPPageViewContentWrapper *theBookCover;

//Pepper views
@property (nonatomic, strong) UIView *pepperView;
@property (nonatomic, retain) NSMutableArray *reusePepperWrapperArray;
@property (nonatomic, retain) NSMutableArray *visiblePepperWrapperArray;
@property (nonatomic, strong) UIView *theLeftView;
@property (nonatomic, strong) UIView *theRightView;
@property (nonatomic, strong) UIView *theView1;
@property (nonatomic, strong) UIView *theView2;
@property (nonatomic, strong) UIView *theView3;
@property (nonatomic, strong) UIView *theView4;

//Page scrollview
@property (nonatomic, strong) UIScrollView *pageScrollView;
@property (nonatomic, strong) NSMutableArray *reusePageViewArray;
@property (nonatomic, strong) NSMutableArray *visiblePageViewArray;

//Page view controller //iOS5.0 and above
@property (nonatomic, strong) UIPageViewController *pageViewController;
@property (nonatomic, strong) NSMutableArray *reusePageViewDetailControllerArray;
@property (nonatomic, strong) NSMutableArray *visiblePageViewDetailControllerArray;

@end


@implementation PPPepperViewController

//public properties
@synthesize hideFirstPage;
@synthesize enableBorderlessGraphic = _enableBorderlessGraphic;
@synthesize animationSlowmoFactor;
@synthesize enableBookScale;
@synthesize enableBookShadow;
@synthesize enableBookRotate;
@synthesize enableOneSideZoom;
@synthesize enableOneSideMiddleZoom;
@synthesize enablePageCurlEffect;
@synthesize enableHighSpeedScrolling;
@synthesize scaleOnDeviceRotation;

@synthesize delegate;
@synthesize dataSource = _dataSource;

//Op flags
@synthesize frameWidth, frameHeight;
@synthesize aspectRatioPortrait, aspectRatioLandscape, edgePaddingPercentage;
@synthesize bookSpacing, pepperPageSpacing, m34;
@synthesize numBooks, numPages;
@synthesize currenPageContentOffsetY;
@synthesize bookCoverImage, pageBackgroundImage;

@synthesize zoomOnLeft;
@synthesize isBookView, isDetailView;
@synthesize currentBookIndex = _currentBookIndex;
@synthesize currentPageIndex = _currentPageIndex;

//Control
@synthesize controlAngle = _controlAngle;
@synthesize controlFlipAngle = _controlFlipAngle;
@synthesize touchDownControlAngle;
@synthesize touchDownControlIndex;
@synthesize previousSpecialControlIndex;

//Timers
@synthesize controlAngleTimerTarget;
@synthesize controlAngleTimerDx;
@synthesize controlAngleTimerLastTime;
@synthesize controlAngleTimer;
@synthesize controlIndex = _controlIndex;
@synthesize controlIndexTimer;
@synthesize controlIndexTimerTarget, controlIndexTimerDx, controlIndexTimerLastTime;

//Book
@synthesize bookScrollView;
@synthesize reuseBookViewArray;
@synthesize visibleBookViewArray;
@synthesize theBookCover;

//Pepper
@synthesize pepperView;
@synthesize reusePepperWrapperArray;
@synthesize visiblePepperWrapperArray;
@synthesize theLeftView, theRightView;
@synthesize theView1, theView2, theView3, theView4;

//Page scrollview
@synthesize pageScrollView;
@synthesize reusePageViewArray;
@synthesize visiblePageViewArray;

//Page view controller
@synthesize pageViewController;
@synthesize reusePageViewDetailControllerArray;
@synthesize visiblePageViewDetailControllerArray;

//I have not found a better way to implement this yet
static float layer23WidthAtMid = 0;
static float layer2WidthAt90 = 0;

//Optimize for performance
static int midXLandscape = 0;
static int midXPortrait = 0;
static int midYLandscape = 0;
static int midYPortrait = 0;
static float deviceFactor = 0;
static BOOL isLowEndDevice = NO;
static BOOL isPad = NO;
static BOOL iOS5AndAbove = NO;

#pragma mark - View life cycle

+ (NSString*)version {
  return @"1.4.0";
}

- (id)dataSource {
//Prevent free-to-try version to modify the datasource
#ifdef DEMO
  self.dataSource = self;
#endif 
  return _dataSource;
}

- (void)setDataSource:(id)newValue {
//Prevent free-to-try version to modify the datasource
#ifdef DEMO
  if (![newValue isEqual:self]) {
    NSLog(@"Free-to-try version does not allow you to change dataSource");
    _dataSource = self;
    return;    
  }
#endif 
  _dataSource = newValue;
}


- (id)init {
  self = [super init];
  if (self == nil)
    return self;
  
  self.delegate = self;
  self.dataSource = self;
  
  //Convert iPad numbers to iPhone
  isLowEndDevice = [self checkLowEndDevice];
  if (deviceFactor == 0)
    deviceFactor = MAX([UIScreen mainScreen].bounds.size.width,[UIScreen mainScreen].bounds.size.height) / 1024.0;
  
  //Device constants
  isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
  iOS5AndAbove = ([[[UIDevice currentDevice] systemVersion] compare:@"5.0" options:NSNumericSearch] != NSOrderedAscending);
  
  self.bookCoverImage = nil;
  self.pageBackgroundImage = nil;
  self.m34 = isPad ? M34_IPAD : M34_IPHONE;
  self.pepperPageSpacing = PEPPER_PAGE_SPACING;
  
  //Configurable public properties
  self.hideFirstPage = HIDE_FIRST_PAGE;
  self.animationSlowmoFactor = 1.0f;
  self.enableBorderlessGraphic = ENABLE_BORDERLESS_GRAPHIC;
  self.enableBookScale = ENABLE_BOOK_SCALE;
  self.enableBookShadow = ENABLE_BOOK_SHADOW;
  self.enableBookRotate = ENABLE_BOOK_ROTATE;
  self.enableOneSideZoom = ENABLE_ONE_SIDE_ZOOM;
  self.enableOneSideMiddleZoom = ENABLE_ONE_SIDE_MIDDLE_ZOOM;
  self.enablePageCurlEffect = ENABLE_PAGE_URL;
  self.enableHighSpeedScrolling = ENABLE_HIGH_SPEED_SCROLLING;
  self.scaleOnDeviceRotation = SMALLER_FRAME_FOR_PORTRAIT;
  
  //Initial op flags
  self.zoomOnLeft = YES;
  self.isBookView = YES;
  self.isDetailView = NO;
  _controlIndex = MIN_CONTROL_INDEX;
  _controlAngle = -THRESHOLD_HALF_ANGLE;
  _controlFlipAngle = -THRESHOLD_HALF_ANGLE;
  
  //Gesture recognizers
  UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onTwoFingerPinch:)];
  pinchGestureRecognizer.delegate = self;
  [self.view addGestureRecognizer:pinchGestureRecognizer];
  
  UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanning:)];
  panGestureRecognizer.delegate = self;
  [self.view addGestureRecognizer:panGestureRecognizer];
  
  return self;
}

- (void)dealloc
{
  [self destroyBookScrollView:YES];
  [self destroyPepperView:YES];
  [self destroyPageScrollView:YES];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  //Initialize self.view
  self.view.autoresizesSubviews = YES;
  self.view.clipsToBounds = YES;
  self.view.backgroundColor = [UIColor clearColor];
  self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

  [self initializeBackgroundImagesAndRatios];
  [self updateFrameSizesForOrientation];
  
  //Initialize big views, in their correct order
  
  if (self.bookScrollView == nil) {
    self.bookScrollView = [[UIScrollView alloc] init];
    self.bookScrollView.frame = self.view.bounds;
    self.bookScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.bookScrollView.autoresizesSubviews = NO;
    self.bookScrollView.bounces = NO;
    self.bookScrollView.showsHorizontalScrollIndicator = NO;
    self.bookScrollView.showsVerticalScrollIndicator = NO;
    self.bookScrollView.directionalLockEnabled = YES;
    self.bookScrollView.clipsToBounds = NO;
    self.bookScrollView.delegate = self;
    self.bookScrollView.alpha = 1;
    [self.view addSubview:self.bookScrollView];
  }
  
  if (self.pepperView == nil) {
    self.pepperView = [[UIScrollView alloc] init];
    self.pepperView.frame = self.view.bounds;
    self.pepperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.pepperView.autoresizesSubviews = NO;
    self.pepperView.hidden = YES;
    [self.view addSubview:self.pepperView];
  }
  
  if (self.pageScrollView == nil) {
    self.pageScrollView = [[UIScrollView alloc] init];
    self.pageScrollView.frame = self.view.bounds;
    self.pageScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.pageScrollView.autoresizesSubviews = NO;
    self.pageScrollView.bounces = NO;
    self.pageScrollView.showsHorizontalScrollIndicator = NO;
    self.pageScrollView.showsVerticalScrollIndicator = NO;
    self.pageScrollView.directionalLockEnabled = YES;
    self.pageScrollView.clipsToBounds = NO;
    self.pageScrollView.delegate = self;
    self.pageScrollView.hidden = YES;
    self.pageScrollView.pagingEnabled = YES;
    [self.view addSubview:self.pageScrollView];
  }
  
  if (self.pageViewController == nil && iOS5AndAbove) {
    self.pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl
                                                              navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                            options:nil];    
    //self.pageViewController.delegate = self;      //set later
    //self.pageViewController.dataSource = self;    //set later
    
    [self addChildViewController:self.pageViewController];
    [self.view addSubview:self.pageViewController.view];
    self.pageViewController.view.frame = self.view.bounds;
    self.pageViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    [self.pageViewController didMoveToParentViewController:self];
    
    //for (UIGestureRecognizer *recognizer in self.pageViewController.gestureRecognizers)
    //  [self.view addGestureRecognizer:recognizer];
  }
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  
  //The functions will check if the view can be destroyed
  [self unloadBookScrollView:NO];
  if (self.isBookView)    [self destroyPepperView:NO];
  else                    [self unloadPepperView:NO];
  [self unloadPageScrollView:NO];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  //Invalidate UI cache, causing problem because of status bar
  midXLandscape = 0;
  midXPortrait = 0;
  midYLandscape = 0;
  midYPortrait = 0;
  
  [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
  
  //Switching from portrait to landscape, with enableOneSideZoom disabled, need to set to even pageIndex
  if (!self.enableOneSideZoom && UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
    if ((int)self.currentPageIndex % 2 != 0)
      self.currentPageIndex -= 1;
  
  //Update new frame sizes
  [self updateFrameSizesForOrientation:toInterfaceOrientation];

  //Relayout the Book views with animation
  for (PPPageViewContentWrapper *subview in self.visibleBookViewArray) {
    int index = subview.tag;
    CGRect frame = [self getFrameForBookIndex:index forOrientation:toInterfaceOrientation];
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
      subview.frame = frame;
    } completion:^(BOOL finished) {
      
    }];
    
    //Animate the tranformation. Not perfect, but ok at high speed
    
    float scale = (index == self.currentBookIndex) ? MAX_BOOK_SCALE : MIN_BOOK_SCALE;
    float angle = (index == self.currentBookIndex) ? 0 : MAX_BOOK_ROTATE;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DScale(transform, scale, scale, 1.0);
    if (self.enableBookRotate)
      transform = CATransform3DRotate(transform, angle, 0, 1, 0);
    
    CABasicAnimation *theAnimation;
    theAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    theAnimation.delegate = nil;
    theAnimation.duration = duration;
    theAnimation.repeatCount = 0;
    theAnimation.removedOnCompletion = YES;
    theAnimation.fillMode = kCAFillModeForwards;
    theAnimation.autoreverses = NO;
    theAnimation.fromValue = [NSValue valueWithCATransform3D:subview.layer.transform];
    theAnimation.toValue = [NSValue valueWithCATransform3D:transform];
    [subview.layer addAnimation:theAnimation forKey:[NSString stringWithFormat:@"animateBookLayerTransform%d", index]];
  }
  [self scrollToBook:self.currentBookIndex duration:duration];
  
  //Relayout detail views with animation
  for (PPPageViewDetailWrapper *subview in self.visiblePageViewArray) {
    int index = subview.tag;
    CGRect frame = [self getFrameForPageIndex:index forOrientation:toInterfaceOrientation];
    
    [subview layoutWithFrame:frame duration:duration];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
      subview.frame = frame;
    } completion:^(BOOL finished) {
      
    }];
  }
  [self updatePageScrollViewContentSizeForOrientation:toInterfaceOrientation];
  [self scrollToPage:self.currentPageIndex duration:duration forOrientation:toInterfaceOrientation];
  
  //Relayout 3D views with animation
  for (PPPageViewContentWrapper *subview in self.visiblePepperWrapperArray) {
    int index = subview.tag;
    CGRect frame = [self getPepperFrameForPageIndex:index forOrientation:toInterfaceOrientation];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
      subview.frame = frame;
    } completion:^(BOOL finished) {
      
    }];
  }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
  [self updateBookScrollViewContentSize];
  [self updateBookScrollViewBookScale];
  [self updatePageScrollViewContentSize]; 
    
  self.controlFlipAngle = self.controlFlipAngle;
  if (self.isBookView || self.isDetailView)
    self.pepperView.hidden = YES;
  
  //Increase number of reusable views for landscape
  int totalViews = self.reuseBookViewArray.count + self.visibleBookViewArray.count;
  if ([self isLandscape]) {
    for (int i=totalViews; i<NUM_REUSE_BOOK_LANDSCAPE; i++)
      [self.reuseBookViewArray addObject:[[PPPageViewContentWrapper alloc] init]];
    [self reuseBookScrollView];
  }
  else {
    [self reuseBookScrollView];
    for (int i=NUM_REUSE_BOOK_PORTRAIT; i<totalViews; i++)
      [self.reuseBookViewArray removeObjectAtIndex:0];
  }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return YES;
}

- (void)reload {
  
  self.numBooks = -1;
  self.numPages = -1;
  
  //Graphic
  self.bookCoverImage = nil;
  self.pageBackgroundImage = nil;
  [self initializeBackgroundImagesAndRatios];
  
  //Initialize book views
  self.bookScrollView.contentOffset = CGPointMake(0,0);
  self.numBooks = [self getNumberOfBooks];
  if (self.numBooks <= 0)
    return;

  self.bookScrollView.hidden = YES;
  self.isBookView = YES;
  self.isDetailView = NO;
  
  //Initialize books scrollview
  //[self destroyBookScrollView:YES];
  //[self destroyPepperView:YES];
  //[self destroyPageScrollView:YES];
  [self unloadBookScrollView:YES];
  [self unloadPepperView:YES];
  [self unloadPageScrollView:YES];

  //Initialize books scrollview
  [self setupReuseablePoolBookViews];
  [self updateBookScrollViewContentSize];
  for (int i=0; i<numBooks; i++)
    [self addBookToScrollView:i];
  self.currentBookIndex = 0;
  [self updateBookScrollViewBookScale];
   
  self.bookScrollView.hidden = NO;
  self.pepperView.hidden = YES;
  self.pageScrollView.hidden = YES;
  self.pageViewController.view.hidden = YES;
}

- (NSString *)rawPlatformString {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *machine = malloc(size);
  sysctlbyname("hw.machine", machine, &size, NULL, 0);
  NSString *platform = [NSString stringWithUTF8String:machine];
  free(machine);
  return platform;
}

- (BOOL)checkLowEndDevice {
  
  NSString *platform = [self rawPlatformString];
  if ([platform isEqualToString:@"iPad1,1"] ||          //iPad 1
      [platform isEqualToString:@"iPhone1,1"] ||        //iPhone 1G
      [platform isEqualToString:@"iPhone2,1"] ||        //iPhone 3G
      [platform isEqualToString:@"iPod1,1"] ||          //iPod Touch 1G
      [platform isEqualToString:@"iPod2,1"]             //iPod Touch 2G
      )
    return YES;
  
  return NO;
}


#pragma mark - PPPageViewWrapperDelegate

- (void)PPPageViewWrapper:(PPPageViewContentWrapper*)thePage viewDidTap:(int)tag
{
  //UI is busy
  if ([self.controlAngleTimer isValid] || [self.controlIndexTimer isValid])
    return;
  if (!self.isBookView && self.controlAngle == 0)
    return;
    
  if (thePage.isBook)
  {
    if (self.currentBookIndex != tag) {
      [self scrollToBook:tag animated:YES];
      return;
    }
    
    self.numPages = -1;
    
    //Optional: Delegate can decide to show or not
    BOOL hasDelegate = [self.delegate respondsToSelector:@selector(ppPepperViewController:didTapOnBookIndex:)];
    if (hasDelegate)
      [self.delegate ppPepperViewController:self didTapOnBookIndex:tag];
    
    //Without delegate, we open it automatically
    else
      [self openBookWithIndex:tag pageIndex:0];
    
    return;
  }
  
  //Tag correction due to wrong z-index
  if (tag < self.controlIndex)      tag = self.controlIndex - 0.5;
  else                              tag = self.controlIndex + 0.5;

  //Optional: Delegate can decide to show or not
  BOOL hasDelegate = [self.delegate respondsToSelector:@selector(ppPepperViewController:didTapOnPageIndex:)];
  if (hasDelegate) {
    [self.delegate ppPepperViewController:self didTapOnPageIndex:tag];
    return;
  }
  
  //Without delegate, we open it automatically
  [self openPageIndex:tag];
}

- (void)PPPageViewDetailWrapper:(PPPageViewDetailWrapper*)thePage viewDidTap:(int)tag
{
  BOOL hasDelegate = [self.delegate respondsToSelector:@selector(ppPepperViewController:didTapOnFullscreenPageIndex:)];
  if (hasDelegate) {
    [self.delegate ppPepperViewController:self didTapOnFullscreenPageIndex:tag];
    return;
  }
}


#pragma mark - Gestures

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  BOOL noGestureInDetailView = self.isDetailView && (self.enableOneSideZoom || [self isPortrait]);
  
  if (self.isBookView || noGestureInDetailView)
    return NO;
  if (self.controlIndexTimer != nil || [self.controlIndexTimer isValid])
    return NO;
  if (self.controlAngleTimer != nil || [self.controlAngleTimer isValid])
    return NO;
  
  if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]])
    return YES;
  
  if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
    if ([self isFullscreen])
      return NO;
    return YES;
  }
  
  return NO;
}

- (void)onTwoFingerPinch:(UIPinchGestureRecognizer *)recognizer 
{  
  //Remember initial value to calculate based on delta later
  if (recognizer.state == UIGestureRecognizerStateBegan) {
    self.touchDownControlAngle = self.controlAngle;
    [self updateLeftRightPointers];
    
    if (![self isFullscreen]) {
      CGPoint centerPoint = [recognizer locationInView:self.view];
      self.zoomOnLeft = centerPoint.x < CGRectGetMidX(self.view.bounds) ? YES : NO;
      int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
      if (self.controlIndex > pageCount-1)
        self.zoomOnLeft = YES;
    }
  }
  
  //Don't scale the first page
  if (!self.isDetailView && self.theLeftView.tag <= 0 && self.zoomOnLeft)
    return;

  //Snap control angle to 3 thresholds
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    if (self.controlAngle >= 0)
      return;
    [self snapControlAngle];
    return;
  }
  
  float boost = 1.25f;
  if (self.enableOneSideZoom && recognizer.scale > 1.0)
    boost = 0.3f;
  
  float dx = boost * (-90.0) * (1.0-recognizer.scale);
  float newControlAngle = self.touchDownControlAngle + dx;
  self.controlAngle = newControlAngle;
}

- (void)onPanning:(UIPanGestureRecognizer *)recognizer
{
  //in case gestureRecognizerShouldBegin does not work properly
  if (self.isDetailView || self.isBookView)
    return;
    
  //Remember initial value to calculate based on delta later
  if (recognizer.state == UIGestureRecognizerStateBegan)
    self.touchDownControlIndex = self.controlIndex;
  
  //The dynamics
  CGPoint translation = [recognizer translationInView:self.pepperView];
  CGPoint velocity = [recognizer velocityInView:self.pepperView];
  float normalizedVelocityX = fabsf(velocity.x / self.pepperView.bounds.size.width / 2);
  
  float direction = (velocity.x >= 0) ? 1 : -1;
  float rawNormalizedVelocityX = normalizedVelocityX;
  
  if (rawNormalizedVelocityX < 1)           rawNormalizedVelocityX = rawNormalizedVelocityX * 0.8;       //expansion
  else if (rawNormalizedVelocityX > 1.1)    rawNormalizedVelocityX = 1 + (rawNormalizedVelocityX-1)/2;   //compression
  
  if (normalizedVelocityX < 1)              normalizedVelocityX = 1;
  else if (normalizedVelocityX > 2.0)       normalizedVelocityX = 2.0;
  
  //Snap to half open
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    
    float snapTo = 0;
    float newControlIndex = self.controlIndex - direction * rawNormalizedVelocityX;     //opposite direction
    
    int lowerBound = (int)floor(newControlIndex);
    int lowerBoundEven = lowerBound % 2 == 0;
    int upperBound = (int)ceil(newControlIndex);
    int theIndex = (int)round(newControlIndex);
    if (lowerBoundEven)               snapTo = lowerBound + 0.5;
    else if (theIndex == upperBound)  snapTo = upperBound + 0.5;
    else                              snapTo = lowerBound - 0.5;

    float diff = fabs(snapTo - newControlIndex);
    float duration = diff / 2.5f;
    if (ENABLE_HIGH_SPEED_SCROLLING && normalizedVelocityX != 0)
      duration /= normalizedVelocityX;
    if (diff <= 0)
      return;
    duration *= self.animationSlowmoFactor;

    //Correct behavior but sluggish
    if (CONTROL_INDEX_USE_TIMER) {
      [self animateControlIndexTo:snapTo duration:duration];
      return;
    }
    
    //This has some kind of glitch
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
      self.controlIndex = snapTo;      
    } completion:^(BOOL finished) {
      _controlAngle = -THRESHOLD_HALF_ANGLE;
    }];
    return;
  }
  
  //Speed calculation
  float boost = 9.5f;
  if (ENABLE_HIGH_SPEED_SCROLLING)
    boost *= normalizedVelocityX;

  float dx = boost * (translation.x / self.view.bounds.size.width/2);
  float newControlIndex = self.touchDownControlIndex - dx;
  self.controlIndex = newControlIndex;
}


#pragma mark - Data Helper functions

- (int)getNumberOfBooks
{
  if (self.numBooks >= 0)
    return self.numBooks;
  
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:numberOfBooks:)]) {
    self.numBooks = [self.dataSource ppPepperViewController:self numberOfBooks:0];
    return self.numBooks;
  }
  
  return 0;
}

- (int)getNumberOfPagesForBookIndex:(int)bookIndex
{
  if (self.numPages >= 0)
    return self.numPages;

  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:numberOfPagesForBookIndex:)]) {
    self.numPages = [self.dataSource ppPepperViewController:self numberOfPagesForBookIndex:bookIndex];
    return self.numPages;
  }
  
  return 0;
}



#pragma mark - UI Helper functions (Common)

- (void)updateFrameSizesForOrientation
{
  [self updateFrameSizesForOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

- (void)setEnableBorderlessGraphic:(BOOL)newValue
{
  _enableBorderlessGraphic = newValue;
  self.bookCoverImage = nil;
  self.pageBackgroundImage = nil;
  [self initializeBackgroundImagesAndRatios];
}

//
// Initialize static UIImage variable declared at the top
//
- (void)initializeBackgroundImagesAndRatios
{
  BOOL graphicChanged = NO;
  
  if (self.bookCoverImage == nil) {
    graphicChanged = YES;
    self.bookCoverImage = [UIImage imageNamed:self.enableBorderlessGraphic ? PAGE_BG_BORDERLESS_IMAGE : BOOK_BG_IMAGE];
  }

  if (self.pageBackgroundImage == nil) {
    graphicChanged = YES;
    self.pageBackgroundImage = [UIImage imageNamed:self.enableBorderlessGraphic ? PAGE_BG_BORDERLESS_IMAGE : PAGE_BG_IMAGE];
  }

  self.edgePaddingPercentage = (float)EDGE_PADDING / self.bookCoverImage.size.height;
  if (self.bookCoverImage == nil || self.bookCoverImage.size.height <= 0)
    NSLog(@"WARNING: Missing page_bg graphic needed for initialization");
  
  if (!graphicChanged)
    return;

  for (PPPageViewContentWrapper *subview in self.reuseBookViewArray)
    [subview setBackgroundImage:self.bookCoverImage];
  
  for (PPPageViewDetailWrapper *subview in self.reusePageViewArray)
    [subview setBackgroundImage:self.pageBackgroundImage];

}

- (void)updateFrameSizesForOrientation:(UIInterfaceOrientation)orientation
{
  BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
  
  float orientationFactor = isLandscape ? 1.0f : FRAME_SCALE_PORTRAIT;
  if (!self.scaleOnDeviceRotation)
    orientationFactor = 1.0f;
  
  //Add padding
  float width = MIN(self.view.bounds.size.width, self.view.bounds.size.height);
  float contentHeight = MAX(self.view.bounds.size.width, self.view.bounds.size.height);
  
  if (width <= 0 || contentHeight <= 0)
    NSLog(@"WARNING: PepperUI is initialized too early");
  
  //Custom aspect ratio for content
  if (isLandscape && FRAME_ASPECT_RATIO_LANDSCAPE > 0)
    contentHeight = roundf(width * FRAME_ASPECT_RATIO_LANDSCAPE);
  else if (!isLandscape && FRAME_ASPECT_RATIO > 0)
    contentHeight = roundf(width * FRAME_ASPECT_RATIO);
  
  //Fit the aspect ratio to self when self.enableOneSideZoom is disabled
  if (!self.enableOneSideZoom && isLandscape) {
    float ratio = [self getMidXForOrientation:orientation] / MIN(self.view.bounds.size.width, self.view.bounds.size.height);   
    contentHeight = width / ratio;
  }
  
  float height = contentHeight / (1.0 - 2*self.edgePaddingPercentage);
  
  //Scaling
  self.frameWidth = orientationFactor * width * (isPad ? FRAME_SCALE_IPAD : FRAME_SCALE_IPHONE);
  self.frameHeight = orientationFactor * height * (isPad ? FRAME_SCALE_IPAD : FRAME_SCALE_IPHONE);

  self.bookSpacing = (self.frameWidth * MAX_BOOK_SCALE) / 3.2;
  if (orientationFactor != 0)     self.bookSpacing *= orientationFactor;
  if (deviceFactor != 0)          self.bookSpacing *= deviceFactor;
  
  //Frame size changes on rotation, these needs to be recalculated
  if (self.scaleOnDeviceRotation) {
    layer23WidthAtMid = 0;
    layer2WidthAt90 = 0;
  }
}

- (BOOL)isPortrait
{
  return UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
}

- (BOOL)isLandscape
{
  return UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
}

- (int)getFrameY
{
  return [self getFrameYForOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

- (int)getFrameYForOrientation:(UIInterfaceOrientation)orientation
{
  int midY = [self getMidYForOrientation:orientation];
  return midY - self.frameHeight/2;
}

- (int)getMidXForOrientation:(UIInterfaceOrientation)orientation
{  
  //Cached
  BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
  if (isLandscape && midXLandscape > 0)
    return midXLandscape;
  if (!isLandscape && midXPortrait > 0)
    return midXPortrait;
  
  int min = MIN(self.view.bounds.size.height, self.view.bounds.size.width);
  int max = MAX(self.view.bounds.size.height, self.view.bounds.size.width);

  midXLandscape = max/2;
  midXPortrait = min/2;
  
  return isLandscape ? midXLandscape : midXPortrait;
}

- (int)getMidYForOrientation:(UIInterfaceOrientation)orientation
{
  //Cached
  BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
  if (isLandscape && midYLandscape > 0)
    return midYLandscape;
  if (!isLandscape && midYPortrait > 0)
    return midYPortrait;
  
  int min = MIN(self.view.bounds.size.height, self.view.bounds.size.width);
  int max = MAX(self.view.bounds.size.height, self.view.bounds.size.width);
  
  midYLandscape = min/2;
  midYPortrait = max/2;
  
  return isLandscape ? midYLandscape : midYPortrait;
}



#pragma mark - UI Helper functions (Pepper)

- (BOOL)isFullscreen
{
  return self.controlAngle >= 0;
}

- (BOOL)isPepperView
{
  return (!self.isBookView && !self.isDetailView);
}

- (float)getCurrentSpecialIndex
{
  float index = 1.5f + ceil((self.controlIndex-2.5) / 2) * 2;
  if (index < 1.5f)
    index = 1.5f;
  return index;
}

- (float)getPepperFrameXForPageIndex:(int)pageIndex gapScale:(float)gapScale {
  return [self getPepperFrameXForPageIndex:pageIndex gapScale:gapScale orientation:[UIApplication sharedApplication].statusBarOrientation];
}

//
// Returns the correct X position of given page, according to current controlIndex
// Note: layer2WidthAt90 static variable must already be calculated before using this function
//       this will NOT be valid for the middle 4 pages
//
- (float)getPepperFrameXForPageIndex:(int)pageIndex gapScale:(float)gapScale orientation:(UIInterfaceOrientation)interfaceOrientation {
  
  //Handle middle 4 pages
  float midX = [self getMidXForOrientation:interfaceOrientation];
  float indexDiff = fabsf(self.controlIndex - pageIndex) - 2.5;                   //2.5 pages away from current center
  if (indexDiff < 0)
    return midX;

  float distance = indexDiff * self.pepperPageSpacing * deviceFactor;
  float maxDistance = NUM_VISIBLE_PAGE_ONE_SIDE * self.pepperPageSpacing * deviceFactor;
  float positionScale = 0.5;
  float magicNumber = layer2WidthAt90 + (MINOR_X_ADJUSTMENT_14*deviceFactor) - layer2WidthAt90*positionScale/2.5;    //see formular for self.theView4.frame, flip to right case
  float diffFromMidX = magicNumber + distance;
  float maxDiffFromMidX = magicNumber + maxDistance;
  
  //last page limit (making the last page 'stucks' to a fixed position)
  if (diffFromMidX > maxDiffFromMidX)
    diffFromMidX = maxDiffFromMidX;
  
  float x = 0;  
  float deltaFromMidX = diffFromMidX * gapScale;
  
  if (pageIndex < self.controlIndex)    x = midX - deltaFromMidX;
  else                                  x = midX + deltaFromMidX;
  return x;
}

//
// Return the frame for this pepper view
//
- (CGRect)getPepperFrameForPageIndex:(int)index forOrientation:(UIInterfaceOrientation)interfaceOrientation {
  float y = [self getFrameYForOrientation:interfaceOrientation];
  float x = [self getPepperFrameXForPageIndex:index gapScale:1.0 orientation:interfaceOrientation];
  return CGRectMake(x, y, self.frameWidth, self.frameHeight);
}

//
// Return the half-open scale for this pepper view
//
- (float)getPepperScaleForPageIndex:(int)index {

  float maxScale = 1.0f;
  float minScale = maxScale - ((NUM_VISIBLE_PAGE_ONE_SIDE-1)*2+0.5 - SCALE_INDEX_DIFF) * SCALE_ATTENUATION;
  
  float indexDiff = fabsf(self.controlIndex - index) - SCALE_INDEX_DIFF;
  float scale = maxScale - indexDiff * SCALE_ATTENUATION;
  if (scale > maxScale)   scale = maxScale;
  if (scale < minScale)   scale = minScale;
  
  //Scale down when closing book
  if (self.controlAngle < -THRESHOLD_HALF_ANGLE) {
    float factor = (self.controlAngle-(-THRESHOLD_HALF_ANGLE)) / ((-MAXIMUM_ANGLE)-(-THRESHOLD_HALF_ANGLE));
    float newScale = scale + (MAX_BOOK_SCALE-scale) * factor;
    scale = newScale;
  }
  
  return scale;
}

//
// Hide & reuse all page in Pepper UI
//
- (void)unloadPepperView:(BOOL)force
{
  if (!force)
    if (!self.isDetailView && !self.isBookView)
      return;
  
  self.pepperView.hidden = YES;
  
  while ([self.visiblePepperWrapperArray count] > 0) {
    PPPageViewContentWrapper *subview = [self.visiblePepperWrapperArray objectAtIndex:0];
    subview.tag = -1;
    subview.hidden = YES;
    [subview unloadContent];
    [self.reusePepperWrapperArray addObject:subview];
    [self.visiblePepperWrapperArray removeObjectAtIndex:0];
  }
}

//
// Dealloc pepper views
//
- (void)destroyPepperView:(BOOL)force
{  
  if (!force)
    if (!self.isDetailView && !self.isBookView)
      return;
  
  self.pepperView.hidden = YES;
  
  [self.reusePepperWrapperArray removeAllObjects];
  self.reusePepperWrapperArray = nil;
  
  while ([self.visiblePepperWrapperArray count] > 0) {
    PPPageViewContentWrapper *subview = [self.visiblePepperWrapperArray objectAtIndex:0];
    [subview unloadContent];
    [subview removeFromSuperview];
    [self.visiblePepperWrapperArray removeObjectAtIndex:0];
  }
  self.visiblePepperWrapperArray = nil;
}

- (void)setupReusablePoolPepperViews
{
  //No need to re-setup
  if (self.reusePepperWrapperArray != nil || [self.reusePepperWrapperArray count] > 0)
    return;
  
  if (self.reusePepperWrapperArray == nil)
    self.reusePepperWrapperArray = [[NSMutableArray alloc] init];
  if (self.visiblePepperWrapperArray == nil)
    self.visiblePepperWrapperArray = [[NSMutableArray alloc] init];
  
  //Reuseable views pool
  CGRect pageFrame = CGRectMake(3000, 0, self.frameWidth, self.frameHeight);
  for (int i=0; i<NUM_REUSE_3D_VIEW; i++) {
    PPPageViewContentWrapper *box = [[PPPageViewContentWrapper alloc] initWithFrame:pageFrame];
    box.delegate = self;
    box.alpha = 1;
    box.tag = -1;
    box.hidden = YES;
    [self.reusePepperWrapperArray addObject:box];
  }
}

- (void)reusePepperViews {
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
      
  //Visible range
  int range = NUM_VISIBLE_PAGE_ONE_SIDE * 2 + 1;        //plus buffer
  float currentIndex = [self getCurrentSpecialIndex];
  int startIndex = currentIndex - range + 2;            //because currentIndex is being bias towards the left
  if (startIndex < 0)
    startIndex = 0;
  int endIndex = startIndex + range*2;
  if (endIndex > pageCount-1)
    endIndex = pageCount-1;
    
  //Reuse out of bound views
  for (int i=0; i<pageCount; i++)
    if (i < startIndex || i > endIndex)
      [self removePageFromPepper:i];
    
  //Reuse out of bound views & hidden views
  NSMutableArray *toBeRemoved = [[NSMutableArray alloc] init];
  for (UIView *subview in self.visiblePepperWrapperArray) {
    int idx = subview.tag;
    if (idx > currentIndex-1.6 && idx < currentIndex+1.6)   //Don't touch the middle 4 pages
      continue;
    if (subview.hidden) {
      [toBeRemoved addObject:subview];
      continue;
    }
    if (idx < startIndex || idx > endIndex) {
      [self removePageFromPepper:idx];
      continue;
    }
    if (idx > currentIndex && idx%2!=0)   //odd page on the right side, should not be removed
      continue;
    if (idx < currentIndex && idx%2==0)   //even page on the left side, should not be removed
      continue;
    [toBeRemoved addObject:subview];
  }
  while (toBeRemoved.count > 0) {
    UIView *subview = [toBeRemoved objectAtIndex:0];
    [self.reusePepperWrapperArray addObject:subview];
    [self.visiblePepperWrapperArray removeObject:subview];
    [toBeRemoved removeObjectAtIndex:0];
    
    //This is quite expensive, substitute by just hiding it & use self.visiblePepperWrapperArray to keep track
    //[subview removeFromSuperview];
    subview.hidden = YES;
  }

  //Add only relevant new views
  for (int i=startIndex; i<=endIndex; i++) {
    if (i > currentIndex-1.6 && i < currentIndex+1.6) {
      [self addPageToPepperView:i];
      continue;
    }
    if (i < currentIndex && i%2!=0)   //odd page on the left side, should not be added
      continue;
    if (i > currentIndex && i%2==0)   //even page on the right side, should not be added
      continue;

    [self addPageToPepperView:i];
  }
}

- (void)reorderPepperViews {
  
  int totalPages = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  
  //Reorder-Z for left pages
  for (int i=0; i < (int)self.controlIndex; i++) {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    [page.superview bringSubviewToFront:page];    //expensive, need to be further optimized
  }
  
  //Reorder-Z for right pages
  for (int i=totalPages-1; i >= (int)self.controlIndex; i--) {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    [page.superview bringSubviewToFront:page];    //expensive, need to be further optimized
  }
}

- (BOOL)hasPageInPepperView:(int)index
{
  BOOL retValue = NO;
  for (PPPageViewContentWrapper *subview in self.visiblePepperWrapperArray) {
    if (subview.tag == index) {
      retValue = YES;
      break;
    }
  }
  return retValue;
}

- (void)addPageToPepperView:(int)index {
  
  //Worst case senario: some bugs causing both array to be empty
  if ([self.reusePepperWrapperArray count] <= 0 && [self.visiblePepperWrapperArray count] <= 0)
    [self setupReusablePoolPepperViews];
  
  //Reuseable pool is empty, should not happen, check removePageFromPepperView code
  if (self.reusePepperWrapperArray.count <= 0)
    return;
  
  //Need to get the first page data here
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
    
  //Check if we already have this Page in pepper view
  if ([self hasPageInPepperView:index])
    return;
  
  int midX = [self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
  int frameY = [self getFrameY];
  CGRect pageFrame = CGRectMake(midX,frameY, self.frameWidth, self.frameHeight);
  PPPageViewContentWrapper *pageView = [self.reusePepperWrapperArray objectAtIndex:0];
  [self.reusePepperWrapperArray removeObjectAtIndex:0];
  if (pageView == nil)
    return;
  if (![pageView isKindOfClass:[PPPageViewContentWrapper class]])    //some sands
    return;
    
  pageView.tag = index;
  pageView.isBook = NO;
  pageView.frame = pageFrame;
  
  BOOL useBookCoverImage = (FIRST_PAGE_BOOK_COVER && index <= 0 && !self.hideFirstPage);
  [pageView setBackgroundImage:(useBookCoverImage ? self.bookCoverImage : self.pageBackgroundImage)];
  
  pageView.alpha = 1;
  pageView.hidden = YES;        //control functions will unhide later
  pageView.delegate = self;  
  pageView.isLeft = (index%2==0) ? YES : NO;
    
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:thumbnailViewForPageIndex:inBookIndex:withFrame:reusableView:)])
    pageView.contentView = [self.dataSource ppPepperViewController:self thumbnailViewForPageIndex:index inBookIndex:self.currentBookIndex withFrame:pageView.bounds reusableView:pageView.contentView];
  else
    [pageView unloadContent];
  
  [self.pepperView addSubview:pageView];
  [self.visiblePepperWrapperArray addObject:pageView];
  
  //Visible range
  int range = NUM_VISIBLE_PAGE_ONE_SIDE * 2 + 1;        //plus buffer
  float currentIndex = [self getCurrentSpecialIndex];
  int startIndex = currentIndex - range + 2;            //because currentIndex is being bias towards the left
  if (startIndex < 0)
    startIndex = 0;
  int endIndex = startIndex + range*2;
  if (endIndex > pageCount-1)
    endIndex = pageCount-1;
  
  //Reorder-Z for left pages
  if (index < self.controlIndex)
  {
    for (int i=startIndex; i < (int)self.controlIndex; i++) {
      PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
      if (page == nil)
        continue;
      [page.superview bringSubviewToFront:page];    //expensive, need to be further optimized
    }
  }

  //Reorder-Z for right pages
  else
  {
    for (int i=endIndex; i >= (int)self.controlIndex; i--) {
      PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
      if (page == nil)
        continue;
      [page.superview bringSubviewToFront:page];    //expensive, need to be further optimized
    }
  }
}

- (void)removePageFromPepper:(int)index {
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
    
  for (PPPageViewContentWrapper *subview in self.visiblePepperWrapperArray) {
    if (subview.tag != index)
      continue;
    subview.tag = -1;
    [subview unloadContent];
    [self.reusePepperWrapperArray addObject:subview];
    [self.visiblePepperWrapperArray removeObject:subview];
    
    //This is quite expensive, substitute by just hiding it & use self.visiblePepperWrapperArray to keep track
    //[subview removeFromSuperview];
    subview.hidden = YES;
    break;
  }
}

- (PPPageViewContentWrapper*)getPepperPageAtIndex:(int)index {
  
  //Visible range
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  int range = NUM_VISIBLE_PAGE_ONE_SIDE * 2 + 1;        //plus buffer
  float currentIndex = [self getCurrentSpecialIndex];
  int startIndex = currentIndex - range + 2;            //because currentIndex is being bias towards the left
  if (startIndex < 0)
    startIndex = 0;
  int endIndex = startIndex + range*2;
  if (endIndex > pageCount-1)
    endIndex = pageCount-1;
  
  if (index < startIndex-1 || index > endIndex+1)       //soft limit
    return nil;
  
  PPPageViewContentWrapper *theView = nil;
  for (PPPageViewContentWrapper *page in self.visiblePepperWrapperArray) {
    if (page.tag != index)
      continue;
    theView = page;
    break;
  }
  return theView;
}

//
// Find the first visible (even) page index, suitable for book cover replacement
//
- (int)getFirstVisiblePepperPageIndex {
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  int firstPageIndex = pageCount;
  
  for (PPPageViewContentWrapper *subview in self.visiblePepperWrapperArray)
    if (subview.tag < firstPageIndex
        && !subview.hidden
        && subview.tag%2 == 0)
      firstPageIndex = subview.tag;
  
  if (firstPageIndex >= pageCount)
    firstPageIndex = self.hideFirstPage ? 1 : 0;
  
  return firstPageIndex;
}

//
// Find the first visible (even) page index, suitable for book cover replacement
//
- (UIView*)getFirstVisiblePepperPageView {
  
  int firstPageIndex = [self getFirstVisiblePepperPageIndex];
  return [self getPepperPageAtIndex:firstPageIndex];
}



#pragma mark - UI Helper functions (Book)

//
// Hide & reuse all page in book scrollview
//
- (void)unloadBookScrollView:(BOOL)force
{
  if (!force)
    if (self.isBookView)
      return;
  
  self.bookScrollView.hidden = YES;
  
  while ([self.visibleBookViewArray count] > 0) {
    PPPageViewContentWrapper *subview = [self.visibleBookViewArray objectAtIndex:0];
    subview.tag = -1;
    subview.hidden = YES;
    [subview unloadContent];
    [self.reuseBookViewArray addObject:subview];   
    [self.visibleBookViewArray removeObjectAtIndex:0];
  }
}

- (void)destroyBookScrollView:(BOOL)force
{
  if (!force)
    if (self.isBookView)
      return;
  
  self.bookScrollView.hidden = YES;
  
  [self.reuseBookViewArray removeAllObjects];
  self.reuseBookViewArray = nil;
  
  while ([self.visibleBookViewArray count] > 0) {
    PPPageViewContentWrapper *subview = [self.visibleBookViewArray objectAtIndex:0];
    [subview unloadContent];
    [subview removeFromSuperview];
    [self.visibleBookViewArray removeObjectAtIndex:0];
  }
  self.visibleBookViewArray = nil;
}

- (void)setupReuseablePoolBookViews
{
  self.bookScrollView.hidden = NO;
  
  //No need to re-setup
  if (self.reuseBookViewArray != nil || [self.reuseBookViewArray count] > 0)
    return;
  
  if (self.reuseBookViewArray == nil)
    self.reuseBookViewArray = [[NSMutableArray alloc] init];
  if (self.visibleBookViewArray == nil)
    self.visibleBookViewArray = [[NSMutableArray alloc] init];
  
  int numReuse = [self isLandscape] ? NUM_REUSE_BOOK_LANDSCAPE : NUM_REUSE_BOOK_PORTRAIT;
  
  //Reuseable views pool
  for (int i=0; i<numReuse; i++)
    [self.reuseBookViewArray addObject:[[PPPageViewContentWrapper alloc] init]];
}

- (void)scrollToBook:(int)bookIndex animated:(BOOL)animated {
  
  int x = bookIndex * (self.frameWidth + self.bookSpacing);
  if (animated)
    self.bookScrollView.userInteractionEnabled = NO;
  
  [self.bookScrollView setContentOffset:CGPointMake(x, 0) animated:animated];
  self.currentBookIndex = bookIndex;
  
  if (animated) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
      self.bookScrollView.userInteractionEnabled = YES;
    });    
  }
}

- (void)scrollToBook:(int)bookIndex duration:(float)duration {
  
  int x = bookIndex * (self.frameWidth + self.bookSpacing);
  self.currentBookIndex = bookIndex;
  
  if (duration <= 0) {
    self.bookScrollView.contentOffset = CGPointMake(x, 0);
    return;
  }
  
  [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.bookScrollView.contentOffset = CGPointMake(x, 0);
  } completion:^(BOOL finished) {
    
  }];
}

- (void)snapBookScrollView {
  int index = [self getCurrentBookIndex];
  int x = index * (self.frameWidth + self.bookSpacing);
  [self.bookScrollView setContentOffset:CGPointMake(x, 0) animated:YES];
  self.currentBookIndex = index;
}

- (void)reuseBookScrollView {
  
  int bookCount = [self getNumberOfBooks];
  
  //Visible indexes
  int range = [self isLandscape] ? floor(NUM_REUSE_BOOK_LANDSCAPE/2.0) : floor(NUM_REUSE_BOOK_PORTRAIT/2.0);
  int currentIndex = [self getCurrentBookIndex];
  int startIndex = currentIndex - range;
  if (startIndex < 0)
    startIndex = 0;
  int endIndex = currentIndex + range;
  if (endIndex > bookCount-1)
    endIndex = bookCount-1;
  
  //Reuse out of bound views
  for (int i=0; i<bookCount; i++)
    if (i < startIndex || i > endIndex)
      [self removeBookFromScrollView:i];
  
  //Add new views
  //Skip current book is being controlled by self.theBookCover
  for (int i=startIndex; i<=endIndex; i++)
    if (i != self.currentBookIndex)
      [self addBookToScrollView:i];
}

//
// Return the frame for this book in scrollview
//
- (CGRect)getFrameForBookIndex:(int)index forOrientation:(UIInterfaceOrientation)interfaceOrientation {
  int frameY = [self getFrameY];
  int midX = [self getMidXForOrientation:interfaceOrientation];
  int x = midX - self.frameWidth/2 + index * (self.frameWidth + self.bookSpacing);
  return CGRectMake(x, frameY, self.frameWidth, self.frameHeight);
}

//
// Return the frame for this book in scrollview
//
- (CGRect)getFrameForBookIndex:(int)index {
  int frameY = [self getFrameY];
  int x = CGRectGetWidth(self.bookScrollView.frame)/2 - self.frameWidth/2 + index * (self.frameWidth + self.bookSpacing);
  return CGRectMake(x, frameY, self.frameWidth, self.frameHeight);
}

//
// Return the current index of book being selected
//
- (int)getCurrentBookIndex
{
  int offsetX = fabs(self.bookScrollView.contentOffset.x);
  int index = round(offsetX / (self.frameWidth+self.bookSpacing));
  return index;
}

- (void)removeBookFromScrollView:(int)index
{
  int bookCount = [self getNumberOfBooks];
  if (index < 0 || index >= bookCount)
    return;
  
  PPPageViewContentWrapper *subview = [self getBookViewAtIndex:index];
  if (subview == nil)
    return;
  subview.tag = -1;
  [subview unloadContent];
  [self.reuseBookViewArray addObject:subview];
  [self.visibleBookViewArray removeObject:subview];
  
  //This is quite expensive, substitute by just hiding it & use self.visibleBookViewArray to keep track
  //[subview removeFromSuperview];
  subview.hidden = YES;
}

- (PPPageViewContentWrapper*)getBookViewAtIndex:(int)index
{
  PPPageViewContentWrapper *theView = nil;
  for (PPPageViewContentWrapper *book in self.visibleBookViewArray) {
    if (book.tag != index)
      continue;
    if (![book isKindOfClass:[PPPageViewContentWrapper class]])
      continue;
    theView = book;
    break;
  }
  return theView;
}

- (BOOL)hasBookInBookScrollView:(int)index
{
  BOOL retValue = NO;
  for (PPPageViewContentWrapper *subview in self.visibleBookViewArray) {
    if (subview.tag == index) {
      retValue = YES;
      break;
    }
  }
  return retValue;
}

- (void)addBookToScrollView:(int)index
{
  //Worst case senario: some bugs causing both array to be empty
  if ([self.reuseBookViewArray count] <= 0 && [self.visibleBookViewArray count] <= 0)
    [self setupReuseablePoolBookViews];
  
  //Buffer is full
  if (self.reuseBookViewArray.count <= 0)
    return;
  
  //Need to get the first page data here
  int bookCount = [self getNumberOfBooks];
  if (index < 0 || index >= bookCount)
    return;
  
  //Check if we already have this Book in scrollview
  if ([self hasBookInBookScrollView:index])
    return;
    
  PPPageViewContentWrapper *coverPage = [self.reuseBookViewArray objectAtIndex:0];
  [self.reuseBookViewArray removeObjectAtIndex:0];
  if (coverPage == nil)
    return;
  
  coverPage.tag = index;
  coverPage.isLeft = NO;
  coverPage.isBook = YES;
  coverPage.delegate = self;
  
  [coverPage setBackgroundImage:(self.hideFirstPage ? self.pageBackgroundImage : self.bookCoverImage)];
  
  coverPage.alpha = 1;
  coverPage.transform = CGAffineTransformIdentity;
  coverPage.frame = [self getFrameForBookIndex:index];
  coverPage.layer.transform = CATransform3DMakeScale(MAX_BOOK_SCALE, MAX_BOOK_SCALE, 1.0);
    
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:viewForBookIndex:withFrame:reusableView:)])
    coverPage.contentView = [self.dataSource ppPepperViewController:self viewForBookIndex:index withFrame:coverPage.bounds reusableView:coverPage.contentView];
  else
    [coverPage unloadContent];

  coverPage.hidden = NO;
  [self.bookScrollView addSubview:coverPage];
  [self.visibleBookViewArray addObject:coverPage];
}


- (void)updateBookScrollViewContentSize {
  int bookCount = [self getNumberOfBooks];
  CGRect lastFrame = [self getFrameForBookIndex:bookCount-1];
  CGSize contentSize = CGSizeMake(CGRectGetMaxX(lastFrame) + CGRectGetWidth(self.bookScrollView.bounds)/2, 250);
  self.bookScrollView.contentSize = contentSize;
}

- (void)updateBookScrollViewBookScale
{  
  //Scale & rotate the book views
  int edgeWidth = CGRectGetWidth(self.bookScrollView.bounds)/2.5;
  if (edgeWidth == 0)   edgeWidth = 1;
  
  for (UIView *subview in self.visibleBookViewArray) {
    float subviewMidX = CGRectGetMidX(subview.frame) - fabs(self.bookScrollView.contentOffset.x);
    
    float scaleForAngle = 1.0;
    if (subviewMidX < edgeWidth)
      scaleForAngle = subviewMidX / (float)edgeWidth;
    else if (subviewMidX > CGRectGetWidth(self.bookScrollView.bounds)-edgeWidth)
      scaleForAngle = 1.0 - (float)(subviewMidX-CGRectGetWidth(self.bookScrollView.bounds)+edgeWidth) / (float)edgeWidth;
    
    if (scaleForAngle < 0)        scaleForAngle = 0;
    else if (scaleForAngle > 1)   scaleForAngle = 1;
    float angle = ((1.0-scaleForAngle) * MAX_BOOK_ROTATE) * PI_DIV_BY_180;
    if (subviewMidX < edgeWidth)
      angle *= -1;
    
    float scale = scaleForAngle * (MAX_BOOK_SCALE-MIN_BOOK_SCALE) + MIN_BOOK_SCALE;
    if (!self.enableBookScale)
      scale = MAX_BOOK_SCALE;
    CGPoint previousAnchor = subview.layer.anchorPoint;
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DScale(transform, scale, scale, 1.0);
    if (self.enableBookRotate)
      transform = CATransform3DRotate(transform, angle, 0, 1, 0);
    subview.layer.anchorPoint = previousAnchor;
    subview.layer.transform = transform;
    
    PPPageViewContentWrapper *wrapper = (PPPageViewContentWrapper*)subview;
    if (!isLowEndDevice && self.enableBookScale && self.enableBookShadow) {
      float shadowScale = 1;
      if (MAX_BOOK_SCALE-MIN_BOOK_SCALE != 0)
        shadowScale = (scale-MIN_BOOK_SCALE) / (MAX_BOOK_SCALE-MIN_BOOK_SCALE);
      wrapper.shadowOffset = isPad ? CGSizeMake(0, 5 + 5*shadowScale) : CGSizeMake(0, 2 + 2*shadowScale);
      wrapper.shadowRadius = isPad ? (10 + 8 * shadowScale) : (5 + 4 * shadowScale);
      [wrapper updateShadow];
    }
    else if (self.enableBookShadow) {
      wrapper.shadowOffset = isPad ? CGSizeMake(0, 5) : CGSizeMake(0, 4);
      wrapper.shadowRadius = isPad ? 18 : 9;
      [wrapper updateShadow];
    }
    else {
      wrapper.shadowOpacity = 0;
    }
  }
}

- (void)openCurrentBookAtPageIndex:(int)pageIndex {
  
  if (!self.isBookView)
    return;
  int index = [self getCurrentBookIndex];
  int bookCount = [self getNumberOfBooks];
  if (index < 0 || index >= bookCount)
    index = 0;
  [self openBookWithIndex:index pageIndex:pageIndex];
}

- (void)openBookWithIndex:(int)bookIndex pageIndex:(int)pageIndex {
  
  self.currentBookIndex = bookIndex;
  self.numPages = -1;
  self.previousSpecialControlIndex = INVALID_NUMBER;
  
  [self updatePageScrollViewContentSize];
  int pageCount = [self getNumberOfPagesForBookIndex:bookIndex];
  
  //Accept even page as argument only
  if (pageIndex%2 != 0)
    pageIndex -= 1;
    
  //Convert integer pageIndex to controlIndex .5 indexes
  if (pageIndex+0.5 < MIN_CONTROL_INDEX)
    _controlIndex = MIN_CONTROL_INDEX;
  else if (pageIndex+0.5 > pageCount - 1.5)
    _controlIndex = pageCount - 1.5;
  else
    _controlIndex = pageIndex + 0.5;
  
  _controlAngle = 0;                            //initial angle for animation
  _controlFlipAngle = -THRESHOLD_HALF_ANGLE;
        
  //Setup Pepper UI
  [self setupReusablePoolPepperViews];
  [self reusePepperViews];
  self.pepperView.hidden = NO;
  
  //Quick & dirty trick to get correct initial angle
  self.controlIndex = self.controlIndex;
  [self flattenAllPepperViews:0];
  
  //Clone the book cover and add to backside of first page
  if (!self.hideFirstPage)
  {
    [self addBookCoverToFirstPageThenRemove:YES];
  }
  //Hide the book cover immediately
  else
  {
    UIView *bookCover = [self getBookViewAtIndex:self.currentBookIndex];
    bookCover.hidden = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.animationSlowmoFactor*OPEN_BOOK_DURATION * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
      bookCover.hidden = NO;
    });
  }
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:willOpenBookIndex:andDuration:)])
    [self.delegate ppPepperViewController:self willOpenBookIndex:bookIndex andDuration:self.animationSlowmoFactor*OPEN_BOOK_DURATION];
  
  //This is where magic happens (animation)
  [self showHalfOpen:YES];
}


#pragma mark - UI Helper functions (Page)

- (int)getCurrentPageIndex
{
  return self.currentPageIndex;
}

- (void)unloadPageScrollView:(BOOL)force
{
  if (!force)
    if (self.controlAngle >= 0 || self.isDetailView)
      return;
  
  self.pageScrollView.hidden = YES;
  
  while ([self.visiblePageViewArray count] > 0) {
    PPPageViewDetailWrapper *subview = [self.visiblePageViewArray objectAtIndex:0];
    subview.tag = -1;
    subview.hidden = YES;
    [subview unloadContent];
    [self.reusePageViewArray addObject:subview];   
    [self.visiblePageViewArray removeObjectAtIndex:0];
  }
  
  self.pageViewController.view.hidden = YES;
  self.pageViewController.delegate = nil;
  self.pageViewController.dataSource = nil;
  [self.pageViewController setViewControllers:nil direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:NULL];
}

- (void)destroyPageScrollView:(BOOL)force
{
  if (!force)
    if (self.controlAngle >= 0 || self.isDetailView)
      return;
    
  self.pageScrollView.hidden = YES;
  self.pageViewController.view.hidden = YES;
    
  [self.reusePageViewArray removeAllObjects];
  self.reusePageViewArray = nil;
  
  while ([self.visiblePageViewArray count] > 0) {
    PPPageViewDetailWrapper *subview = [self.visiblePageViewArray objectAtIndex:0];
    [subview unloadContent];
    [subview removeFromSuperview];
    [self.visiblePageViewArray removeObjectAtIndex:0];
  }
  self.visiblePageViewArray = nil;
}

- (void)setupReuseablePoolPageViews
{
  //No need to re-setup
  if (self.reusePageViewArray != nil || [self.reusePageViewArray count] > 0)
    return;
  
  if (self.reusePageViewArray == nil)
    self.reusePageViewArray = [[NSMutableArray alloc] init];
  if (self.visiblePageViewArray == nil)
  self.visiblePageViewArray = [[NSMutableArray alloc] init];
  
  //Reuseable views pool
  int total = self.enableOneSideZoom ? NUM_REUSE_DETAIL_VIEW : 2*NUM_REUSE_DETAIL_VIEW;
  for (int i=0; i<total; i++) {
    PPPageViewDetailWrapper *wrapperView = [[PPPageViewDetailWrapper alloc] initWithFrame:self.pageScrollView.bounds];
    [wrapperView setBackgroundImage:self.pageBackgroundImage];
    [self.reusePageViewArray addObject:wrapperView];
  }
}

- (void)setupPageScrollview
{  
  //Re-setup in case memory warning
  [self setupReuseablePoolPageViews];
    
  //Populate page scrollview
  [self reusePageScrollview];
    
  //Reset pages UI
  for (PPPageViewDetailWrapper *subview in self.visiblePageViewArray) {
    subview.hidden = NO;
    if (subview.tag == self.currentPageIndex)     [subview resetWithoutOffset:NO];
    else                                          [subview reset:NO];
  }
  
  [self updatePageScrollViewContentSize];
  [self scrollToPage:self.currentPageIndex duration:0];
  
  //Setup page flip effect
  if (iOS5AndAbove && self.enablePageCurlEffect)
    [self setupPageViewController];
  
  if (!self.enableOneSideMiddleZoom)
    return;
    
  //Scroll to vertically center
  PPPageViewDetailWrapper *wrapper = [self getDetailViewAtIndex:self.currentPageIndex];
  if (wrapper == nil)
    return;
    
  CGSize contentSize = wrapper.contentSize;
  int offsetX = 0;
  int offsetY = contentSize.height/2 - wrapper.bounds.size.height/2;
  wrapper.contentOffset = CGPointMake(offsetX, offsetY);
}

- (void)setupPageViewController
{
  if (!iOS5AndAbove)
    return;
  
  self.pageViewController.delegate = self;
  self.pageViewController.dataSource = self;
  self.pageViewController.view.hidden = NO;
  
  if ([self.pageViewController.viewControllers count] > 0)
    return;
  
  PPPageViewDetailController *currentViewController = [self getPageViewDetailControllerAtIndex:self.currentPageIndex];
  if (currentViewController == nil)
    return;
  
  //One page only
  if (self.enableOneSideZoom || [self isPortrait]) {
    NSArray *viewControllers = [NSArray arrayWithObject:currentViewController];
    [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:NULL];
    return;
  }
  
  NSArray *viewControllers = nil;
  if ((int)self.currentPageIndex % 2 == 0) {
    PPPageViewDetailController *nextViewController = [self getPageViewDetailControllerAtIndex:self.currentPageIndex+1];
    viewControllers = [NSArray arrayWithObjects:currentViewController, nextViewController, nil];
  }
  else 
  {
    PPPageViewDetailController *prevViewController = [self getPageViewDetailControllerAtIndex:self.currentPageIndex-1];
    viewControllers = [NSArray arrayWithObjects:prevViewController, currentViewController, nil];    
  }
  [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:NULL];
}

- (void)reusePageScrollview {
  int currentIndex = (int)self.currentPageIndex;
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
    
  //Visible indexes
  int total = self.enableOneSideZoom ? NUM_REUSE_DETAIL_VIEW : 2*NUM_REUSE_DETAIL_VIEW;
  int range = total / 3;
  int startIndex = currentIndex - range;
  if (startIndex < 0)
    startIndex = 0;
  int endIndex = startIndex + total - 1;
  if (endIndex > pageCount-1)
    endIndex = pageCount-1;
  
  //Reuse out of bound views
  for (int i=0; i<pageCount; i++)
    if (i < startIndex || i > endIndex)
      [self removePageFromScrollView:i];
    
  //Add new views
  for (int i=startIndex; i<=endIndex; i++)
    [self addPageToScrollView:i];
}

//
// Return the frame for this page in scrollview
// This is on the frame for scrollview inside scrollview, not content frame
//
- (CGRect)getFrameForPageIndex:(int)index forOrientation:(UIInterfaceOrientation)interfaceOrientation {
  
  BOOL isPortrait = UIInterfaceOrientationIsPortrait(interfaceOrientation);
  
  if (self.enableOneSideZoom || isPortrait) {
    int width = 2 * [self getMidXForOrientation:interfaceOrientation];
    int height = 2 * [self getMidYForOrientation:interfaceOrientation];
    int x = (self.hideFirstPage) ? (index-1)*width : index*width;
    return CGRectMake(x, 0, width, height);
  }
  
  //Zoom both side, landscape
  int width = [self getMidXForOrientation:interfaceOrientation];
  int x = (self.hideFirstPage) ? (index-1)*width : index*width;
  
  float contentAspectRatio = self.frameHeight / self.frameWidth;
  if (FRAME_ASPECT_RATIO > 0)
    contentAspectRatio = FRAME_ASPECT_RATIO;
  
  //Fit the aspect ratio to self when self.enableOneSideZoom is disabled
  if (!self.enableOneSideZoom)
    contentAspectRatio = self.view.bounds.size.height / [self getMidXForOrientation:interfaceOrientation];
  
  int height = contentAspectRatio * width;
  int y = [self getMidYForOrientation:interfaceOrientation] - height/2;   //vertically centered

  int maxHeight = 2 * [self getMidYForOrientation:interfaceOrientation];
  if (height > maxHeight) {
    height = maxHeight;
    y = 0;
  }  

  return CGRectMake(x, y, width, height);
}

//
// Return the frame for this page in scrollview
//
- (CGRect)getFrameForPageIndex:(int)index {
  return [self getFrameForPageIndex:index forOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

- (void)removePageFromScrollView:(int)index {
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
  
  for (PPPageViewDetailWrapper *subview in self.visiblePageViewArray) {
    if (subview.tag != index)
      continue;
    subview.tag = -1;
    [subview unloadContent];
    [self.reusePageViewArray addObject:subview];
    [self.visiblePageViewArray removeObject:subview];
    
    //This is quite expensive, substitute by just hiding it & use self.visiblePageViewArray to keep track
    //[subview removeFromSuperview];
    subview.hidden = YES;
    break;
  }
}

- (PPPageViewDetailWrapper*)getDetailViewAtIndex:(int)index {
  for (PPPageViewDetailWrapper *page in self.visiblePageViewArray) {
    if (page.tag != index)
      continue;
    if (![page isKindOfClass:[PPPageViewDetailWrapper class]])
      continue;
    return page;
  }
  return nil;
}

- (BOOL)hasPageInPageScrollView:(int)index
{
  BOOL retValue = NO;
  for (PPPageViewDetailWrapper *subview in self.visiblePageViewArray) {
    if (subview.tag == index) {
      retValue = YES;
      break;
    }
  }
  return retValue;
}

- (void)addPageToScrollView:(int)index {
  
  //Worst case senario: some bugs causing both array to be empty
  if ([self.reusePageViewArray count] <= 0 && [self.visiblePageViewArray count] <= 0)
    [self setupReuseablePoolPageViews];

  //Buffer is full
  if (self.reusePageViewArray.count <= 0)
    return;
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
  
  //Check if we already have this Page in scrollview
  if ([self hasPageInPageScrollView:index])
    return;
  
  PPPageViewDetailWrapper *pageDetailView = [self.reusePageViewArray objectAtIndex:0];
  [self.reusePageViewArray removeObjectAtIndex:0];
  if (pageDetailView == nil)
    return;

  CGRect pageFrame = [self getFrameForPageIndex:index];
  pageDetailView.tag = index; 
  pageDetailView.frame = pageFrame;
  pageDetailView.alpha = 1;
  
  BOOL useBookCoverImage = (FIRST_PAGE_BOOK_COVER && index <= 0 && !self.hideFirstPage);
  [pageDetailView setBackgroundImage:(useBookCoverImage ? self.bookCoverImage : self.pageBackgroundImage)];
   
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:detailViewForPageIndex:inBookIndex:withFrame:reusableView:)])
    pageDetailView.contentView = [self.dataSource ppPepperViewController:self detailViewForPageIndex:index inBookIndex:self.currentBookIndex withFrame:pageDetailView.bounds reusableView:pageDetailView.contentView];
  else
    [pageDetailView unloadContent];
  
  [pageDetailView layoutWithFrame:pageFrame duration:0];

  pageDetailView.customDelegate = self;
  pageDetailView.hidden = NO;
  [self.pageScrollView addSubview:pageDetailView];
  [self.visiblePageViewArray addObject:pageDetailView];
}

- (void)updatePageScrollViewContentSize
{
  [self updatePageScrollViewContentSizeForOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

- (void)updatePageScrollViewContentSizeForOrientation:(UIInterfaceOrientation)orientation
{
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex]; 
  int _pageCount = self.hideFirstPage ? pageCount-1 : pageCount;
    
  CGRect onePageFrame = [self getFrameForPageIndex:0 forOrientation:orientation];
  CGSize contentSize = CGSizeMake(_pageCount * CGRectGetWidth(onePageFrame), 20);
  self.pageScrollView.contentSize = contentSize;
}

- (void)scrollToPage:(int)pageIndex duration:(float)duration {
  [self scrollToPage:pageIndex duration:duration forOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

- (void)scrollToPage:(int)pageIndex duration:(float)duration forOrientation:(UIInterfaceOrientation)interfaceOrientation {
  
  CGRect pageFrame = [self getFrameForPageIndex:pageIndex forOrientation:interfaceOrientation];
  
  if (duration <= 0) {
    self.pageScrollView.contentOffset = CGPointMake(pageFrame.origin.x, 0);
    return;
  }
  
  [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.pageScrollView.contentOffset = CGPointMake(pageFrame.origin.x, 0);
  } completion:^(BOOL finished) {
  
  }];
}

- (void)openPageIndex:(int)pageIndex
{
  if (self.isBookView) {
    NSLog(@"You can't call this function in book mode");
    return;
  }
  if (self.isDetailView) {
    NSLog(@"You can't call this function in fullscreen mode");
    return;
  }
  
  //In landscape, with enableOneSideZoom disabled, need to set to even pageIndex
  if (!self.enableOneSideZoom && [self isLandscape])
    if (pageIndex % 2 != 0)
      pageIndex -= 1;
  
  self.currentPageIndex = pageIndex;
  self.zoomOnLeft = pageIndex%2==0;
  self.previousSpecialControlIndex = INVALID_NUMBER;
  
  [self unloadBookScrollView:NO];
  [self showFullscreenUsingTimer];
}

- (void)closeCurrentPage:(BOOL)animated
{
  if (self.isBookView) {
    NSLog(@"You can't call this function in book mode");
    return;
  }
  if ([self isPepperView]) {
    NSLog(@"You can't call this function in pepper mode");
    return;
  }
  
  if (animated) {
    [self showHalfOpenUsingTimer];
    return;
  }
  
  [self showHalfOpen:NO];
}



#pragma mark - UI Helper functions (Page flip effect)

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
  //Flip to the same page
  if (!completed)
    return;
  
  PPPageViewDetailController *currentViewController = [self.pageViewController.viewControllers objectAtIndex:0];
  int index = [self indexOfPageViewDetailController:currentViewController];
  self.currentPageIndex = index;
  
  self.pepperView.hidden = YES;
  self.pageScrollView.userInteractionEnabled = NO;
  self.zoomOnLeft = ((int)self.currentPageIndex % 2 == 0) ? YES : NO;
  self.controlIndex = ((int)self.currentPageIndex % 2 == 0) ? self.currentPageIndex+0.5 : self.currentPageIndex-0.5;
  //self.controlAngle = 0;
  
  [self reusePageScrollview];
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didSnapToPageIndex:)])
    [self.delegate ppPepperViewController:self didSnapToPageIndex:self.currentPageIndex];
}

- (UIPageViewControllerSpineLocation)pageViewController:(UIPageViewController *)pageViewController
                   spineLocationForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
  BOOL midSpine = !self.enableOneSideZoom && UIInterfaceOrientationIsLandscape(orientation);

  PPPageViewDetailController *currentViewController = nil;
  if ([self.pageViewController.viewControllers count] > 0)
    currentViewController = [self.pageViewController.viewControllers objectAtIndex:0];
  else
    currentViewController = [self getPageViewDetailControllerAtIndex:self.currentPageIndex];
  currentViewController.view.hidden = NO;
  
  //One side
  if (currentViewController == nil)
    return UIPageViewControllerSpineLocationNone;
  
  if (!midSpine) {
    [self.pageViewController setViewControllers:[NSArray arrayWithObject:currentViewController]
                                      direction:UIPageViewControllerNavigationDirectionForward 
                                       animated:NO 
                                     completion:NULL];    
    [self.pageViewController setDoubleSided:NO];
    return UIPageViewControllerSpineLocationMin;
  }

  //Side-by-side
  NSArray *viewControllers = nil;
  if ((int)self.currentPageIndex % 2 == 0) {
    UIViewController *nextViewController = [self.pageViewController.dataSource pageViewController:self.pageViewController
                                                                viewControllerAfterViewController:currentViewController];
    nextViewController.view.hidden = NO;
    viewControllers = [NSArray arrayWithObjects:currentViewController, nextViewController, nil];
  } else {
    UIViewController *previousViewController = [self.pageViewController.dataSource pageViewController:self.pageViewController 
                                                                   viewControllerBeforeViewController:currentViewController];
    previousViewController.view.hidden = NO;
    viewControllers = [NSArray arrayWithObjects:previousViewController, currentViewController, nil];
  }
  
  [self.pageViewController setViewControllers:viewControllers
                                    direction:UIPageViewControllerNavigationDirectionForward
                                     animated:NO 
                                   completion:NULL];
  [self.pageViewController setDoubleSided:YES];
  return UIPageViewControllerSpineLocationMid;
}

#pragma mark - Page View Controller Data Source

- (NSUInteger)indexOfPageViewDetailController:(PPPageViewDetailController *)viewController
{   
  return viewController.view.tag;
}

- (PPPageViewDetailController *)getPageViewDetailControllerAtIndex:(int)index
{   
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (pageCount <= 0 || index < 0 || index >= pageCount)
    return nil;
  
  PPPageViewDetailController *dataViewController = [[PPPageViewDetailController alloc] init];
  PPPageViewDetailWrapper *wrapper = [self getDetailViewAtIndex:index];
  dataViewController.view = wrapper;
  dataViewController.view.tag = index;
  dataViewController.view.hidden = NO;
  [wrapper removeFromSuperview];
  return dataViewController;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
  NSUInteger index = [self indexOfPageViewDetailController:(PPPageViewDetailController *)viewController];
  if ((index <= 0) || (index == NSNotFound)) {
    return nil;
  }
  
  index--;
  return [self getPageViewDetailControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
  NSUInteger index = [self indexOfPageViewDetailController:(PPPageViewDetailController *)viewController];
  if (index == NSNotFound)
    return nil;
  index++;
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index >= pageCount)
    return nil;
  return [self getPageViewDetailControllerAtIndex:index];
}




#pragma mark - Flipping implementation

- (float)maxControlIndex
{
  float limit = 0;
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (pageCount % 2 != 0)    limit = pageCount-0.5;       //odd
  else                       limit = pageCount-1.5;       //even
  return limit;
}

// This function controls everything about flipping
// @param: valid range 0.5 to [self maxControlIndex]
- (void)setControlIndex:(float)newIndex 
{
  //Temporary, should be an elastic scale
  float offset = 0.48;
  
  //lower limit
  if (newIndex < MIN_CONTROL_INDEX)
    newIndex = MIN_CONTROL_INDEX;
  
  //upper limit
  float limit = [self maxControlIndex] + offset;
  if (newIndex > limit)
    newIndex = limit;
  
  _controlIndex = newIndex;

  //Notify the delegate
  if ([self isPepperView])
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didFlippedWithIndex:)])
      [self.delegate ppPepperViewController:self didFlippedWithIndex:self.controlIndex];
  
  float theSpecialIndex = [self getCurrentSpecialIndex];
  float normalizedGroupControlIndex = 1.0 - (theSpecialIndex-newIndex) / 2.0 - 0.5;
  
  float angleDiff = -LEFT_RIGHT_ANGLE_DIFF;
  float max = -THRESHOLD_HALF_ANGLE;
  float min = -(180+max+angleDiff);
  float newControlFlipAngle = max - normalizedGroupControlIndex * fabs(max-min);
  self.controlFlipAngle = newControlFlipAngle;
}

- (void)setControlFlipAngle:(float)angle
{  
  float angleDiff = -LEFT_RIGHT_ANGLE_DIFF;
  float max = -THRESHOLD_HALF_ANGLE;
  float min = -(180+max+angleDiff);                    //note: this is max for 1 side   //-140

  //Limits
  if (angle > max)    angle = max;
  if (angle < min)    angle = min;
  _controlFlipAngle = angle;
  
  [self updateFlipPointers];

  int frameY = [self getFrameY];
  float angle2 = angle + angleDiff;
  float positionScale = fabs((angle-min) / fabs(max-min)) - 0.5;
  float scale1 = [self getPepperScaleForPageIndex:self.theView1.tag];
  float scale4 = [self getPepperScaleForPageIndex:self.theView4.tag];
  
  //Center
  if (fabs(angle) <= 90.0 && fabs(angle2) >= 90.0) {        
    scale1 = 1.0;
    scale4 = 1.0;
  }
    
  //Static one time calculations
  if (layer23WidthAtMid == 0) {
    CALayer *layer2 = self.theView2.layer;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, (max/2+min/2) * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    layer2.anchorPoint = CGPointMake(0, 0.5);
    layer2.transform = transform;
    layer23WidthAtMid = layer2.frame.size.width;
  }
  if (layer2WidthAt90 == 0) {
    CALayer *layer2 = self.theView2.layer;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, (-90-angleDiff) * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    layer2.anchorPoint = CGPointMake(0, 0.5);
    layer2.transform = transform;
    layer2WidthAt90 = layer2.frame.size.width;
  }

  //Transformation for center 4 pages
  CALayer *layer1 = self.theView1.layer;
  CATransform3D transform = CATransform3DIdentity;
  transform.m34 = self.m34;
  transform = CATransform3DRotate(transform, (min+angleDiff) * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
  transform = CATransform3DScale(transform, scale1,scale1, 1.0);
  layer1.anchorPoint = CGPointMake(0, 0.5);
  layer1.transform = transform;
  
  CALayer *layer2 = self.theView2.layer;
  transform = CATransform3DIdentity;
  transform.m34 = self.m34;
  transform = CATransform3DRotate(transform, angle * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
  layer2.anchorPoint = CGPointMake(0, 0.5);
  layer2.transform = transform;
  
  CALayer *layer3 = self.theView3.layer;
  transform = CATransform3DIdentity;
  transform.m34 = self.m34;
  transform = CATransform3DRotate(transform, angle2 * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
  layer3.anchorPoint = CGPointMake(0, 0.5);
  layer3.transform = transform;
  
  CALayer *layer4 = self.theView4.layer;
  transform = CATransform3DIdentity;
  transform.m34 = self.m34;
  transform = CATransform3DRotate(transform, max * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
  transform = CATransform3DScale(transform, scale4,scale4, 1.0);
  layer4.anchorPoint = CGPointMake(0, 0.5);
  layer4.transform = transform;
  
  float position = position = CGRectGetMidX(self.view.bounds) + 2*positionScale*layer23WidthAtMid;
  self.theView2.frame = CGRectMake(position-layer23WidthAtMid, frameY, self.frameWidth, self.frameHeight);
  self.theView3.frame = CGRectMake(position+layer23WidthAtMid, frameY, self.frameWidth, self.frameHeight);
  self.theView1.hidden = NO;
  self.theView4.hidden = NO;
  
  //Center
  if (fabs(angle) <= 90.0 && fabs(angle2) >= 90.0) {        
    self.theView1.frame = CGRectMake(CGRectGetMinX(layer2.frame), frameY, self.frameWidth, self.frameHeight);
    self.theView4.frame = CGRectMake(CGRectGetMaxX(layer3.frame), frameY, self.frameWidth, self.frameHeight);
    self.theView2.hidden = NO;
    self.theView3.hidden = NO;
  }
  //Flip to left
  else if (fabs(angle) > 90.0 && fabs(angle2) > 90.0) {
    self.theView1.frame = CGRectMake(CGRectGetMaxX(layer3.frame) - layer2WidthAt90 - (MINOR_X_ADJUSTMENT_14*deviceFactor) - layer2WidthAt90*positionScale/2.5,
                                     frameY, self.frameWidth, self.frameHeight);
    self.theView4.frame = CGRectMake(CGRectGetMaxX(layer3.frame), frameY, self.frameWidth, self.frameHeight);
    self.theView2.hidden = YES;
    self.theView3.hidden = NO;
  }
  //Flip to right
  else {
    self.theView1.frame = CGRectMake(CGRectGetMinX(layer2.frame), frameY, self.frameWidth, self.frameHeight);
    self.theView4.frame = CGRectMake(CGRectGetMinX(layer2.frame) + layer2WidthAt90 + (MINOR_X_ADJUSTMENT_14*deviceFactor) - layer2WidthAt90*positionScale/2.5,
                                     frameY, self.frameWidth, self.frameHeight);
    self.theView2.hidden = NO;
    self.theView3.hidden = YES;
  }
  
  //Visible range
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  int range = NUM_VISIBLE_PAGE_ONE_SIDE * 2 + 1;        //plus buffer
  float currentIndex = [self getCurrentSpecialIndex];
  int startIndex = currentIndex - range + 2;            //because currentIndex is being bias towards the left
  if (startIndex < 0)
    startIndex = 0;
  int endIndex = startIndex + range*2;
  if (endIndex > pageCount-1)
    endIndex = pageCount-1;
  
  //Hide irrelevant pages
  for (int i=startIndex-1; i <= endIndex+1; i++) {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    if (self.hideFirstPage && i==0) {
      page.hidden = YES;
      continue;
    }
    if ([page isEqual:self.theView1] || [page isEqual:self.theView2] || [page isEqual:self.theView3] || [page isEqual:self.theView4])
      continue;
    
    if (i < self.controlIndex && i%2!=0) {
      page.hidden = YES;
      continue;
    }
    if (i >= self.controlIndex && i%2==0) {
      page.hidden = YES;
      continue;
    }
    
    page.hidden = NO;
    
    float scale = [self getPepperScaleForPageIndex:i];
    
    if (i < self.controlIndex) {
      CALayer *layerLeft = page.layer;
      CATransform3D transform = CATransform3DIdentity;
      transform.m34 = self.m34;
      transform = CATransform3DRotate(transform, (min+angleDiff) * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
      transform = CATransform3DScale(transform, scale,scale, 1.0);
      layerLeft.anchorPoint = CGPointMake(0, 0.5);
      layerLeft.transform = transform;
    }
    else {
      CALayer *layerRight = page.layer;
      CATransform3D transform = CATransform3DIdentity;
      transform.m34 = self.m34;
      transform = CATransform3DRotate(transform, max * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
      transform = CATransform3DScale(transform, scale,scale, 1.0);
      layerRight.anchorPoint = CGPointMake(0, 0.5);
      layerRight.transform = transform;
    }

    //Smooth transition of position
    float frameX = [self getPepperFrameXForPageIndex:i gapScale:1.0];
    page.frame = CGRectMake(frameX, frameY, self.frameWidth, self.frameHeight);
  }
}

- (void)updateFlipPointers
{
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  float theSpecialIndex = [self getCurrentSpecialIndex];
  BOOL specialIndexChanged = NO;
  
  //Detect change of page flipping index for cell reuse purpose
  if (self.previousSpecialControlIndex == INVALID_NUMBER) {
    self.previousSpecialControlIndex = theSpecialIndex;
    specialIndexChanged = YES;
  }
  
  if (self.previousSpecialControlIndex != theSpecialIndex)
    specialIndexChanged = YES;
  
  self.previousSpecialControlIndex = theSpecialIndex;
  
  if (!specialIndexChanged)
    return;
  
  [self onSpecialControlIndexChanged];
  
  self.theView1 = nil;
  self.theView2 = nil;
  self.theView3 = nil;
  self.theView4 = nil;
  
  float tempIndex1 = (int)round(theSpecialIndex - 1.5f);
  float tempIndex2 = (int)round(theSpecialIndex - 0.5f);
  float tempIndex3 = (int)round(theSpecialIndex + 0.5f);
  float tempIndex4 = (int)round(theSpecialIndex + 1.5f);

  if (tempIndex1 < 0 || tempIndex1 >= pageCount)    tempIndex1 = -1;
  if (tempIndex2 < 0 || tempIndex2 >= pageCount)    tempIndex2 = -1;
  if (tempIndex3 < 0 || tempIndex3 >= pageCount)    tempIndex3 = -1;
  if (tempIndex4 < 0 || tempIndex4 >= pageCount)    tempIndex4 = -1;
  
  //Optimized code
  for (PPPageViewContentWrapper *page in self.visiblePepperWrapperArray)
  {
    if (self.theView1 == nil && tempIndex1 >= 0)
    {
      if (page.tag == tempIndex1) {
        self.theView1 = page;
        continue;
      }
    }
    
    if (self.theView2 == nil && tempIndex2 >= 0)
    {
      if (page.tag == tempIndex2) {
        self.theView2 = page;
        continue;
      }
    }
    
    if (self.theView3 == nil && tempIndex3 >= 0)
    {
      if (page.tag == tempIndex3) {
        self.theView3 = page;
        continue;
      }
    }
    
    if (self.theView4 == nil && tempIndex4 >= 0)
    {
      if (page.tag == tempIndex4) {
        self.theView4 = page;
        continue;
      }
    }
  }
}

- (void)onSpecialControlIndexChanged {
  [self reusePepperViews];
}

- (void)animateControlIndexTo:(float)index duration:(float)duration
{
  if (self.controlIndexTimer != nil || [self.controlIndexTimer isValid])
    return;
  
  //Upper limit
  float limit = [self maxControlIndex];
  if (index < MIN_CONTROL_INDEX)
    index = MIN_CONTROL_INDEX;
  if (index > limit)
    index = limit;
  self.controlIndexTimerTarget = index;
  
  if (duration <= 0) {
    [self onControlIndexTimerFinish];
    return;
  }
  
  //0.016667 = 1/60
  self.controlIndexTimerLastTime = [[NSDate alloc] init];
  self.controlIndexTimerDx = (self.controlIndexTimerTarget - self.controlIndex) / (duration / TIMER_INTERVAL);
  self.controlIndexTimer = [NSTimer scheduledTimerWithTimeInterval: TIMER_INTERVAL
                                                            target: self
                                                          selector: @selector(onControlIndexTimer:)
                                                          userInfo: nil
                                                           repeats: YES];
}

- (void)onControlIndexTimer:(NSTimer *)timer
{
  NSDate *nowDate = [[NSDate alloc] init];
  float deltaMs = fabsf([self.controlIndexTimerLastTime timeIntervalSinceNow]);
  self.controlIndexTimerLastTime = nowDate;
  float deltaDiff = deltaMs / TIMER_INTERVAL;
  
  float newValue = self.controlIndex + self.controlIndexTimerDx * deltaDiff;
  /*
  if (newValue > [self maxControlIndex])
    newValue = [self maxControlIndex];
   */
  
  if (self.controlIndexTimerDx >= 0 && newValue > self.controlIndexTimerTarget)
    newValue = self.controlIndexTimerTarget;
  else if (self.controlIndexTimerDx < 0 && newValue < self.controlIndexTimerTarget)
    newValue = self.controlIndexTimerTarget;

  BOOL finish = newValue == self.controlIndex || fabs(newValue - self.controlIndexTimerTarget) <= fabs(self.controlIndexTimerDx*1.5);
  
  if (!finish) {
    self.controlIndex = newValue;
    return;
  }
  
  [self onControlIndexTimerFinish];
}

- (void)onControlIndexTimerFinish
{
  [self.controlIndexTimer invalidate];
  self.controlIndexTimer = nil;
  
  [self reusePepperViews];
  
  float newValue = self.controlIndexTimerTarget;
  if (newValue > [self maxControlIndex])
    newValue = [self maxControlIndex];
  self.controlIndex = newValue;
  
  _controlAngle = -THRESHOLD_HALF_ANGLE;
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didFinishFlippingWithIndex:)])
    [self.delegate ppPepperViewController:self didFinishFlippingWithIndex:self.controlIndex];
}

#pragma mark - Pinch control implementation

- (void)showFullscreenUsingTimer
{
  self.isBookView = NO;
  
  float diff = fabs(self.controlAngle - 0) / 45.0;
  if (!self.enableOneSideZoom)    diff /= 1.3;
  else                            diff *= 1.3;
    
  [self animateControlAngleTo:0 duration:self.animationSlowmoFactor*diff];
  
  //Worst case senario
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (1.5 * self.animationSlowmoFactor) * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    //[self destroyPepperView:NO];
    [self unloadPepperView:NO];
  });
}

- (void)showFullscreen:(BOOL)animated
{
  self.isBookView = NO;

  //Populate detailed page scrollview
  [self setupPageScrollview];
  
  if (!animated) {
    self.controlAngle = 0;
    self.pageScrollView.hidden = NO;
    self.pageViewController.view.hidden = NO;
    return;
  }
  
  float diff = fabs(self.controlAngle - 0) / 90.0;
  if (!self.enableOneSideZoom)    diff /= 1.3;
  else                      diff *= 1.3;
  
  [UIView animateWithDuration:self.animationSlowmoFactor*diff delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.controlAngle = 0;
  } completion:^(BOOL finished) {
    self.pageScrollView.hidden = NO;
    self.pageViewController.view.hidden = NO;
  }];
}

- (void)showHalfOpenUsingTimer
{
  self.isBookView = NO;
      
  float diff = fabs(self.controlAngle - (-THRESHOLD_HALF_ANGLE)) / 90.0;
  float duration = diff * 1.3;
  if (duration < 0.2)     duration = 0.2;
  if (duration > 0.5)     duration = 0.5;
    
  [self animateControlAngleTo:-THRESHOLD_HALF_ANGLE duration:self.animationSlowmoFactor*duration];

  //Worst case senario
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (1.5 * self.animationSlowmoFactor) * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    //[self destroyPageScrollView:NO];
    [self unloadPageScrollView:NO];
  });
}

//
// This is only used in opening a book
//
- (void)showHalfOpen:(BOOL)animated
{
  BOOL previousIsBookView = self.isBookView;
  self.isBookView = NO;
  self.isDetailView = NO;
  
  //[self destroyPageScrollView:NO];
  [self unloadPageScrollView:NO];
  
  //Re-setup book scrollview if we are coming out from fullscreen
  //And also apply correct scaling for books
  if (!previousIsBookView) {
    [self setupReuseablePoolBookViews];
    [self reuseBookScrollView];
    [self updateBookScrollViewBookScale];
  }
  
  if (!animated) {   
    self.controlAngle = -THRESHOLD_HALF_ANGLE;
    _controlFlipAngle = -THRESHOLD_HALF_ANGLE;
    self.controlIndex = self.controlIndex;
    return;
  }
  
  float diff = fabs(self.controlAngle - (-THRESHOLD_HALF_ANGLE)) / 90.0;
  float duration = diff * 2;
  
  [UIView animateWithDuration:self.animationSlowmoFactor*duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.controlAngle = -THRESHOLD_HALF_ANGLE;
  } completion:^(BOOL finished) {
    _controlFlipAngle = -THRESHOLD_HALF_ANGLE;
    self.controlIndex = self.controlIndex;
    self.currenPageContentOffsetY = 0;
    
    //Notify the delegate
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didOpenBookIndex:atPageIndex:)])
      [self.delegate ppPepperViewController:self didOpenBookIndex:self.currentBookIndex atPageIndex:self.currentPageIndex];
  }];
}

- (void)closeCurrentBook:(BOOL)animated
{
  self.isDetailView = NO;
  
  float diff = fabs(self.controlAngle - (-MAXIMUM_ANGLE)) / 90.0 / 1.3;
  if (diff < 0.4)
    diff = 0.4;
  
  //Unload fullscreen view
  //[self destroyPageScrollView:NO];
  [self unloadPageScrollView:NO];
  
  //Re-setup book scrollview if needed
  [self setupReuseablePoolBookViews];
  [self reuseBookScrollView];
  [self addBookToScrollView:self.currentBookIndex];
  
  //Reapply scaling to book views
  [self scrollViewDidScroll:self.bookScrollView];

  //Replace 1st page by book cover, need to redo this due to pepper page reuse
  [self addBookCoverToFirstPageThenRemove:NO];
  
  //Should be already visible, just for sure
  self.bookScrollView.alpha = 1;
  for (UIView *subview in self.visibleBookViewArray)
    if (subview.tag != self.currentBookIndex) {
      subview.alpha = 1;
      subview.hidden = NO;
    }
  
  if (!animated) {
    self.isBookView = YES;
    [self removeBookCoverFromFirstPage];
    [self destroyPepperView:NO];
    //[self unloadPepperView:NO];     //pepper view can't seem to recover from this
    return;
  }
  
  self.view.userInteractionEnabled = NO;
  
  //This is where magic happens (animation)
  [self flattenAllPepperViews:diff];
  
  //Not perfect but good enough for fast animation
  float animationDuration = self.animationSlowmoFactor*diff;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (animationDuration+0.1) * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    self.isBookView = YES;
   
    //Notify the delegate
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didCloseBookIndex:)])
      [self.delegate ppPepperViewController:self didCloseBookIndex:self.currentBookIndex];
  });

  //Memory management
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (animationDuration+0.3) * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    [self removeBookCoverFromFirstPage];
    [self destroyPepperView:NO];
    self.view.userInteractionEnabled = YES;
    //[self unloadPepperView:NO];     //pepper view can't seem to recover from this
  });
}

- (void)flattenAllPepperViews:(float)animationDuration
{
  float flatAngle = 0;
  float scale = MAX_BOOK_SCALE;
  
  //Find the first visible page view (already replaced by book cover)
  int firstPageIndex = [self getFirstVisiblePepperPageIndex];

  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  for (int i=0; i<pageCount; i++) {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    
    //Position
    int frameY = [self getFrameY];
    int midX = [self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
    float x = midX - self.frameWidth/2 * MAX_BOOK_SCALE;
    CGRect pageFrame = CGRectMake(x, frameY, self.frameWidth, self.frameHeight);
    
    //Alpha
    float alpha = 0;
    if (i == firstPageIndex)
      alpha = 1;
        
    //Transformation
    CALayer *layer = page.layer;
    layer.anchorPoint = CGPointMake(0, 0.5);
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, flatAngle * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    transform = CATransform3DScale(transform, scale,scale, 1.0);
    
    if (animationDuration <= 0) {
      page.frame = pageFrame;
      page.alpha = 1;
      layer.transform = transform;
      continue;
    }
    
    //Other page hide faster to avoid Z-conflict
    [UIView animateWithDuration:self.animationSlowmoFactor*animationDuration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
      page.frame = pageFrame;
      page.alpha = alpha;
    } completion:^(BOOL finished) {
      page.alpha = 1;
    }];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation.toValue = [NSValue valueWithCATransform3D:transform];
    animation.duration = self.animationSlowmoFactor * animationDuration;
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];    
    [layer addAnimation:animation forKey:[NSString stringWithFormat:@"closeBookAnimation%d",i]];
  }
}

- (void)addBookCoverToFirstPageThenRemove:(BOOL)animated
{
  if (self.theBookCover != nil)
    return;
  
  self.theBookCover = [self getBookViewAtIndex:self.currentBookIndex];
  if (self.theBookCover == nil)
    return;
  
  //Find the first visible page view
  //This is in case user open at non-zero page
  int firstPageIndex = [self getFirstVisiblePepperPageIndex];
  PPPageViewContentWrapper *firstPageView = [self getPepperPageAtIndex:firstPageIndex];
  if (firstPageView == nil)
    return;

  firstPageView.hidden = NO;
  [firstPageView addSubview:self.theBookCover];
  [firstPageView.superview bringSubviewToFront:firstPageView];
  firstPageView.shadowOpacity = 0;
  self.theBookCover.layer.transform = CATransform3DIdentity;
  self.theBookCover.frame = firstPageView.bounds;
  self.theBookCover.hidden = NO;
  self.theBookCover.alpha = 1;

  if (!animated)
    return;
    
  //Remove layer later (not the best implementation, but looks almost perfect even in slo-mo)
  float animationDuration = self.animationSlowmoFactor*OPEN_BOOK_DURATION;
  float removeCoverDuration = 90.0/(180.0-THRESHOLD_HALF_ANGLE) * animationDuration;
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, removeCoverDuration * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    [self hideBookCoverFromFirstPage];
  });
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (animationDuration+0.2) * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    [self removeBookCoverFromFirstPage];
  });
}

- (void)hideBookCoverFromFirstPage
{
  if (self.theBookCover == nil)
    return;
  self.theBookCover.hidden = YES;
}

- (void)removeBookCoverFromFirstPage
{ 
  if (self.theBookCover == nil)
    return;
  
  [self.theBookCover removeFromSuperview];

  //Add it back to book scrollview
  [self.bookScrollView addSubview:self.theBookCover];
  self.theBookCover.hidden = NO;
  self.theBookCover.transform = CGAffineTransformIdentity;
  self.theBookCover.frame = [self getFrameForBookIndex:self.theBookCover.tag];
  self.theBookCover.layer.transform = CATransform3DMakeScale(MAX_BOOK_SCALE, MAX_BOOK_SCALE, MAX_BOOK_SCALE);
  
  //De-reference
  self.theBookCover = nil;
}

- (void)updateLeftRightPointers
{
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  int tempIndex = 0;
  self.theLeftView = nil;
  self.theRightView = nil;
  
  tempIndex = (int)round(self.controlIndex - 0.5f);
  if (tempIndex >= 0 && tempIndex < pageCount)
    self.theLeftView = [self getPepperPageAtIndex:tempIndex];
  
  tempIndex = (int)round(self.controlIndex + 0.5f);
  if (tempIndex >= 0 && tempIndex < pageCount)
    self.theRightView = [self getPepperPageAtIndex:tempIndex];
}

//
// Snap control angle to 3 thresholds
//
- (void)snapControlAngle
{  
  if (self.controlAngle > -THRESHOLD_FULL_ANGLE) {
    [self showFullscreenUsingTimer];
  }
  
  else if (self.controlAngle > -THRESHOLD_CLOSE_ANGLE) {
    [self showHalfOpenUsingTimer];
  }
  
  else {
    [self closeCurrentBook:YES];
  }
}

// This function controls everything about zooming
// @param: valid range 0 to -MAXIMUM_ANGLE
//                     0: fully open (flat)
//        -MAXIMUM_ANGLE: fully closed (leave a bit of perspective)
- (void)setControlAngle:(float)newControlAngle
{ 
  //Limits
  if (newControlAngle > 0)                  newControlAngle = 0;
  if (newControlAngle < -MAXIMUM_ANGLE)     newControlAngle = -MAXIMUM_ANGLE;
  float previousControlAngle = _controlAngle;
  _controlAngle = newControlAngle;
  
  BOOL hasNoPageScrollView = self.reusePageViewArray == nil;
  BOOL switchingToBookView = previousControlAngle > -THRESHOLD_HALF_ANGLE-30 && newControlAngle <= -THRESHOLD_HALF_ANGLE-30;
  BOOL switchingToFullscreen = previousControlAngle < 0 && newControlAngle >= 0;
  BOOL switchingToPepper = previousControlAngle >= 0 && newControlAngle < 0;
  BOOL switchingFromPepperToFullscreen = previousControlAngle <= -THRESHOLD_HALF_ANGLE && newControlAngle > -THRESHOLD_HALF_ANGLE && hasNoPageScrollView;
  BOOL zoomingOneSide = self.enableOneSideZoom || [self isPortrait];
  
  if (switchingToFullscreen)
    for (PPPageViewDetailWrapper *subview in self.visiblePageViewArray)
      [subview setEnableScrollingZooming:zoomingOneSide];   
  
  //Memory management
  if (switchingFromPepperToFullscreen)
  {
    self.currenPageContentOffsetY = INVALID_NUMBER;
    [self reorderPepperViews];
    
    //Notify the delegate
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:willOpenPageIndex:)])
      [self.delegate ppPepperViewController:self willOpenPageIndex:self.currentPageIndex];
  }
  else if (switchingToFullscreen)
  {
    [self setupPageScrollview];
    self.pepperView.hidden = YES;
  }
  else if (switchingToPepper)
  {
    //For intermediate zoom OUT
    PPPageViewDetailWrapper *detailView = [self getDetailViewAtIndex:self.currentPageIndex];
    self.currenPageContentOffsetY = detailView.contentOffset.y;
    
    [self setupReusablePoolPepperViews];
    [self reusePepperViews];
    self.pepperView.hidden = NO;
    self.previousSpecialControlIndex = INVALID_NUMBER;
  }
  else if (switchingToBookView)
  {
    [self setupReuseablePoolBookViews];
    [self reuseBookScrollView];   
    //Reapply scaling to book views
    [self scrollViewDidScroll:self.bookScrollView];
  }
  
  //--------------------
  
  //Show/hide Pepper & Page scrollview accordingly
  self.pageScrollView.hidden = (newControlAngle < 0);
  self.pageViewController.view.hidden = (newControlAngle < 0);
  self.isDetailView = !self.pageScrollView.hidden;
  if (!self.isBookView && newControlAngle < 0)
    self.pepperView.hidden = NO;
  
  //General scale for all frames
  float scale = [self getPepperScaleForPageIndex:self.controlIndex];
  
  //Frame scale factor
  float frameScale = 0;
  if (newControlAngle > -THRESHOLD_HALF_ANGLE)
    frameScale = 1.0 - (newControlAngle/(-THRESHOLD_HALF_ANGLE));       //0 to 1
  
  //Alpha factor
  CGFloat alpha = 0;
  if (newControlAngle > -THRESHOLD_HALF_ANGLE-40) {
    alpha = 0;
  }
  else {
    alpha = fabs(newControlAngle - (-THRESHOLD_HALF_ANGLE-40)) / 20;
    if (alpha > 1)
      alpha = 1;
  }
  
  //Angle factor
  float angleZoomInFactor = 1.0f - fabsf(newControlAngle/THRESHOLD_HALF_ANGLE);
  
  float angle = newControlAngle;
  float angle2 = -180.0 - angle;
  
  [self updateLeftRightPointers];
  //[self updateFlipPointers];
        
  //Fade book scrollview
  self.bookScrollView.alpha = alpha;
  UIView *bookCover = [self getBookViewAtIndex:self.currentBookIndex];
  [bookCover setAlpha:0];
  
  //Notify the delegate
  if (self.controlAngle < -THRESHOLD_HALF_ANGLE)
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:closingBookWithAlpha:)])
      [self.delegate ppPepperViewController:self closingBookWithAlpha:alpha];
  
  //Calculate zoomFrame for all pages, all pages share mostly the same frame
  int frameY = [self getFrameY];
  int midX = [self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
  int midY = [self getMidYForOrientation:[UIApplication sharedApplication].statusBarOrientation];
  int midPositionX = [self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
  float frameAspectRatio = (float)self.frameWidth / (float)self.frameHeight;
  float fullHeight = self.view.bounds.size.width / frameAspectRatio;

  CGRect originalFrame = CGRectMake(midPositionX, frameY, self.frameWidth, self.frameHeight);
  CGRect zoomedFrame;
  
  //Zoom in on 1 side
  if (zoomingOneSide)
  {    
    zoomedFrame.origin.x = originalFrame.origin.x + ((self.zoomOnLeft ? self.view.bounds.size.width : 0) - originalFrame.origin.x) * frameScale;
    zoomedFrame.size.width = originalFrame.size.width + (self.view.bounds.size.width - originalFrame.size.width) * frameScale;
    zoomedFrame.size.height = zoomedFrame.size.width / frameAspectRatio;

    //Reset content offset upon opening
    if (self.currenPageContentOffsetY == INVALID_NUMBER)
      self.currenPageContentOffsetY = 0;

    //Zoom INTO middle of page
    float fullFrameY = 0;
    if (hasNoPageScrollView && self.enableOneSideMiddleZoom)      fullFrameY = midY - fullHeight/2;
    //Intermediate zoom OUT (normal case)
    else                                                          fullFrameY = - self.currenPageContentOffsetY;
    
    float fullDy = frameY - fullFrameY;
    zoomedFrame.origin.y = originalFrame.origin.y - (fullDy * frameScale) - EDGE_PADDING*frameScale;
    
    self.currentPageIndex = self.zoomOnLeft ? self.controlIndex - 0.5 : self.controlIndex + 0.5;
  }
  //Zoom both side
  else
  {
    zoomedFrame.origin.x = originalFrame.origin.x;
    zoomedFrame.size.width = originalFrame.size.width + (self.view.bounds.size.width/2 - originalFrame.size.width) * frameScale;
    zoomedFrame.size.height = zoomedFrame.size.width / frameAspectRatio;
    zoomedFrame.origin.y = CGRectGetMidY(originalFrame) - zoomedFrame.size.height/2;    //vertically centered
    
    self.currentPageIndex = self.controlIndex - 0.5;
  }

  //This is very expensive because the frame changes & invalidate the rasterization cache
  //self.theLeftView.frame = zoomedFrame;
  //self.theRightView.frame = zoomedFrame;
    
  //So we keep the frame size the same, vary only origin.x & scale the layer with frameZoomScaleX/Y
  float newMidYFullDy = CGRectGetMidY(zoomedFrame) - CGRectGetMidY(originalFrame);
  frameY = originalFrame.origin.y + (newMidYFullDy * frameScale);
  self.theLeftView.frame = CGRectMake(zoomedFrame.origin.x, frameY, self.frameWidth, self.frameHeight);
  self.theRightView.frame = CGRectMake(zoomedFrame.origin.x, frameY, self.frameWidth, self.frameHeight);
  float frameZoomScaleX = zoomedFrame.size.width / originalFrame.size.width;
  float frameZoomScaleY = zoomedFrame.size.height / originalFrame.size.height;
  
  CALayer *layerLeft = self.theLeftView.layer;
  CATransform3D transform = CATransform3DIdentity;
  transform.m34 = self.m34;
  transform = CATransform3DRotate(transform, angle2 * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
  transform = CATransform3DScale(transform, scale*frameZoomScaleX, scale*frameZoomScaleY, 1.0);
  layerLeft.anchorPoint = CGPointMake(0, 0.5);
  layerLeft.transform = transform;
  self.theLeftView.hidden = [self.theLeftView isEqual:[self getPepperPageAtIndex:0]] && self.hideFirstPage ? YES : NO;
  
  CALayer *layerRight = self.theRightView.layer;
  transform = CATransform3DIdentity;
  transform.m34 = self.m34;
  transform = CATransform3DRotate(transform, angle * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
  transform = CATransform3DScale(transform, scale*frameZoomScaleX, scale*frameZoomScaleY, 1.0);
  layerRight.anchorPoint = CGPointMake(0, 0.5);
  layerRight.transform = transform;
  self.theRightView.hidden = NO;
  
  //------------------
  
  //This is for shifting the entire animation to one side upon zooming in on 1 side
  int diffFromMidX = zoomedFrame.origin.x - midX;
      
  //Notify the delegate
  if (self.controlAngle > -THRESHOLD_HALF_ANGLE && self.controlAngle <= 0) {
    float scale = 1.0 + self.controlAngle / fabs(THRESHOLD_HALF_ANGLE);
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didZoomWithPageIndex:zoomScale:)])
      [self.delegate ppPepperViewController:self didZoomWithPageIndex:self.currentPageIndex zoomScale:scale];
  }
    
  //Hide unneccessary pages
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  for (int i=0; i <pageCount; i++)
  {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    if ([page isEqual:self.theLeftView] || [page isEqual:self.theRightView])
      continue;
    
    if (i==0 && self.hideFirstPage) {
      page.hidden = YES;
      continue;
    }
    
    if (i < self.controlIndex && i%2!=0) {
      page.hidden = YES;
      continue;
    }
    if (i >= self.controlIndex && i%2==0) {
      page.hidden = YES;
      continue;
    }
 
    page.hidden = NO;
  }
  
  //degree, must not go beyond 0 to avoid wrong z-index
  //because angle & angle2 are already half
  //The correct fomular should be THRESHOLD_HALF_ANGLE/2+0.5, but positionScale can't sync nicely with this
  float newAngleVariation = THRESHOLD_HALF_ANGLE * angleZoomInFactor;
      
  //Other pages position & frame
  
  //This controls the pulling together of the pages when closing book
  float positionScale = 1.0f;
  if (newControlAngle > -THRESHOLD_HALF_ANGLE) {
    positionScale = 1.0f - 1.05f * angleZoomInFactor;
  }
  else {
    positionScale = 1.0f - fabs(newControlAngle-(-THRESHOLD_HALF_ANGLE)) / fabs(-MAXIMUM_ANGLE-(-THRESHOLD_HALF_ANGLE));
    positionScale = 0.07f + positionScale * 0.93f;
  }
  if (positionScale <= 0.05)
    positionScale = 0.05;
  
  for (int i=0; i <pageCount; i++)
  {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    if ([page isEqual:self.theLeftView] || [page isEqual:self.theRightView])
      continue;
    if (page.hidden)
      continue;
        
    //New position of frame
    float frameX = [self getPepperFrameXForPageIndex:i gapScale:(float)positionScale];
    if (self.enableOneSideZoom || [self isPortrait])
      frameX += diffFromMidX;
    
    //We keep the frame size the same, vary only origin.x & scale the layer with additionalScale
    page.frame = CGRectMake(frameX, frameY, self.frameWidth, self.frameHeight);
    
    float otherPageScale = [self getPepperScaleForPageIndex:i];
    
    //When closing: follow the 2 middle page
    //When opening: bend the angle backwards
    float newAngle = i < self.controlIndex ? angle2 : angle;
    if (newControlAngle > -THRESHOLD_HALF_ANGLE)
    {
      if (i < self.controlIndex) {
        newAngle -= newAngleVariation;
        if (newAngle < -180)
          newAngle = -180;
      }
      else {
        newAngle += newAngleVariation;
        if (newAngle > 0)
          newAngle = 0;
      }
    }
        
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, newAngle * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    transform = CATransform3DScale(transform, otherPageScale*frameZoomScaleX, otherPageScale*frameZoomScaleY, 1.0);
    page.layer.anchorPoint = CGPointMake(0, 0.5);
    page.layer.transform = transform;
  }
}

- (void)animateControlAngleTo:(float)angle duration:(float)duration
{
  if (self.controlAngleTimer != nil || [self.controlAngleTimer isValid])
    return;
    
  if (duration <= 0 || fabsf(self.controlAngle-angle) <= 0) {
    [self onControlAngleTimerFinish];
    return;
  }
  
  //TIMER_INTERVAL = 1/60
  self.controlAngleTimerLastTime = [[NSDate alloc] init];
  self.controlAngleTimerTarget = angle;
  self.controlAngleTimerDx = (self.controlAngleTimerTarget - self.controlAngle) / (duration / TIMER_INTERVAL);
  self.controlAngleTimer = [NSTimer scheduledTimerWithTimeInterval: TIMER_INTERVAL
                                                            target: self
                                                          selector: @selector(onControlAngleTimer:)
                                                          userInfo: nil
                                                           repeats: YES];
}

- (void)onControlAngleTimer:(NSTimer *)timer
{
  NSDate *nowDate = [[NSDate alloc] init];
  float deltaMs = fabsf([self.controlAngleTimerLastTime timeIntervalSinceNow]);
  self.controlAngleTimerLastTime = nowDate;
  float deltaDiff = deltaMs / TIMER_INTERVAL;
  
  float newValue = self.controlAngle + self.controlAngleTimerDx * deltaDiff;
  if (self.controlAngleTimerDx >= 0 && newValue > self.controlAngleTimerTarget)
    newValue = self.controlAngleTimerTarget;
  else if (self.controlAngleTimerDx < 0 && newValue < self.controlAngleTimerTarget)
    newValue = self.controlAngleTimerTarget;
  
  BOOL finish = fabs(newValue - self.controlAngleTimerTarget) <= fabs(self.controlAngleTimerDx*1.5);
  
  if (!finish) {
    self.controlAngle = newValue;
    return;
  }
  
  [self onControlAngleTimerFinish];
}
  
- (void)onControlAngleTimerFinish
{
  [self.controlAngleTimer invalidate];
  self.controlAngleTimer = nil;
  
  self.controlAngle = self.controlAngleTimerTarget;
    
  //Open fullscreen
  if (self.controlAngle >= 0) {
    
    //Notify the delegate
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didOpenPageIndex:)])
      [self.delegate ppPepperViewController:self didOpenPageIndex:self.currentPageIndex];
    return;
  }

  //Destroy page view
  //[self destroyPageScrollView:NO];
  [self unloadPageScrollView:NO];

  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didClosePageIndex:)])
    [self.delegate ppPepperViewController:self didClosePageIndex:self.currentPageIndex];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)theScrollView {

  //Fullscreen page scrolling
  if ([theScrollView isEqual:self.pageScrollView]) {
    
    PPPageViewDetailWrapper *onePage = nil;
    for (PPPageViewDetailWrapper *subview in self.visiblePageViewArray) {
      if (![subview isKindOfClass:[PPPageViewDetailWrapper class]])
        continue;
      onePage = subview;
      break;
    }
    
    //Don't notify the delegate if we are not in detail view
    if (!self.isDetailView || self.controlAngle < 0)
      return;
    
    float onePageWidth = 2 * [self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
    if (onePage != nil)
      onePageWidth = CGRectGetWidth(onePage.frame);
    
    int offsetX = fabs(self.pageScrollView.contentOffset.x);
    float pageIndex = offsetX / onePageWidth;
    
    //Notify the delegate
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didScrollWithPageIndex:)])
      [self.delegate ppPepperViewController:self didScrollWithPageIndex:pageIndex];
    return;
  }
  
  if (![theScrollView isEqual:self.bookScrollView])
    return;
  
  [self updateBookScrollViewBookScale];
  
  //Don't notify the delegate if bookScrollView is hidden
  if (self.bookScrollView.hidden || !self.isBookView)
    return;
  
  int offsetX = fabs(self.bookScrollView.contentOffset.x);
  float bookIndex = offsetX / (self.frameWidth+self.bookSpacing);
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didScrollWithBookIndex:)])
    [self.delegate ppPepperViewController:self didScrollWithBookIndex:bookIndex];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)theScrollView willDecelerate:(BOOL)decelerate
{
  if ([theScrollView isEqual:self.bookScrollView]) {
    if (!decelerate)
      [self snapBookScrollView];
    return;
  }
  
  if ([theScrollView isEqual:self.pageScrollView]) {
    
    self.pageScrollView.userInteractionEnabled = !decelerate;
    
    if (!decelerate)
      [self didSnapPageScrollview];
  }
}

//For book scrollview only
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)theScrollView
{
  if ([theScrollView isEqual:self.bookScrollView])
    [self snapBookScrollView];
}

//For book scrollview only
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)theScrollView
{
  if ([theScrollView isEqual:self.bookScrollView])
    [self reuseBookScrollView];
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didSnapToBookIndex:)])
    [self.delegate ppPepperViewController:self didSnapToBookIndex:self.currentBookIndex];
}

//For page scrollview only
- (void)scrollViewDidEndDecelerating:(UIScrollView *)theScrollView
{
  if ([theScrollView isEqual:self.pageScrollView]) 
    [self didSnapPageScrollview];
}

//
// Custom delegate from page scrollview
//
- (void)scrollViewDidZoom:(UIScrollView *)theScrollView {
  if ([theScrollView isKindOfClass:[PPPageViewDetailWrapper class]])
  {   
    if (theScrollView.zoomScale > 1.0) {
      self.controlAngle = 1.0;
      
      if (!self.enableOneSideZoom && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        theScrollView.zoomScale = 1;
        theScrollView.contentOffset = CGPointZero;
        return;
      }
      
      //Notify the delegate
      if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didZoomWithPageIndex:zoomScale:)])
        [self.delegate ppPepperViewController:self didZoomWithPageIndex:self.currentPageIndex zoomScale:theScrollView.zoomScale];
      return;
    }
    
    float scale = theScrollView.zoomScale;      //1.0 and smaller

    //Memory warning kills Pepper view
    /*
    if (theScrollView.hidden == YES) {
      [self setupReusablePoolPepperViews];
      [self reusePepperViews];
    }*/
       
    self.controlAngle = fabs(1.0 - scale) * (-THRESHOLD_CLOSE_ANGLE);
  }
}

- (void)scrollViewDidEndZooming:(UIScrollView *)theScrollView withView:(UIView *)view atScale:(float)scale {
  if ([theScrollView isKindOfClass:[PPPageViewDetailWrapper class]])
    [self snapControlAngle];
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didEndZoomingWithPageIndex:zoomScale:)])
    [self.delegate ppPepperViewController:self didEndZoomingWithPageIndex:self.currentPageIndex zoomScale:theScrollView.zoomScale];
}

- (void)didSnapPageScrollview
{
  PPPageViewDetailWrapper *anyPage = [self.visiblePageViewArray objectAtIndex:0];
  
  float onePageWidth = 2*[self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
  if (anyPage != nil)
    onePageWidth = CGRectGetWidth(anyPage.bounds);
  
  self.currentPageIndex = floor((self.pageScrollView.contentOffset.x) / onePageWidth);
  if (self.hideFirstPage)
    self.currentPageIndex += 1;
    
  self.pepperView.hidden = YES;
  self.pageScrollView.userInteractionEnabled = YES;
  self.zoomOnLeft = ((int)self.currentPageIndex % 2 == 0) ? YES : NO;
  self.controlIndex = ((int)self.currentPageIndex % 2 == 0) ? self.currentPageIndex+0.5 : self.currentPageIndex-0.5;
  self.controlAngle = 0;
  
  [self reusePageScrollview];
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didSnapToPageIndex:)])
    [self.delegate ppPepperViewController:self didSnapToPageIndex:self.currentPageIndex];
}




#pragma mark - Dummy PPScrollListViewControllerDataSource

- (int)ppPepperViewController:(PPPepperViewController*)scrollList numberOfBooks:(int)dummy;
{
  return DEMO_NUM_BOOKS;
}
- (int)ppPepperViewController:(PPPepperViewController*)scrollList numberOfPagesForBookIndex:(int)bookIndex
{
  return DEMO_NUM_PAGES;
}

- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList viewForBookIndex:(int)bookIndex withFrame:(CGRect)frame reusableView:(UIView*)contentView
{
  //NOTE: this should be encapsulated in a proper class, see demo project for proper implementation
  
  //Check if we can reuse the view
  UIView *myView = nil;
  UILabel *myLabel = nil;
  if (contentView != nil)
    for (UIView *subview in contentView.subviews)
      if ([subview isKindOfClass:[UILabel class]])
        myLabel = (UILabel*)subview; 
  
  //No-reuse, create it
  if (myLabel == nil) {
    myView = [[UIView alloc] initWithFrame:frame];
    myView.backgroundColor = [UIColor clearColor];

    myLabel = [[UILabel alloc] initWithFrame:myView.bounds];
    myLabel.backgroundColor = [UIColor clearColor];
    myLabel.textColor = [UIColor grayColor];
    myLabel.numberOfLines = 0;
    myLabel.textAlignment = UITextAlignmentCenter;
    myLabel.textAlignment = UITextAlignmentCenter;
    myLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                              | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    int fontSize = 12*deviceFactor;
    if (fontSize <= 5)
      fontSize = 5;
    myLabel.font = [UIFont systemFontOfSize:fontSize];

    [myView addSubview:myLabel];
  }
  else {
    myView = contentView;
  }
  
  //Configure view with new data
  myLabel.text = [NSString stringWithFormat:@"Implement your own\nPPScrollListViewControllerDataSource\nto supply content for\nthis book cover\n\n\n\n\n\n\nBook index: %d", bookIndex];
  
  return myView;
}

- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList thumbnailViewForPageIndex:(int)pageIndex inBookIndex:(int)bookIndex withFrame:(CGRect)frame reusableView:(UIView*)contentView
{
  //NOTE: this should be encapsulated in a proper class, see demo project for proper implementation
  
  //Check if we can reuse the view
  UIView *myView = nil;
  UILabel *myLabel = nil;
  if (contentView != nil)
    for (UIView *subview in contentView.subviews)
      if ([subview isKindOfClass:[UILabel class]])
        myLabel = (UILabel*)subview; 
  
  //No-reuse, create it
  
  if (myLabel == nil) {
    myView = [[UIView alloc] initWithFrame:frame];
    myView.backgroundColor = [UIColor clearColor];
    
    myLabel = [[UILabel alloc] initWithFrame:myView.bounds];
    myLabel.backgroundColor = [UIColor clearColor];
    myLabel.textColor = [UIColor grayColor];
    myLabel.numberOfLines = 0;
    myLabel.textAlignment = UITextAlignmentCenter;
    myLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                               | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    int fontSize = 12*deviceFactor;
    if (fontSize <= 5)
      fontSize = 5;
    myLabel.font = [UIFont systemFontOfSize:fontSize];
    
    [myView addSubview:myLabel];
  }
  else {
    myView = contentView;
  }

  //Configure view with new data
  myLabel.text = [NSString stringWithFormat:@"Implement your own\nPPScrollListViewControllerDataSource\nto supply content\nfor this page\n\n\n\n\n\n\nPage index: %d", pageIndex];
  
  return myView;
}

- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList detailViewForPageIndex:(int)pageIndex inBookIndex:(int)bookIndex withFrame:(CGRect)frame reusableView:(UIView*)contentView
{
  //NOTE: this should be encapsulated in a proper class, see demo project for proper implementation
  
  //Check if we can reuse the view
  UIView *myView = nil;
  UILabel *myLabel = nil;
  if (contentView != nil)
    for (UIView *subview in contentView.subviews)
      if ([subview isKindOfClass:[UILabel class]])
        myLabel = (UILabel*)subview; 
  
  //No-reuse, create it
  if (myLabel == nil) {
    myView = [[UIView alloc] initWithFrame:frame];
    myView.backgroundColor = [UIColor clearColor];
    
    myLabel = [[UILabel alloc] initWithFrame:myView.bounds];
    myLabel.backgroundColor = [UIColor clearColor];
    myLabel.textColor = [UIColor blackColor];
    myLabel.numberOfLines = 0;
    myLabel.textAlignment = UITextAlignmentCenter;
    myLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                               | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    int fontSize = 12*deviceFactor;
    if (fontSize <= 5)
      fontSize = 5;
    myLabel.font = [UIFont systemFontOfSize:fontSize];
    
    [myView addSubview:myLabel];
  }
  else {
    myView = contentView;
  }
  
  //Configure view with new data
  myLabel.text = [NSString stringWithFormat:@"Implement your own\nPPScrollListViewControllerDataSource\nto supply content\nfor this fullsize page\n\n\n\n\n\n\nDetailed page index: %d", pageIndex];
  
  return myView;
}


@end
