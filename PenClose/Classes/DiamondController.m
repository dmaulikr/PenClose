//
//  DiamondController.m
//  PenClose
//
//  Created by Davide De Rosa on 6/7/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import "DiamondController.h"

// minimum touchable rect size
#define MIN_TOUCHABLE       64.0

// intersect rects with square diagonals for higher touch precision

static inline BOOL isTopTouch(const CGRect *touchRects, const CGPoint *offset, const NSUInteger edge) {
    return CGRectContainsPoint(touchRects[kTouchPosTop], *offset) &&
            (offset->x > offset->y) && (offset->x < edge - offset->y);
}

static inline BOOL isRightTouch(const CGRect *touchRects, const CGPoint *offset, const NSUInteger edge) {
    return CGRectContainsPoint(touchRects[kTouchPosRight], *offset) &&
            (offset->x > offset->y) && (offset->x > edge - offset->y);
}

static inline BOOL isBottomTouch(const CGRect *touchRects, const CGPoint *offset, const NSUInteger edge) {
    return CGRectContainsPoint(touchRects[kTouchPosBottom], *offset) &&
            (offset->x < offset->y) && (offset->x > edge - offset->y);
}

static inline BOOL isLeftTouch(const CGRect *touchRects, const CGPoint *offset, const NSUInteger edge) {
    return CGRectContainsPoint(touchRects[kTouchPosLeft], *offset) &&
            (offset->x < offset->y) && (offset->x < edge - offset->y);
}

@implementation DiamondController

@synthesize model;
@synthesize innerView = sheetView;
@synthesize contentDelegate;
@synthesize view;

#pragma mark - init/dealloc

- (id) init
{
    if ((self = [super init])) {
        NSString *soundPath = [[NSBundle mainBundle] pathForResource:@"Stroke" ofType:@"caf"];
        NSURL *soundURL = [[NSURL alloc] initFileURLWithPath:soundPath];
        AudioServicesCreateSystemSoundID((CFURLRef) soundURL, &strokeSound);
        [soundURL release];

        contentDelegate = [[DiamondContentDelegate alloc] init];
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"Diamond: dealloc");
    
    [self releaseView];
    [model release];
    [contentDelegate release];

    AudioServicesDisposeSystemSoundID(strokeSound);

    [super dealloc];
}

#pragma mark - Public interface

// call AFTER model creation
- (void) createViewWithFrame:(CGRect)frame touchTolerance:(CGFloat)tolerance
{
    [self releaseView];

    // allocate sheet with adjusted cell size to model
    sheetView = [[SheetView alloc] initWithFrame:frame];
    sheetView.cellSize = frame.size.width / (model.size + 2);
    NSLog(@"Diamond: cellSize = %d", sheetView.cellSize);

    // centered containment rect
    CGRect containment;
    containment.size.width = sheetView.cellSize * model.size;
    containment.size.height = sheetView.cellSize * model.size;
    containment.origin.x = (frame.size.width - containment.size.width) / 2;
    containment.origin.y = (frame.size.height - containment.size.height) / 2;

    // align sheet with diamond
    sheetView.offset = CGPointMake((NSUInteger) containment.origin.x % sheetView.cellSize,
                                   (NSUInteger) containment.origin.y % sheetView.cellSize);

    // update content delegate accordingly
    contentDelegate.model = model;
    contentDelegate.containment = containment;
    [contentDelegate setGeometryAndAssignToView:sheetView];

    // touch areas by tolerance
    touchMargin = tolerance * sheetView.cellSize;

    // overlapping (intersected later), 0123 = TRBL
    touchRects[kTouchPosTop] = CGRectMake(0, 0, sheetView.cellSize, touchMargin);
    touchRects[kTouchPosRight] = CGRectMake(sheetView.cellSize - touchMargin, 0, touchMargin, sheetView.cellSize);
    touchRects[kTouchPosBottom] = CGRectMake(0, sheetView.cellSize - touchMargin, sheetView.cellSize, touchMargin);
    touchRects[kTouchPosLeft] = CGRectMake(0, 0, touchMargin, sheetView.cellSize);

    // wrap into scroll view
    view = [[UIScrollView alloc] initWithFrame:frame];
    view.contentSize = frame.size;
    view.minimumZoomScale = 1.0;
    view.maximumZoomScale = MAX(MIN_TOUCHABLE / sheetView.cellSize, 1.0);
    view.clipsToBounds = YES;
    view.delegate = self;
    [view addSubview:sheetView];
}

- (void) releaseView
{
    [sheetView release];
    sheetView = nil;
    [view release];
    view = nil;
}

- (unsigned) mark:(const MarkItem *)item forOwner:(MarkOwner)owner sound:(BOOL)soundEnabled
{
    // delegate to model
    const unsigned filledSquares = [model mark:item forOwner:owner];

    // redraw sheet (XXX here?)
    [sheetView setNeedsDisplay];
    NSLog(@"Diamond: mark added at (%d, %d), direction=%d", item->gx, item->gy, item->direction);

    // play pencil mark sound
    if (soundEnabled) {
        AudioServicesPlaySystemSound(strokeSound);
    }

    if (filledSquares > 0) {
        NSLog(@"Diamond: filled %d squares", filledSquares);
    }

    return filledSquares;
}

- (BOOL) convertPoint:(CGPoint)point toMark:(MarkItem *)item
{
    NSLog(@"Diamond: touch point %@", NSStringFromCGPoint(point));
    const CGRect containment = contentDelegate.containment;

    // trivial containment check
    if (!CGRectContainsPoint(containment, point)) {
        NSLog(@"Diamond: outside frame");
        return NO;
    }

    // sheet grid coordinates
    const unsigned sx = point.x / sheetView.cellSize;
    const unsigned sy = point.y / sheetView.cellSize;
    NSLog(@"Diamond: sheet coordinates (%d, %d)", sx, sy);
    
    // coordinates inside diamond rect
    unsigned gx = (point.x - containment.origin.x) / sheetView.cellSize;
    unsigned gy = (point.y - containment.origin.y) / sheetView.cellSize;
    
    // offset inside diamond cell
    const CGPoint offset = CGPointMake((NSUInteger)(point.x - containment.origin.x) % sheetView.cellSize,
                                       (NSUInteger)(point.y - containment.origin.y) % sheetView.cellSize);
    
    NSLog(@"Diamond: diamond coordinates (%d, %d)", gx, gy);
    NSLog(@"Diamond: diamond cell offset %@", NSStringFromCGPoint(offset));
    
    // check touchable area
    MarkDirection direction;
    if (isTopTouch(touchRects, &offset, sheetView.cellSize)) {
        direction = kMarkDirHorizontal;
    } else if (isRightTouch(touchRects, &offset, sheetView.cellSize)) {
        direction = kMarkDirVertical;
        
        // right vertex
        ++gx;
    } else if (isBottomTouch(touchRects, &offset, sheetView.cellSize)) {
        direction = kMarkDirHorizontal;
        
        // below vertex
        ++gy;
    } else if (isLeftTouch(touchRects, &offset, sheetView.cellSize)) {
        direction = kMarkDirVertical;
    } else {
        NSLog(@"Diamond: non touchable area");
        return NO;
    }

    // valid touch area, check position and owner
    item->gx = gx;
    item->gy = gy;
    item->direction = direction;
    if (![model isMarkableItem:item]) {
        NSLog(@"Diamond: outside frame or marked already");
        return NO;
    }

    return YES;
}

- (void) panToMark:(const MarkItem *)item
{
    // only pan if zoomed
    if (view.zoomScale > 1.0) {
        CGPoint point = CGPointMake(contentDelegate.containment.origin.x + item->gx * sheetView.cellSize,
                                    contentDelegate.containment.origin.y + item->gy * sheetView.cellSize);

        // move to mark center
        if (item->direction == kMarkDirHorizontal) {
            point.x +=  sheetView.cellSize / 2;
        } else if (item->direction == kMarkDirVertical) {
            point.y +=  sheetView.cellSize / 2;
        }

        // current zoomed size
        CGSize zoomedSize;
        zoomedSize.width = view.frame.size.width / view.zoomScale;
        zoomedSize.height = view.frame.size.height / view.zoomScale;

        // point offset to center
        CGPoint offset;
        offset.x = point.x - zoomedSize.width / 2;
        offset.y = point.y - zoomedSize.height / 2;

        // fix margins
        if (offset.x < 0) {
            offset.x = 0;
        } else if (offset.x + zoomedSize.width > view.frame.size.width) {
            offset.x = view.frame.size.width - zoomedSize.width;
        }
        if (offset.y < 0) {
            offset.y = 0;
        } else if (offset.y + zoomedSize.height > view.frame.size.height) {
            offset.y = view.frame.size.height - zoomedSize.height;
        }

        // re-scale to content
        offset.x *= view.zoomScale;
        offset.y *= view.zoomScale;

        [view setContentOffset:offset animated:YES];
        //[view zoomToRect:viewport animated:YES];
    }
}

- (MarkOwner) enemyOf:(MarkOwner)owner
{
    switch (owner) {
        case kMarkP1:
            return kMarkP2;
        case kMarkP2:
            return kMarkP1;
        default:
            return -1;
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return sheetView;
}

- (void) scrollViewDidEndZooming:(UIScrollView *)scrollView
                        withView:(UIView *)view
                         atScale:(float)scale
{
    NSLog(@"Diamond: scrollViewDidEndZooming: scale=%f", scale);
}

@end
