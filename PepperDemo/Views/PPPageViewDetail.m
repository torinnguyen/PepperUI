//
//  PPPageViewDetail.m
//  PepperDemo
//
//  Created by Torin Nguyen on 2/6/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import "PPPageViewDetail.h"

@implementation PPPageViewDetail

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {

  }
  return self;
}

//
// Populate various UI elements with a Page model  data
//
- (void)configureWithPageModel:(Page*)pageModel
{
  self.imageView.image = nil;
  [self fetchImageWithUrl:pageModel.fullsizeURL];
}

@end
