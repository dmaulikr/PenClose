//
//  DiamondContentDelegate.m
//  PenClose
//
//  Created by Davide De Rosa on 6/13/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import "DiamondContentDelegate.h"

#define STROKE_RECT
#define HIGHLIGHT_LAST
//#define ANTIALIAS

@implementation DiamondContentDelegate

@synthesize model;
@synthesize containment;
@synthesize colors;

#pragma mark - init/dealloc

- (id) init
{
    if ((self = [super init])) {
        UIColor *p1Color = [[UIColor blueColor] retain];
        UIColor *p2Color = [[UIColor redColor] retain];
        UIColor *frameColor = [[UIColor blackColor] retain];

        colors = [[NSArray arrayWithObjects:p1Color, p2Color, frameColor, nil] retain];

        [frameColor release];
        [p1Color release];
        [p2Color release];
    }
    return self;
}

- (void) dealloc
{
    [colors release];

    [super dealloc];
}

#pragma mark - SheetContentDelegate

// MUST be called before first draw!
- (void) setGeometryAndAssignToView:(SheetView *)view
{
    cellSize = view.cellSize;

    // supporting variables
    markWidth = 2 * view.lineWidth;
    markEdge = cellSize - 2 * markWidth;
    squareRect.size.width = markEdge;
    squareRect.size.height = markEdge;

    // set as delegate
    view.contentDelegate = self;
}

#ifdef HIGHLIGHT_LAST
- (void) drawInView:(SheetView *)sheetView inContext:(CGContextRef)context inRect:(CGRect)rect
{
    static NSEnumerator *enumerator;
    static id element;
    static id nextElement;
    static UIColor *color;
    static MarkItem item;
    static DiamondVertex *vertex;
    static unsigned i;
#ifdef STROKE_RECT
    static CGRect markRect;
#else
    static CGPoint markLine[2];
#endif

    // move to origin
    CGContextTranslateCTM(context, containment.origin.x, containment.origin.y);

    // line style
    CGContextSetLineWidth(context, markWidth);
#ifdef ANTIALIAS
    CGContextSetShouldAntialias(context, YES);
    CGContextSetLineCap(context, kCGLineCapRound);
#else
    CGContextSetAllowsAntialiasing(context, NO);
#endif

    // squares (owner color)
    for (i = 0; i < DIAMOND_OWNERS; ++i) {
        color = (UIColor *)[colors objectAtIndex:i];
        CGContextSetFillColorWithColor(context, color.CGColor);

        enumerator = [[model squaresForOwner:i] objectEnumerator];
        while ((element = [enumerator nextObject])) {
            [(NSValue *)element getValue:&vertex];
            
            squareRect.origin.x = vertex->gx * cellSize + markWidth;
            squareRect.origin.y = vertex->gy * cellSize + markWidth;
            CGContextFillRect(context, squareRect);
        }
    }

    // marks
    for (i = 0; i < DIAMOND_OWNERS; ++i) {

        // old marks = frame color
        color = (UIColor *)[colors objectAtIndex:kMarkFrame];
#ifndef STROKE_RECT
        CGContextSetStrokeColorWithColor(context, color.CGColor);
#else
        CGContextSetFillColorWithColor(context, color.CGColor);
#endif    

        enumerator = [[model marksForOwner:i] objectEnumerator];
        nextElement = [enumerator nextObject];
        while ((element = nextElement)) {
            [(NSValue *)element getValue:&item];

            // pre-advance
            nextElement = [enumerator nextObject];

            // last mark = owner color
            if (element == model.lastMark) {
                color = (UIColor *)[colors objectAtIndex:i];
#ifndef STROKE_RECT
                CGContextSetStrokeColorWithColor(context, color.CGColor);
#else
                CGContextSetFillColorWithColor(context, color.CGColor);
#endif
            }

#ifdef STROKE_RECT
            if (item.direction == kMarkDirHorizontal) {
                markRect.origin.x = item.gx * cellSize + markWidth;
                markRect.origin.y = item.gy * cellSize - markWidth / 2;
                markRect.size.width = markEdge;
                markRect.size.height = markWidth;
            } else if (item.direction == kMarkDirVertical) {
                markRect.origin.x = item.gx * cellSize - markWidth / 2;
                markRect.origin.y = item.gy * cellSize + markWidth;
                markRect.size.width = markWidth;
                markRect.size.height = markEdge;
            }

            CGContextFillRect(context, markRect);
#else
            if (item.direction == kMarkDirHorizontal) {
                markLine[0].x = item.gx * cellSize + markWidth;
                markLine[0].y = item.gy * cellSize;
                markLine[1].x = markLine[0].x + markEdge;
                markLine[1].y = markLine[0].y;
            } else if (item.direction == kMarkDirVertical) {
                markLine[0].x = item.gx * cellSize;
                markLine[0].y = item.gy * cellSize + markWidth;
                markLine[1].x = markLine[0].x;
                markLine[1].y = markLine[0].y + markEdge;
            }

            CGContextBeginPath(context);
            CGContextAddLines(context, markLine, 2);
            CGContextStrokePath(context);
#endif
        }
    }
}
#else
- (void) drawInView:(SheetView *)sheetView inContext:(CGContextRef)context inRect:(CGRect)rect
{
    static NSEnumerator *enumerator;
    static id element;
    static UIColor *color;
    static MarkItem item;
    static DiamondVertex *vertex;
    static unsigned i;
#ifdef STROKE_RECT
    static CGRect markRect;
#else
    static CGPoint markLine[2];
#endif
    
    // move to origin
    CGContextTranslateCTM(context, containment.origin.x, containment.origin.y);
    
    // line style
    CGContextSetLineWidth(context, markWidth);
#ifdef ANTIALIAS
    CGContextSetShouldAntialias(context, YES);
    CGContextSetLineCap(context, kCGLineCapRound);
#else
    CGContextSetAllowsAntialiasing(context, NO);
#endif

    for (i = 0; i < DIAMOND_OWNERS; ++i) {
        color = (UIColor *)[colors objectAtIndex:i];
#ifndef STROKE_RECT
        CGContextSetStrokeColorWithColor(context, color.CGColor);
#endif
        CGContextSetFillColorWithColor(context, color.CGColor);

        // marks
        enumerator = [[model marksForOwner:i] objectEnumerator];
        while ((element = [enumerator nextObject])) {
            [(NSValue *)element getValue:&item];

#ifdef STROKE_RECT
            if (item.direction == kMarkDirHorizontal) {
                markRect.origin.x = item.gx * cellSize + markWidth;
                markRect.origin.y = item.gy * cellSize - markWidth / 2;
                markRect.size.width = markEdge;
                markRect.size.height = markWidth;
            } else if (item.direction == kMarkDirVertical) {
                markRect.origin.x = item.gx * cellSize - markWidth / 2;
                markRect.origin.y = item.gy * cellSize + markWidth;
                markRect.size.width = markWidth;
                markRect.size.height = markEdge;
            }
            
            CGContextFillRect(context, markRect);
#else
            if (item.direction == kMarkDirHorizontal) {
                markLine[0].x = item.gx * cellSize + markWidth;
                markLine[0].y = item.gy * cellSize;
                markLine[1].x = markLine[0].x + markEdge;
                markLine[1].y = markLine[0].y;
            } else if (item.direction == kMarkDirVertical) {
                markLine[0].x = item.gx * cellSize;
                markLine[0].y = item.gy * cellSize + markWidth;
                markLine[1].x = markLine[0].x;
                markLine[1].y = markLine[0].y + markEdge;
            }

            CGContextBeginPath(context);
            CGContextAddLines(context, markLine, 2);
            CGContextStrokePath(context);
#endif
        }

        // squares
        enumerator = [[model squaresForOwner:i] objectEnumerator];
        while ((element = [enumerator nextObject])) {
            [(NSValue *)element getValue:&vertex];

            squareRect.origin.x = vertex->gx * cellSize + markWidth;
            squareRect.origin.y = vertex->gy * cellSize + markWidth;
            CGContextFillRect(context, squareRect);
        }
    }
}
#endif

@end
