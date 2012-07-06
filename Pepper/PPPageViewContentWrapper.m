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
@property (nonatomic, retain) UIImageView *shadow;
@property (nonatomic, retain) UIImageView *background;
@property (nonatomic, retain) UITapGestureRecognizer *tapGestureRecognizer;
@end

@implementation PPPageViewContentWrapper

@synthesize isBook = _isBook;
@synthesize delegate;
@synthesize background;
@synthesize tapGestureRecognizer;
@synthesize contentView = _contentView;
@synthesize isLeft = _isLeft;
@synthesize shadowOffset = _shadowOffset;
@synthesize shadowRadius = _shadowRadius;
@synthesize shadowOpacity = _shadowOpacity;
@synthesize shadow;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.isBook = NO;
    self.layer.doubleSided = YES;

    self.backgroundColor = [UIColor clearColor];
    self.autoresizesSubviews = YES;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    
    // Create gesture recognizer
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOneFingerTap)];
    [self.tapGestureRecognizer setNumberOfTapsRequired:1];
    [self.tapGestureRecognizer setNumberOfTouchesRequired:1];
    [self addGestureRecognizer:self.tapGestureRecognizer];

    // Background image
    self.background = [[UIImageView alloc] init];
    self.background.image = nil;
    self.background.frame = self.bounds;
    self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.background.backgroundColor = [UIColor clearColor];
    [self addSubview:self.background];
        
    self.contentView = [[UIView alloc] initWithFrame:frame];
    self.contentView.frame = self.bounds;
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.contentView];
  }
  return self;
}

- (void)setBackgroundImage:(UIImage*)image
{
  self.background.image = image;
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
  
  self.layer.shouldRasterize = YES;
  self.layer.rasterizationScale = [[UIScreen mainScreen] scale];
}

- (void)setIsBook:(BOOL)isBook
{ 
  _isBook = isBook;
}

- (void)setContentView:(UIView *)theContentView
{
  [_contentView removeFromSuperview];
  _contentView = theContentView;
  if (theContentView == nil)
    return;
  
  theContentView.frame = self.bounds;
  theContentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self insertSubview:theContentView aboveSubview:self.background];
    
  //Flip content horizontally for odd page
  if (self.isLeft)    self.contentView.layer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
  else                self.contentView.layer.transform = CATransform3DMakeRotation(0, 0, 1, 0);
}


#pragma mark - Shadow

- (void)setShadowOffset:(CGSize)newValue
{
  _shadowOffset = newValue;
  [self setupShadow];
  [self updateShadow];
}

- (void)setShadowOpacity:(float)newValue
{
  _shadowOpacity = newValue;
  if (newValue == 0) {
    [self.shadow removeFromSuperview];
    self.shadow = nil;
    return;
  }
  
  self.shadow.alpha = newValue;
}

- (void)setShadowRadius:(float)newValue
{
  _shadowRadius = newValue;
  [self setupShadow];
  [self updateShadow];
}

- (void)setupShadow
{
  if (self.shadow != nil)
    return;
  
  self.shadow = [[UIImageView alloc] init];
  self.shadow.image = [UIImage imageNamed:@"page_bg_shadow"];
  self.shadow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.shadow.backgroundColor = [UIColor clearColor];
  [self insertSubview:self.shadow belowSubview:self.background];
  [self updateShadow];
}

- (void)updateShadow
{
  CGRect frame = self.bounds;
  frame.size.width += 2 * self.shadowRadius;
  frame.size.height += 2 * self.shadowRadius;
  frame.origin.x -= self.shadowRadius;
  frame.origin.y -= self.shadowRadius;
  
  frame.origin.x += self.shadowOffset.width;
  frame.origin.y += self.shadowOffset.height;
  self.shadow.frame = frame;
}

@end
