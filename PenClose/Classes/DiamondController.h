//
//  DiamondController.h
//  PenClose
//
//  Created by Davide De Rosa on 6/7/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "DiamondModel.h"
#import "SheetView.h"
#import "DiamondContentDelegate.h"

typedef enum {
    kTouchPosTop,
    kTouchPosRight,
    kTouchPosBottom,
    kTouchPosLeft
} TouchPosition;

@interface DiamondController : NSObject<UIScrollViewDelegate> {
    DiamondModel *model;
    SheetView *sheetView;
    DiamondContentDelegate *contentDelegate;
    UIScrollView *view;

    CGFloat touchMargin;
    CGRect touchRects[4]; // consistent with TouchPosition

    SystemSoundID strokeSound;
}

@property (nonatomic, retain) DiamondModel *model;
@property (nonatomic, readonly) UIView *innerView;
@property (nonatomic, readonly) DiamondContentDelegate *contentDelegate;
@property (nonatomic, readonly) UIScrollView *view;

- (void) createViewWithFrame:(CGRect)frame touchTolerance:(CGFloat)tolerance;
- (void) releaseView;
- (unsigned) mark:(const MarkItem *)item forOwner:(MarkOwner)owner sound:(BOOL)soundEnabled;
- (BOOL) convertPoint:(CGPoint)point toMark:(MarkItem *)item;
- (void) panToMark:(const MarkItem *)item;
- (MarkOwner) enemyOf:(MarkOwner)owner;

@end
