//
//  AHAppDelegate.m
//  AHLayout
//
//  Created by John Wright on 1/16/13.
// CPright (c) 2013 Airheart. All rights reserved.
//

#import "AHAppDelegate.h"
//#import "AHLayout.h"
#import "ExampleView.h"
#import <AtoZ/AtoZ.h>


@interface AHAppDelegate ()
@property AHLayout *horizontalLayout, *verticalLayout;
@property TUIButton *button, *removeButton;
@property BOOL collapsed;
@property NSMA *vertObjects,  *horizObjects;
@end
@implementation AHAppDelegate
@synthesize button, removeButton, collapsed;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	self.window.contentView = [TUINSView.alloc initWithFrame:_window.contentRect];
	TUIV*v = [TUIView.alloc initWithFrame:_window.contentRect];

	[v addSubview:_horizontalLayout		= [AHLayout.alloc initWithFrame:AZUpperEdge(_window.bounds, 100)]];
	_horizontalLayout.typeOfLayout 		= AHLayoutHorizontal;
	_horizontalLayout.bgC				 	= LINEN;
	_horizontalLayout.arMASK 		 		= TUIViewAutoresizingFlexibleBottomMargin | TUIViewAutoresizingFlexibleWidth;
	_horizontalLayout.dataSource 	      = self;
	_horizontalLayout.clipsToBounds     = YES;
	_horizontalLayout.spaceBetweenViews = 0;
	_horizontalLayout.viewClass 			= ExampleView.class;
//	_horizontalLayout];
	

	[v addSubview:_verticalLayout 		= [AHLayout.alloc initWithFrame:AZRectTrimmedOnTop(_window.bounds, 100)]];
	_verticalLayout.backgroundColor 		= RED;
	_verticalLayout.autoresizingMask 	= TUIViewAutoresizingFlexibleSize;
	_verticalLayout.dataSource 			= self;
	_verticalLayout.clipsToBounds 		= YES;
	_verticalLayout.viewClass 				= ExampleView.class;
	
	((TUINSView*)_window.contentView).rootView = v;
	
	_horizObjects 	= [[NSC.randomPalette withMinItems:199] map:^id(id obj) {
		 return @{@"color": @{ @"name" : [obj nameOfColor], @"color": obj} }; 
	}].mutableCopy;
	_vertObjects	= [NSMD newInstances:50]; 

	[_verticalLayout reloadData];
	[_horizontalLayout reloadData];
}
//	TUILabel *label;
//	[((TUINSView*)_window.contentView).rootView addSubview: label = [TUILabel.alloc initWithFrame:
//									CGRectMake(_window.width / 2, 0, 250, 50)]];
//	label.text = @"Right click on any cell for options";
//	label.font = AtoZ.controlFont;
//	label.backgroundColor = [NSColor clearColor];
//	 addSubview:label];

#pragma mark - AHLayoutDataSource methods

- (TUIV*) layout:(AHLayout*)l viewForIndex:(NSI)index	
{
	ExampleView *v = (ExampleView*) _verticalLayout.dequeueReusableView;
	v.objects = l == _verticalLayout ? _vertObjects : _horizObjects;
	return v;
}

- (NSUI)numberOfViewsInLayout:(AHLayout*)l { 	return l == _verticalLayout ? _vertObjects.count
																	              			    : _horizObjects.count;
}

- (CGS) layout:(AHLayout*)l sizeOfViewAtIndex:(NSUI)index {

	return l == _verticalLayout ? CGSizeMake(_window.width, 100) : CGSizeMake(100, 100);
}

@end
