//
//  DiamondModel.m
//  PenClose
//
//  Created by Davide De Rosa on 6/9/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import "DiamondModel.h"

//#define BENCHMARK
#define MARK(gx, gy, d, o)        [self markX:(gx) y:(gy) direction:d forOwner:o]

@interface DiamondModel ()

- (void) setupFrame;
- (unsigned) markX:(unsigned)gx y:(unsigned)gy direction:(MarkDirection)aDirection forOwner:(MarkOwner)owner;
- (unsigned) surroundVertex:(DiamondVertex *)vertex forOwner:(MarkOwner)aOwner;

@end

@implementation DiamondModel

@synthesize size;
@synthesize emptySquaresCount;
@synthesize lastMark;

#pragma mark - init/dealloc

- (id) initWithSize:(unsigned)aSize
{
    if ((self = [super init])) {
        size = aSize;

        // allocate diamond matrix
        area = (DiamondVertex **) calloc(size + 1, sizeof(DiamondVertex *));
        DiamondVertex *vertex;
        for (unsigned gy = 0; gy <= size; ++gy) {
            area[gy] = (DiamondVertex *) calloc(size + 1, sizeof(DiamondVertex));
            for (unsigned gx = 0; gx <= size; ++gx) {
                vertex = &area[gy][gx];

                // embed coordinates
                vertex->gx = gx;
                vertex->gy = gy;

                // default to nothing markable
                vertex->h = kMarkOutside;
                vertex->v = kMarkOutside;

                // surrounding count (square is filled at 4)
                vertex->surrounding = 0;
            }
        }

        // second pass for adjacencies
        for (unsigned gy = 0; gy <= size; ++gy) {
            for (unsigned gx = 0; gx <= size; ++gx) {
                vertex = &area[gy][gx];
                
                vertex->top = (gy > 0) ? &area[gy - 1][gx] : NULL;
                vertex->right = (gx <= size) ? &area[gy][gx + 1] : NULL;
                vertex->bottom = (gy <= size) ? &area[gy + 1][gx] : NULL;
                vertex->left = (gx > 0) ? &area[gy][gx - 1] : NULL;
            }
        }

        // marks and squares varying lists
        for (unsigned i = 0; i < DIAMOND_OWNERS; ++i) {
            marks[i] = [[NSMutableArray alloc] init];
            squares[i] = [[NSMutableArray alloc] init];
        }
        
        // empty squares count
        emptySquaresCount = 0;

        // build up diamond frame
#ifndef BENCHMARK
        [self setupFrame];
#else
        // benchmark
        for (unsigned gy = 0; gy <= size; ++gy) {
            for (unsigned gx = 0; gx <= size; ++gx) {
                MARK(gx, gy, kMarkDirHorizontal, kMarkP1);
                MARK(gx, gy, kMarkDirVertical, kMarkP2);
            }
        }
#endif
    }
    return self;
}

- (void) dealloc
{
    [lastMark release];

    // marks and squares
    for (unsigned i = 0; i < DIAMOND_OWNERS; ++i) {
        [marks[i] release];
        [squares[i] release];
    }
    
    // vertices
    for (unsigned i = 0; i <= size; ++i) {
        free(area[i]);
    }
    free(area);
    
    [super dealloc];
}

#pragma mark - Public interface

- (void) clear
{
    // reset vertices
    DiamondVertex *vertex;
    for (unsigned gy = 0; gy <= size; ++gy) {
        for (unsigned gx = 0; gx <= size; ++gy) {
            vertex = &area[gy][gx];
            vertex->h = kMarkOutside;
            vertex->v = kMarkOutside;
            vertex->surrounding = 0;
        }
    }

    // erase drawing lists
    for (unsigned i = 0; i < DIAMOND_OWNERS; ++i) {
        [marks[i] removeAllObjects];
        [squares[i] removeAllObjects];
    }
}

- (BOOL) isMarkableItem:(const MarkItem *)item
{
    const DiamondVertex *vertex = &area[item->gy][item->gx];

    if ((item->direction == kMarkDirHorizontal) && (vertex->h != kMarkNone)) {
        NSLog(@"Diamond: marked already or outside frame");
        return NO;
    } else if ((item->direction == kMarkDirVertical) && (vertex->v != kMarkNone)) {
        NSLog(@"Diamond: marked already or outside frame");
        return NO;
    }

    return YES;
}

// return filled squares
- (unsigned) mark:(const MarkItem *)item forOwner:(MarkOwner)owner
{
    DiamondVertex *vertex = &area[item->gy][item->gx];
    unsigned filledSquares = 0;

    // shared code by all marks
    if (item->direction == kMarkDirHorizontal) {
        vertex->h = owner;
    } else if (item->direction == kMarkDirVertical) {
        vertex->v = owner;
    }

    // drawing lists (exclude empty marks)
    if (owner != kMarkNone) {
        NSValue *value = [NSValue value:item withObjCType:@encode(MarkItem)];

        // append mark to owner list
        [marks[owner] addObject:value];

        // update last added mark
        [lastMark release];
        lastMark = [value retain];

        // decrease adjacent squares fill count
        if (item->direction == kMarkDirHorizontal) {
            filledSquares += [self surroundVertex:vertex->top forOwner:owner];
        } else if (item->direction == kMarkDirVertical) {
            filledSquares += [self surroundVertex:vertex->left forOwner:owner];
        }
        filledSquares += [self surroundVertex:vertex forOwner:owner];
    }

    return filledSquares;
}

- (NSArray *) marksForOwner:(MarkOwner)owner
{
    return marks[owner];
}

- (NSArray *) squaresForOwner:(MarkOwner)owner
{
    return squares[owner];
}

- (unsigned) squareCountForOwner:(MarkOwner)owner
{
    return [squares[owner] count];
}

#pragma mark - Private interface

// XXX: ugly code (poor data structures, efficiency doesn't matter here)
- (void) setupFrame
{
    unsigned center, gx, gy, vdelta, distance;
    BOOL odd = size & 1;
    
    // start from diamond left center
    gy = size / 2;
    gx = 0;
    distance = size;
    vdelta = 1;
    
    // central markable area
    center = (odd ? 2 : 1);
    for (unsigned c = 0; c < center; ++c) {
        for (unsigned i = 0; i < distance; ++i) {
            MARK(gx + i, gy + c, kMarkDirHorizontal, kMarkNone);
            
            // vertical edges = frame
            if ((i > 0) && (i < distance)) {
                MARK(gx + i, gy + c, kMarkDirVertical, kMarkNone);
            }
        }
    }
    
    // build frame symmetrically from the middle
    while (distance > 1) {
        
        // upper
        MARK(gx, gy - vdelta, kMarkDirHorizontal, kMarkFrame);
        MARK(gx + distance - 1, gy - vdelta, kMarkDirHorizontal, kMarkFrame);
        MARK(gx, gy - vdelta, kMarkDirVertical, kMarkFrame);
        MARK(gx + distance, gy - vdelta, kMarkDirVertical, kMarkFrame);
        
        // markable
        for (unsigned i = 1; i < distance; ++i) {
            if (i < distance - 1) {
                MARK(gx + i, gy - vdelta, kMarkDirHorizontal, kMarkNone);
            }
            MARK(gx + i, gy - vdelta, kMarkDirVertical, kMarkNone);
        }
        
        if (odd) {
            ++vdelta;
        }
        
        // lower
        MARK(gx, gy + vdelta, kMarkDirHorizontal, kMarkFrame);
        MARK(gx + distance - 1, gy + vdelta, kMarkDirHorizontal, kMarkFrame);
        MARK(gx, gy + vdelta - 1, kMarkDirVertical, kMarkFrame);
        MARK(gx + distance, gy + vdelta - 1, kMarkDirVertical, kMarkFrame);

        // markable (exclude bottom)
        if (distance > 3) {
            for (unsigned i = 1; i < distance; ++i) {
                if (i < distance - 1) {
                    MARK(gx + i, gy + vdelta, kMarkDirHorizontal, kMarkNone);
                }
                MARK(gx + i, gy + vdelta, kMarkDirVertical, kMarkNone);
            }
        }

        ++gx;
        distance -= 2;
        
        if (!odd) {
            ++vdelta;
        }        
    }
    
    // edge padding for odd diamond
    if (odd) {
        const unsigned middle = size / 2;
        
        MARK(middle, 0, kMarkDirHorizontal, kMarkFrame);
        MARK(middle, size, kMarkDirHorizontal, kMarkFrame);
        MARK(0, middle, kMarkDirVertical, kMarkFrame);
        MARK(size, middle, kMarkDirVertical, kMarkFrame);
    }

    // initially empty squares
    if (odd) {
        emptySquaresCount = 4 * (size - 1) + 2 * size - 1;
    } else {
        emptySquaresCount = size * size / 2 + size;
    }
}

// expanded markItem version
- (unsigned) markX:(unsigned)gx y:(unsigned)gy direction:(MarkDirection)aDirection forOwner:(MarkOwner)owner
{
    MarkItem item;
    item.gx = gx;
    item.gy = gy;
    item.direction = aDirection;
    return [self mark:&item forOwner:owner];
}

- (unsigned) surroundVertex:(DiamondVertex *)vertex forOwner:(MarkOwner)aOwner
{
    if (vertex) {
        ++vertex->surrounding;

        // count == 4, square is surrounded
        if (vertex->surrounding == 4) {
            [squares[aOwner] addObject:[NSValue valueWithPointer:vertex]];
            --emptySquaresCount;
            return 1;
        }
    }
    return 0;
}

@end
