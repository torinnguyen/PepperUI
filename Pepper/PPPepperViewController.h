//
//  PPScrollListViewControllerViewController.h
//  pepper
//
//  Created by Torin Nguyen on 25/4/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PPPepperViewController;

@protocol PPScrollListViewControllerDataSource <NSObject>

- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList viewForBookIndex:(int)bookIndex withFrame:(CGRect)frame;
- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList thumbnailViewForPageIndex:(int)pageIndex inBookIndex:(int)bookIndex withFrame:(CGRect)frame;
- (UIView*)ppPepperViewController:(PPPepperViewController*)scrollList detailViewForPageIndex:(int)pageIndex inBookIndex:(int)bookIndex withFrame:(CGRect)frame;

/*
 * Delegate to return the number of books
 */
- (int)ppPepperViewController:(PPPepperViewController*)scrollList numberOfBooks:(int)dummy;

/*
 * Delegate to return the number of pages in the given book index
 */
- (int)ppPepperViewController:(PPPepperViewController*)scrollList numberOfPagesForBookIndex:(int)bookIndex;

@end

@protocol PPScrollListViewControllerDelegate <NSObject>
@optional

/*
 * This is called when a book is tapped on
 * The book will not open automatically by the library, you need to call [scrollList openCurrentBook];
 */
- (void)ppPepperViewController:(PPPepperViewController*)scrollList didTapOnBookIndex:(int)tag;

/*
 * This is called just before the book opens
 */
- (void)ppPepperViewController:(PPPepperViewController*)scrollList willOpenBookIndex:(int)tag andDuration:(float)duration;

/*
 * When the book is being closed, the library will calculate the necessary alpha value to reveal the initial menu bar
 */
- (void)ppPepperViewController:(PPPepperViewController*)scrollList closingBookWithAlpha:(float)alpha;
@end





@interface PPPepperViewController : UIViewController

@property (nonatomic, unsafe_unretained) id <PPScrollListViewControllerDataSource> dataSource;
@property (nonatomic, unsafe_unretained) id <PPScrollListViewControllerDelegate> delegate;
@property (nonatomic, assign) BOOL scaleDownBookNotInFocus;
@property (nonatomic, assign) BOOL rotateBookNotInFocus;
@property (nonatomic, assign) BOOL hideFirstPage;
@property (nonatomic, assign) BOOL oneSideZoom;
@property (nonatomic, assign) float animationSlowmoFactor;
@property (nonatomic, assign) float pageSpacing;
@property (nonatomic, assign) BOOL scaleOnDeviceRotation;

@property (nonatomic, assign) float controlIndex;
@property (nonatomic, assign, readonly) BOOL isBookView;
@property (nonatomic, assign, readonly) BOOL isDetailView;

- (void)reload;
- (void)openCurrentBookAtPageIndex:(int)pageIndex;

@end
