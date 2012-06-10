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
        
    self.background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"page_bg"]];  //native size
    self.background.backgroundColor = [UIColor clearColor];
    self.background.contentMode = UIViewContentModeScaleToFill;
    
    CGRect bgframe = self.background.bounds;
    float scale = frame.size.width / bgframe.size.width;
    bgframe.origin.x = 0;
    bgframe.origin.y -= EDGE_PADDING*scale;
    bgframe.size.width = frame.size.width;
    bgframe.size.height = scale * bgframe.size.height;
    self.background.frame = bgframe;
    
    CGRect contentFrame;
    contentFrame.origin.x = 0;
    contentFrame.origin.y = 0;
    contentFrame.size.width = frame.size.width;
    contentFrame.size.height = bgframe.size.height - 2*EDGE_PADDING*scale;

    self.contentViewWrapper = [[UIView alloc] initWithFrame:contentFrame];
    self.contentViewWrapper.backgroundColor = [UIColor clearColor];
    self.contentViewWrapper.autoresizesSubviews = NO;
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

  self.zoomScale = 1.0f;
  self.contentOffset = CGPointZero;
  
  theContentView.frame = self.contentViewWrapper.bounds;
  theContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
  [self.contentViewWrapper addSubview:theContentView];
}

#pragma mark - Memory management

- (void)unloadContent
{
  [self.contentView removeFromSuperview];
  self.contentView = nil;
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
