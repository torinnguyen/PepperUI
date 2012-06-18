//
//  PPScrollListViewControllerViewController.m
//  pepper
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

//Don't mess with these
#define OPEN_BOOK_DURATION           0.5
#define PEPPER_PAGE_SPACING          35.0f        //gap between pages in 3D mode
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
#define NUM_DOWNLOAD_THREAD          2
#define MIN_CONTROL_INDEX            0.5
#define MINOR_X_ADJUSTMENT_14        4.0
#define SCALE_ATTENUATION            0.03
#define SCALE_INDEX_DIFF             2.5
#define CONTROL_INDEX_USE_TIMER      YES
#define M34                          (-1.0 / 1000.0)  //0:flat, more negative: more perspective

@interface PPPepperViewController()
<
 UIGestureRecognizerDelegate,
 UIScrollViewDelegate,
 PPPageViewWrapperDelegate
>

//Almost contants
@property (nonatomic, assign) float frameWidth;
@property (nonatomic, assign) float frameHeight;
@property (nonatomic, assign) float bookSpacing;

//Control
@property (nonatomic, assign) float controlIndex;
@property (nonatomic, assign) float controlAngle;
@property (nonatomic, assign) float controlFlipAngle;
@property (nonatomic, assign) float touchDownControlAngle;
@property (nonatomic, assign) float touchDownControlIndex;
@property (nonatomic, assign) BOOL zoomOnLeft;
@property (nonatomic, assign) BOOL isBookView;
@property (nonatomic, assign) BOOL isDetailView;

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
@property (nonatomic, assign) int currentBookIndex;
@property (nonatomic, strong) UIView *theBookCover;
@property (nonatomic, strong) UIScrollView *bookScrollView;
@property (nonatomic, strong) NSMutableArray *reuseBookViewArray;

//Pepper views
@property (nonatomic, strong) UIView *pepperView;
@property (nonatomic, strong) UIView *theLeftView;
@property (nonatomic, strong) UIView *theRightView;
@property (nonatomic, strong) UIView *theView1;
@property (nonatomic, strong) UIView *theView2;
@property (nonatomic, strong) UIView *theView3;
@property (nonatomic, strong) UIView *theView4;
@property (nonatomic, retain) NSMutableArray *reusePepperWrapperArray;
@property (nonatomic, strong) NSMutableArray *pageOnDemandQueue;

//Page scrollview
@property (nonatomic, assign) float currentPageIndex;
@property (nonatomic, strong) UIScrollView *pageScrollView;
@property (nonatomic, strong) NSMutableArray *reusePageViewArray;

//Fullscreen page on-demand fetching queue
/*
@property (nonatomic, strong) NSMutableArray *fullsizeOnDemandQueue;
@property (nonatomic, strong) Page *backgroundDownloadPage;
@property (nonatomic, strong) Page *onDemandDownloadPdf;
 */
@end


@implementation PPPepperViewController

//public properties
@synthesize animationSlowmoFactor;
@synthesize enableBookScale;
@synthesize enableBookRotate;
@synthesize hideFirstPage;
@synthesize oneSideZoom;
@synthesize pepperPageSpacing;
@synthesize scaleOnDeviceRotation;

@synthesize isBookView;
@synthesize isDetailView;

@synthesize delegate;
@synthesize dataSource;

@synthesize theBookCover, theLeftView, theRightView;
@synthesize theView1, theView2, theView3, theView4;
@synthesize controlAngle = _controlAngle;
@synthesize controlFlipAngle = _controlFlipAngle;
@synthesize touchDownControlAngle;
@synthesize touchDownControlIndex;
@synthesize controlIndexTimerTarget, controlIndexTimerDx, controlIndexTimerLastTime;
@synthesize zoomOnLeft;
@synthesize controlIndex = _controlIndex;
@synthesize controlIndexTimer;
@synthesize frameWidth, frameHeight, bookSpacing;

@synthesize controlAngleTimerTarget;
@synthesize controlAngleTimerDx;
@synthesize controlAngleTimerLastTime;
@synthesize controlAngleTimer;

@synthesize pepperView;
@synthesize reusePepperWrapperArray;
@synthesize pageOnDemandQueue;

@synthesize currentBookIndex;
@synthesize bookScrollView;
@synthesize reuseBookViewArray;

@synthesize currentPageIndex;
@synthesize reusePageViewArray;
@synthesize pageScrollView;

/*
@synthesize fullsizeOnDemandQueue;
@synthesize backgroundDownloadPage;
@synthesize onDemandDownloadPdf;
 */

//I have not found a better way to implement this yet
static float layer23WidthAtMid = 0;
static float layer2WidthAt90 = 0;
static float layer3WidthAt90 = 0;

#pragma mark - View life cycle

+ (NSString*)version {
  return @"1.0";
}

- (void)viewDidLoad
{
  [super viewDidLoad];
    
  //Configurable properties
  self.hideFirstPage = HIDE_FIRST_PAGE;
  self.oneSideZoom = YES;
  self.animationSlowmoFactor = 1.0f;
  self.enableBookScale = ENABLE_BOOK_SCALE;
  self.enableBookRotate = ENABLE_BOOK_ROTATE;
  self.pepperPageSpacing = PEPPER_PAGE_SPACING;
  self.scaleOnDeviceRotation = SMALLER_FRAME_FOR_PORTRAIT;

  //Initial values
  [self updateFrameSizesForOrientation];
  self.zoomOnLeft = YES;
  self.isBookView = YES;
  self.isDetailView = NO;
  _controlIndex = MIN_CONTROL_INDEX;
  _controlAngle = -THRESHOLD_HALF_ANGLE;
  _controlFlipAngle = -THRESHOLD_HALF_ANGLE;
  
  self.delegate = self;
  self.dataSource = self;
  
  //Download queue data
  /*
  self.pageOnDemandQueue = [[NSMutableArray alloc] init];
  self.fullsizeOnDemandQueue = [[NSMutableArray alloc] init];
   */
  
  //Initialize views
  self.view.autoresizesSubviews = YES;
  self.view.clipsToBounds = YES;
  self.view.backgroundColor = [UIColor clearColor];
  self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
  UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onTwoFingerPinch:)];
  pinchGestureRecognizer.delegate = self;
  [self.view addGestureRecognizer:pinchGestureRecognizer];
  
  UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanning:)];
  panGestureRecognizer.delegate = self;
  [self.view addGestureRecognizer:panGestureRecognizer];
  
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
  
  if (self.pepperView == nil) {
    self.pepperView = [[UIScrollView alloc] init];
    self.pepperView.frame = self.view.bounds;
    self.pepperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.pepperView.autoresizesSubviews = NO;
    self.pepperView.hidden = YES;
    [self.view addSubview:self.pepperView];
  }
  
  //Warning about incomplete iPhone implementation
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
  {
    NSLog(@"WARNING: iPhone support in development & not officially supported yet. Most features are kind-of working.");
    [[[UIAlertView alloc] initWithTitle:@"Adventourous?"
                                message:@"iPhone support in development & not officially supported yet. Most features are kind-of working."
                               delegate:nil
                      cancelButtonTitle:@"OK. Got it!"
                      otherButtonTitles: nil] show];
  }
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  
  //Dealloc Book scrollview
  BOOL canDestroyBookView = !self.isBookView;
  if (canDestroyBookView) {
    [self destroyBookScrollView];
  }
  
  //Dealloc Pepper views
  BOOL canDestroyPepperView = ![self isPepperView] && !(self.isDetailView && self.controlAngle < 0);
  if (canDestroyPepperView) {
    while (self.pepperView.subviews.count > 0)
      [[self.pepperView.subviews objectAtIndex:0] removeFromSuperview];
    [self.reusePepperWrapperArray removeAllObjects];
    self.reusePepperWrapperArray = nil;
  }
  
  //Dealloc Page scrollview
  BOOL canDestroyPageView = !self.isDetailView && !([self isPepperView] && self.controlAngle > -THRESHOLD_HALF_ANGLE);
  if (canDestroyPageView) {
    [self destroyPageScrollView];
  }
}

- (void)viewDidUnload
{
  [super viewDidUnload];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
  
  //Animate frame size
  [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    [self updateFrameSizesForOrientation:toInterfaceOrientation];
  } completion:^(BOOL finished) {

  }];
  
  //Relayout the Book views with animation
  for (PPPageViewContentWrapper *subview in self.bookScrollView.subviews) {
    int index = subview.tag;
    CGRect frame = [self getFrameForBookIndex:index forOrientation:toInterfaceOrientation];
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
      subview.frame = frame;
    } completion:^(BOOL finished) {
      
    }];
  }
  
  //Relayout fullsize views with animation
  for (UIView *subview in self.pageScrollView.subviews) {
    int index = subview.tag;
    CGRect frame = [self getFrameForPageIndex:index forOrientation:toInterfaceOrientation];
    
    //Layout subviews of each fullscreen page
    if ([subview isKindOfClass:[PPPageViewDetailWrapper class]])
      [(PPPageViewDetailWrapper*)subview layoutForWidth:frame.size.width duration:duration];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
      subview.frame = frame;
    } completion:^(BOOL finished) {
      
    }];
  }
  [self scrollToPage:self.currentPageIndex duration:duration];
  
  //Relayout 3D views with animation
  for (UIView *subview in self.pepperView.subviews) {
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
  [self updatePageScrollViewContentSize];
  
  [self scrollViewDidScroll:self.bookScrollView];
  self.controlFlipAngle = self.controlFlipAngle;
  if (self.isBookView || self.isDetailView)
    self.pepperView.hidden = YES;
  
  //Increase number of reusable views for landscape
  BOOL isLandscape = (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation));
  int totalViews = self.reuseBookViewArray.count + self.bookScrollView.subviews.count;
  if (isLandscape) {
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
  
  //Initialize book views
  self.bookScrollView.contentOffset = CGPointMake(0,0);
  int numBooks = [self getNumberOfBooks];
  if (numBooks <= 0)
    return;

  self.bookScrollView.hidden = YES;
  self.isBookView = YES;
  self.isDetailView = NO;

  //Initialize books scrollview
  [self destroyBookScrollView];
  [self destroyPeperView];
  [self destroyPageScrollView];

  //Initialize books scrollview
  [self setupReuseablePoolBookViews];
  [self updateBookScrollViewContentSize];
  for (int i=0; i<numBooks; i++)
    [self addBookToScrollView:i];
  self.currentBookIndex = 0;
  [self scrollViewDidScroll:self.bookScrollView];
  
  //Start downloading thumbnails for 1st page
  //[self fetchBookThumbnailsMultithread];
   
  self.bookScrollView.hidden = NO;
  self.pepperView.hidden = YES;
  self.pageScrollView.hidden = YES;
}


#pragma mark - PPPageViewWrapperDelegate

- (void)PPPageViewWrapper:(PPPageViewContentWrapper*)thePage viewDidTap:(int)tag
{
  if ([self.controlAngleTimer isValid] || [self.controlIndexTimer isValid])
    return;
  if (!self.isBookView && self.controlAngle == 0)
    return;
  
  if (thePage.isBook) {
    if (self.currentBookIndex != tag) {
      [self scrollToBook:tag animated:YES];
      return;
    }
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didTapOnBookIndex:)])
      [self.delegate ppPepperViewController:self didTapOnBookIndex:tag];
    
    //Optional: Delegate can decide to show or not
    if (AUTO_OPEN_BOOK)
      [self openBookWithIndex:tag pageIndex:0];
    
    return;
  }
  
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didTapOnPageIndex:)])
    [self.delegate ppPepperViewController:self didTapOnPageIndex:tag];
  
  //Optional: Delegate can decide to show or not
  if (!AUTO_OPEN_PAGE)
    return;
    
  //Open one page in fullscreen
  [self openPageIndex:tag];
}


#pragma mark - Gestures

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (self.isBookView || self.isDetailView)
    return NO;
  
  if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]])
    return YES;
  
  if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
    if ([self isFullscreen] || self.controlIndexTimer != nil || [self.controlIndexTimer isValid] || [self.controlAngleTimer isValid])
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
  if (self.theLeftView.tag == 0 && self.zoomOnLeft)
    return;

  //Snap control angle to 3 thresholds
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    [self snapControlAngle];
    return;
  }
  
  float boost = 1.0f;
  if (self.oneSideZoom && recognizer.scale > 1.0)
    boost = 0.3f;
  
  float dx = boost * (-90.0) * (1.0-recognizer.scale);
  float newControlAngle = self.touchDownControlAngle + dx;
  self.controlAngle = newControlAngle;
}

- (void)onPanning:(UIPanGestureRecognizer *)recognizer
{
  //in case gestureRecognizerShouldBegin does not work properly
  if ([self isFullscreen])
    return;
    
  //Remember initial value to calculate based on delta later
  if (recognizer.state == UIGestureRecognizerStateBegan)
    self.touchDownControlIndex = self.controlIndex;
  
  //The dynamics
  CGPoint translation = [recognizer translationInView:self.pepperView];
  CGPoint velocity = [recognizer velocityInView:self.pepperView];
  float normalizedVelocityX = fabsf(velocity.x / self.pepperView.bounds.size.width / 2);
  if (normalizedVelocityX < 1)          normalizedVelocityX = 1;
  else if (normalizedVelocityX > 2.0)   normalizedVelocityX = 2.0;

  //Snap to half open
  if (recognizer.state == UIGestureRecognizerStateEnded) {    
    float snapTo = 0;
    int lowerBound = (int)floor(self.controlIndex);
    int lowerBoundEven = lowerBound % 2 == 0;
    int upperBound = (int)ceil(self.controlIndex);
    int theIndex = (int)round(self.controlIndex);
    if (lowerBoundEven)               snapTo = lowerBound + 0.5;
    else if (theIndex == upperBound)  snapTo = upperBound + 0.5;
    else                              snapTo = lowerBound - 0.5;

    float diff = fabs(snapTo - self.controlIndex);
    float duration = diff / 2.0f;
    if (ENABLE_HIGH_SPEED_SCROLLING)
      duration /= normalizedVelocityX;
    if (diff <= 0)
      return;
    duration *= self.animationSlowmoFactor;

    //Correct behavior but sluggish
    if (CONTROL_INDEX_USE_TIMER) {
      [self animateControlIndexTo:snapTo duration:duration];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
      });
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

- (int)getNumberOfBooks {
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:numberOfBooks:)])
    return [self.dataSource ppPepperViewController:self numberOfBooks:0];
  return 0;
}

- (int)getNumberOfPagesForBookIndex:(int)bookIndex {
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:numberOfPagesForBookIndex:)])
    return [self.dataSource ppPepperViewController:self numberOfPagesForBookIndex:bookIndex];
  return 0;
}



#pragma mark - UI Helper functions (Common)

- (void)updateFrameSizesForOrientation
{
  [self updateFrameSizesForOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

- (void)updateFrameSizesForOrientation:(UIInterfaceOrientation)orientation
{
  //Scale for iPhone too
  BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
  float deviceFactor = MAX([UIScreen mainScreen].bounds.size.width,[UIScreen mainScreen].bounds.size.height) / 1024.0;
  float orientationFactor = isLandscape ? 1.0f : FRAME_SCALE_PORTRAIT;
  
  if (!self.scaleOnDeviceRotation)
    orientationFactor = 1.0f;
  self.frameHeight = FRAME_HEIGHT_LANDSCAPE * orientationFactor * deviceFactor;
  self.frameWidth = FRAME_WIDTH_LANDSCAPE * orientationFactor * deviceFactor;
  self.bookSpacing = (FRAME_WIDTH_LANDSCAPE * MAX_BOOK_SCALE) / 2.4 * orientationFactor * deviceFactor;
  
  //Frame size changes on rotation, these needs to be recalculated
  if (self.scaleOnDeviceRotation) {
    layer23WidthAtMid = 0;
    layer2WidthAt90 = 0;
    layer3WidthAt90 = 0;
  }
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
  BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
  int min = MIN(self.view.bounds.size.height, self.view.bounds.size.width);
  int max = MAX(self.view.bounds.size.height, self.view.bounds.size.width);
  return isLandscape ? max/2 : min/2;
}

- (int)getMidYForOrientation:(UIInterfaceOrientation)orientation
{
  BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
  int min = MIN(self.view.bounds.size.height, self.view.bounds.size.width);
  int max = MAX(self.view.bounds.size.height, self.view.bounds.size.width);
  return isLandscape ? min/2 : max/2;
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
// Note: layer3WidthAt90 static variable must already be calculated before using this function
//       this will NOT be valid for the middle 4 pages
//
- (float)getPepperFrameXForPageIndex:(int)pageIndex gapScale:(float)gapScale orientation:(UIInterfaceOrientation)interfaceOrientation {
  
  //Handle middle 4 pages
  float midX = [self getMidXForOrientation:interfaceOrientation];
  float indexDiff = fabsf(self.controlIndex - pageIndex) - 2.5;                   //2.5 pages away from current center
  if (indexDiff < 0)
    return midX;

  float distance = indexDiff * self.pepperPageSpacing;
  float positionScale = 0.5;
  float magicNumber = layer3WidthAt90 + MINOR_X_ADJUSTMENT_14 - layer3WidthAt90*positionScale/2.5;    //see formular for self.theView4.frame, flip to right case
  float diffFromMidX = magicNumber + distance;
  
  //edge limit. maybe not needed because we already have cell reuse & scale limit
  BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
  if (isLandscape) {
    if (indexDiff > NUM_VISIBLE_PAGE_ONE_SIDE)
      diffFromMidX = midX-self.frameWidth;
  }
  
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
- (void)destroyPeperView { 
  
  while (self.pepperView.subviews.count > 0)
    [[self.pepperView.subviews objectAtIndex:0] removeFromSuperview];
  [self.reusePepperWrapperArray removeAllObjects];
  self.reusePepperWrapperArray = nil;
  
  self.pepperView.hidden = YES;
}

- (void)setupReusablePoolPepperViews
{
  //No need to re-setup
  if (self.reusePepperWrapperArray != nil || self.reusePepperWrapperArray.count > 0)
    return;
  
  self.reusePepperWrapperArray = [[NSMutableArray alloc] init];
  
  //Reuseable views pool
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  int total = pageCount == 0 ? NUM_REUSE_3D_VIEW : MIN(NUM_REUSE_3D_VIEW, pageCount);
  CGRect pageFrame = CGRectMake(3000, 0, self.frameWidth, self.frameHeight);
  for (int i=0; i<total; i++) {
    PPPageViewContentWrapper *box = [[PPPageViewContentWrapper alloc] initWithFrame:pageFrame];
    box.delegate = self;
    box.alpha = 1;
    [self.reusePepperWrapperArray addObject:box];
  }
}

- (void)reusePepperViews {
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  
  //Some funny UIImageView gets into our view
  NSMutableArray *tempArray = [[NSMutableArray alloc] init];
  for (UIView *subview in self.pepperView.subviews)
    if (![subview isKindOfClass:[PPPageViewContentWrapper class]])
      [tempArray addObject:subview];
  for (UIView *subview in tempArray)
    [subview removeFromSuperview];
  [tempArray removeAllObjects];
  
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
  for (int i=0; i<pageCount; i++) {
    if (i > currentIndex-1.6 && i < currentIndex+1.6)   //Don't touch the middle 4 pages
      continue;
    if (i < startIndex || i > endIndex) {
      [self removePageFromPepper:i];
      continue;
    }
  }
    
  //Reuse hidden views
  NSMutableArray *toBeRemoved = [[NSMutableArray alloc] init];
  for (UIView *subview in self.pepperView.subviews) {
    int idx = subview.tag;
    if (idx > currentIndex-1.6 && idx < currentIndex+1.6)   //Don't touch the middle 4 pages
      continue;
    if (idx > currentIndex && idx%2!=0)
      continue;
    if (idx < currentIndex && idx%2==0)
      continue;
    [toBeRemoved addObject:subview];
  }
  while (toBeRemoved.count > 0) {
    UIView *subview = [toBeRemoved objectAtIndex:0];
    [self removePageFromPepper:subview.tag];
    [toBeRemoved removeObjectAtIndex:0];
  }

  //Add only relevant new views
  NSMutableArray *toBeAdded = [[NSMutableArray alloc] init];
  for (int i=startIndex; i<=endIndex; i++) {
    if (i > currentIndex-1.6 && i < currentIndex+1.6) {
      [self addPageToPepperView:i];
      [toBeAdded addObject:[NSString stringWithFormat:@"%d", i]];
      continue;
    }
    if (i < currentIndex && i%2!=0)
      continue;
    if (i >= currentIndex && i%2==0)
      continue;

    [self addPageToPepperView:i];
    [toBeAdded addObject:[NSString stringWithFormat:@"%d", i]];
  }
  [toBeAdded removeAllObjects];
  //NSLog(@"%@",[toBeAdded componentsJoinedByString: @","]);
}

- (void)addPageToPepperView:(int)index {
  if (self.reusePepperWrapperArray.count <= 0)
    return;
  
  //Need to get the first page data here
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
    
  //Check if we already have this Page in pepper view
  for (PPPageViewContentWrapper *subview in self.pepperView.subviews)
    if (subview.tag == index)
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
  pageView.bgBookImage = (FIRST_PAGE_BOOK_COVER && index <= 0 && !self.hideFirstPage);
  
  pageView.frame = pageFrame;
  pageView.alpha = 1;
  pageView.hidden = YES;        //control functions will unhide later
  pageView.delegate = self;  
  pageView.isLeft = (index%2==0) ? YES : NO;
  [self.pepperView addSubview:pageView];
  
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:thumbnailViewForPageIndex:inBookIndex:withFrame:reusableView:)])
    pageView.contentView = [self.dataSource ppPepperViewController:self thumbnailViewForPageIndex:index inBookIndex:self.currentBookIndex withFrame:pageView.bounds reusableView:pageView.contentView];
  else
    pageView.contentView = nil;
}

- (void)removePageFromPepper:(int)index {
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
  
  for (PPPageViewContentWrapper *subview in self.pepperView.subviews) {
    if (![subview isKindOfClass:[PPPageViewContentWrapper class]])
      continue;
    if (subview.tag != index)
      continue;
    [self.reusePepperWrapperArray addObject:subview];
    [subview removeFromSuperview];
    break;
  }
}

- (PPPageViewContentWrapper*)getPepperPageAtIndex:(int)index {
  for (PPPageViewContentWrapper *page in self.pepperView.subviews) {
    if (![page isKindOfClass:[PPPageViewContentWrapper class]])
      continue;
    if (page.tag != index)
      continue;
    return page;
  }
  return nil;
}

//
// Find the first visible (even) page index, suitable for book cover replacement
//
- (int)getFirstVisiblePepperPageIndex {
  
  int firstPageIndex = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  
  for (UIView *subview in self.pepperView.subviews)
    if (subview.tag < firstPageIndex
        && subview.tag%2 == 0
        && !subview.hidden
        && [subview isKindOfClass:[PPPageViewContentWrapper class]])
      firstPageIndex = subview.tag;
  
  if (firstPageIndex >= [self getNumberOfPagesForBookIndex:self.currentBookIndex])
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

- (void)destroyBookScrollView
{
  while (self.bookScrollView.subviews.count > 0)
    [[self.bookScrollView.subviews objectAtIndex:0] removeFromSuperview];
  [self.reuseBookViewArray removeAllObjects];
  self.reuseBookViewArray = nil;
}

- (void)setupReuseablePoolBookViews
{  
  //No need to re-setup
  if (self.reuseBookViewArray != nil || self.reuseBookViewArray.count > 0)
    return;
  
  BOOL isLandscape = (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation));
  int numReuse = isLandscape ? NUM_REUSE_BOOK_LANDSCAPE : NUM_REUSE_BOOK_PORTRAIT;
  self.reuseBookViewArray = [[NSMutableArray alloc] init];
  
  //Reuseable views pool
  for (int i=0; i<numReuse; i++)
    [self.reuseBookViewArray addObject:[[PPPageViewContentWrapper alloc] init]];
}

- (void)scrollToBook:(int)bookIndex animated:(BOOL)animated {
  int x = bookIndex * (self.frameWidth + self.bookSpacing);
  [self.bookScrollView setContentOffset:CGPointMake(x, 0) animated:animated];
  self.currentBookIndex = bookIndex;
}

- (void)snapBookScrollView {
  int index = [self getCurrentBookIndex];
  int x = index * (self.frameWidth + self.bookSpacing);
  [self.bookScrollView setContentOffset:CGPointMake(x, 0) animated:YES];
  self.currentBookIndex = index;
}

- (void)reuseBookScrollView {
  
  BOOL isLandscape = (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation));
  int bookCount = [self getNumberOfBooks];
  
  //Some funny UIImageView gets into our view
  NSMutableArray *tempArray = [[NSMutableArray alloc] init];
  for (UIView *subview in self.bookScrollView.subviews)
    if (![subview isKindOfClass:[PPPageViewContentWrapper class]])
      [tempArray addObject:subview];
  for (UIView *subview in tempArray)
    [subview removeFromSuperview];
  [tempArray removeAllObjects];
  
  //Visible indexes
  int range = isLandscape ? floor(NUM_REUSE_BOOK_LANDSCAPE/2.0) : floor(NUM_REUSE_BOOK_PORTRAIT/2.0);
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

- (void)hideBookScrollview
{
  //Reuse all book views
  for (UIView *subview in self.bookScrollView.subviews)
    [self.reuseBookViewArray addObject:subview];
  while (self.bookScrollView.subviews.count > 0)
    [[self.bookScrollView.subviews objectAtIndex:0] removeFromSuperview];
  self.bookScrollView.hidden = YES;
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
- (int)getCurrentBookIndex {
  
  int offsetX = fabs(self.bookScrollView.contentOffset.x);
  int index = round(offsetX / (self.frameWidth+self.bookSpacing));
  return index;
}

- (void)removeBookFromScrollView:(int)index {
  
  int bookCount = [self getNumberOfBooks];
  if (index < 0 || index >= bookCount)
    return;
  
  for (PPPageViewContentWrapper *subview in self.bookScrollView.subviews) {
    if (subview.tag != index)
      continue;
    [self.reuseBookViewArray addObject:subview];
    [subview removeFromSuperview];
    break;
  }
}

//
// Convert from Book data model to view
//
- (void)addBookToScrollView:(int)index {
  
  if (self.reuseBookViewArray.count <= 0)
    return;
  
  //Need to get the first page data here
  int bookCount = [self getNumberOfBooks];
  if (index < 0 || index >= bookCount)
    return;
  
  //Check if we already have this Book in scrollview
  for (PPPageViewContentWrapper *subview in self.bookScrollView.subviews)
    if (subview.tag == index)
      return;
    
  PPPageViewContentWrapper *coverPage = [self.reuseBookViewArray objectAtIndex:0];
  [self.reuseBookViewArray removeObjectAtIndex:0];
  if (coverPage == nil)
    return;
  
  coverPage.tag = index;
  coverPage.isLeft = NO;
  coverPage.isBook = YES;
  coverPage.bgBookImage = !self.hideFirstPage;
  coverPage.delegate = self;
  
  coverPage.hidden = NO;
  coverPage.alpha = 1;
  coverPage.transform = CGAffineTransformIdentity;
  coverPage.frame = [self getFrameForBookIndex:index];
  coverPage.layer.transform = CATransform3DMakeScale(MAX_BOOK_SCALE, MAX_BOOK_SCALE, 1.0);
    
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:viewForBookIndex:withFrame:reusableView:)])
    coverPage.contentView = [self.dataSource ppPepperViewController:self viewForBookIndex:index withFrame:coverPage.bounds reusableView:coverPage.contentView];
  else
    coverPage.contentView = nil;

  [self.bookScrollView addSubview:coverPage];
    
  /*
  coverPage.layer.shadowColor = [UIColor blackColor].CGColor;
  coverPage.layer.shadowOpacity = 0.4f;
  coverPage.layer.shadowOffset = CGSizeMake(0,15);
  coverPage.layer.shadowRadius = 10.0f;
  coverPage.layer.masksToBounds = NO;
  UIBezierPath *path = [UIBezierPath bezierPathWithRect:coverPage.bounds];
  coverPage.layer.shadowPath = path.CGPath;
   */
}


- (void)updateBookScrollViewContentSize {
  int bookCount = [self getNumberOfBooks];
  CGRect lastFrame = [self getFrameForBookIndex:bookCount-1];
  CGSize contentSize = CGSizeMake(CGRectGetMaxX(lastFrame) + CGRectGetWidth(self.bookScrollView.bounds)/2, 100);
  self.bookScrollView.contentSize = contentSize;
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
  [self updatePageScrollViewContentSize];
  int pageCount = [self getNumberOfPagesForBookIndex:bookIndex];
  
  //Even page only
  if (pageIndex%2 != 0)
    pageIndex -= 1;
    
  //Convert integer to actual 0.5 indexes
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
  [self addBookCoverToFirstPage:YES];
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:willOpenBookIndex:andDuration:)])
    [self.delegate ppPepperViewController:self willOpenBookIndex:bookIndex andDuration:self.animationSlowmoFactor*OPEN_BOOK_DURATION];
  
  //This is where magic happens (animation)
  [self showHalfOpen:YES];
     
  //Start downloading thumbnails only
  //[self fetchPageLargeThumbnailsMultithread];
}


#pragma mark - UI Helper functions (Page)

- (void)destroyPageScrollView
{
  while (self.pageScrollView.subviews.count > 0)
    [[self.pageScrollView.subviews objectAtIndex:0] removeFromSuperview];
  [self.reusePageViewArray removeAllObjects];
  self.reusePageViewArray = nil;
}

- (void)setupReuseablePoolPageViews
{  
  //No need to re-setup
  if (self.reusePageViewArray != nil || self.reusePageViewArray.count > 0)
    return;
  
  self.reusePageViewArray = [[NSMutableArray alloc] init];
  
  //Reuseable views pool
  for (int i=0; i<NUM_REUSE_DETAIL_VIEW; i++)
    [self.reusePageViewArray addObject:[[PPPageViewDetailWrapper alloc] initWithFrame:self.pageScrollView.bounds]];
}

- (void)setupPageScrollview
{  
  //Re-setup in case memory warning
  [self setupReuseablePoolPageViews];
  
  //Populate page scrollview  
  [self reusePageScrollview];
  
  //Reset pages UI
  for (UIView *subview in self.pageScrollView.subviews) {
    if (![subview isKindOfClass:[PPPageViewDetailWrapper class]])
      continue;
    subview.hidden = NO;
    [(PPPageViewDetailWrapper*)subview reset];
  }
        
  [self updatePageScrollViewContentSize]; 
  [self scrollToPage:self.currentPageIndex duration:0];
  [self.view bringSubviewToFront:self.pageScrollView];
  
  //Start loading index
  /*
  int startIndex = self.currentPageIndex - 1;
  if (startIndex < 0)     startIndex = 0;
  if (self.hideFirstPage && startIndex < 1)
    startIndex = 1;
  
  //Start downloading PDFs
  [self fetchFullsizeInBackground:startIndex];
  */
}

- (void)reusePageScrollview {
  int currentIndex = (int)self.currentPageIndex;
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  
  //Some funny UIImageView gets into our view
  NSMutableArray *tempArray = [[NSMutableArray alloc] init];
  for (UIView *subview in self.pageScrollView.subviews)
    if (![subview isKindOfClass:[PPPageViewDetailWrapper class]])
      [tempArray addObject:subview];
  for (UIView *subview in tempArray)
    [subview removeFromSuperview];
  [tempArray removeAllObjects];
  
  //Visible indexes
  int range = floor(NUM_REUSE_DETAIL_VIEW/2.0);
  int startIndex = currentIndex - range;
  if (startIndex < 0)
    startIndex = 0;
  int endIndex = startIndex + NUM_REUSE_DETAIL_VIEW;
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

- (void)hidePageScrollview
{
  //Reuse all PDF views
  for (UIView *subview in self.pageScrollView.subviews)
    [self.reusePageViewArray addObject:subview];
  while (self.pageScrollView.subviews.count > 0)
    [[self.pageScrollView.subviews objectAtIndex:0] removeFromSuperview];
  self.pageScrollView.hidden = YES;
}

//
// Return the frame for this page in scrollview
//
- (CGRect)getFrameForPageIndex:(int)index forOrientation:(UIInterfaceOrientation)interfaceOrientation {
  int width = 2 * [self getMidXForOrientation:interfaceOrientation];
  int height = 2 * [self getMidYForOrientation:interfaceOrientation];
  int x = (self.hideFirstPage) ? (index-1)*width : index*width;
  return CGRectMake(x, 0, width, height);
}

//
// Return the frame for this page in scrollview
//
- (CGRect)getFrameForPageIndex:(int)index {
  int width = 2 * [self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
  int height = 2 * [self getMidYForOrientation:[UIApplication sharedApplication].statusBarOrientation];
  int x = index * CGRectGetWidth(self.bookScrollView.bounds);
  return CGRectMake(x, 0, width, height);
}

- (void)removePageFromScrollView:(int)index {
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
  
  for (UIView *subview in self.pageScrollView.subviews) {
    if (![subview isKindOfClass:[PPPageViewDetailWrapper class]])
      continue;
    if (subview.tag != index)
      continue;
    [(PPPageViewDetailWrapper*)subview unloadContent];
    [self.reusePageViewArray addObject:subview];
    [subview removeFromSuperview];
    break;
  }
}

- (void)addPageToScrollView:(int)index {
  
  if (self.reusePageViewArray.count <= 0)
    return;
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index < 0 || index >= pageCount)
    return;
  
  //Check if we already have this Page in scrollview
  for (UIView *subview in self.pageScrollView.subviews)
    if (subview.tag == index)
      return;
  
  CGRect pageFrame = [self getFrameForPageIndex:self.hideFirstPage ? index-1 : index];
  PPPageViewDetailWrapper *pageDetailView = [self.reusePageViewArray objectAtIndex:0];
  [self.reusePageViewArray removeObjectAtIndex:0];
  if (pageDetailView == nil)
    return;
  
  pageDetailView.tag = index; 
  pageDetailView.frame = pageFrame;
  pageDetailView.alpha = 1;
  pageDetailView.hidden = NO;
  pageDetailView.customDelegate = self;
  [self.pageScrollView addSubview:pageDetailView];
   
  if ([self.dataSource respondsToSelector:@selector(ppPepperViewController:viewForBookIndex:withFrame:reusableView:)])
    pageDetailView.contentView = [self.dataSource ppPepperViewController:self detailViewForPageIndex:index inBookIndex:self.currentBookIndex withFrame:pageDetailView.bounds reusableView:pageDetailView.contentView];
  else
    pageDetailView.contentView = nil;

  [pageDetailView layoutForWidth:pageFrame.size.width duration:0];
  
  /*
  UIImage *image = [self getCachedThumbnailForPageID:index];
  UIImage *fullsize = [self getCachedFullsizeForPageID:index];
  if (fullsize != nil) {
    [pageDetailView loadWithFrame:pageFrame thumbnail:image fullsize:fullsize];
  }
  else {
    //[self fetchFullsizeOnDemand:index];
  }
   */
}

- (void)updatePageScrollViewContentSize {
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  int numPages = self.hideFirstPage ? pageCount-1 : pageCount;
  CGSize contentSize = CGSizeMake(numPages * CGRectGetWidth(self.pageScrollView.bounds), 100);
  self.pageScrollView.contentSize = contentSize;
}

- (void)scrollToPage:(int)pageIndex duration:(float)duration {
  if (self.hideFirstPage)
    pageIndex -= 1;
  CGRect pageFrame = [self getFrameForPageIndex:pageIndex];
  
  if (duration <= 0) {
    self.pageScrollView.contentOffset = CGPointMake(pageFrame.origin.x, 0);
    return;
  }
  
  [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.pageScrollView.contentOffset = CGPointMake(pageFrame.origin.x, 0);
  } completion:^(BOOL finished) {
    
  }];
}

- (void)openPageIndex:(int)pageIndex {
  if (self.isBookView) {
    NSLog(@"You can't call this function in book mode");
    return;
  }
  if (self.isDetailView) {
    NSLog(@"You can't call this function in fullscreen mode");
    return;
  }

  self.currentPageIndex = pageIndex;
  self.zoomOnLeft = pageIndex%2==0;
  [self destroyBookScrollView];
  [self showFullscreenUsingTimer];
}



#pragma mark - Flipping implementation

// This function controls everything about flipping
// @param: valid range 0.5 to count-1.5
- (void)setControlIndex:(float)newIndex 
{
  //Temporary, should be an elastic scale
  float offset = 0.48;
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  //if (newIndex < MIN_CONTROL_INDEX-offset)   newIndex = MIN_CONTROL_INDEX-offset;
  if (newIndex < MIN_CONTROL_INDEX)           newIndex = MIN_CONTROL_INDEX;
  if (newIndex >= pageCount-1.5+offset)       newIndex = pageCount-1.5+offset;
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
  
  //Reorder-Z for left pages
  int totalPages = pageCount;
  for (int i=0; i < (int)self.controlIndex; i++) {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    [page.superview bringSubviewToFront:page];
  }
  //Reorder-Z for right pages
  for (int i=totalPages-1; i >= (int)self.controlIndex; i--) {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    [page.superview bringSubviewToFront:page];
  }
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
  float m34 = M34;
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
    transform.m34 = m34;
    transform = CATransform3DRotate(transform, (max/2+min/2) * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
    layer2.anchorPoint = CGPointMake(0, 0.5);
    layer2.transform = transform;
    layer23WidthAtMid = layer2.frame.size.width;
  }
  if (layer2WidthAt90 == 0) {
    CALayer *layer2 = self.theView2.layer;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = m34;
    transform = CATransform3DRotate(transform, (-90-angleDiff) * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
    layer2.anchorPoint = CGPointMake(0, 0.5);
    layer2.transform = transform;
    layer2WidthAt90 = layer2.frame.size.width;
  }
  if (layer3WidthAt90 == 0) {
    CALayer *layer3 = self.theView3.layer;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = m34;
    transform = CATransform3DRotate(transform, (-90+angleDiff) * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
    layer3.anchorPoint = CGPointMake(0, 0.5);
    layer3.transform = transform;
    layer3WidthAt90 = layer3.frame.size.width;
  }

  //Transformation for center 4 pages
  CALayer *layer1 = self.theView1.layer;
  CATransform3D transform = CATransform3DIdentity;
  transform.m34 = m34;
  transform = CATransform3DRotate(transform, (min+angleDiff) * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
  transform = CATransform3DScale(transform, scale1,scale1, 1.0);
  layer1.anchorPoint = CGPointMake(0, 0.5);
  layer1.transform = transform;
  
  CALayer *layer2 = self.theView2.layer;
  transform = CATransform3DIdentity;
  transform.m34 = m34;
  transform = CATransform3DRotate(transform, angle * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
  layer2.anchorPoint = CGPointMake(0, 0.5);
  layer2.transform = transform;
  
  CALayer *layer3 = self.theView3.layer;
  transform = CATransform3DIdentity;
  transform.m34 = m34;
  transform = CATransform3DRotate(transform, angle2 * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
  layer3.anchorPoint = CGPointMake(0, 0.5);
  layer3.transform = transform;
  
  CALayer *layer4 = self.theView4.layer;
  transform = CATransform3DIdentity;
  transform.m34 = m34;
  transform = CATransform3DRotate(transform, max * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
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
    self.theView1.frame = CGRectMake(CGRectGetMaxX(layer3.frame) - layer2WidthAt90 - MINOR_X_ADJUSTMENT_14 - layer3WidthAt90*positionScale/2.5,
                                     frameY, self.frameWidth, self.frameHeight);
    self.theView4.frame = CGRectMake(CGRectGetMaxX(layer3.frame), frameY, self.frameWidth, self.frameHeight);
    self.theView2.hidden = YES;
    self.theView3.hidden = NO;
  }
  //Flip to right
  else {
    self.theView1.frame = CGRectMake(CGRectGetMinX(layer2.frame), frameY, self.frameWidth, self.frameHeight);
    self.theView4.frame = CGRectMake(CGRectGetMinX(layer2.frame) + layer3WidthAt90 + MINOR_X_ADJUSTMENT_14 - layer3WidthAt90*positionScale/2.5,
                                     frameY, self.frameWidth, self.frameHeight);
    self.theView2.hidden = NO;
    self.theView3.hidden = YES;
  }

  //Hide irrelevant pages
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  for (int i=0; i <pageCount; i++) {
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
  }
    
  //Other pages transformation & position
  for (int i=0; i <pageCount; i++)
  {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    if ([page isEqual:self.theView1] || [page isEqual:self.theView2] || [page isEqual:self.theView3] || [page isEqual:self.theView4])
      continue;
    if (page.hidden)
      continue;
        
    float scale = [self getPepperScaleForPageIndex:i];
    
    if (i < self.controlIndex) {
      CALayer *layerLeft = page.layer;
      CATransform3D transform = CATransform3DIdentity;
      transform.m34 = m34;
      transform = CATransform3DRotate(transform, (min+angleDiff) * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
      transform = CATransform3DScale(transform, scale,scale, 1.0);
      layerLeft.anchorPoint = CGPointMake(0, 0.5);
      layerLeft.transform = transform;
    }
    else {
      CALayer *layerRight = page.layer;
      CATransform3D transform = CATransform3DIdentity;
      transform.m34 = m34;
      transform = CATransform3DRotate(transform, max * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
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
  int tempIndex = 0;
  
  //Detect change of page flipping index for cell reuse purpose
  static float previousControlIndex = -100;
  if (previousControlIndex == -100)
    previousControlIndex = theSpecialIndex;
  if (previousControlIndex != theSpecialIndex)
    [self onSpecialControlIndexChanged];
  previousControlIndex = theSpecialIndex;
  
  self.theView1 = nil;
  self.theView2 = nil;
  self.theView3 = nil;
  self.theView4 = nil;
  
  tempIndex = (int)round(theSpecialIndex - 1.5f);
  if (tempIndex >= 0 && tempIndex < pageCount)
    self.theView1 = [self getPepperPageAtIndex:tempIndex];
  
  tempIndex = (int)round(theSpecialIndex - 0.5f);
  if (tempIndex >= 0 && tempIndex < pageCount)
    self.theView2 = [self getPepperPageAtIndex:tempIndex];
  
  tempIndex = (int)round(theSpecialIndex + 0.5f);
  if (tempIndex >= 0 && tempIndex < pageCount)
    self.theView3 = [self getPepperPageAtIndex:tempIndex];
  
  tempIndex = (int)round(theSpecialIndex + 1.5f);
  if (tempIndex >= 0 && tempIndex < pageCount)
    self.theView4 = [self getPepperPageAtIndex:tempIndex];
  
  //[self addShadow];
}

- (void)onSpecialControlIndexChanged {
  [self reusePepperViews];
}

- (void)addShadow
{
  float corner = 0;
  float shadowRadius = 20.0;
  float shadowOpacity = 0.3;
  
  //Shadow
  self.theView1.layer.shadowColor = [[UIColor blackColor] CGColor];
  self.theView1.layer.shadowOpacity = shadowOpacity;
  self.theView1.layer.shadowRadius = shadowRadius;
  self.theView1.layer.shadowOffset = CGSizeMake(0, 0);
  self.theView1.layer.cornerRadius = corner;
  self.theView1.layer.masksToBounds = NO;
  UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.theView1.bounds];
  self.theView1.layer.shadowPath = path.CGPath;
  
  self.theView2.layer.shadowColor = [[UIColor blackColor] CGColor];
  self.theView2.layer.shadowOpacity = shadowOpacity;
  self.theView2.layer.shadowRadius = shadowRadius;
  self.theView2.layer.shadowOffset = CGSizeMake(0, 0);
  self.theView2.layer.cornerRadius = corner;
  self.theView2.layer.masksToBounds = NO;
  path = [UIBezierPath bezierPathWithRect:self.theView2.bounds];
  self.theView2.layer.shadowPath = path.CGPath;
  
  self.theView3.layer.shadowColor = [[UIColor blackColor] CGColor];
  self.theView3.layer.shadowOpacity = shadowOpacity;
  self.theView3.layer.shadowRadius = shadowRadius;
  self.theView3.layer.shadowOffset = CGSizeMake(0, 0);
  self.theView3.layer.cornerRadius = corner;
  self.theView3.layer.masksToBounds = NO;
  path = [UIBezierPath bezierPathWithRect:self.theView3.bounds];
  self.theView3.layer.shadowPath = path.CGPath;
  
  self.theView4.layer.shadowColor = [[UIColor blackColor] CGColor];
  self.theView4.layer.shadowOpacity = shadowOpacity;
  self.theView4.layer.shadowRadius = shadowRadius;
  self.theView4.layer.shadowOffset = CGSizeMake(0, 0);
  self.theView4.layer.cornerRadius = corner;
  self.theView4.layer.masksToBounds = NO;
  path = [UIBezierPath bezierPathWithRect:self.theView4.bounds];
  self.theView4.layer.shadowPath = path.CGPath;
}

- (void)animateControlIndexTo:(float)index duration:(float)duration
{
  if (self.controlIndexTimer != nil || [self.controlIndexTimer isValid])
    return;
  
  if (duration <= 0) {
    [self onControlIndexTimerFinish];
    return;
  }
  
  //0.016667 = 1/60
  self.controlIndexTimerLastTime = [[NSDate alloc] init];
  self.controlIndexTimerTarget = index;
  self.controlIndexTimerDx = (self.controlIndexTimerTarget - self.controlIndex) / (duration / 0.0166666667);
  self.controlIndexTimer = [NSTimer scheduledTimerWithTimeInterval: 0.0166666667
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
  float deltaDiff = deltaMs / 0.0166666667;
  
  float newValue = self.controlIndex + self.controlIndexTimerDx * deltaDiff;
  if (self.controlIndexTimerDx >= 0 && newValue > self.controlIndexTimerTarget)
    newValue = self.controlIndexTimerTarget;
  else if (self.controlIndexTimerDx < 0 && newValue < self.controlIndexTimerTarget)
    newValue = self.controlIndexTimerTarget;

  BOOL finish = fabs(newValue - self.controlIndexTimerTarget) <= fabs(self.controlIndexTimerDx*1.5);
  
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
  self.controlIndex = self.controlIndexTimerTarget;
  _controlAngle = -THRESHOLD_HALF_ANGLE;
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didFinishFlippingWithIndex:)])
    [self.delegate ppPepperViewController:self didFinishFlippingWithIndex:self.controlIndex];
}

#pragma mark - Pinch control implementation

- (void)showFullscreenUsingTimer
{
  self.isBookView = NO;
  self.isDetailView = YES;
  float diff = fabs(self.controlAngle - 0) / 45.0;

  //Populate detailed page scrollview
  [self setupPageScrollview];

  if (!self.oneSideZoom)    diff /= 1.3;
  else                      diff *= 1.3;
    
  [self animateControlAngleTo:0 duration:self.animationSlowmoFactor*diff];
}

- (void)showFullscreen:(BOOL)animated
{
  self.isBookView = NO;
  self.isDetailView = YES;

  //Populate detailed page scrollview
  [self setupPageScrollview];
  
  if (!animated) {
    self.controlAngle = 0;
    self.pageScrollView.hidden = NO;
    return;
  }
  
  float diff = fabs(self.controlAngle - 0) / 90.0;
  if (!self.oneSideZoom)    diff /= 1.3;
  else                      diff *= 1.3;
  
  [UIView animateWithDuration:self.animationSlowmoFactor*diff delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.controlAngle = 0;
  } completion:^(BOOL finished) {
    self.pageScrollView.hidden = NO;
    [[self.pageScrollView superview] bringSubviewToFront:self.pageScrollView];
  }];
}

- (void)showHalfOpenUsingTimer
{
  BOOL previousIsBookView = self.isBookView;
  self.isBookView = NO;
  self.isDetailView = NO;
  
  //Hide other view
  [self hidePageScrollview];
  
  //Re-setup book scrollview if we are coming out from fullscreen
  if (!previousIsBookView) {
    [self setupReuseablePoolBookViews];
    [self reuseBookScrollView];
  }

  float diff = fabs(self.controlAngle - (-THRESHOLD_HALF_ANGLE)) / 90.0;
  if (!self.oneSideZoom)    diff /= 1.3;
  else                      diff *= 1.3;
  
  [self animateControlAngleTo:-THRESHOLD_HALF_ANGLE duration:self.animationSlowmoFactor*diff];
}

- (void)showHalfOpen:(BOOL)animated
{
  BOOL previousIsBookView = self.isBookView;
  self.isBookView = NO;
  self.isDetailView = NO;
  
  //Hide other view
  [self destroyPageScrollView];
  
  //Re-setup book scrollview if we are coming out from fullscreen
  if (!previousIsBookView) {
    [self setupReuseablePoolBookViews];
    [self reuseBookScrollView];
  }
  
  if (!animated) {   
    self.controlAngle = -THRESHOLD_HALF_ANGLE;
    _controlFlipAngle = -THRESHOLD_HALF_ANGLE;
    self.controlIndex = self.controlIndex;
    return;
  }
  
  float diff = fabs(self.controlAngle - (-THRESHOLD_HALF_ANGLE)) / 90.0;
  if (!self.oneSideZoom)    diff /= 1.3;
  else                      diff *= 1.5;
  
  [UIView animateWithDuration:self.animationSlowmoFactor*diff delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.controlAngle = -THRESHOLD_HALF_ANGLE;
  } completion:^(BOOL finished) {
    _controlFlipAngle = -THRESHOLD_HALF_ANGLE;
    self.controlIndex = self.controlIndex;
  }];
}

- (void)closeCurrentList:(BOOL)animated
{
  self.isBookView = YES;
  self.isDetailView = NO;
  
  float diff = fabs(self.controlAngle - (-MAXIMUM_ANGLE)) / 90.0 / 1.3;
  if (diff < 0.4)
    diff = 0.4;
  
  //Dealloc fullscreen view
  [self destroyPageScrollView];
  
  //Re-setup book scrollview if needed
  [self setupReuseablePoolBookViews];
  [self reuseBookScrollView];
  [self addBookToScrollView:self.currentBookIndex];

  //Replace 1st page by book cover, need to redo this due to pepper page reuse
  [self addBookCoverToFirstPage:NO];
  
  //Should be already visible, just for sure
  self.bookScrollView.alpha = 1;
  for (UIView *subview in self.bookScrollView.subviews)
    if (subview.tag != self.currentBookIndex)
      subview.alpha = 1;
  
  if (!animated) {
    [self destroyPeperView];
    [self removeBookCoverFromFirstPage];
    return;
  }
  
  //Not perfect but good enough for fast animation
  float animationDuration = self.animationSlowmoFactor*diff;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, animationDuration * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    [self destroyPeperView];
    [self removeBookCoverFromFirstPage];
    
    //Notify the delegate
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didCloseBookIndex:)])
      [self.delegate ppPepperViewController:self didCloseBookIndex:self.currentBookIndex];
  });
  
  //This is where magic happens (animation)
  [self flattenAllPepperViews:diff];
}

- (void)flattenAllPepperViews:(float)animationDuration
{
  float m34 = M34;
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
    transform.m34 = m34;
    transform = CATransform3DRotate(transform, flatAngle * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
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
    
    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.fillMode = kCAFillModeBoth;
    animationGroup.removedOnCompletion = NO;
    [animationGroup setDuration:self.animationSlowmoFactor * animationDuration];
    [animationGroup setAnimations:[NSArray arrayWithObject:animation]];
    
    [layer addAnimation:animationGroup forKey:[NSString stringWithFormat:@"closeBookAnimation%d",i]];
  }
}

- (UIView*)getCurrentBookCover
{ 
  for (UIView *subview in self.bookScrollView.subviews)
    if (subview.tag == self.currentBookIndex)
      return subview;
  return nil;
}

- (void)addBookCoverToFirstPage:(BOOL)animated
{
  if (self.theBookCover != nil)
    return;
  self.theBookCover = [self getCurrentBookCover];
  if (self.theBookCover == nil)
    return;
  
  //Find the first visible page view
  int firstPageIndex = [self getFirstVisiblePepperPageIndex];
  UIView *firstPageView = [self getPepperPageAtIndex:firstPageIndex];
  if (firstPageView == nil)
    return;

  [firstPageView addSubview:self.theBookCover];
  [firstPageView.superview bringSubviewToFront:firstPageView];
  self.theBookCover.layer.transform = CATransform3DMakeScale(MAX_BOOK_SCALE, MAX_BOOK_SCALE, 1);
  self.theBookCover.frame = firstPageView.bounds;
  self.theBookCover.hidden = NO;
  self.theBookCover.alpha = 1;

  if (!animated)
    return;
    
  //Remove layer later (not perfect but good enough for fast animation)
  float animationDuration = self.animationSlowmoFactor*OPEN_BOOK_DURATION;
  float removeCoverDuration = (90.0-THRESHOLD_HALF_ANGLE)/(180.0-THRESHOLD_HALF_ANGLE) * animationDuration;    //this is a wrong fomula, but I have no idea why it works
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, removeCoverDuration * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    [self hideBookCoverFromFirstPage];
  });
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, animationDuration * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
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
  self.theBookCover.layer.transform = CATransform3DMakeScale(MAX_BOOK_SCALE, MAX_BOOK_SCALE, 1.0);
  
  //De-reference, dealloc
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
  if (self.controlAngle > -THRESHOLD_FULL_ANGLE)
    [self showFullscreenUsingTimer];
  
  else if (self.controlAngle > -THRESHOLD_CLOSE_ANGLE)
    [self showHalfOpenUsingTimer];
  
  else
    [self closeCurrentList:YES];
}

// This function controls everything about zooming
// @param: valid range 0 to -88
//         0:  fully open (flat)
//         -88: fully closed (leave a bit of perspective)
- (void)setControlAngle:(float)newControlAngle
{ 
  //Limits
  if (newControlAngle > 0)                  newControlAngle = 0;
  if (newControlAngle < -MAXIMUM_ANGLE)     newControlAngle = -MAXIMUM_ANGLE;
  float previousControlAngle = _controlAngle;
  _controlAngle = newControlAngle;
    
  //Memory management
  if (previousControlAngle < 0 && self.controlAngle >= 0) {
    [self setupPageScrollview];
    self.pepperView.hidden = YES;
  }
  else if (previousControlAngle >= 0 && self.controlAngle < 0) {
    [self setupReusablePoolPepperViews];
    [self reusePepperViews];
    self.pepperView.hidden = NO;
  }
  self.pageScrollView.hidden = (newControlAngle < 0);
  
  float scale = 1;
  BOOL isClosing = (newControlAngle < -THRESHOLD_HALF_ANGLE);
  scale = [self getPepperScaleForPageIndex:self.controlIndex];
  
  float frameScale = 0;
  if (newControlAngle > -THRESHOLD_HALF_ANGLE)
    frameScale = 1.0 - (newControlAngle/(-THRESHOLD_HALF_ANGLE));       //0 to 1
  
  float angle = newControlAngle;
  float angle2 = -180.0 - angle;
  float m34 = M34;
  
  [self updateLeftRightPointers];
  [self updateFlipPointers];
    
  //Fade in the other books
  CGFloat alpha = 0;
  if (self.controlAngle > -THRESHOLD_HALF_ANGLE-40) {
    alpha = 0;
  }
  else {
    alpha = fabs(self.controlAngle - (-THRESHOLD_HALF_ANGLE-40)) / 20;
    if (alpha > 1)
      alpha = 1;
  }
  
  //Fade book scrollview
  self.bookScrollView.alpha = alpha;
  for (UIView *subview in self.bookScrollView.subviews)
    if (subview.tag == self.currentBookIndex)
      subview.alpha = 0;
  
  //Notify the delegate
  if (self.controlAngle < -THRESHOLD_HALF_ANGLE)
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:closingBookWithAlpha:)])
      [self.delegate ppPepperViewController:self closingBookWithAlpha:alpha];
    
  CALayer *layerLeft = self.theLeftView.layer;
  CATransform3D transform = CATransform3DIdentity;
  transform.m34 = m34;
  transform = CATransform3DRotate(transform, angle2 * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
  if (!self.oneSideZoom || isClosing)
    transform = CATransform3DScale(transform, scale,scale, 1.0);
  layerLeft.anchorPoint = CGPointMake(0, 0.5);
  layerLeft.transform = transform;
  self.theLeftView.hidden = [self.theLeftView isEqual:[self getPepperPageAtIndex:0]] && self.hideFirstPage ? YES : NO;
  
  CALayer *layerRight = self.theRightView.layer;
  transform = CATransform3DIdentity;
  transform.m34 = m34;
  transform = CATransform3DRotate(transform, angle * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
  if (!self.oneSideZoom || isClosing)
    transform = CATransform3DScale(transform, scale,scale, 1.0);
  layerRight.anchorPoint = CGPointMake(0, 0.5);
  layerRight.transform = transform;
  self.theRightView.hidden = NO;
  
  //Default bias to left page
  self.currentPageIndex = self.controlIndex - 0.5;
  
  //Zoom in on 1 side
  if (self.oneSideZoom) {
    int frameY = [self getFrameY];
    int midPositionX = [self getMidXForOrientation:[UIApplication sharedApplication].statusBarOrientation];
    //int midPositionY = [self getMidYForOrientation:[UIApplication sharedApplication].statusBarOrientation];
    CGRect leftFrameOriginal = CGRectMake(midPositionX, frameY, self.frameWidth, self.frameHeight);
    float aspectRatio = (float)self.frameWidth / (float)self.frameHeight;
    CGRect frame;
    frame.origin.x = leftFrameOriginal.origin.x + ((self.zoomOnLeft ? self.view.bounds.size.width : 0) - leftFrameOriginal.origin.x) * frameScale;
    frame.size.width = leftFrameOriginal.size.width + (self.view.bounds.size.width - leftFrameOriginal.size.width) * frameScale;
    frame.size.height = frame.size.width / aspectRatio;
    frame.origin.y = leftFrameOriginal.origin.y - (leftFrameOriginal.origin.y * frameScale) - EDGE_PADDING*frameScale;
    self.theLeftView.frame = frame;
    self.theRightView.frame = frame;
    
    self.currentPageIndex = self.zoomOnLeft ? self.controlIndex - 0.5 : self.controlIndex + 0.5;
  }
  
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

    //If current left & right page already cover this page
    if (self.oneSideZoom && self.controlAngle > -THRESHOLD_HALF_ANGLE) {
      BOOL isCovered = CGRectGetMinX(self.theLeftView.frame) < CGRectGetMinX(page.frame) && CGRectGetMaxX(page.frame) < CGRectGetMaxX(self.theRightView.frame);
      if (isCovered) {
        page.hidden = YES;
        continue;
      }
    }
    
    //Fallback hardcoded condition for above
    if (self.oneSideZoom && scale > 1.15) {

      if (i > self.controlIndex) {
        if (self.zoomOnLeft) {
          page.hidden = YES;
          continue;
        }
      }
      else {
        if (!self.zoomOnLeft) {
          page.hidden = YES;
          continue;
        }
      }
    }
    
    page.hidden = NO;
  }
  
  //Other pages scale & transform
  
  for (int i=0; i <pageCount; i++)
  {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    if ([page isEqual:self.theLeftView] || [page isEqual:self.theRightView])
      continue;
    if (page.hidden)
      continue;
    
    float scale = [self getPepperScaleForPageIndex:i];
    /*
    if (self.controlAngle < -THRESHOLD_HALF_ANGLE) {
      float factor = (self.controlAngle-(-THRESHOLD_HALF_ANGLE)) / ((-MAXIMUM_ANGLE)-(-THRESHOLD_HALF_ANGLE));
      float newScale = scale + (1.0-scale) * factor;
      scale = newScale;
    }
    else {
      //scale for middle 4 pages is 1.0 in normal case
      if (self.controlIndex-2.6 < i && i < self.controlIndex+2.6)
        scale = 1;
    }
     */

    if (i < self.controlIndex) {
      CALayer *layerLeft = page.layer;
      CATransform3D transform = CATransform3DIdentity;
      transform.m34 = m34;
      transform = CATransform3DRotate(transform, angle2 * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
      transform = CATransform3DScale(transform, scale,scale, 1.0);
      layerLeft.anchorPoint = CGPointMake(0, 0.5);
      layerLeft.transform = transform;
    }
    else {
      CALayer *layerRight = page.layer;
      CATransform3D transform = CATransform3DIdentity;
      transform.m34 = m34;
      transform = CATransform3DRotate(transform, angle * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
      transform = CATransform3DScale(transform, scale,scale, 1.0);
      layerRight.anchorPoint = CGPointMake(0, 0.5);
      layerRight.transform = transform;
    }
  }
  
  //Other pages position
  
  //This controls the pulling together of the pages when closing book
  float positionScale = 1.0f;
  if (newControlAngle > -THRESHOLD_HALF_ANGLE)
    positionScale = 0.5f + (newControlAngle / (-THRESHOLD_HALF_ANGLE))/2;
  else {
    positionScale = 1.0f - fabs(newControlAngle-(-THRESHOLD_HALF_ANGLE)) / fabs(-MAXIMUM_ANGLE-(-THRESHOLD_HALF_ANGLE));
    positionScale = 0.07f + positionScale * 0.93f;
  }
  if (positionScale < 0)
    positionScale = 0;
  
  for (int i=0; i <pageCount; i++)
  {
    PPPageViewContentWrapper *page = [self getPepperPageAtIndex:i];
    if (page == nil)
      continue;
    if ([page isEqual:self.theLeftView] || [page isEqual:self.theRightView])      //always centered
      continue;
    if (page.hidden)
      continue;
        
    //Smooth transition of position
    float frameY = [self getFrameY];
    float frameX = [self getPepperFrameXForPageIndex:i gapScale:(float)positionScale];
    page.frame = CGRectMake(frameX, frameY, self.frameWidth, self.frameHeight);
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
  
  //0.0166666667 = 1/60
  self.controlAngleTimerLastTime = [[NSDate alloc] init];
  self.controlAngleTimerTarget = angle;
  self.controlAngleTimerDx = (self.controlAngleTimerTarget - self.controlAngle) / (duration / 0.0166666667);
  self.controlAngleTimer = [NSTimer scheduledTimerWithTimeInterval: 0.0166666667
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
  float deltaDiff = deltaMs / 0.0166666667;
  
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
  
  //Not open fullscreen
  if (self.controlAngle < 0)
    return;
  
  //Notify the delegate about didOpenBookIndex
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didOpenBookIndex:atPageIndex:)])
    [self.delegate ppPepperViewController:self didOpenBookIndex:self.currentBookIndex atPageIndex:self.currentPageIndex];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)theScrollView {

  //Fullscreen page scrolling
  if ([theScrollView isEqual:self.pageScrollView]) {
    int offsetX = fabs(self.pageScrollView.contentOffset.x);
    float pageIndex = offsetX / self.pageScrollView.bounds.size.width;
    
    //Notify the delegate
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didScrollWithPageIndex:)])
      [self.delegate ppPepperViewController:self didScrollWithPageIndex:pageIndex];
    return;
  }
  
  if (![theScrollView isEqual:self.bookScrollView])
    return;
  
  //Scale & rotate the book views
  int edgeWidth = CGRectGetWidth(self.bookScrollView.bounds)/2.5;
  for (UIView *subview in self.bookScrollView.subviews) {
    float subviewMidX = CGRectGetMidX(subview.frame) - fabs(self.bookScrollView.contentOffset.x);
    
    float scaleForAngle = 1.0;
    if (subviewMidX < edgeWidth)
      scaleForAngle = subviewMidX / (float)edgeWidth;
    else if (subviewMidX > CGRectGetWidth(self.bookScrollView.bounds)-edgeWidth)
      scaleForAngle = 1.0 - (float)(subviewMidX-CGRectGetWidth(self.bookScrollView.bounds)+edgeWidth) / (float)edgeWidth;
    
    if (scaleForAngle < 0)        scaleForAngle = 0;
    else if (scaleForAngle > 1)   scaleForAngle = 1;
    float angle = ((1.0-scaleForAngle) * MAX_BOOK_ROTATE)/180.0*M_PI;
    if (subviewMidX < edgeWidth)
      angle *= -1;
    
    float scale = scaleForAngle * (MAX_BOOK_SCALE-MIN_BOOK_SCALE) + MIN_BOOK_SCALE;
    if (!self.enableBookScale)
      scale = MAX_BOOK_SCALE;
    CGPoint previousAnchor = subview.layer.anchorPoint;
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = M34;
    transform = CATransform3DScale(transform, scale, scale, 1.0);
    if (self.enableBookRotate)
      transform = CATransform3DRotate(transform, angle, 0, 1, 0);
    subview.layer.anchorPoint = previousAnchor;
    subview.layer.transform = transform;
  }
  
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
      self.pageScrollView.hidden = NO;
      self.pepperView.hidden = NO;
      
      //Notify the delegate
      if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didZoomWithPageIndex:zoomScale:)])
        [self.delegate ppPepperViewController:self didZoomWithPageIndex:self.currentPageIndex zoomScale:theScrollView.zoomScale];
      return;
    }
    
    float scale = theScrollView.zoomScale;      //1.0 and smaller
    theScrollView.hidden = (scale < 1.0) ? YES : NO;
    self.pepperView.hidden = !theScrollView.hidden;

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
  if (scale > 1)
    if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didEndZoomingWithPageIndex:zoomScale:)])
      [self.delegate ppPepperViewController:self didEndZoomingWithPageIndex:self.currentPageIndex zoomScale:theScrollView.zoomScale];
}

- (void)didSnapPageScrollview {
  
  self.currentPageIndex = floor((self.pageScrollView.contentOffset.x - CGRectGetWidth(self.pageScrollView.bounds) / 2) / CGRectGetWidth(self.pageScrollView.bounds)) + 1;
  if (self.hideFirstPage)
    self.currentPageIndex += 1;
  
  self.pepperView.hidden = YES;
  self.pageScrollView.userInteractionEnabled = YES;
  self.zoomOnLeft = ((int)self.currentPageIndex % 2 == 0) ? YES : NO;
  self.controlIndex = ((int)self.currentPageIndex % 2 == 0) ? self.currentPageIndex+0.5 : self.currentPageIndex-0.5;
  self.controlAngle = 0;
  [self.view bringSubviewToFront:self.pageScrollView];
  
  [self reusePageScrollview];
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPepperViewController:didSnapToPageIndex:)])
    [self.delegate ppPepperViewController:self didSnapToPageIndex:self.currentPageIndex];
}



/*
#pragma mark - Downloading (Book)
 
- (void)fetchBookThumbnailsMultithread {
  int startIndex = self.hideFirstPage ? 1 : 0;
  for (int i=startIndex; i<NUM_DOWNLOAD_THREAD+startIndex; i++)
    [self fetchBookThumbnails:i];
}

- (void)fetchBookThumbnails:(NSUInteger)index {
  
  int bookCount = [self getNumberOfBooks];
  if (index >= bookCount)
    return;
  
  int pageCount = [self getNumberOfPagesForBookIndex:index];
  if (pageCount <= 0)
    return;
  
  Page *page = [pageArray objectAtIndex:0];
  NSString *imagePath = page.halfsizeURL;
  
  if (imagePath != nil) {
    [self fetchBookThumbnails:index+NUM_DOWNLOAD_THREAD];
    return;
  }
  
  [self fetchThumbnailForPageID:page.pageID success:^(NSData *data) {
    [self didDownloadBookThumbnailWithIndex:index];
    [self fetchBookThumbnails:index+NUM_DOWNLOAD_THREAD];
  } failure:^(NSError *error) {
    NSLog(@"Error in downloading thumbnail of page %@, with error %@", page.pageID, [error localizedDescription]);
    [self fetchBookThumbnails:index];
  }];
}

- (void)didDownloadBookThumbnailWithIndex:(NSUInteger)index {
  int bookCount = [self getNumberOfBooks];
  if (index >= bookCount)
    return;
  for (PPPageViewWrapper *book in self.bookScrollView.subviews) {
    if (book.tag != index)
      continue;
    PPPageViewContent *pageContent = book.contentView;
    [pageContent refresh];
    break;
  }
}


#pragma mark - Downloading (Pepper)

- (void)fetchPageLargeThumbnailsMultithread {
  int startIndex = self.hideFirstPage ? 1 : 0;
  for (int i=startIndex; i<NUM_DOWNLOAD_THREAD+startIndex; i++)
    [self fetchPageLargeThumbnails:i];
}

- (void)fetchPageLargeThumbnails:(NSUInteger)index {
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index >= pageCount)
    return;
  
  NSString *imagePath = page.halfsizeURL;
  
  if (imagePath != nil) {
    [self fetchPageLargeThumbnails:index+NUM_DOWNLOAD_THREAD];
    return;
  }
  
  [self fetchThumbnailForPageID:index success:^(NSData *data) {
    [self didDownloadPageLargeThumbnailWithIndex:index];
    [self fetchPageLargeThumbnails:index+NUM_DOWNLOAD_THREAD];
  } failure:^(NSError *error) {
    NSLog(@"Error in downloading thumbnail of page %@, with error %@", page.pageID, [error localizedDescription]);
    [self fetchPageLargeThumbnails:index];
  }];
}

- (void)didDownloadPageLargeThumbnailWithIndex:(NSUInteger)index {
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index >= pageCount)
    return;
  PPPageViewWrapper *page = [self getPepperPageAtIndex:index];
  if (page == nil)
    return;
  PPPageViewContent *pageContent = page.contentView;
  [pageContent refresh];
}


#pragma mark - Downloading (Page)

- (void)fetchFullsizeInBackground:(NSUInteger)index {
  
  int pageCount = [self getNumberOfPagesForBookIndex:self.currentBookIndex];
  if (index >= pageCount) {
    self.backgroundDownloadPage = nil;
    return;
  }
  
  UIImage *fullsize = [self getCachedFullsizeForPageID:index];
  if (fullsize != nil || [thePageModel isEqual:self.onDemandDownloadPdf]) {
    [self didDownloadFullsizeWithIndex:index];
    [self fetchFullsizeInBackground:index+1];
    return;
  }
  
  NSLog(@"downloading fullsize image for index: %d", index);
  self.backgroundDownloadPage = thePageModel;
  [self fetchFullsizeForPageID:thePageModel.pageID success:^(NSData *data){
    [self didDownloadFullsizeWithIndex:index];
    [self fetchFullsizeInBackground:index+1];

  } failure:^(NSError *error){
    NSLog(@"Error in downloading fullsize image for index %d, with error %@", index, [error localizedDescription]);
    [self fetchFullsizeInBackground:index];
  }];
}

- (void)fetchFullsizeOnDemand:(NSUInteger)index {
  
  //If the on-demand page is not already downloaded, add it to the first in queue (last in array)
  if (index > 0) {
    Page *thePageModel = [self.pageModelArray objectAtIndex:index];
    UIImage *fullsize = [self getCachedFullsizeForPageID:thePageModel.pageID];
    if (fullsize == nil)
      [self.fullsizeOnDemandQueue addObject:thePageModel];
  }
  
  //Nothing else to download
  if (self.fullsizeOnDemandQueue == nil || self.fullsizeOnDemandQueue.count <= 0) {
    self.onDemandDownloadPdf = nil;
    return;
  }
  
  //Already downloaded or being downloaded by background thread, skip it
  Page *thePageModel = [self.fullsizeOnDemandQueue lastObject];
  UIImage *fullsize = [self getCachedFullsizeForPageID:thePageModel.pageID];
  if (fullsize != nil || [thePageModel isEqual:self.backgroundDownloadPage]) {
    [self.fullsizeOnDemandQueue removeObject:thePageModel];
    [self fetchFullsizeOnDemand:0];
    return;
  }
  
  NSLog(@"downloading on-demand fullsize image for index: %d (ID: %d)", index, thePageModel.pageID);
  self.onDemandDownloadPdf = thePageModel;
  [self fetchFullsizeForPageID:thePageModel.pageID success:^(NSData *data){
    [self didDownloadFullsizeWithIndex:index];
    [self fetchFullsizeInBackground:index+1];
    
  } failure:^(NSError *error){
    NSLog(@"Error in downloading on-demand fullsize image for pageID %@, with error %@", thePageModel.pageID, [error localizedDescription]);
    [self fetchFullsizeInBackground:index];
  }];
}

- (void)didDownloadFullsizeWithIndex:(NSUInteger)index {
  
  if (![[self.pageModelArray objectAtIndex:index] isKindOfClass:[Page class]])
    return;
  Page *thePageModel = [self.pageModelArray objectAtIndex:index];
      
  for (PPPageViewDetailWrapper *subview in self.pageScrollView.subviews) {
    if (subview.tag != thePageModel.pageID)
      continue;
    UIImage *image = [self getCachedThumbnailForPageID:thePageModel.pageID];
    UIImage *fullsize = [self getCachedFullsizeForPageID:thePageModel.pageID];
    if (fullsize != nil)
      [subview loadWithFrame:subview.frame thumbnail:image fullsize:fullsize];
    break;
  }
}



- (void)fetchThumbnailForPageID:(int)pageID
             success:(void (^)(NSData *data))success 
             failure:(void (^)(NSError *error))failure
{
  
}

- (void)fetchFullsizeForPageID:(int)pageID
           success:(void (^)(NSData *data))success 
           failure:(void (^)(NSError *error))failure
{

}

*/
#pragma mark - Dummy PPScrollListViewControllerDelegate

- (void)ppPepperViewController:(PPPepperViewController*)scrollList didTapOnBookIndex:(int)tag
{
  if (AUTO_OPEN_BOOK)
    return;
  [self openCurrentBookAtPageIndex:0];
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
    myLabel.font = [UIFont systemFontOfSize:12];
    myLabel.numberOfLines = 0;
    myLabel.textAlignment = UITextAlignmentCenter;
    myLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
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
    myLabel.font = [UIFont systemFontOfSize:12];
    myLabel.numberOfLines = 0;
    myLabel.textAlignment = UITextAlignmentCenter;
    myLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
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
    myLabel.font = [UIFont systemFontOfSize:12];
    myLabel.numberOfLines = 0;
    myLabel.textAlignment = UITextAlignmentCenter;
    myLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
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
