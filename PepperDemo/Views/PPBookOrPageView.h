//
//  PPPageViewContent.h
//  pepper
//
//  Created by Torin Nguyen on 26/4/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PPPageBaseView.h"
#import "Page.h"
#import "Book.h"

@interface PPBookOrPageView : PPPageBaseView

- (void)configureWithPageModel:(Page*)pageModel;
- (void)configureWithBookModel:(Book*)bookModel;
- (void)refresh;

@end
