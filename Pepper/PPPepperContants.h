//
//  PPPepperContants.h
//
//  Created by Torin Nguyen on 7/6/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#ifndef PepperDemo_PPPepperContants_h
#define PepperDemo_PPPepperContants_h

//Behavior
#define AUTO_OPEN_BOOK               YES              //book will open on tap. disable this to implement your subscribtion system if needed
#define HIDE_FIRST_PAGE              NO               //hide the first page
#define FIRST_PAGE_BOOK_COVER        YES              //background of the first page uses book cover image
#define ENABLE_HIGH_SPEED_SCROLLING  YES              //in 3D mode only
#define ENABLE_BOOK_SCALE            YES              //other book not in center will be smaller
#define ENABLE_BOOK_ROTATE           NO               //other book not in center will be slightly rotated (carousel effect)
#define SMALLER_FRAME_FOR_PORTRAIT   YES              //resize everything smaller when device is in portrait mode

//Graphics
#define EDGE_PADDING                 5                //Don't change this after graphic is fixed
#define BOOK_BG_IMAGE                @"book_bg"
#define PAGE_BG_IMAGE                @"page_bg"

//Look & feel
#define FRAME_WIDTH_LANDSCAPE        (768*0.4)        //please see documentation for correct aspect ratio
#define FRAME_HEIGHT_LANDSCAPE       (1034*0.4)       //please see documentation for correct aspect ratio
#define FRAME_SCALE_PORTRAIT         0.9f             //SMALLER_FRAME_FOR_PORTRAIT must be enabled for this to take effect

#define MIN_BOOK_SCALE               0.85f            //ENABLE_BOOK_SCALE must be enabled for this to take effect
#define MAX_BOOK_SCALE               1.0f             //anything < 1.0 is experimental
#define MAX_BOOK_ROTATE              20.0f            //degree. ENABLE_BOOK_ROTATE must be enabled for this to take effect

#define PAGE_SPACING                 35.0f            //gap between pages in 3D mode

#endif
