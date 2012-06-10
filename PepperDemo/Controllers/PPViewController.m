//
//  PPViewController.m
//
//  Created by Torin Nguyen on 2/6/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#include <stdlib.h>   //simply for random number function

#import "PPViewController.h"
#import "PPPepperViewController.h"
#import "MyBookOrPageView.h"
#import "MyPageViewDetail.h"

@interface PPViewController () <PPScrollListViewControllerDataSource, PPScrollListViewControllerDelegate>
@property (nonatomic, strong) IBOutlet UIView * menuView;
@property (nonatomic, strong) IBOutlet UISegmentedControl * speedSegmented;
@property (nonatomic, strong) IBOutlet UISwitch * switchRandomPage;
@property (nonatomic, strong) IBOutlet UISwitch * switchScaleOnDeviceRotation;
@property (nonatomic, strong) PPPepperViewController * pepperViewController;
@property (nonatomic, strong) NSMutableArray *bookDataArray;
@end

@implementation PPViewController
@synthesize menuView;
@synthesize speedSegmented;
@synthesize switchRandomPage;
@synthesize switchScaleOnDeviceRotation;
@synthesize pepperViewController;
@synthesize bookDataArray;

- (void)viewDidLoad
{
  [super viewDidLoad];

  //Insert Pepper UI below our top level menu
  self.pepperViewController = [[PPPepperViewController alloc] init];
  self.pepperViewController.view.frame = self.view.bounds;
  self.pepperViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:self.pepperViewController.view];
  self.pepperViewController.delegate = self;
  //self.pepperViewController.dataSource = self;
  
  //Optional
  [self onSpeedChange:self.speedSegmented];
  [self onSwitchRandomPage:self.switchRandomPage];
  [self onSwitchScaleOnDeviceRotation:self.switchScaleOnDeviceRotation];
  
  //Bring our top level menu to highest z-index
  [self.view bringSubviewToFront:self.menuView];
  
  //Initialize data
  [self initializeBookData];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.pepperViewController viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self.pepperViewController viewDidAppear:animated];
  [self.pepperViewController reload];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
}

- (void)didReceiveMemoryWarning {
  [self.pepperViewController didReceiveMemoryWarning];
  [super didReceiveMemoryWarning];
}


#pragma mark - View rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                duration:(NSTimeInterval)duration {  
  [self.pepperViewController willRotateToInterfaceOrientation:toInterfaceOrientation
                                                     duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                         duration:(NSTimeInterval)duration {
  [self.pepperViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation
                                                              duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
  [self.pepperViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}



#pragma mark - Actions

- (IBAction)onSpeedChange:(id)sender
{
  int idx = self.speedSegmented.selectedSegmentIndex;
  float factor = 1.0;
  switch (idx) {
    case 2:      factor = 12.0f;      break;
    case 1:      factor = 2.0f;       break;
    default:     break;
  }
  self.pepperViewController.animationSlowmoFactor = factor;
}

- (IBAction)onSwitchRandomPage:(id)sender
{
  if ([self.pepperViewController.delegate isEqual:self])
    return;
  [[[UIAlertView alloc] initWithTitle:@"Warning"
                              message:@"You must set self.pepperViewController.delegate = self; to use this feature"
                             delegate:nil
                    cancelButtonTitle:@"Dismiss"
                    otherButtonTitles:nil] show];
}

- (IBAction)onSwitchScaleOnDeviceRotation:(id)sender
{
  self.pepperViewController.scaleOnDeviceRotation = self.switchScaleOnDeviceRotation.on;
}



#pragma mark - Data

- (void)initializeBookData
{
  //You can populate book data from else where, for demo purpose, it is hardcoded with random data
  
  int randomBookID = arc4random() % 123;
  int randomPageID = arc4random() % 123;
  
  self.bookDataArray = [[NSMutableArray alloc] init];
  for (int i=0; i<DEMO_NUM_BOOKS; i++) {
    Book *myBook = [[Book alloc] init];
    myBook.bookID = randomBookID;
    myBook.pages = [[NSMutableArray alloc] init];
    //myBook.coverURL = @"book_cover";
    randomBookID += arc4random() % 123;
    
    int randomNumPages = DEMO_NUM_PAGES;
    for (int i=0; i<randomNumPages; i++) {
      Page *myPage = [[Page alloc] init];
      myPage.pageID = randomPageID;
      //myPage.halfsizeURL = @"http://www.linenplace.com/boutiques/product-ideas/bamboo.jpg";
      myPage.fullsizeURL = @"http://www.linenplace.com/boutiques/product-ideas/bamboo.jpg";
      randomPageID += arc4random() % 123;
      
      [myBook.pages addObject:myPage];
    }
    
    [self.bookDataArray addObject:myBook];
  }
}


#pragma mark - PPScrollListViewControllerDelegate

/*
 * This is called when a book is tapped on
 * The book will not open automatically by the library, you need to call [scrollList openCurrentBook];
 */
- (void)ppPepperViewController:(PPPepperViewController*)scrollList didTapOnBookIndex:(int)bookIndex
{
  //You can implement your own logic here to prompt user to login before viewinh this content if needed
  //You can implement your own logic here to get remembered last opened page for this book
  
  //Open random page for demo purpose
  Book *theBook = [self.bookDataArray objectAtIndex:bookIndex];
  int pageCount = theBook.pages.count - 1;
  int randomPage = rand() % pageCount;
  int pageIndex = self.switchRandomPage.on ? randomPage : 0;
  if (self.switchRandomPage.on)
    NSLog(@"Open current book at random page: %d", randomPage);
  [scrollList openCurrentBookAtPageIndex:pageIndex];
}

/*
 * This is called just before the book opens
 */
- (void)ppPepperViewController:(PPPepperViewController*)scrollList willOpenBookIndex:(int)tag andDuration:(float)duration
{
  //Hide our menu together with the books
  self.menuView.userInteractionEnabled = NO;
  [UIView animateWithDuration:duration animations:^{
    self.menuView.alpha = 0;
  }];
}

/*
 * When the book is being closed, the library will calculate the necessary alpha value to reveal the initial menu bar
 */
- (void)ppPepperViewController:(PPPepperViewController*)scrollList closingBookWithAlpha:(float)alpha
{
  //Show our menu together with the books
  self.menuView.alpha = alpha;
  self.menuView.userInteractionEnabled = (alpha != 0);
}


#pragma mark - PPScrollListViewControllerDataSource

- (int)ppPepperViewController:(PPPepperViewController*)scrollList numberOfBooks:(int)dummy;
{
  return self.bookDataArray.count;
}

- (int)ppPepperViewController:(PPPepperViewController*)scrollList numberOfPagesForBookIndex:(int)bookIndex
{
  if (bookIndex < 0 || bookIndex >= self.bookDataArray.count)
    return 0;
  Book *theBook = [self.bookDataArray objectAtIndex:bookIndex];
  return theBook.pages.count;
}

- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList viewForBookIndex:(int)bookIndex withFrame:(CGRect)frame
{
  Book *theBook = [self.bookDataArray objectAtIndex:bookIndex];
  MyBookOrPageView *view = [[MyBookOrPageView alloc] initWithFrame:frame];
  [view configureWithBookModel:theBook];
  return view;
}

- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList thumbnailViewForPageIndex:(int)pageIndex inBookIndex:(int)bookIndex withFrame:(CGRect)frame
{
  Book *theBook = [self.bookDataArray objectAtIndex:bookIndex];
  Page *thePage = [theBook.pages objectAtIndex:pageIndex];
  MyBookOrPageView *view = [[MyBookOrPageView alloc] initWithFrame:frame];
  [view configureWithPageModel:thePage];
  return view;
}

- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList detailViewForPageIndex:(int)pageIndex inBookIndex:(int)bookIndex withFrame:(CGRect)frame
{
  Book *theBook = [self.bookDataArray objectAtIndex:bookIndex];
  Page *thePage = [theBook.pages objectAtIndex:pageIndex];
  MyPageViewDetail *view = [[MyPageViewDetail alloc] initWithFrame:frame];
  [view configureWithPageModel:thePage];
  return view;
}

@end
