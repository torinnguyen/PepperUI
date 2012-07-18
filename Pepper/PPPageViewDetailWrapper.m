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
        
    [self initBackgroundImage];
    
    //Don't care about the frame & contentSize, we will relayout later
    
    self.background = [[UIImageView alloc] initWithImage:backgroundImage];
    self.background.backgroundColor = [UIColor clearColor];
    self.background.contentMode = UIViewContentModeScaleToFill;
    self.background.autoresizesSubviews = YES;
    [self addSubview:self.background];
    
    // Create gesture recognizer
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOneFingerTap)];
    [self.tapGestureRecognizer setNumberOfTapsRequired:1];
    [self.tapGestureRecognizer setNumberOfTouchesRequired:1];
    self.tapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:self.tapGestureRecognizer];
  }
  return self;
}

- (void)dealloc
{
  [self unloadContent];
}

- (void)setContentView:(UIView *)theContentView
{
  [self reset:NO];
  
  [_myContentView removeFromSuperview];
  _myContentView = nil;
  _myContentView = theContentView;
  
  if (theContentView == nil) {
    self.contentSize = CGSizeZero;
    return;
  }
    
  //Flip background horizontally for even page
  if (self.tag%2 == 0)  self.background.image = backgroundImageFlipped;
  else                  self.background.image = backgroundImage;
  
  theContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.background addSubview:theContentView];
}

- (void)setBackgroundImage:(UIImage*)image
{  
  backgroundImageFlipped = nil;
  backgroundImage = image;
  [self initBackgroundImage];
  
  if (self.tag%2 == 0)  self.background.image = backgroundImageFlipped;
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
  self.originalFrame = frame;
  self.previousZoomScale = 1.0f;
  self.contentOffsetBeforeZoomOut = CGPointZero;
   
  [self reset:NO];
}

#pragma mark - Helpers

- (void)unloadContent
{
  [self.contentView removeFromSuperview];
  self.contentView = nil;
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
  self.background.frame = bgFrame;
  self.contentView.frame = self.background.bounds;
  
  //This is a bit complex
  float ratio = self.aspectRatio;
  ratio = [self adjustRatioForBiggerFrame:self.originalFrame];
  
  float bgframeHeight = self.originalFrame.size.width * ratio;
  float margin = round( self.edgePaddingHeightPercent * bgframeHeight );
  
  //Content offset & size
  self.contentOffset = self.contentOffsetBeforeZoomOut;
  self.contentSize = CGSizeMake(bgFrame.size.width, bgFrame.size.height - 2*margin);
    
  if (self.contentView != nil && [self.contentView respondsToSelector:@selector(reset)])
    [self.contentView performSelector:@selector(reset)];
  
  self.delegate = prevDelegate;
}

- (CGRect)getBackgroundFrameForWrapperFrame:(CGRect)frame
{
  //This is a bit complex
  float ratio = self.aspectRatio;
  ratio = [self adjustRatioForBiggerFrame:frame];
  
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

- (void)onOneFingerTap
{
  if (self.customDelegate != nil && [self.customDelegate respondsToSelector:@selector(PPPageViewDetailWrapper:viewDidTap:)])
    [self.customDelegate PPPageViewDetailWrapper:self viewDidTap:self.tag];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  return YES;
}

@end
