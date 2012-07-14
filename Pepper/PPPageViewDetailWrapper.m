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

@interface PPPageViewDetailWrapper() <UIScrollViewDelegate>
@property (nonatomic, strong) UIImageView *background;
@property (nonatomic, assign) float aspectRatio;
@property (nonatomic, assign) float edgePaddingHeightPercent;
@end

@implementation PPPageViewDetailWrapper

@synthesize customDelegate;
@synthesize contentView = _myContentView;
@synthesize background;
@synthesize aspectRatio;
@synthesize edgePaddingHeightPercent;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.contentView = nil;
    self.delegate = self;
    self.minimumZoomScale = 0.1f;                   //don't change this, needed for Pepper view operation
    self.maximumZoomScale = MAXIMUM_ZOOM_SCALE;     //user might change this
    
    [self initBackgroundImage];
    
    //Don't care about the frame & contentSize, we will relayout later
    
    self.background = [[UIImageView alloc] initWithImage:backgroundImage];
    self.background.backgroundColor = [UIColor clearColor];
    self.background.contentMode = UIViewContentModeScaleToFill;
    self.background.autoresizesSubviews = YES;
    [self addSubview:self.background];
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
  //This is a bit complex
  float ratio = self.aspectRatio;
  ratio = [self adjustRatioForBiggerFrame:frame];
  
  float bgframeHeight = frame.size.width * ratio;
  float margin = round( self.edgePaddingHeightPercent * bgframeHeight );
  
  CGRect bgframe = [self getBackgroundFrameForWrapperFrame:frame];
  
  //Content size
  self.contentOffset = CGPointZero;
  self.contentSize = CGSizeMake(bgframe.size.width, bgframe.size.height - 2*margin);   

  //Debug
  /*
  NSLog(@"index: %d   %.1f %.1f %.1f", self.tag, self.aspectRatio, ratio, margin);
  NSLog(@"frame %.1f %.1f %.1f %.1f", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
  NSLog(@"bgframe %.1f %.1f %.1f %.1f", bgframe.origin.x, bgframe.origin.y, bgframe.size.width, bgframe.size.height);
  NSLog(@"contentFrame %.1f %.1f %.1f %.1f", contentFrame.origin.x, contentFrame.origin.y, contentFrame.size.width, contentFrame.size.height);
  self.background.backgroundColor = [UIColor redColor];
  self.contentView.backgroundColor = [UIColor greenColor];
  self.contentView.alpha = 0.75;
   */
  
  if (duration <= 0) {
    [self reset:NO];
    self.background.frame = bgframe;
    self.contentView.frame = self.background.bounds;
    return;
  }
  
  [self reset:YES];
  [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.background.frame = bgframe;
    self.contentView.frame = self.background.bounds;
  } completion:^(BOOL finished) {
    
  }];
}

#pragma mark - Helpers

- (void)unloadContent
{
  [self.contentView removeFromSuperview];
  self.contentView = nil;
}

- (void)reset:(BOOL)animated
{
  //Prevent unwanted delegate call;
  id prevDelegate = self.delegate;
  self.delegate = nil;

  self.contentOffset = CGPointZero;
  self.zoomScale = 1.0f;
  
  //Kill 'em all
  //if (!animated) {
  self.transform = CGAffineTransformIdentity;
  self.layer.transform = CATransform3DIdentity;
  self.background.transform = CGAffineTransformIdentity;
  self.background.layer.transform = CATransform3DIdentity;

  //Zooming causes the background.frame to drift
  CGRect bgFrame = [self getBackgroundFrameForWrapperFrame:self.bounds];
  self.background.frame = bgFrame;
  self.contentView.frame = self.background.bounds;
  
  if (self.contentView != nil && [self.contentView respondsToSelector:@selector(reset)])
    [self.contentView performSelector:@selector(reset)];
  
  self.delegate = prevDelegate;
  return;
  //}
  
  return;
  
  //Doesn't seem to have any effect
  [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.transform = CGAffineTransformIdentity;
    self.background.transform = CGAffineTransformIdentity;
  } completion:^(BOOL finished) {
    self.delegate = prevDelegate;
  }];
  
  CABasicAnimation *theAnimation;
  theAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
  theAnimation.delegate = self;
  theAnimation.duration = 0.4;
  theAnimation.repeatCount = 0;
  theAnimation.removedOnCompletion = YES;
  theAnimation.fillMode = kCAFillModeBoth;
  theAnimation.autoreverses = NO;
  theAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
  [self.background.layer addAnimation:theAnimation forKey:@"animateLayer"];
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
  
}

- (void)scrollViewDidZoom:(UIScrollView *)theScrollView
{
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


@end
