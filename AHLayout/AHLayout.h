//
//  AHLayout.h
//  Swift
//
//  Created by John Wright on 11/13/11.
// CPright (c) 2011 AirHeart. All rights reserved.
//

#define kAHLayoutViewHeight @"kAHLayoutViewHeight"
#define kAHLayoutViewWidth @"kAHLayoutViewWidth"

//#import "TUIKit.h"
#import <AtoZ/AtoZ.h>

@interface NSString(TUICompare)
- (NSComparisonResult)compareNumberStrings:(NSString *)str;
@end
typedef NS_ENUM( NSUI, AHLayoutScrollPosition ){		
AHLayoutScrollPositionNone,			AHLayoutScrollPositionTop,		
AHLayoutScrollPositionMiddle,		AHLayoutScrollPositionBottom,
AHLayoutScrollPositionToVisible 	// currently the only supported arg
}; 
// a callback handler to be used in various layout operations
typedef NS_ENUM( NSUI, AHLayoutType) {	AHLayoutVertical,   AHLayoutHorizontal }; 	

#define kAHLayoutAnimation @"AHLayoutAnimation"
@class AHLayout;
@class AHLayoutObject;
typedef void(^AHLayoutHandler)(AHLayout *layout);
typedef void(^AHLayoutViewAnimationBlock)(AHLayout *layout, TUIV*view);

@protocol AHLayoutDataSource;
@interface AHLayout : TUIScrollView <TUIScrollViewDelegate>

@property (NATOM,WK) 		NSObject<AHLayoutDataSource> *dataSource;
@property (NATOM,WK)		Class 					  			 viewClass;
@property (NATOM) 			AHLayoutType 		  			 typeOfLayout;
@property (NATOM) 			CGFloat 					  spaceBetweenViews;
@property (NATOM,RONLY) NSI 					  		   numberOfViews;
@property (NATOM,STRNG) NSDate 				 			*reloadedDate;
@property (NATOM,CP)	 	AHLayoutHandler    			reloadHandler;
@property (NATOM,RONLY) NSA						 			*visibleViews;
@property (NATOM) 			BOOL 							  didFirstLayout;

#pragma mark - General

- (TUIV*)  dequeueReusableView;
- (void)   reloadData;
- (NSI)    indexForView:			 (TUIV*) v;
- (TUIV*)  viewForIndex:		     (NSUI) index;
- (NSUI)   indexOfViewAtPoint:   (CGP) point;
- (TUIV*)  viewAtPoint:		      (CGP) point;
- (NSUI)   objectIndexAtTopOfScreen;
- (CGR) rectForViewAtIndex: 			 (NSUI) index;
- (TUIV*)  replaceViewForObjectAtIndex: (NSUI) index withSize:(CGSZ) size;
- (void)   scrollToViewAtIndex: 			 (NSUI) index atScrollPosition:(AHLayoutScrollPosition)scrollPosition 
																				 animated:(BOOL)animated;
#pragma mark - Layout transactions
- (void) beginUpdates;
- (void) endUpdates;

#pragma mark - Resizing
- (void) resizeViewsAtIndexes:(NSA*) objectIndexes 				  sizes:(NSA*) sizes 
					animationBlock:(void (^)())animationBlock completion:(void (^)())completionBlock;
					
- (void) resizeViewsToSize:(CGSZ) size 			  scrollToObjectIndex:(NSUI) scrollToObjectIndex 
			  animationBlock:(void (^)())animationBlock 	completionBlock:(void (^)())completion;
			  
- (void) resizeViewAtIndex:(NSUI) index toSize:(CGSZ) size animationBlock:(void (^)())animationBlock  
																		      completionBlock:(void (^)())completionBlock;
#pragma mark - Adding and removing views
- (void) insertViewAtIndex:(NSUI) index;

- (void) insertViewAtIndex:(NSUI) index  
           animationBlock:(AHLayoutViewAnimationBlock)animationBlock  
			 completionBlock:(void (^)())completionBlock;

- (void)removeViewsAtIndexes:(NSIS*)indexes 
				 animationBlock:(AHLayoutViewAnimationBlock)animationBlock
				completionBlock:(void (^)())completionBlock;
				
- (void) prependNumOfViews:(NSI) numOfObjects 
			  animationBlock:(void (^)())animationBlock  
			 completionBlock:(void (^)())completionBlock;

# pragma mark - Scrolling
@end


#pragma mark Protocol AHLayoutDataSource *********

@protocol AHLayoutDataSource <NSObject>
@required	 // Populating subview items
- (NSUI)	 numberOfViewsInLayout:(AHLayout *)layout;
- (CGSZ)	 layout:(AHLayout*)layout sizeOfViewAtIndex:(NSUI)index;
- (TUIV*) layout:(AHLayout*)layout viewForIndex:(NSI)index;
@optional
- (TUIV*) layout:(AHLayout*)layout objectAtIndex:(NSI)index;
@end



