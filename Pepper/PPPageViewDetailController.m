//
//  PPPageViewDetailController.m
//
//  Created by Torin Nguyen on 24/7/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import "PPPageViewDetailController.h"

@interface PPPageViewDetailController ()

@end

@implementation PPPageViewDetailController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor redColor];

  UIButton *button1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  button1.frame = CGRectMake(0, 0, 100, 32);
  button1.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
  [self.view addSubview:button1];
  
  UIButton *button2 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  button2.frame = CGRectMake(self.view.bounds.size.width-100, 0, 100, 32);
  button2.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
  [self.view addSubview:button2];
  
  UIButton *button3 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  button3.frame = CGRectMake(0, self.view.bounds.size.height-32, 100, 32);
  button3.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
  [self.view addSubview:button3];
  
  UIButton *button4 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  button4.frame = CGRectMake(self.view.bounds.size.width-100, self.view.bounds.size.height-32, 100, 32);
  button4.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
  [self.view addSubview:button4];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  for (UIButton *button in self.view.subviews)
    if ([button isKindOfClass:[UIButton class]])
      [button setTitle:[NSString stringWithFormat:@"%d", self.view.tag] forState:UIControlStateNormal];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return YES;
}

@end
