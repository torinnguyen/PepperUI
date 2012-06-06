//
//  PPPageViewDetail.m
//  PepperDemo
//
//  Created by Torin Nguyen on 2/6/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import "PPPageViewDetailWrapper.h"

#define ZOOM_AMOUNT 0.25f
#define MINIMUM_ZOOM_SCALE 0.1f
#define MAXIMUM_ZOOM_SCALE 2.0f

@interface PPPageViewDetailWrapper() <UIScrollViewDelegate>

@end

@implementation PPPageViewDetailWrapper

@synthesize customDelegate;
@synthesize contentView = _myContentView;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.contentView = nil;
    self.delegate = self;
    self.minimumZoomScale = MINIMUM_ZOOM_SCALE;
    self.maximumZoomScale = MAXIMUM_ZOOM_SCALE;
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
  
  //theContentView.frame = self.bounds;
  theContentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

  [self addSubview:theContentView];
  self.contentSize = theContentView.bounds.size;
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
  return self.contentView;
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
