//
//  DiamondModel.h
//  PenClose
//
//  Created by Davide De Rosa on 6/9/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import <Foundation/Foundation.h>

// TODO: C/C++ for reuse

// same size as MarkOwner valid cases (0 = frame, 1 = p1, 2 = p2)
#define DIAMOND_OWNERS          3

// keep order!!!
typedef enum {
    kMarkP1,        // 0
    kMarkP2,        // 1
    kMarkFrame,     // 2
    kMarkNone,
    kMarkOutside
} MarkOwner;

typedef enum {
    kMarkDirHorizontal,
    kMarkDirVertical
} MarkDirection;

typedef struct _DiamondVertex {
    unsigned gx;
    unsigned gy;
    MarkOwner h;
    MarkOwner v;
    unsigned surrounding;

    // adjacent vertices
    struct _DiamondVertex *top;
    struct _DiamondVertex *right;
    struct _DiamondVertex *bottom;
    struct _DiamondVertex *left;
} DiamondVertex;

typedef struct {
    unsigned gx;
    unsigned gy;
    MarkDirection direction;
} MarkItem;

@interface DiamondModel : NSObject {
    unsigned size;
    DiamondVertex **area;
    NSValue *lastMark;

    NSMutableArray *marks[DIAMOND_OWNERS];      // of MarkItem
    NSMutableArray *squares[DIAMOND_OWNERS];    // of DiamondVertex *
    unsigned emptySquaresCount;
}

@property (nonatomic, readonly) unsigned size;
@property (nonatomic, readonly) unsigned emptySquaresCount;
@property (nonatomic, readonly) NSValue *lastMark;

- (id) initWithSize:(unsigned)size;

- (void) clear;
- (BOOL) isMarkableItem:(const MarkItem *)item;
- (unsigned) mark:(const MarkItem *)item forOwner:(MarkOwner)owner;

- (NSArray *) marksForOwner:(MarkOwner)owner;
- (NSArray *) squaresForOwner:(MarkOwner)owner;
- (unsigned) squareCountForOwner:(MarkOwner)owner;

@end
