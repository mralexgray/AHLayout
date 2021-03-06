
//
//  AHLayout.m
//  Swift
//
//  Created by John Wright on 11/13/11.
// CPright (c) 2011 AirHeart. All rights reserved.
//

// ARC is compatible with iOS 4.0 upwards, but you need at least Xcode 4.2 with Clang LLVM 3.0 to compile it.

#if !__has_feature(objc_arc)
#error This project must be compiled with ARC (Xcode 4.2+ with LLVM 3.0 and above)
#endif
#import "AHLayout.h"

@implementation NSString(TUICompare)
- (NSComparisonResult)compareNumberStrings:(NSString *)str {
	NSNumber * me = [NSNumber numberWithInt:[self intValue]];
	NSNumber * you = [NSNumber numberWithInt:[str intValue]];
	
	return [you compare:me];
}
@end
#define kAHLayoutDefaultAnimationDuration 0.5
@interface AHLayoutObject : NSObject
@property (NATOM,STRNG) CAA 	*animation;
@property (NATOM,STRNG) NSS 	*indexString;
@property (NATOM,RONLY) CGR 	calculatedFrame;
@property (NATOM)	 		CGSZ 	size;
@property (NATOM) 			CGR	oldFrame;
@property (NATOM) 			CGF 	x, y;
@property (NATOM) 			NSI 	index;
@property (NATOM) 			BOOL 	markedForInsertion, markedForRemoval,  markedForUpdate;
@end

@implementation AHLayoutObject
@synthesize oldFrame, size, x, y, animation, markedForInsertion, markedForRemoval, markedForUpdate, index, indexString;
- (CGR) calculatedFrame {
	return CGRectMake(self.x, self.y, self.size.width, self.size.height);
}
@end

@class AHLayoutTransaction;
@interface AHLayout()
@property (NATOM,RONLY) AHLayoutTransaction *updatingTransaction;
@property (NATOM,STRNG) AHLayoutTransaction *executingTransaction;
@property (NATOM,STRNG) NSMD *objectViewsMap;
@property (NATOM,STRNG) NSMA *objects;
- (void) executeNextLayoutTransaction;
- (void) enqueueReusableView:(TUIV*)view;
- (TUIV*)createView;
@end

typedef NS_ENUM(NSUI, AHLayoutTransactionPhase) {	AHLayoutTransactionPhaseNormal,		AHLayoutTransactionPhasePrelayout,
																	AHLayoutTransactionPhaseAnimating,	AHLayoutTransactionPhaseDoneAnimating,	};
@interface AHLayoutTransaction : NSObject
@property (NATOM,STRNG) NSMA *changeList;
@property (NATOM,WK) 		AHLayout *layout;
@property (NATOM,CP) 		AHLayoutHandler animationBlock;
@property (NATOM,CP) 		AHLayoutViewAnimationBlock viewAnimationBlock;
@property (NATOM) 			AHLayoutTransactionPhase phase;
@property (NATOM) CGR	 	nextVisibleRect;
@property (NATOM) NSI 	scrollToObjectIndex;
@property (NATOM) CGSZ 	objectSize,	 				contentSize;
@property (NATOM) CGF 	animationDuration;
@property (NATOM) CGP		contentOffset;
@property (NATOM) BOOL 	maintainContentOffset, 	shouldNotCallDelegate, shouldAnimate, calculated;;
- (void) applyLayout;
- (void) addCompletionBlock:(AHLayoutHandler) block;
- (CGP)  calculateNextContentOffset;
- (void) calculateContentSize;
- (CGP)  modifyContentOffset:(CGP)c forRect:(CGR)rect inVisibleRect:(CGR) visible horizontal:(BOOL)horizontal;
- (void) calculateNextVisibleRect;
- (void) calculateObjectOffsets;
- (void) calculateObjectOffsetsVertical;
- (void) calculateObjectOffsetsHorizontal;

- (NSMA *)objectIndexesInRect:(CGR)rect;
- (NSS*) indexKeyForObject:(AHLayoutObject*) object;

- (void) moveViews;
- (void) addNewlyVisibleSubviews;
- (TUIV*) addSubviewForObject:(AHLayoutObject*) object atIndex:(NSS*) objectIndex;
- (void) rebaseForInsertionsAndRemovals;
- (void) processChangeList;
- (void) cleanup;
- (void) moveObjectsAfterPoint:(CGP) point byIndexAmount:(NSI) indexAmount;
@end

@implementation AHLayoutTransaction {
	NSMA *completionBlocks;
	BOOL calculatedContentSize;
	NSMA *objectIndexesToBringIntoView;
	BOOL shouldChangeContentOffset;
	BOOL preLayoutPass;
	CGRect lastBounds;
	NSMA *viewsToRemove;
}

@synthesize layout, animationBlock, shouldAnimate, contentSize, nextVisibleRect, phase, scrollToObjectIndex, changeList, objectSize, calculated, animationDuration, contentOffset;

#pragma mark - Getters and Setters
- (id) init {
	if (self != super.init ) return nil;
	scrollToObjectIndex = -1;
	return self;
}
- (void) addCompletionBlock:(AHLayoutHandler)block {
	if (block == nil) 			return;
	if (!completionBlocks) 	completionBlocks = NSMA.new;
	[completionBlocks addObject:[block copy]];
}
- (NSMA*) changeList { 	return changeList = changeList  ?: NSMA.new;	}

#pragma mark - Layout
- (void) applyLayout 					{
	
	
	CGRect bounds = layout.bounds;
	CGFloat resizingYOffset, resizingXOffset; resizingYOffset = resizingXOffset = 0.0;

	if ([self.layout.nsView inLiveResize]) {
		resizingYOffset = (lastBounds.size).height - bounds.size.height;
		resizingXOffset = (lastBounds.size).width - bounds.size.width;
	}
	
	// save off some current offset info
	CGFloat previousYOffset = self.layout.contentSize.height + self.layout.contentOffset.y;
	CGFloat previousXOffset =  self.layout.contentSize.width + self.layout.contentOffset.x;
	CGFloat relativeOffset = 0.0f;
	NSI savedIndex = -1;
	if (layout.objects.count > 0 && [self.layout.nsView inLiveResize]) {
		savedIndex = [layout objectIndexAtTopOfScreen];
		if (savedIndex >=0) {
			CGRect v = [self.layout visibleRect];
			CGRect r = [self.layout rectForViewAtIndex:savedIndex];
			if (layout.typeOfLayout == AHLayoutHorizontal) {
				relativeOffset = ((v.origin.x + v.size.width) - (r.origin.x + r.size.width));
				relativeOffset += (lastBounds.size.width - bounds.size.width);
				relativeOffset += resizingXOffset;
			} else {
				relativeOffset = ((v.origin.y + v.size.height) - (r.origin.y + r.size.height));
				relativeOffset += (lastBounds.size.height - bounds.size.height);
				relativeOffset += resizingYOffset;
			}
		}
	}
	
	
	if (!calculated || !CGSizeEqualToSize(bounds.size, lastBounds.size)) {
		if (!self.shouldNotCallDelegate) self.contentSize = CGSizeZero; //reset the contentSize
		[self calculateContentSize];
		[self processChangeList];
		[self calculateObjectOffsets];
		calculated = YES;
	}
	lastBounds = bounds;
	
	if (self.shouldAnimate && phase != AHLayoutTransactionPhaseDoneAnimating) {
		if (phase == AHLayoutTransactionPhaseNormal) {
			phase = AHLayoutTransactionPhasePrelayout;
			self.shouldAnimate = NO;
			// Perform a prelayout transaction where we bring in needed subviews
			// into their old location so that the animations looks ok
			[CATransaction begin];
			__weak NSMA *weakCompletionBlocks = completionBlocks;
			__weak AHLayoutTransaction *weakSelf = self;
			[CATransaction setCompletionBlock:^{
				// In this CATransaction we animate the layout
				weakSelf.phase = AHLayoutTransactionPhaseAnimating;
				[CATransaction begin];
				[CATransaction setCompletionBlock:^{
					if (changeList.count > 0) {
						for (AHLayoutObject *object in changeList)
							object.markedForInsertion = object.markedForRemoval = object.markedForUpdate = NO;
						[changeList removeAllObjects];
					}
					weakSelf.phase = AHLayoutTransactionPhaseNormal;
					shouldAnimate = NO;
					if (viewsToRemove.count > 0) {
						for (TUIV*v in viewsToRemove) {
							[v removeFromSuperview];
							[self.layout enqueueReusableView:v];
						}
					}
					if (!CGRectEqualToRect(layout.visibleRect, nextVisibleRect)) {
						NSLog(@"Visible rect calculation is wrong\nTransaction: %@\nLayout: %@", NSStringFromRect(nextVisibleRect), NSStringFromRect(layout.visibleRect));
					}
					for (AHLayoutHandler block in weakCompletionBlocks) block(weakSelf.layout);
				}];
				
				CGFloat duration = weakSelf.animationDuration > 0 ? weakSelf.animationDuration :  kAHLayoutDefaultAnimationDuration;
				
				layout.contentSize = contentSize;
				
				[TUIView animateWithDuration:duration animations:^{
					// Time for the key animation...
					// animate changing the content offset, moving the views,
					// and a user supplied animation block together
					weakSelf.layout.contentOffset = contentOffset;
					[self moveViews];
					if (weakSelf.animationBlock) weakSelf.animationBlock(weakSelf.layout);
				}];
				[CATransaction commit];
			}];
			
			// Process insertions and removals
			[weakSelf rebaseForInsertionsAndRemovals];
			AHLayoutObject *scrollToObject = nil;
			if (scrollToObjectIndex >= 0 && layout.objects.count > scrollToObjectIndex)
				scrollToObject = [layout.objects objectAtIndex:scrollToObjectIndex];
			
			contentOffset = layout.contentOffset;
			[self calculateNextVisibleRect];
			// Now refine the contentOffset a bit more to make sure we scroll to the right object
			if (scrollToObject) {
				// scroll the view to bottom or left
				CGRect r = scrollToObject.calculatedFrame;
				contentOffset = self.layout.typeOfLayout == AHLayoutHorizontal ? CGPointMake(-r.origin.x, 0) 
																										      : CGPointMake(0, -r.origin.y);
			}
			contentOffset = [self fixContentOffset:contentOffset forSize:contentSize inBounds:layout.bounds];
			[self calculateNextVisibleRect];
			
			objectIndexesToBringIntoView = [self objectIndexesInRect:nextVisibleRect];
			
			// Bring in any needed views needed for the animation
			// Existing subviews will come in using their old frames
			[self addNewlyVisibleSubviews];
			// This ensures that the newly added subviews are added before the animation
			// This will kick off multiple layout passes all occuring with old frames before the animation
			[CATransaction commit];
		}
	} else {
		[TUIView setAnimationsEnabled:NO block:^{
			// maintain position after new layout
			if (savedIndex >=0 && relativeOffset >= 0) {
				CGRect v = [self.layout visibleRect];
				CGRect r = [self.layout rectForViewAtIndex:savedIndex];
				if (layout.typeOfLayout == AHLayoutHorizontal) {
					r.origin.x -= (v.size.width - r.size.width);
					r.size.width += (v.size.width - r.size.width);
					r.origin.x += relativeOffset;
				}  else {
					r.origin.y -= (v.size.height - r.size.height);
					r.size.height += (v.size.height - r.size.height);
					r.origin.y += relativeOffset;
				}
				[self.layout scrollRectToVisible:r animated:NO];
			}
			else if (self.maintainContentOffset) {
				if (layout.typeOfLayout == AHLayoutHorizontal) {
					CGFloat newOffset = previousXOffset - self.contentSize.width - resizingXOffset;
					self.contentOffset = CGPointMake(newOffset, self.layout.contentOffset.y);
				} else {
					CGFloat newOffset = previousYOffset - self.contentSize.height - resizingYOffset;
					self.contentOffset = CGPointMake(self.layout.contentOffset.x, newOffset);
				}
			}
			
			layout.contentSize = contentSize;
			if (!layout.didFirstLayout && (layout.objects.count > 0)) {
				[layout scrollToTopAnimated:NO];
				layout.didFirstLayout = YES;
			}
			[self calculateNextVisibleRect];
			
			objectIndexesToBringIntoView = [self objectIndexesInRect:nextVisibleRect];
			[self addNewlyVisibleSubviews];
			[self moveViews];
			[self cleanup];
		}];
	}
	
}
- (void) addNewlyVisibleSubviews {
	
	// Process objects that need to be brought into view view
	NSMA *objectIndexesToAdd = objectIndexesToBringIntoView.mutableCopy;
	[objectIndexesToAdd removeObjectsInArray:layout.objectViewsMap.allKeys];
	
	// Remove any objects marked for insertion or deletion.  These will be handled separately
	if (shouldAnimate && [changeList count] > 0) {
		for (AHLayoutObject * object in changeList) {
			if (object.markedForInsertion || object.markedForRemoval) 
				[objectIndexesToAdd removeObject:$(@"%ld", object.index)];
		}
	}
	
	for (NSString *objectIndex in objectIndexesToAdd) {
		AHLayoutObject *object = [layout.objects objectAtIndex:[objectIndex intValue]];
		[self addSubviewForObject:object atIndex:objectIndex];
	}
}
- (TUIV*) addSubviewForObject:(AHLayoutObject*) object atIndex:(NSS*) objectIndex {
	
	if([layout.objectViewsMap objectForKey:objectIndex]  && !object.markedForInsertion) { 
		NSLog(@"!!! Warning: already have a view in place for index %ld", object.index);
	} else {
		NSI index 	= [objectIndex integerValue];
		TUIV* v 		= [layout.dataSource layout:layout viewForIndex:index];
		v.tag 			= index;
		AHLayoutTransactionPhase thePhase = self.phase;
		[TUIView setAnimationsEnabled:NO block:^{
			v.frame = thePhase == AHLayoutTransactionPhasePrelayout 
					  ?	 !CGRectIsNull(object.oldFrame)  && !CGRectEqualToRect(CGRectZero, object.oldFrame) 
						  ? object.oldFrame	//Bring subviews in under their oldFrame in the last transaction
						  : object.calculatedFrame
					  : object.calculatedFrame;
		}];
		
		// Only add subviews if they are on screen
		if (!v.superview) {
			if (object.markedForInsertion) {
				if (self.viewAnimationBlock) {
					self.viewAnimationBlock(self.layout, v);
				}
			}
			[layout addSubview:v];
		}
		[layout.objectViewsMap setObject:v forKey:objectIndex];
		[v layoutSubviews];
		[v setNeedsDisplay];
		return v;
	}
	return nil;
}
- (void) rebaseForInsertionsAndRemovals {
	if ([changeList count] > 0) {
		for (AHLayoutObject *object in changeList) {
			TUIV*v = [layout viewForIndex:object.index];
			if (object.markedForInsertion || object.markedForRemoval) {
				NSI moveAmount =  object.markedForInsertion ? 1 : -1;
				[self moveObjectsAfterPoint:object.calculatedFrame.origin byIndexAmount:moveAmount];
			}
			if (object.markedForInsertion) {
				[self addSubviewForObject:object atIndex:object.indexString];
			}
			if (object.markedForRemoval) {
				if (v) {
					if (self.viewAnimationBlock) {
						self.viewAnimationBlock(self.layout, v);
					} else {
						v.alpha = 0.1;
					}
					if (!viewsToRemove) {
						viewsToRemove = NSMA.new;
					}
					[viewsToRemove addObject:v];
				}
			}
		}
	}
}
- (void) processChangeList		 	{
	if ([changeList count] > 0) {
		for (AHLayoutObject *object in changeList) {
			if (object.markedForUpdate) {
				[layout.objects replaceObjectAtIndex:object.index withObject:object];
			} else if (object.markedForRemoval) {
				[layout.objects removeObjectAtIndex:object.index];
				for (NSI i = object.index; i < layout.objects.count; i++) {
					[[layout.objects objectAtIndex:i] setIndex:i];
				}
			} else if (object.markedForInsertion) {
				[layout.objects insertObject:object atIndex:object.index];
				for (NSI i = object.index+1; i < layout.objects.count; i++) {
					[[layout.objects objectAtIndex:i] setIndex:i];
				}
			}
		}
	}
}
// Update the frames of the visible subviews
- (void) moveViews {
	__weak AHLayoutTransaction *weakSelf = self;
	[layout.objectViewsMap enumerateKeysAndObjectsUsingBlock:^(NSString* key, TUIV*v, BOOL *stop) {
		NSI index = [key integerValue];
		if (index >= weakSelf.layout.objects.count) {
			return;
		}
		AHLayoutObject *object = [weakSelf.layout.objects objectAtIndex:index];

		if (object.animation) {
			[v.layer addAnimation:object.animation forKey:kAHLayoutAnimation];
			object.animation = nil;
		}

		if (self.phase == AHLayoutTransactionPhasePrelayout) {
			if (!CGRectIsNull(object.oldFrame)  && !CGRectEqualToRect(CGRectZero, object.oldFrame) && !CGRectEqualToRect(v.frame, object.oldFrame)) {
				v.frame = object.oldFrame;
			}
		} else if (!CGRectEqualToRect(v.frame, object.calculatedFrame))
		{
			v.frame = object.calculatedFrame;
		}

		if (self.phase == AHLayoutTransactionPhasePrelayout) {
			if (object.markedForInsertion) {
				// send new views to back so other views can animate over it
				[weakSelf.layout sendSubviewToBack:v];
			}
		} else if (object.markedForInsertion) {
			[weakSelf.layout bringSubviewToFront:v];
			object.markedForInsertion = NO;
		}

		[v layoutSubviews];
	}];
	
}
// Remove views marked for removal or no longer on screen
- (void) cleanup {
	__weak AHLayout *weakLayout = self.layout;
	dispatch_async(dispatch_get_main_queue(), ^{
		NSMA *indexesToRemove = [[NSMA alloc] init];
		[weakLayout.objectViewsMap enumerateKeysAndObjectsUsingBlock:^(NSString* key, TUIV*v, BOOL *stop) {
			// check if this view is still on screen
			if (!CGRectIntersectsRect(nextVisibleRect, v.frame)) {
				[indexesToRemove addObject:key];
			}
		}];
		
		for (NSString* index in indexesToRemove) {
			TUIV*v = [weakLayout.objectViewsMap objectForKey:index];
			[weakLayout enqueueReusableView:v];
			[v removeFromSuperview];
			[weakLayout.objectViewsMap removeObjectForKey:index];
		}
	});
}
// Shift the index of objects to views on the screen by a positive or negative amount
- (void) moveObjectsAfterPoint:(CGP) point byIndexAmount:(NSI) indexAmount  {
	if ([layout.objectViewsMap count]) {
		NSMD *newObjectViewsMap = [[NSMD alloc] init];
		[layout.objectViewsMap enumerateKeysAndObjectsUsingBlock:^(NSString* key, TUIV*v, BOOL *stop) {
			BOOL afterPoint = NO;
			BOOL onPoint = NO;
			if (self.layout.typeOfLayout == AHLayoutHorizontal) {
				afterPoint = v.frame.origin.x > point.x;
				onPoint = v.frame.origin.x == point.x;
			} else {
				afterPoint = v.frame.origin.y < point.y;
				onPoint = v.frame.origin.y == point.y;
			}
			if (afterPoint ) {
				NSI index = [key integerValue] + indexAmount;
				NSString *newIndexKey = [NSString stringWithFormat:@"%ld", index];
				[newObjectViewsMap setValue:v forKey:newIndexKey];
				[v setTag:index];
				[v setNeedsDisplay];
			} else if (!onPoint || indexAmount == 1) {
				[newObjectViewsMap setValue:v forKey:key];
			}
		}];
		// Replace map
		[layout.objectViewsMap setDictionary:newObjectViewsMap];
	}
}

#pragma mark - Calculations
- (CGP) calculateNextContentOffset 			{
	[self calculateContentSize];
	[self calculateObjectOffsets];
	CGPoint p = [self contentOffset:layout.contentOffset afterChangeInContentSizeFrom:layout.contentSize toSize:contentSize];
	return [self fixContentOffset:p forSize:contentSize inBounds:layout.bounds];
}
- (void) calculateNextVisibleRect		 	{
	if (!(phase == AHLayoutTransactionPhasePrelayout)) {
		// Update to the visibleRect of the scrollView
		nextVisibleRect = layout.visibleRect;
	} else {
		// Calculate the new visble rect
		nextVisibleRect = layout.bounds;
		CGPoint offset = contentOffset;
		offset.x = -offset.x;
		offset.y = -offset.y;
		nextVisibleRect.origin = offset;
	}
	nextVisibleRect = CGRectIntegral(nextVisibleRect);
}
- (void) calculateContentSize 				{
	__block CGFloat calculatedHeight = 0;
	__block CGFloat calculatedWidth = 0;
	__block AHLayoutType layoutType = layout.typeOfLayout;
	__weak AHLayout *weakLayout = self.layout;
	NSI idx = 0;
	if (CGSizeEqualToSize(CGSizeZero, self.contentSize)) {
		for (AHLayoutObject *object in layout.objects) {
			object.size = [layout.dataSource layout:layout sizeOfViewAtIndex:object.index];
			if (layoutType == AHLayoutVertical) {
				calculatedHeight += object.size.height + weakLayout.spaceBetweenViews;
			} else {
				calculatedWidth += object.size.width + weakLayout.spaceBetweenViews;
			}
			idx +=1;
		}
	} else {
		calculatedHeight = contentSize.height;
		calculatedWidth = contentSize.width;
	}
	// final contentSize is modified by the amount of insertions, removals, and resizs
	for (AHLayoutObject *object in changeList) {
		if (object.markedForUpdate) {
			AHLayoutObject *oldObject = [layout.objects objectAtIndex:object.index];
			calculatedHeight += (object.size.height - oldObject.size.height);
			calculatedWidth += (object.size.width - oldObject.size.width);
		}
		if (object.markedForInsertion) {
			calculatedHeight += object.size.height;
			calculatedWidth += object.size.width;
		}
		if (object.markedForRemoval) {
			calculatedHeight -= object.size.height;
			calculatedWidth -= object.size.width;
		}
	}
	if (layoutType == AHLayoutHorizontal) {
		calculatedHeight = weakLayout.bounds.size.height;
	} else {
		calculatedWidth = weakLayout.bounds.size.width;
	}
	self.contentSize = CGSizeMake(calculatedWidth, calculatedHeight);
}
- (void) calculateObjectOffsets			 	{
	(layout.typeOfLayout == AHLayoutVertical) ? [self calculateObjectOffsetsVertical] : [self calculateObjectOffsetsHorizontal];
}
- (void) calculateObjectOffsetsVertical 	{
	CGFloat offset = self.contentSize.height;
	for (AHLayoutObject *object in layout.objects) {
		offset -= object.size.height + layout.spaceBetweenViews;
		object.y = offset + layout.spaceBetweenViews;
	}
}
- (void) calculateObjectOffsetsHorizontal {
	CGFloat i = 0;
	CGFloat offset = 0;
	for (AHLayoutObject *object in layout.objects) {
		if (i==0) {
			offset += layout.spaceBetweenViews;
		}
		object.x = offset;
		i += 1;
		offset += object.size.width + layout.spaceBetweenViews;
	}
}

#pragma mark - Geometry

- (CGP) contentOffset:(CGP) theContentOffset afterChangeInContentSizeFrom:(CGSZ) oldContentSize toSize:(CGSZ) newContentSize {
	CGPoint c = theContentOffset;
	if (self.layout.typeOfLayout == AHLayoutHorizontal  && oldContentSize.width > 0) {
		c.x = oldContentSize.width + c.x - newContentSize.width;
		c.x = roundf(c.x);
	}
	if (self.layout.typeOfLayout == AHLayoutVertical && oldContentSize.height > 0) {
		c.y += oldContentSize.height + c.y - newContentSize.height;
		c.y = roundf(c.y);
	}
	return c;
}
- (CGP) modifyContentOffset:(CGP)c forRect:(CGR)rect inVisibleRect:(CGR) visible horizontal:(BOOL)horizontal	{
	// What about horizontal scrolling peeps
	if (horizontal) {
		if (rect.origin.x + rect.size.width > visible.origin.x + visible.size.width) {
			//Scroll right, have rect be flush with right of visible view
			c = CGPointMake(-rect.origin.x + visible.size.width - rect.size.width, 0);
		} else if (rect.origin.x  < visible.origin.x) {
			// Scroll left, rect flush with left of leftmost visible view
			c = CGPointMake(-rect.origin.x, 0);
		}
	} else if (rect.origin.y < visible.origin.y) {
		// scroll down, have rect be flush with bottom of visible view
		c= CGPointMake(0, -rect.origin.y);
	} else if (rect.origin.y + rect.size.height > visible.origin.y + visible.size.height) {
		// scroll up, rect to be flush with top of view
		c = CGPointMake(0, -rect.origin.y + visible.size.height - rect.size.height);
	}
	return c;
}
- (NSMA *)objectIndexesInRect:(CGR)rect					{
	NSMA *foundObjects = [NSMA arrayWithCapacity:5];
	for(AHLayoutObject *object in layout.objects) {
		if(CGRectIntersectsRect(object.calculatedFrame, rect)) {
			[foundObjects addObject:[NSString stringWithFormat:@"%ld", [layout.objects indexOfObject:object]]];
		}
	}
	return foundObjects;
}
- (NSS*) indexKeyForObject:(AHLayoutObject*) object 	{
	return [NSString stringWithFormat:@"%ld", [layout.objects indexOfObject:object]];
}
- (CGP) fixContentOffset:(CGP)offset forSize:(CGSZ) size inBounds:(CGR) b		{
	CGSize s = size;
	
	CGFloat mx = offset.x + s.width;
	if (s.width > b.size.width) {
		if (mx < b.size.width) {
			offset.x = b.size.width - s.width;
		}
		if (offset.x > 0.0) {
			offset.x = 0.0;
		}
	} else {
		if (mx > b.size.width) {
			offset.x = b.size.width - s.width;
		}
		if (offset.x < 0.0) {
			offset.x = 0.0;
		}
	}
	
	CGFloat my = offset.y + s.height;
	if (s.height > b.size.height) { // content bigger than bounds
		if (my < b.size.height) {
			offset.y = b.size.height - s.height;
		}
		if (offset.y > 0.0) {
			offset.y = 0.0;
		}
	} else { // content smaller than bounds
		if (0) { // let it move around in bounds
			if (my > b.size.height) {
				offset.y = b.size.height - s.height;
			}
			if (offset.y < 0.0) {
				offset.y = 0.0;
			}
		}
		if (1) { // pin to top
			offset.y = b.size.height - s.height;
		}
	}
	
	return offset;
}

@end


@implementation AHLayout 
{
	AHLayoutTransaction *defaultTransaction;
	NSMA *updateStack, *executionQueue, *reusableViews;
	BOOL animating;
}

@synthesize viewClass, executingTransaction, objectViewsMap, objects, dataSource, spaceBetweenViews, reloadedDate, typeOfLayout, reloadHandler, didFirstLayout;

- (id)initWithFrame:(CGR)frame {
	if((self = [super initWithFrame:frame])) {
		spaceBetweenViews = 0;
		self.objects = NSMA.new;
		objectViewsMap = NSMD.new;
		updateStack = NSMA.new;
		executionQueue = NSMA.new;
		
		defaultTransaction = [[AHLayoutTransaction alloc] init];
		defaultTransaction.layout = self;
		
		self.typeOfLayout = AHLayoutVertical;
		self.viewClass = [TUIView class];
		
	}
	return self;
}

#pragma mark - Execute Transactions

- (void) layoutSubviews{
	[super layoutSubviews];
	// don't interfere with active animating transactions
	if ( !self.executingTransaction || (self.executingTransaction && (self.executingTransaction.phase != AHLayoutTransactionPhaseAnimating))) {
		[self executeNextLayoutTransaction];
	}
}
- (void) executeNextLayoutTransaction {
	
	// check for any updates
	AHLayoutTransaction *nextTransaction = [executionQueue lastObject];
	// continue to execute the last transaction if no updates pending
	if (!nextTransaction) nextTransaction = self.executingTransaction;
	// On first layout, we use the default transaction
	if (!nextTransaction) nextTransaction = defaultTransaction;
	self.executingTransaction = nextTransaction;
	
	if ([executionQueue count] >= 1 && nextTransaction.phase == AHLayoutTransactionPhaseNormal) {
		__weak AHLayout* weakSelf = self;
		__weak NSMA *weakExecutionQueue = executionQueue;
		[nextTransaction addCompletionBlock: ^(AHLayout* l){
			if (weakSelf.executingTransaction.phase == AHLayoutTransactionPhaseNormal) {
				[weakExecutionQueue removeLastObject];
			}
			[weakSelf performSelector:@selector(setNeedsLayout) withObject:nil afterDelay:0];
		}];
	}
	[nextTransaction applyLayout];
}
- (void) setNeedsLayout {
	[super setNeedsLayout];
}
- (void) beginUpdates {
	AHLayoutTransaction *transaction = [[AHLayoutTransaction alloc] init];
	transaction.shouldAnimate = YES;
	transaction.layout = self;
	[updateStack addObject:transaction];
}
- (AHLayoutTransaction*) updatingTransaction {
	AHLayoutTransaction *t = [updateStack lastObject];
	if (!t) t = self.executingTransaction;
	if (!t) t = defaultTransaction;
	return t;
}
- (void) endUpdates {
	// Send this transaction be executed
	if ([updateStack count] > 0) {
		[executionQueue addObject:[updateStack lastObject]];
		[updateStack removeLastObject];
		[self setNeedsLayout];
	}
}

# pragma mark - Public
- (void) reloadData						{
	if (!dataSource || ![dataSource respondsToSelector:@selector(numberOfViewsInLayout:)]) {
		NSAssert(false, @"Must supply data source");
	}
	
	if (CGRectEqualToRect(CGRectZero, self.bounds)) {
		// NSAssert(false, @"Calling reloadData with empty bounds");
	}
	
	self.contentSize = CGSizeMake(0, 0);
	
	reloadedDate = [NSDate date];
	NSString *firstObjectIndex = nil;
	if (objectViewsMap.allKeys && objectViewsMap.allKeys.count > 0) {
		NSA*sortedKeys = [[objectViewsMap allKeys] sortedArrayUsingSelector:@selector(compare:)];
		if (sortedKeys && sortedKeys.count> 0) {
			firstObjectIndex = [sortedKeys objectAtIndex:0];
		}
	}
	[objectViewsMap enumerateKeysAndObjectsUsingBlock:^(NSString *indexKey, TUIV*view, BOOL *stop) {
		[self enqueueReusableView:view];
		[view removeFromSuperview];
	}];
	
	objectViewsMap = NSMD.new;
	NSUI numberOfObjects = [dataSource numberOfViewsInLayout:self];
	if (numberOfObjects == 0) {
		objects = NSMA.new;
		[self setNeedsLayout];
		return;
	}
	self.objects = [NSMA arrayWithCapacity:numberOfObjects];
	for (NSUI i =0; i < numberOfObjects; i++) {
		AHLayoutObject *object = [[AHLayoutObject alloc] init];
		[self.objects addObject:object];
		object.index = i;
		object.indexString = [NSString stringWithFormat:@"%ld", i];
	}
	
	if (self.executingTransaction) {
		self.executingTransaction = nil;
		defaultTransaction.phase = AHLayoutTransactionPhasePrelayout;
		defaultTransaction.calculated = false;
		defaultTransaction = [[AHLayoutTransaction alloc] init];
		defaultTransaction.layout = self;
	}
	
	//First do some calculation to maintain the content offset
	CGPoint contentOffset = [defaultTransaction calculateNextContentOffset];
	
	// Now refine the contentOffset a bit more to make sure we scroll to the right object
	if (firstObjectIndex && firstObjectIndex.length && firstObjectIndex.integerValue < self.objects.count) {
		AHLayoutObject *scrollToObject = [self.objects objectAtIndex:[firstObjectIndex integerValue]];
		contentOffset = [defaultTransaction modifyContentOffset:contentOffset forRect:scrollToObject.calculatedFrame inVisibleRect:self.visibleRect horizontal:(self.typeOfLayout == AHLayoutHorizontal)];
		contentOffset = [defaultTransaction fixContentOffset:contentOffset forSize:defaultTransaction.contentSize inBounds:self.bounds];
	}
	self.contentOffset = contentOffset;
	
	[self executeNextLayoutTransaction];
	
	if (reloadHandler) {
		reloadHandler(self);
	}
}
- (TUIV*) dequeueReusableView			{
	TUIV*v = [reusableViews lastObject];
	if(v) [reusableViews removeLastObject];
	if (!v) v = [self createView];
	return v;
}
- (TUIV*) viewForIndex:(NSUI)index 	{
	if (!objectViewsMap || ![objectViewsMap.allKeys count]) return nil;
	NSString *indexKey = [NSString stringWithFormat:@"%ld", index];
	return [objectViewsMap objectForKey:indexKey];
}
- (NSI)   indexForView:(TUIV*)v 		{
	if (!objectViewsMap || ![objectViewsMap.allKeys count]) return -1;
	NSA*a = [objectViewsMap allKeysForObject:v];
	if (a.count > 0) {
		NSString *indexStr = [a objectAtIndex:0];
		return [indexStr integerValue];
	}
	return -1;
}

- (AHLayoutObject*) objectAtPoint:(CGP) point {
	for (AHLayoutObject *object in objects) {
		if (CGRectContainsPoint(object.calculatedFrame, point)) {
			return object;
		}
	}
	return nil;
}
- (NSUI) indexOfViewAtPoint:(CGP) point 	{
	return [self objectAtPoint:point].index;
}
- (TUIV*) viewAtPoint:		 (CGP) point		{
	AHLayoutObject *object = [self objectAtPoint:point];
	if (object) {
		return [objectViewsMap objectForKey:object.indexString];
	}
	return nil;
}
- (NSUI) scrollToViewIndex 						{
	return self.updatingTransaction.scrollToObjectIndex;
}
- (CGR) rectForViewAtIndex:  (NSUI)index 	{
	AHLayoutObject *object = [objects objectAtIndex:index];
	return object.calculatedFrame;
}
- (void) scrollToViewAtIndex:(NSUI)index atScrollPosition:(AHLayoutScrollPosition)scrollPosition animated:(BOOL)animated {
	CGRect v = [self visibleRect];
	CGRect r = [self rectForViewAtIndex:index];
	
	switch(scrollPosition) {
		case TUITableViewScrollPositionNone:
			// do nothing
			break;
		case TUITableViewScrollPositionTop:
			r.origin.x -= (v.size.width - r.size.width);
			r.size.width += (v.size.width - r.size.width);
			[self scrollRectToVisible:r animated:animated];
			break;
		case TUITableViewScrollPositionToVisible:
		default:
			[self scrollRectToVisible:r animated:animated];
			break;
	}
}

// This method create a new view for the object at the specified index so that the existing view can be pulled out of the layout and used elsewhere, useful for certain animations.   Returns the replaced view
- (TUIV*) replaceViewForObjectAtIndex:(NSUI) index withSize:(CGSZ) size {
	
	// This view has to already exist
	if (!objects || ![objects count]) return nil;
	NSString *indexKey = [NSString stringWithFormat:@"%ld", index];
	AHLayoutObject *object = [self.objects objectAtIndex:index];
	
	// Make sure the view exists
	TUIV*v = [objectViewsMap objectForKey:indexKey];
	if (v) {
		// remove the view from our mapping
		[self.objectViewsMap removeObjectForKey:indexKey];
		// remove it so it won't be reused
		[reusableViews removeObject:v];
		//Add another one in it's place
		object.size = size;
		return [self.executingTransaction addSubviewForObject:object atIndex:[NSString stringWithFormat:@"%ld", index]];
	}
	return nil;
}

- (void) resizeViewsAtIndexes:(NSA*) objectIndexes sizes:(NSA*) sizes animationBlock:(void (^)())animationBlock
																									     completion:(void (^)())completionBlock
{
	[objectIndexes enumerateObjectsUsingBlock:^(NSString *stringIndex, NSUI idx, BOOL *stop) {
		NSI index = [stringIndex integerValue];
		[self.updatingTransaction addCompletionBlock:completionBlock];
		self.updatingTransaction.animationBlock = animationBlock;
		self.updatingTransaction.animationDuration = 2.3;
		AHLayoutObject *oldObject = [self.objects objectAtIndex:index];
		AHLayoutObject *object = [[AHLayoutObject alloc] init];
		NSValue *objectSize = [sizes objectAtIndex:idx];
		object.size = [objectSize sizeValue];
		object.oldFrame = oldObject.calculatedFrame;
		object.markedForUpdate = YES;
		object.index = index;
		object.indexString = [NSString stringWithFormat:@"%ld", index];
		[self.updatingTransaction.changeList addObject:object];
	}];
}
- (void) resizeViewsToSize:(CGSZ) size            scrollToObjectIndex:(NSUI) scrollToObjectIndex
				animationBlock:(void (^)())animationBlock completionBlock:(void (^)())completion {
	[self.updatingTransaction addCompletionBlock:completion];
	self.updatingTransaction.animationBlock = animationBlock;
	self.updatingTransaction.animationDuration = 0.5;
	self.updatingTransaction.scrollToObjectIndex = scrollToObjectIndex;
	[self.objects enumerateObjectsUsingBlock:^(AHLayoutObject *obj, NSUI idx, BOOL *stop) {
		AHLayoutObject *object = [[AHLayoutObject alloc] init];
		object.size = size;
		object.oldFrame = obj.calculatedFrame;
		object.markedForUpdate = YES;
		object.index = obj.index;
		object.indexString = [NSString stringWithFormat:@"%ld", idx];
		[self.updatingTransaction.changeList addObject:object];
	}];
}

- (void) resizeViewAtIndex:(NSUI) index toSize:(CGSZ) size animationBlock:(void (^)())animationBlock  
																			 completionBlock:(void (^)())completionBlock {
	[self.updatingTransaction addCompletionBlock:completionBlock];
	self.updatingTransaction.animationBlock = animationBlock;
	self.updatingTransaction.animationDuration = 0.5;
	self.updatingTransaction.scrollToObjectIndex = index;
	AHLayoutObject *oldObject = [self.objects objectAtIndex:index];
	AHLayoutObject *object = [[AHLayoutObject alloc] init];
	object.size = size;
	object.oldFrame = oldObject.calculatedFrame;
	object.markedForUpdate = YES;
	object.index = index;
	object.indexString = [NSString stringWithFormat:@"%ld", index];
	[self.objects enumerateObjectsUsingBlock:^(AHLayoutObject *obj, NSUI idx, BOOL *stop) {
		obj.oldFrame = obj.calculatedFrame;
	}];
	[self.updatingTransaction.changeList addObject:object];
}
- (void) insertViewAtIndex:(NSUI) index  {
	[self insertViewAtIndex:index animationBlock:nil completionBlock:nil];
}

- (void) insertViewAtIndex:(NSUI) index  animationBlock:(AHLayoutViewAnimationBlock)animationBlock  
													 completionBlock:(void (^)())completionBlock
{
	// Check for a valid insertion point
	NSAssert(index >= 0 && index <= ([self.objects count]), @"AHLayout object out of range");
	[self beginUpdates];
	AHLayoutObject *object = [[AHLayoutObject alloc] init];
	object.size = [dataSource layout:self  sizeOfViewAtIndex:index];
	object.markedForInsertion = YES;
	object.index = index;
	object.indexString = [NSString stringWithFormat:@"%ld", index];
	[self.updatingTransaction.changeList addObject:object];
	self.updatingTransaction.animationDuration = 0.2;
	self.updatingTransaction.scrollToObjectIndex = index;
	self.updatingTransaction.viewAnimationBlock = animationBlock;
	[self.updatingTransaction addCompletionBlock:completionBlock];
	[self endUpdates];
}

- (void) removeViewsAtIndexes:(NSIS*)indexes animationBlock:(AHLayoutViewAnimationBlock)animationBlock  completionBlock:(void (^)())completionBlock {
	[self beginUpdates];
	
	[indexes enumerateIndexesUsingBlock:^(NSUI idx, BOOL *stop) {
		// Valid index
		NSAssert(idx >= 0 || idx < ([self.objects count]), @"AHLayout object out of range");
		AHLayoutObject *object = [self.objects objectAtIndex:idx];
		object.markedForRemoval = YES;
		self.updatingTransaction.scrollToObjectIndex = object.index;
		[self.updatingTransaction.changeList addObject:object];
	}];
	self.updatingTransaction.contentSize = self.contentSize;
	self.updatingTransaction.shouldNotCallDelegate = YES;  //in case the caller deletes the objects from their model before calling this
	self.updatingTransaction.viewAnimationBlock = animationBlock;
	[self.updatingTransaction addCompletionBlock:completionBlock];
	
	[self endUpdates];
}

- (void) prependNumOfViews:(NSI) numOfObjects animationBlock:(void (^)())animationBlock  
															completionBlock:(void (^)())completionBlock {
	[self beginUpdates];
	for (NSI i = numOfObjects; i > 0; i--) {
		AHLayoutObject *object = [[AHLayoutObject alloc] init];
		object.size = [dataSource layout:self sizeOfViewAtIndex:i];
		object.markedForInsertion = YES;
		object.index = i - 1;
		object.indexString = [NSString stringWithFormat:@"%ld", object.index];
		[self.updatingTransaction.changeList addObject:object];
	}
	self.updatingTransaction.scrollToObjectIndex = [self objectIndexAtTopOfScreen];
	self.updatingTransaction.viewAnimationBlock = animationBlock;
	[self.updatingTransaction addCompletionBlock:completionBlock];
	[self endUpdates];
}
- (NSA*)visibleViews					 {
	return [objectViewsMap allValues];
}
- (NSUI) objectIndexAtTopOfScreen {
	if (objectViewsMap.allKeys.count >0) {
		NSA*sortedIndexes = [[self.objectViewsMap allKeys] sortedArrayUsingSelector:@selector(compareNumberStrings:)];
		if (sortedIndexes.count > 0) {
			NSString *indexKey = [sortedIndexes lastObject];
			return [indexKey integerValue];
		}
	}
	return -1;
}

#pragma mark - Getters and Setters
#pragma mark - View Reuse
- (void) enqueueReusableView:(TUIV*)view	{
	if(!reusableViews) {
		reusableViews = [[NSMA alloc] init];
	}
	view.alpha = 1;
	[reusableViews addObject:view];
}
- (TUIV*) createView 								{
	TUIV*v = [[self.viewClass alloc] initWithFrame:CGRectZero];
	return v;
}
- (NSI) numberOfViews	 							{
	NSI numberOfCells = [self.objects count];
	return numberOfCells;
}

@end