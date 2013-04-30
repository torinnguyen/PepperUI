//
//  PPViewController.m
//  PepperSimple
//
//  Created by Torin on 30/4/13.
//  Copyright (c) 2013 Torin Nguyen. All rights reserved.
//

#import "PPViewController.h"
#import "PPPepperViewController.h"

@interface PPViewController ()
@property (nonatomic, strong) PPPepperViewController * pepperViewController;
@end

@implementation PPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //Basic setup
    self.pepperViewController = [[PPPepperViewController alloc] init];
    self.pepperViewController.view.frame = self.view.bounds;
    self.pepperViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.pepperViewController.view];
    
    //ViewController containment for iOS 5.0 and above
    BOOL iOS5AndAbove = ([[[UIDevice currentDevice] systemVersion] compare:@"5.0" options:NSNumericSearch] != NSOrderedAscending);
    if (iOS5AndAbove) {
        [self addChildViewController:self.pepperViewController];
        [self.pepperViewController didMoveToParentViewController:self];
    }
    
    [self.pepperViewController reload];
    
    //Optional customization
    /*
     self.pepperViewController.enableBookShadow = YES;
     self.pepperViewController.enableBorderlessGraphic = YES;
     self.pepperViewController.enableOneSideZoom = YES;
     self.pepperViewController.enableOneSideMiddleZoom = YES;
     self.pepperViewController.enableDualDetailedPage = NO;  //very very experimental, totally NOT supported by me
     self.pepperViewController.enablePageCurlEffect = YES;   //iOS5 and above only, fallback to pageFlipEffect
     self.pepperViewController.enablePageFlipEffect = YES;
     self.pepperViewController.hideFirstPage = YES;
     */
}


#pragma mark - Device orientation

//iOS 5.0 Rotations
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

//iOS 6.0 Rotations
- (BOOL)shouldAutorotate
{
    return YES;
}
- (NSUInteger) supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

@end
