//
//  AHAppDelegate.h
//  AHLayout
//
//  Created by John Wright on 1/16/13.
// CPright (c) 2013 Airheart. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import "AHLayout.h"
#import <AtoZ/AtoZ.h>

@interface AHAppDelegate : NSObject <NSApplicationDelegate, AHLayoutDataSource>

@property (assign) IBOutlet NSWindow *window;

@end
