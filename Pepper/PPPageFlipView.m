//
//  PPPageFlipView.m
//
//  Created by Torin Nguyen on 20/8/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PPPageFlipView.h"

#define THRESHOLD_HALF_ANGLE         25
#define LEFT_RIGHT_ANGLE_DIFF        9.9                //should be perfect 10, but we cheated
#define TIMER_INTERVAL               0.016666667        //60fps
#define PI_DIV_BY_180                0.01745329251994   // M_PI / 180.0f  conversion from degree to radian

@interface PPPageFlipView() <UIGestureRecognizerDelegate>

@property (nonatomic, assign) float controlIndex;
@property (nonatomic, assign) float controlFlipAngle;
@property (nonatomic, assign) float touchDownControlIndex;

//Timers
@property (nonatomic, assign) float controlIndexTimerTarget;
@property (nonatomic, assign) float controlIndexTimerDx;
@property (nonatomic, strong) NSDate *controlIndexTimerLastTime;
@property (nonatomic, strong) CADisplayLink *displayLink;


@end

@implementation PPPageFlipView
@synthesize delegate;
@synthesize currentPageIndex;
@synthesize zoomingOneSide, m34;

@synthesize theView0 = _theView0;
@synthesize theView1 = _theView1;
@synthesize theView2 = _theView2;
@synthesize theView3 = _theView3;
@synthesize theView4 = _theView4;
@synthesize theView5 = _theView5;

@synthesize controlIndex = _controlIndex;
@synthesize controlFlipAngle = _controlFlipAngle;
@synthesize touchDownControlIndex;
@synthesize displayLink;
@synthesize controlIndexTimerTarget, controlIndexTimerDx, controlIndexTimerLastTime;


- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self == nil)
    return self;
  
  self.backgroundColor = [UIColor clearColor];
  self.controlIndex = 0;
  
  UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanning:)];
  panGestureRecognizer.delegate = self;
  [self addGestureRecognizer:panGestureRecognizer];
  
  self.displayLink = nil;
  
  return self;
}


#pragma mark - Helpers

- (float)getCurrentSpecialIndex
{
  float index = 1.5f + ceil((self.controlIndex-2.5) / 2) * 2;
  if (index < 1.5f)
    index = 1.5f;
  return index;
}

- (BOOL)isBusy
{
  return (self.displayLink != nil);
}


#pragma mark - Control

- (void)onPanning:(UIPanGestureRecognizer *)recognizer
{
  //hands-off during animation
  if ([self isBusy])
    return;
    
  //Remember initial value to calculate based on delta later
  if (recognizer.state == UIGestureRecognizerStateBegan)
    self.touchDownControlIndex = self.controlIndex;
  
  //The dynamics
  CGPoint translation = [recognizer translationInView:self];
  CGPoint velocity = [recognizer velocityInView:self];
  float normalizedVelocityX = fabsf(velocity.x / self.bounds.size.width / 2);
  
  float direction = (velocity.x >= 0) ? 1 : -1;
  float rawNormalizedVelocityX = normalizedVelocityX;
  
  if (rawNormalizedVelocityX < 1)           rawNormalizedVelocityX = rawNormalizedVelocityX * 0.8;       //expansion
  else if (rawNormalizedVelocityX > 1.1)    rawNormalizedVelocityX = 1 + (rawNormalizedVelocityX-1)/2;   //compression
  
  if (normalizedVelocityX < 1)              normalizedVelocityX = 1;
  else if (normalizedVelocityX > 2.0)       normalizedVelocityX = 2.0;
   
  //Snap to half open
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    
    float snapTo = 0;
    float newControlIndex = self.controlIndex - direction * rawNormalizedVelocityX;     //opposite direction
    
    if (self.zoomingOneSide) {
      if (newControlIndex > 0 && newControlIndex < 0.25)        snapTo = 0;
      else if (newControlIndex > 0)                             snapTo = 0.5;
      else if (newControlIndex < 0 && newControlIndex > -0.75)  snapTo = -0.5;
      else                                                      snapTo = -1.0;    //special
    }
    else {
      if (newControlIndex < 0)    snapTo = -1;
      else                        snapTo = 1;
    }
    
    float diff = fabs(snapTo - newControlIndex);
    if (diff <= 0)
      return;
    
    float duration = diff / 2;
    if (duration <= 0.2)
      duration = 0.2;
    
    //Correct behavior but sluggish
    [self animateControlIndexTo:snapTo duration:duration];
    return;
  }
  
  //Speed calculation
  float boost = self.zoomingOneSide ? 2.0f : 3.0f;
  float dx = boost * (translation.x / self.bounds.size.width/2);
  float newControlIndex = self.touchDownControlIndex - dx;

  //Special case for one-side zoom, flip to the right
  if (self.zoomingOneSide && newControlIndex < 0)
    newControlIndex -= 0.5;

  self.controlIndex = newControlIndex;
}

// This function controls everything about flipping
// @param: valid range 0.5 to [self maxControlIndex]
- (void)setControlIndex:(float)newIndex 
{
  if (newIndex < -1)   newIndex = -1;
  if (newIndex > 1)    newIndex = 1;
    
  _controlIndex = newIndex;
  
  float newControlFlipAngle = 0;
  if (self.controlIndex > 0)      newControlFlipAngle = self.controlIndex * -180.0;
  else                            newControlFlipAngle = self.controlIndex * -180.0;
  self.controlFlipAngle = newControlFlipAngle;
  
  float increment = 0;
  if (self.zoomingOneSide) {
    if (self.controlIndex < 0)    increment = 2*self.controlIndex + 1;  //-0.5 to -1
    else                          increment = 2*self.controlIndex;      //0 to 0.5
  }
  else {
    increment = 2*self.controlIndex;
  }
  
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPageFlipView:didFlippedWithIndex:)])
    [self.delegate ppPageFlipView:self didFlippedWithIndex:self.currentPageIndex + increment];
}


- (void)setControlFlipAngle:(float)angle
{  
  _controlFlipAngle = angle;
  float angle2 = angle - 180;

  //Transformation for center 2 pages 
  if (self.controlIndex >= 0) {
    CALayer *layer3 = self.theView3.layer;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, angle * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    layer3.anchorPoint = CGPointMake(0, 0.5);
    layer3.transform = transform;
    
    CALayer *layer4 = self.theView4.layer;
    transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, angle2 * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    layer4.anchorPoint = CGPointMake(1, 0.5);
    layer4.transform = transform;
    
    CGRect frame3;
    frame3.origin.y = 0;
    frame3.origin.x = self.zoomingOneSide ? 0 : self.bounds.size.width/2;
    frame3.size.height = self.bounds.size.height;
    frame3.size.width = self.zoomingOneSide ? self.bounds.size.width : self.bounds.size.width/2;
    self.theView3.frame = frame3;
    
    CGRect frame4;
    frame4.origin.y = 0;
    frame4.origin.x = 0;
    frame4.size.height = self.bounds.size.height;
    frame4.size.width = self.zoomingOneSide ? self.bounds.size.width : self.bounds.size.width/2;
    self.theView4.frame = frame4;
    
    [self bringSubviewToFront:self.theView3];
    [self bringSubviewToFront:self.theView4];
    self.theView0.hidden = YES;
    self.theView3.hidden = NO;
    self.theView4.hidden = NO;
    self.theView5.hidden = NO;
  }
  else {   
    CALayer *layer1 = self.theView1.layer;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, angle2 * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    layer1.anchorPoint = CGPointMake(0, 0.5);
    layer1.transform = transform;
    
    CALayer *layer2 = self.theView2.layer;
    transform = CATransform3DIdentity;
    transform.m34 = self.m34;
    transform = CATransform3DRotate(transform, angle * PI_DIV_BY_180, 0.0f, 1.0f, 0.0f);
    layer2.anchorPoint = CGPointMake(1, 0.5);
    layer2.transform = transform;
    
    CGRect frame1;
    frame1.origin.y = 0;
    frame1.origin.x = self.zoomingOneSide ? 0 : self.bounds.size.width/2;
    frame1.size.height = self.bounds.size.height;
    frame1.size.width = self.zoomingOneSide ? self.bounds.size.width : self.bounds.size.width/2;
    self.theView1.frame = frame1;
    
    CGRect frame2;
    frame2.origin.y = 0;
    frame2.origin.x = 0;
    frame2.size.height = self.bounds.size.height;
    frame2.size.width = self.zoomingOneSide ? self.bounds.size.width : self.bounds.size.width/2;
    self.theView2.frame = frame2;
    
    [self bringSubviewToFront:self.theView1];
    [self bringSubviewToFront:self.theView2];
    self.theView0.hidden = NO;
    self.theView1.hidden = NO;
    self.theView2.hidden = NO;
    self.theView5.hidden = YES;
  }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  //Hands-off during animation
  if ([self isBusy])
    return NO;
  
  //Just in case
  if (self.hidden)
    return NO;
  
  return YES;
}




#pragma mark - Custom setters

- (void)setTheView0:(UIView *)theView
{
  [self addView:theView isLeft:YES];
  theView.hidden = YES;
  _theView0 = theView;
}

//For zoom oneside: previous page
- (void)setTheView1:(UIView *)theView
{
  [self addView:theView isLeft:YES];
  theView.hidden = YES;
  _theView1 = theView;
}

//For zoom oneside: current page
- (void)setTheView2:(UIView *)theView
{
  [self addView:theView isLeft:YES];
  theView.hidden = NO;
  _theView2 = theView;
}

//For zoom oneside: next page
- (void)setTheView3:(UIView *)theView
{
  [self addView:theView isLeft:NO];
  theView.hidden = NO;
  _theView3 = theView;
}

- (void)setTheView4:(UIView *)theView
{
  [self addView:theView isLeft:NO];
  theView.hidden = YES;
  _theView4 = theView;
}

- (void)setTheView5:(UIView *)theView
{
  [self addView:theView isLeft:NO];
  theView.hidden = YES;
  _theView5 = theView;
}

- (void)addView:(UIView *)theView isLeft:(BOOL)isLeft
{
  CGRect frame = theView.frame;
  
  if (self.zoomingOneSide) {
    frame.size.width = self.bounds.size.width;
    frame.origin.x = isLeft ? -self.bounds.size.width : 0;
  }
  else  {
    frame.size.width = self.bounds.size.width/2;
    frame.origin.x = isLeft ? 0 : self.bounds.size.width/2;
  }
  
  frame.origin.y = 0;
  frame.size.height = self.bounds.size.height;
  theView.frame = frame;
  theView.layer.doubleSided = NO;
  
  [theView removeFromSuperview];
  [self addSubview:theView];
  
  [self bringSubviewToFront:self.theView2];
  [self bringSubviewToFront:self.theView3];
  
  //reset
  _controlIndex = 0;
}


#pragma mark - Timers

- (void)animateControlIndexTo:(float)index duration:(float)duration
{
  if (self.displayLink != nil)
    return;
   
  if (index < -1)     index = -1;
  if (index > 1)      index = 1;
  self.controlIndexTimerTarget = index;
  
  if (duration <= 0) {
    [self onControlIndexTimerFinish];
    return;
  }
  
  //0.016667 = 1/60
  self.controlIndexTimerLastTime = [[NSDate alloc] init];
  self.controlIndexTimerDx = (self.controlIndexTimerTarget - self.controlIndex) / (duration / TIMER_INTERVAL);
  
  self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onControlIndexTimer)];
  [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)onControlIndexTimer
{
  float deltaMs = fabsf([self.controlIndexTimerLastTime timeIntervalSinceNow]);
  float deltaDiff = deltaMs / TIMER_INTERVAL;
  float newValue = self.controlIndex + self.controlIndexTimerDx * deltaDiff;
  
  self.controlIndexTimerLastTime = [[NSDate alloc] init];
  
  if (self.controlIndexTimerDx >= 0 && newValue > self.controlIndexTimerTarget)
    newValue = self.controlIndexTimerTarget;
  else if (self.controlIndexTimerDx < 0 && newValue < self.controlIndexTimerTarget)
    newValue = self.controlIndexTimerTarget;
  
  BOOL finish = newValue == self.controlIndex || fabs(newValue - self.controlIndexTimerTarget) <= fabs(self.controlIndexTimerDx*1.5);
  
  if (!finish) {
    self.controlIndex = newValue;
    return;
  }
  
  [self onControlIndexTimerFinish];
}

- (void)onControlIndexTimerFinish
{
  [self.displayLink invalidate];
  self.displayLink = nil;
  
  float newValue = self.controlIndexTimerTarget;
  if (newValue > 1)
    newValue = 1;
  self.controlIndex = newValue;
  
  if (self.zoomingOneSide)
  {
    if (self.controlIndex > 0) {
      self.theView1.hidden = YES;
      self.theView3.hidden = YES;
      self.theView5.hidden = NO;
    }
    else {
      self.theView1.hidden = NO;
      self.theView3.hidden = YES;
      self.theView5.hidden = YES;
    }
  }
  else
  {
    if (self.controlIndex > 0) {
      self.theView0.hidden = YES;
      self.theView1.hidden = YES;
      self.theView2.hidden = YES;
      self.theView3.hidden = YES;
      self.theView4.hidden = NO;
      self.theView5.hidden = NO;
    }
    else {
      self.theView0.hidden = NO;
      self.theView1.hidden = NO;
      self.theView2.hidden = YES;
      self.theView3.hidden = YES;
      self.theView4.hidden = YES;
      self.theView5.hidden = YES;
    }
  }
  
  float increment = 0;
  if (self.zoomingOneSide) {
    if (self.controlIndex < 0)    increment = 2*self.controlIndex + 1;  //-0.5 to -1
    else                          increment = 2*self.controlIndex;      //0 to 0.5
  }
  else {
    increment = 2*self.controlIndex;
  }
    
  //Notify the delegate
  if ([self.delegate respondsToSelector:@selector(ppPageFlipView:didFinishFlippingWithIndex:)])
    [self.delegate ppPageFlipView:self didFinishFlippingWithIndex:self.currentPageIndex + increment];
}

@end
