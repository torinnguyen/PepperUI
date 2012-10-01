//
//  PPPageViewDetail.m
//
//  Created by Torin Nguyen on 2/6/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PPPepperContants.h"
#import "PPPageViewDetailWrapper.h"

static UIImage *backgroundImage = nil;
static UIImage *backgroundImageFlipped = nil;

#define MAXIMUM_ZOOM_SCALE  4.0f

@interface PPPageViewDetailWrapper() <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIImageView *background;
@property (nonatomic, assign) float aspectRatio;
@property (nonatomic, assign) float edgePaddingHeightPercent;
@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, assign) CGPoint contentOffsetBeforeZoomOut;
@property (nonatomic, assign) float previousZoomScale;
@property (nonatomic, retain) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, retain) UITapGestureRecognizer *doubleTapGestureRecognizer;
@end

@implementation PPPageViewDetailWrapper

@synthesize customDelegate;
@synthesize contentView = _myContentView;
@synthesize background;
@synthesize aspectRatio;
@synthesize edgePaddingHeightPercent;
@synthesize originalFrame;
@synthesize contentOffsetBeforeZoomOut;
@synthesize previousZoomScale;
@synthesize tapGestureRecognizer;
@synthesize doubleTapGestureRecognizer;

#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.contentView = nil;
    self.delegate = self;
    self.minimumZoomScale = 0.1f;                   //don't change this, needed for Pepper view operation
    self.maximumZoomScale = MAXIMUM_ZOOM_SCALE;     //user might change this
    self.previousZoomScale = 1.0f;
    self.bouncesZoom = NO;
    self.bounces = NO;
    self.directionalLockEnabled = YES;
        
    [self initBackgroundImage];
    
    //Don't care about the frame & contentSize, we will relayout later
    
    self.background = [[UIImageView alloc] initWithImage:backgroundImage];
    self.background.backgroundColor = [UIColor clearColor];
    self.background.contentMode = UIViewContentModeScaleToFill;
    self.background.autoresizesSubviews = YES;
    [self addSubview:self.background];
        
    // Create gesture recognizer
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOneFingerTap:)];
    [self.tapGestureRecognizer setNumberOfTapsRequired:1];
    [self.tapGestureRecognizer setNumberOfTouchesRequired:1];
    self.tapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:self.tapGestureRecognizer];
    
    self.doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
    [self.doubleTapGestureRecognizer setNumberOfTapsRequired:2];
    [self.doubleTapGestureRecognizer setNumberOfTouchesRequired:1];
    self.doubleTapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:self.doubleTapGestureRecognizer];
    
  	[self.tapGestureRecognizer requireGestureRecognizerToFail:self.doubleTapGestureRecognizer];
  }
  return self;
}

- (void)dealloc
{
  [self unloadContent];
}

- (void)setContentView:(UIView *)theContentView
{    
  [_myContentView removeFromSuperview];
  _myContentView = nil;
  _myContentView = theContentView;
  
  if (theContentView == nil) {
    self.contentSize = CGSizeMake(10,10);
    return;
  }
  
  [self reset:NO];
    
  //Flip background horizontally for even page
  if (self.tag%2 == 0)  self.background.image = backgroundImageFlipped;
  else                  self.background.image = backgroundImage;
  
  theContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.background addSubview:theContentView];
  
  theContentView.hidden = NO;
}

- (void)setBackgroundImage:(UIImage*)image
{  
  backgroundImageFlipped = nil;
  backgroundImage = image;
  [self initBackgroundImage];
      
  if (self.tag%2 == 0)  self.background.image = backgroundImageFlipped;   //This causes 'singular matrix' error
  else                  self.background.image = backgroundImage;
}

- (void)initBackgroundImage
{
  if (backgroundImage == nil) {
    self.aspectRatio = 1;
    self.edgePaddingHeightPercent = 0;
    return;
  }
  
  if (backgroundImageFlipped == nil)
    backgroundImageFlipped = [UIImage imageWithCGImage:backgroundImage.CGImage 
                                                 scale:1.0
                                           orientation:UIImageOrientationUpMirrored];
  if (FRAME_ASPECT_RATIO > 0)
    self.aspectRatio = FRAME_ASPECT_RATIO;
  else
    self.aspectRatio = backgroundImage.size.height / backgroundImage.size.width;
  
  self.edgePaddingHeightPercent = EDGE_PADDING / backgroundImage.size.height;
}

//
// If the frame is bigger than native background frame, scale it to frame
//
- (float)adjustRatioForBiggerFrame:(CGRect)frame
{
  //Calculate the content height with current ratio
  float ratio = self.aspectRatio;
  float bgframeHeight = frame.size.width * ratio;
  float margin = round( self.edgePaddingHeightPercent * (frame.size.width * ratio) );
  float contentFrameHeight = bgframeHeight - 2*margin;
  
  //Not smaller, return the same number
  if (contentFrameHeight >= frame.size.height)
    return ratio;
  contentFrameHeight = frame.size.height;
  
  //Calculate new background height
  bgframeHeight = contentFrameHeight / (1.0 - 2*self.edgePaddingHeightPercent);
  ratio = bgframeHeight / frame.size.width;
  
  return ratio;
}

- (void)layoutWithFrame:(CGRect)frame duration:(float)duration
{
  BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
  if (isLandscape && FRAME_ASPECT_RATIO_LANDSCAPE > 0)
    self.aspectRatio = FRAME_ASPECT_RATIO_LANDSCAPE;
  else if (!isLandscape && FRAME_ASPECT_RATIO > 0)
    self.aspectRatio = FRAME_ASPECT_RATIO;
  
  self.originalFrame = frame;
  self.previousZoomScale = 1.0f;
  self.contentOffsetBeforeZoomOut = CGPointZero;
   
  [self reset:NO];
}

- (void)setEnableScrollingZooming:(BOOL)enable
{
  self.scrollEnabled = enable;
  if (enable)     self.maximumZoomScale = MAXIMUM_ZOOM_SCALE;
  else            self.maximumZoomScale = 1;
}



#pragma mark - Helpers

- (void)unloadContent
{
  self.contentView.hidden = YES;
  
  //This is too expensive
  //[self.contentView removeFromSuperview];
  //self.contentView = nil;
}

/*
 * Reset everything. animated property is not used yet.
 */
- (void)reset:(BOOL)animated
{
  [self resetWithoutOffset:animated];
  
  //Prevent unwanted delegate call
  id prevDelegate = self.delegate;
  self.delegate = nil;

  self.previousZoomScale = 1.0f;
  self.contentOffsetBeforeZoomOut = CGPointZero;
  self.contentOffset = CGPointZero;
  self.delegate = prevDelegate;
}

/*
 * Reset everything except contentOffset. animated property is not used yet.
 */
- (void)resetWithoutOffset:(BOOL)animated
{
  //Prevent unwanted delegate call
  id prevDelegate = self.delegate;
  self.delegate = nil;
  
  self.zoomScale = 1.0f;
  
  //Kill 'em all
  self.transform = CGAffineTransformIdentity;
  self.layer.transform = CATransform3DIdentity;
  self.background.transform = CGAffineTransformIdentity;
  self.background.layer.transform = CATransform3DIdentity;
  
  //Zooming causes the background.frame to drift
  CGRect bgFrame = [self getBackgroundFrameForWrapperFrame:self.originalFrame];
  if (bgFrame.size.width > 0 && bgFrame.size.height > 0)
    self.background.frame = bgFrame;
  self.contentView.frame = self.background.bounds;
   
  //This is a bit complex
  float ratio = [self adjustRatioForBiggerFrame:self.originalFrame];
      
  float bgframeHeight = self.originalFrame.size.width * ratio;
  float margin = round( self.edgePaddingHeightPercent * bgframeHeight );
  
  //Content offset & size
  self.contentOffset = self.contentOffsetBeforeZoomOut;
  if (bgFrame.size.width > 0 && bgFrame.size.height > 2*margin)
    self.contentSize = CGSizeMake(bgFrame.size.width, bgFrame.size.height - 2*margin);
  
  if (self.contentView != nil && [self.contentView respondsToSelector:@selector(reset)])
    [self.contentView performSelector:@selector(reset)];
  
  self.delegate = prevDelegate;
}

- (CGRect)getBackgroundFrameForWrapperFrame:(CGRect)frame
{
  //This is a bit complex
  float ratio = [self adjustRatioForBiggerFrame:frame];
  
  float bgframeHeight = frame.size.width * ratio;
  float margin = round( self.edgePaddingHeightPercent * bgframeHeight );
  
  CGRect bgframe = CGRectZero;
  bgframe.origin.x = 0;
  bgframe.origin.y = -margin;
  bgframe.size.width = frame.size.width;
  bgframe.size.height = bgframeHeight;
  
  return bgframe;
}


#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
  return self.background;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (self.zoomScale == 1.0)
    self.contentOffsetBeforeZoomOut = self.contentOffset;
}

- (void)scrollViewDidZoom:(UIScrollView *)theScrollView
{  
  if (self.previousZoomScale >= 1 && self.zoomScale <= 1.0)
    self.contentOffsetBeforeZoomOut = self.contentOffset;
  self.previousZoomScale = self.zoomScale;
  
  if ([self.customDelegate respondsToSelector:@selector(scrollViewDidZoom:)])
    [self.customDelegate scrollViewDidZoom:theScrollView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)theScrollView withView:(UIView *)view atScale:(float)scale
{
  if (scale >= 1.0)
    return;

  if ([self.customDelegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)])
    [self.customDelegate scrollViewDidEndZooming:theScrollView withView:view atScale:scale];
}


#pragma mark - Gesture

- (void)onOneFingerTap:(UITapGestureRecognizer *)recognizer
{
  if (self.customDelegate != nil && [self.customDelegate respondsToSelector:@selector(PPPageViewDetailWrapper:viewDidTap:)])
    [self.customDelegate PPPageViewDetailWrapper:self viewDidTap:self.tag];
}

- (void)onDoubleTap:(UITapGestureRecognizer *)recognizer
{
  //No double tap in side-by-side mode
  //Don't put this in gestureRecognizerShouldBegin to avoid double tap generating tap delegate event
  if (!self.scrollEnabled || self.maximumZoomScale <= 1)
    return;
  
  float newZoomScale = self.zoomScale;
  float halfZoomScale = 1.0/2 + self.maximumZoomScale/2;
  if (newZoomScale < halfZoomScale)       newZoomScale = self.maximumZoomScale;
  else                                    newZoomScale = 1.0f;
  
  CGPoint tapPoint = [recognizer locationInView:self];
	[self zoomToScale:newZoomScale atPoint:tapPoint animated:YES];
  
  if (self.customDelegate != nil && [self.customDelegate respondsToSelector:@selector(PPPageViewDetailWrapper:viewDidDoubleTap:)])
    [self.customDelegate PPPageViewDetailWrapper:self viewDidDoubleTap:self.tag];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  return NO;
}

- (void)zoomToScale:(float)newScale atPoint:(CGPoint)point animated:(BOOL)animated
{  
  float currentZoomScale = self.zoomScale;
  float x,y;
  [self setZoomScale:newScale animated:animated];
  
  //Currently zoomed out, now perform zoom in
  float halfZoomScale = 1.0/2 + self.maximumZoomScale/2;
  if (newScale >= halfZoomScale)
  {
    x = point.x*newScale - self.bounds.size.width/2;
    y = point.y*newScale - self.bounds.size.height/2;
  }
  else
  {
    x = 0;
    y = (point.y*1/currentZoomScale - self.bounds.size.height/2);
  }

  //Limit to content bounds
  if (x < 0)   x = 0;
  if (y < 0)   y = 0;
  if (x > self.contentSize.width - self.bounds.size.width)
    x = self.contentSize.width - self.bounds.size.width;
  if (y > self.contentSize.height - self.bounds.size.height)
    y = self.contentSize.height - self.bounds.size.height;
  
  [self setContentOffset:CGPointMake(x, y) animated:NO];
}

@end
