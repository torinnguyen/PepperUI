//
//  PPPageViewDetail.m
//
//  Created by Torin Nguyen on 2/6/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PPPepperContants.h"
#import "PPPageViewDetailWrapper.h"

#define MINIMUM_ZOOM_SCALE  0.1f
#define MAXIMUM_ZOOM_SCALE  2.0f

@interface PPPageViewDetailWrapper() <UIScrollViewDelegate>
@property (nonatomic, retain) UIImageView *background;
@property (nonatomic, retain) UIView *contentViewWrapper;
@end

@implementation PPPageViewDetailWrapper

@synthesize customDelegate;
@synthesize contentView = _myContentView;
@synthesize background;
@synthesize contentViewWrapper;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.contentView = nil;
    self.delegate = self;
    self.minimumZoomScale = MINIMUM_ZOOM_SCALE;
    self.maximumZoomScale = MAXIMUM_ZOOM_SCALE;
    
    static UIImage *bg = nil;
    if (bg == nil)
      bg = [UIImage imageNamed:USE_BORDERLESS_GRAPHIC ? PAGE_BG_BORDERLESS_IMAGE : PAGE_BG_IMAGE];
    
    self.background = [[UIImageView alloc] initWithImage:bg];     //we use size & aspect ratio from native image size
    self.background.backgroundColor = [UIColor clearColor];
    self.background.contentMode = UIViewContentModeScaleToFill;
    self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.alpha = 0.5;
    
    CGRect bgframe = self.background.bounds;
    float scale = frame.size.width / bgframe.size.width;
    bgframe.origin.x = 0;
    bgframe.origin.y -= EDGE_PADDING*scale;
    bgframe.size.width = frame.size.width;
    bgframe.size.height = scale * bgframe.size.height;
    self.background.frame = bgframe;
    
    CGRect contentWrapperFrame;
    contentWrapperFrame.origin.x = 0;
    contentWrapperFrame.origin.y = 0;
    contentWrapperFrame.size.width = frame.size.width;
    contentWrapperFrame.size.height = bgframe.size.height - 2*EDGE_PADDING*scale;

    self.contentViewWrapper = [[UIView alloc] initWithFrame:contentWrapperFrame];
    self.contentViewWrapper.backgroundColor = [UIColor clearColor];
    self.contentViewWrapper.autoresizesSubviews = YES;
    [self.contentViewWrapper addSubview:self.background];
    [self addSubview:self.contentViewWrapper];
    
    self.contentSize = self.contentViewWrapper.bounds.size;
    self.contentViewWrapper.layer.shouldRasterize = YES;
    self.contentViewWrapper.layer.rasterizationScale = [UIScreen mainScreen].scale;
  }
  return self;
}

- (void)setContentView:(UIView *)theContentView
{
 [_myContentView removeFromSuperview];
  _myContentView = theContentView;
  if (theContentView == nil) {
    self.contentSize = CGSizeZero;
    return;
  }
  
  //Flip background horizontally for odd page
  if (self.tag%2 == 0)  self.background.layer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
  else                  self.background.layer.transform = CATransform3DMakeRotation(0, 0, 1, 0);

  [self reset];  
  theContentView.frame = self.contentViewWrapper.bounds;
  theContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
  [self.contentViewWrapper addSubview:theContentView];
}

- (void)layoutForWidth:(int)newWidth duration:(float)duration
{
  float aspectRatio = self.contentViewWrapper.bounds.size.height / self.contentViewWrapper.bounds.size.width;
  float newHeight = newWidth * aspectRatio;
  
  CGRect contentWrapperFrame;
  contentWrapperFrame.origin.x = 0;
  contentWrapperFrame.origin.y = 0;
  contentWrapperFrame.size.width = newWidth;
  contentWrapperFrame.size.height = newHeight;
  
  if (duration <= 0) {
    self.contentViewWrapper.frame = contentWrapperFrame;
    [self reset];
    return;
  }
  
  [self reset];
  [UIView animateWithDuration:duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    self.contentViewWrapper.frame = contentWrapperFrame;
  } completion:^(BOOL finished) {
    
  }];
}

#pragma mark - Memory management

- (void)unloadContent
{
  [self.contentView removeFromSuperview];
  self.contentView = nil;
}

- (void)reset
{
  //Prevent unwanted delegate call;
  id prevDelegate = self.delegate;
  self.delegate = nil;

  self.contentOffset = CGPointZero;
  self.zoomScale = 1.0f;
  
  //Kill 'em all
  self.transform = CGAffineTransformIdentity;
  self.layer.transform = CATransform3DIdentity;
  self.contentViewWrapper.transform = CGAffineTransformIdentity;
  self.contentViewWrapper.layer.transform = CATransform3DIdentity;
  self.contentView.transform = CGAffineTransformIdentity;
  self.contentView.layer.transform = CATransform3DIdentity;
  
  self.delegate = prevDelegate;
}



#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
  return self.contentViewWrapper;
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
