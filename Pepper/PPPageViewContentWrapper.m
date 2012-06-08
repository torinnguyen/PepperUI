//
//  PPPageView.m
//  pepper
//
//  Created by Torin Nguyen on 26/4/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PPPepperContants.h"
#import "PPPageViewContentWrapper.h"

#define EDGE_ALPHA            0.1

@interface PPPageViewContentWrapper()
@property (nonatomic, retain) UIImageView *background;
@property (nonatomic, retain) UIImageView *backgroundEdge;
@property (nonatomic, retain) UITapGestureRecognizer *tapGestureRecognizer;
@end

@implementation PPPageViewContentWrapper

@synthesize isBook = _isBook;
@synthesize delegate;
@synthesize background;
@synthesize backgroundEdge;
@synthesize tapGestureRecognizer;
@synthesize contentView = _contentView;
@synthesize isLeft = _isLeft;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.isBook = NO;
    self.layer.doubleSided = YES;

    self.backgroundColor = [UIColor clearColor];
    self.autoresizesSubviews = YES;
    self.clipsToBounds = YES;
    
    // Create gesture recognizer
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOneFingerTap)];
    [self.tapGestureRecognizer setNumberOfTapsRequired:1];
    [self.tapGestureRecognizer setNumberOfTouchesRequired:1];
    [self addGestureRecognizer:self.tapGestureRecognizer];

    self.background = [[UIImageView alloc] init];
    self.background.image = [UIImage imageNamed:@"page_bg"];
    self.background.frame = self.bounds;
    self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.background.backgroundColor = [UIColor clearColor];
    [self addSubview:self.background];
        
    self.contentView = [[UIView alloc] initWithFrame:frame];
    self.contentView.frame = self.bounds;
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.contentView];
    
    self.backgroundEdge = [[UIImageView alloc] init];
    self.backgroundEdge.image = [UIImage imageNamed:@"page_edge"];
    self.backgroundEdge.frame = self.bounds;
    self.backgroundEdge.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundEdge.backgroundColor = [UIColor clearColor];
    self.backgroundEdge.alpha = EDGE_ALPHA;
    [self addSubview:self.backgroundEdge];
  }
  return self;
}

- (void)onOneFingerTap
{
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(PPPageViewWrapper:viewDidTap:)])
    [self.delegate PPPageViewWrapper:self viewDidTap:self.tag];
}


#pragma mark - Public functions

- (void)setIsLeft:(BOOL)isLeftView
{
  _isLeft = isLeftView;
  
  //No edge graphic for right page (this is what Paper does)
  if (!self.isLeft)
    self.backgroundEdge.image = nil;

  //Flip content horizontally for odd page
  if (self.isLeft)  self.backgroundEdge.layer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
  else              self.backgroundEdge.layer.transform = CATransform3DMakeRotation(0, 0, 1, 0);
  
  self.layer.shouldRasterize = YES;
  self.layer.rasterizationScale = [[UIScreen mainScreen] scale];
}

- (void)setIsBook:(BOOL)isBook {
  _isBook = isBook;
  self.backgroundEdge.hidden = _isBook;
  if (self.isBook || self.tag <= 0)     self.background.image = [UIImage imageNamed:@"book_bg"];
  else                                  self.background.image = [UIImage imageNamed:@"page_bg"];
}

- (void)setContentView:(UIView *)theContentView
{
  [_contentView removeFromSuperview];
  _contentView = theContentView;
  if (theContentView == nil)
    return;
  
  theContentView.frame = self.bounds;
  theContentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self insertSubview:theContentView belowSubview:self.backgroundEdge];
    
  //Flip content horizontally for odd page
  if (self.isLeft)    self.contentView.layer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
  else                self.contentView.layer.transform = CATransform3DMakeRotation(0, 0, 1, 0);
}

@end
