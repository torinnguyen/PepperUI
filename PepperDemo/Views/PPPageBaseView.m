//
//  PPPageViewContent.m
//  pepper
//
//  Created by Torin Nguyen on 26/4/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import "PPPepperContants.h"
#import "PPPageBaseView.h"

@interface PPPageBaseView()
@end

@implementation PPPageBaseView

@synthesize imageView;
@synthesize loadingIndicator;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    self.backgroundColor = [UIColor clearColor];
    
    CGRect imageFrame = CGRectMake(0, EDGE_PADDING, frame.size.width, frame.size.height-2*EDGE_PADDING);
    self.imageView = [[UIImageView alloc] initWithFrame:imageFrame];
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.imageView.backgroundColor = [UIColor clearColor];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.clipsToBounds = YES;
    [self addSubview:self.imageView];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.frame = self.imageView.bounds;
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.loadingIndicator.contentMode = UIViewContentModeCenter;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.loadingIndicator stopAnimating];
    [self.imageView addSubview:self.loadingIndicator];
  }
  return self;
}

//
// Get image asynchronously from somewhere
//

- (void)fetchImageWithUrl:(NSString *)stringUrl
{
  if (stringUrl == nil)
    return;

  //Local image
  if (![stringUrl hasPrefix:@"http"]) {
    self.imageView.image = [UIImage imageNamed:stringUrl];
    [self.loadingIndicator stopAnimating];
    return;
  }
  
  //Asynchronous loading using GCD
  [self.loadingIndicator startAnimating];
  dispatch_queue_t backgroundQueue = dispatch_queue_create("com.companyname.downloadqueue", NULL);
  dispatch_async(backgroundQueue, ^(void) {
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:stringUrl]]];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
      self.imageView.image = image;
      [self.loadingIndicator stopAnimating];
    });
  });
}

@end
