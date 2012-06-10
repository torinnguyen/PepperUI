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
@property (nonatomic, retain) UITapGestureRecognizer *tapGestureRecognizer;
@end

@implementation PPPageViewContentWrapper

@synthesize isBook = _isBook;
@synthesize delegate;
@synthesize background;
@synthesize tapGestureRecognizer;
@synthesize contentView = _contentView;
@synthesize isLeft = _isLeft;
@synthesize bgBookImage = _bgBookImage;

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

- (void)setBgBookImage:(BOOL)bgBookImage
{
  //Initialize once
  static UIImage *book_bg = nil;
  if (book_bg==nil)
    book_bg = [UIImage imageNamed:BOOK_BG_IMAGE];
  static UIImage *page_bg = nil;
  if (page_bg==nil)
    page_bg = [UIImage imageNamed:PAGE_BG_IMAGE];
  
  if (bgBookImage)    self.background.image = book_bg;
  else                self.background.image = page_bg;
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

@end
