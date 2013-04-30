//
//  PPAppDelegate.m
//  PepperSimple
//
//  Created by Torin on 30/4/13.
//  Copyright (c) 2013 Torin Nguyen. All rights reserved.
//

#import "PPAppDelegate.h"

#import "PPViewController.h"

@implementation PPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[PPViewController alloc] initWithNibName:@"PPViewController_iPhone" bundle:nil];
    } else {
        self.viewController = [[PPViewController alloc] initWithNibName:@"PPViewController_iPad" bundle:nil];
    }
    
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
