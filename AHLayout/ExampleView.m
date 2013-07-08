//  ExampleColorView.m
//  AHLayout
//  Created by John Wright on 11/27/11.
// CPright (c) 2011 AirHeart. All rights reserved.

#import "ExampleView.h"
#import <AtoZ/AtoZ.h>

@interface ExampleView ()
@property NSI objectIndex;
@property TUITextRenderer *textRenderer;
@property NSAS *attributedString;
@property CGSZ originalSize;
@end

@implementation ExampleView

- (id)initWithFrame:(CGR)frame {
	if (!(self = [super initWithFrame:frame])) return nil;
//	self.opaque = self.clipsToBounds = YES;
	self.textRenderers 	= @[_textRenderer = TUITextRenderer.new];
	self.backgroundColor = RANDOMGRAY;
//	[self bind:@"name" toObject: withKeyPath: nilValue:@""];
	// transform:<#^id(id value)transformBlock#>objects[tag][@"color"][@"name"];
//	[_textRenderer bind:@"attributedString" toObject:_objects[self.tag] withKeyPath:@"color.name" transform:^id(id value) {
//		return  [NSAttributedString.alloc initWithString:value ?: NSS.randomDicksonism];
//		}];
		//self.objects[@"color"]];// $(@"%ld", self.tag)];
	return self;
}
- (AHLayout*) parentLayout 		 {	return (AHLayout*)self.superview;	}
- (void) setTag:(NSI) tag 	 	 {
	[super setTag:tag];
	NSS* name = self.objects[tag][@"color"][@"name"];
	_textRenderer.attributedString = [NSAttributedString.alloc initWithString: name ?: NSS.randomDicksonism];//self.objects[@"color"]];// $(@"%ld", self.tag)];
}
- (NSMenu*) menuForEvent:(NSE*)event
{
	__block NSMenu *menu = NSMenu.new;
	[@{         @"Insert Above" : @"insertObject", 	@"Insert Below":@"insertObjectBelow", 
		         @"Insert at top": @"prepend", 			     @"Remove" : @"remove:", 
		@"Toggle Expand To Fill" : @"toggleExpanded" } each:^(id k, id v)  {
		NSMI *i = 	  [NSMenuItem.alloc  initWithTitle:NSLocalizedString(k, nil) 
						       action:NSSelectorFromString(v) keyEquivalent:@""];  
							 i.target = self; 							 [menu addItem:i];
	}]; return menu;
}
- (void) toggleExpanded 					
{
	__block CGSize tSize; __block CGF w, h;
	self.parentLayout.typeOfLayout == AHLayoutHorizontal ? ^{
				     w = _expanded  ? _originalSize.width : self.parentLayout.width;
			    tSize = 	   (CGS)  { w, self.height };
	}() : ^{		  h = _expanded  ? _originalSize.height : self.parentLayout.height;
		       tSize = 		(CGS)  { self.width, h  };
	}();
	[self.parentLayout beginUpdates];
	[self.parentLayout resizeViewAtIndex:self.tag toSize:tSize aniBlock:nil  completion:^{ 	_expanded = !_expanded;	 }];
	[self.parentLayout endUpdates];
}
- (void) insertObject				{	[_objects addObject:NSMD.new];
											[self.parentLayout insertViewAtIndex:self.tag];
}
- (void) insertObjectBelow 		{	[_objects addObject:NSMD.new];
											[self.parentLayout insertViewAtIndex:self.tag-1];
}
- (void) prepend 					{	[_objects addObject:NSMD.new];
											[self.parentLayout prependNumOfViews:1 aniBlock:nil completion:nil];
}
- (IBAction)remove:(id)sender 	{	[_objects removeObjectAtIndex:self.tag];
											[self.parentLayout removeViewsAtIndexes:[NSIndexSet indexSetWithIndex:self.tag ]
											                         aniBlock:nil           completion:nil ];
}

- (void)drawRect:(CGR)rect
{
	CGR b 		  = self.bounds;
	CGCREF ctx = TUIGraphicsGetCurrentContext();
	_originalSize = CGSizeEqualToSize(CGSizeZero, _originalSize) ? b.size : _originalSize;
	LOGWARN(@"DRAWRECT: %@", AZString(b));
	if(self.selected) {
		NSLog(@"iam selected!");
		// selected background
//		CGContextSetRGBFillColor(ctx, .87, .87, .87, 1);
//		CGContextFillRect(ctx, b);
		NSBP *path = [NSBP bezierPathWithRect:b];
		[path strokeWithColor:BLACK andWidth:10];
		[path fillWithColor:CHECKERS];
		[self.layer addAnimation:[CAA shakeAnimation]];
	} else {
		// light gray background
//		CGContextSetRGBFillColor(ctx, .7, .7, .7, 1);
//		CGContextFillRect(ctx, b);
		NSRectFillWithColor(b, self.objects[self.tag][@"color"][@"color"] ?: GRAY4);
		
		// emboss
		CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.9); // light at the top
		CGContextFillRect(ctx, CGRectMake(0, b.size.height-1, b.size.width, 1));
		CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.08); // dark at the bottom
		CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
	}
	
	// text
	CGRect textRect = CGRectOffset(b, 15, -15);
	_textRenderer.frame = textRect; // set the frame so it knows where to draw itself
	[_textRenderer draw];
	
}


- (void)mouseDown:(NSEvent *)event
{
	[super mouseDown:event]; // always call super when overriding mouseXXX: methods - lots of plumbing happens in TUIView
	self.selected = YES;
	[self setNeedsDisplay];
}

- (void)mouseUp:(NSEvent *)event
{
	[super mouseUp:event];

	// rather than a simple -setNeedsDisplay, let's fade it back out
	[TUIView animateWithDuration:0.5 animations:^{

	self.selected = NO;
	[self redraw]; // -redraw forces a .contents update immediately based on drawRect, and it happens inside an animation block, so CoreAnimation gives us a cross-fade for free
	}];
	
	if([self eventInside:event]) { // only perform the action if the mouse up happened inside our bounds - ignores mouse down, drag-out, mouse up
		NSLog(@"did seleted %@", self);
//		[[self tabBar].delegate tabBar:[self tabBar] didSelectTab:self.tag];
	}
}
@end
