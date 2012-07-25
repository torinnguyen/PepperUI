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

@synthesize button;

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor greenColor];

  self.button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  self.button.center = CGPointMake(200, 200);
  [self.view addSubview:self.button];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
  self.button = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return YES;
}

@end
