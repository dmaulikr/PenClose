//
//  GameController.h
//  PenClose
//
//  Created by Davide De Rosa on 6/6/11.
//  Copyright 2011 Davide De Rosa. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PeerSession.h"
#import "DiamondController.h"
#import "KSCheckView.h"

@interface GameController : UIViewController<PeerGameDelegate, UIAlertViewDelegate> {
    IBOutlet UIView *playerPanel;
    IBOutlet UILabel *ownLabel;
    IBOutlet KSCheckView *ownSquare;
    IBOutlet UILabel *enemyLabel;
    IBOutlet KSCheckView *enemySquare;
    UIAlertView *alert;

    // transport and core
    PeerSession *session;
    DiamondController *diamond;

    // prevent race conditions on remote premature disconnection
    BOOL appeared;
    BOOL popLater;

    // game logic
    MarkOwner ownPlayer;
    MarkOwner enemyPlayer;
    MarkOwner currentPlayer;
    BOOL gameOver;

    // preferences
    BOOL prefSoundEffects;
}

- (void) preparePlayersWithSession:(PeerSession *)sessionOrNil;
- (void) highlightCurrentPlayer;
- (void) handleDiamondTap:(UITapGestureRecognizer *)recognizer;
- (void) handleAddedItem:(const MarkItem *)item;
- (void) updateWithFilledSquares:(NSInteger)filledSquares;
- (void) backToMenu;
- (void) quitGame;

@end
