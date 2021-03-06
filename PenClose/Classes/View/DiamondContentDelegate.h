//
//  DiamondContentDelegate.h
//  PenClose
//
//  Created by Davide De Rosa on 6/13/11.
//  Copyright 2011 Davide De Rosa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KSSheetView.h"
#import "DiamondModel.h"

@interface DiamondContentDelegate : NSObject<KSSheetViewDelegate> {
    DiamondModel *model;
    CGRect containment;
    NSArray *colors;

    NSUInteger cellSize;
    CGFloat markWidth;
    CGFloat markEdge;
    CGRect squareRect;
}

@property (nonatomic, assign) DiamondModel *model;
@property (nonatomic, assign) CGRect containment;
@property (nonatomic, readonly) NSArray *colors;
//@property (nonatomic, retain) NSArray *colors;

- (void) setGeometryAndAssignToView:(KSSheetView *)view;

@end
