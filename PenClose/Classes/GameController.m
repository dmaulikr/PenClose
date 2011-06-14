//
//  GameController.m
//  PenClose
//
//  Created by Davide De Rosa on 6/6/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import "GameController.h"
#import "OptionsController.h"

// TODO editable size from options
#define DIAMOND_SIZE                14
//#define DIAMOND_SIZE                4
#define TOUCH_TOLERANCE             0.25

#define ALERT_QUIT                  1
#define ALERT_DISCONNECTION         2

@implementation GameController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.title = @"Play";

        // initialize diamond controller with model
        diamond = [[DiamondController alloc] init];
        DiamondModel *model = [[DiamondModel alloc] initWithSize:DIAMOND_SIZE];
        diamond.model = model;
        [model release];

        // set on viewDidAppear and willDisconnect to prevent pop before appear
        appeared = NO;
        popLater = NO;
    }
    return self;
}

- (void) preparePlayersWithSession:(PeerSession *)sessionOrNil
{
    BOOL isStartingPlayer;

    // retain session (if any) and set as delegate
    if (sessionOrNil) {
        session = [sessionOrNil retain];
        session.gameDelegate = self;
    }

    // online: initiator starts
    if (session) {
        isStartingPlayer = session.isInitiator;
    }

    // single: TODO read from options
    else {
        isStartingPlayer = YES;
    }

    // player 1 starts (blue)
    currentPlayer = kMarkP1;
    if (isStartingPlayer) {
        ownPlayer = currentPlayer;
    } else {
        ownPlayer = [diamond enemyOf:currentPlayer];
    }
    enemyPlayer = [diamond enemyOf:ownPlayer];

    // initialize labels
    ownLabel.text = @"You: 0";
    enemyLabel.text = @"Enemy: 0";

    // game has just started
    gameOver = NO;
}

- (void) didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void) viewDidLoad
{
    NSLog(@"Game: viewDidLoad");

    [super viewDidLoad];

    // do not interrupt match
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];

    // customize navigation bar
    UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:@"Quit"
                                                                      style:UIBarButtonItemStyleBordered
                                                                     target:self
                                                                     action:@selector(backToMenu)];
    self.navigationItem.leftBarButtonItem = newBackButton;
    [newBackButton release];
    UIBarButtonItem *optionsButton = [[UIBarButtonItem alloc] initWithTitle:@"Options"
                                                                      style:UIBarButtonItemStyleBordered
                                                                     target:self
                                                                     action:@selector(showOptions)];
    self.navigationItem.rightBarButtonItem = optionsButton;
    self.navigationItem.hidesBackButton = YES;
    [optionsButton release];

    // adjust to parent
    CGRect diamondFrame = self.view.frame;
    diamondFrame.size.height -= playerPanel.frame.size.height;
    [diamond createViewWithFrame:diamondFrame touchTolerance:TOUCH_TOLERANCE];

    // single tap gesture (inner view)
    diamond.innerView.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                                          initWithTarget:self
                                                          action:@selector(handleDiamondTap:)];
    singleTapGestureRecognizer.numberOfTapsRequired = 1;
    [diamond.innerView addGestureRecognizer:singleTapGestureRecognizer];

    // assign player color to square
    NSArray *colors = diamond.contentDelegate.colors;
    ownSquare.color = [UIColor whiteColor];
    ownSquare.backgroundColor = [colors objectAtIndex:ownPlayer];
    enemySquare.color = [UIColor whiteColor];
    enemySquare.backgroundColor = [colors objectAtIndex:enemyPlayer];

    // highlight
    [self highlightCurrentPlayer];

    // add diamond to game view and send to background
    [self.view addSubview:diamond.view];
    [self.view sendSubviewToBack:diamond.view];
}

- (void) viewDidAppear:(BOOL)animated
{
    appeared = YES;
    if (popLater) {
        [self.navigationController popToRootViewControllerAnimated:YES];
        return;
    }

    // reload preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    prefSoundEffects = [defaults boolForKey:@"soundEffects"];    
}

- (void) viewDidUnload
{
    NSLog(@"Game: viewDidUnload");

    [ownLabel release];
    [enemyLabel release];
    [ownSquare release];
    [enemySquare release];
    [playerPanel release];
    ownLabel = nil;
    enemyLabel = nil;
    ownSquare = nil;
    enemySquare = nil;
    playerPanel = nil;

    // only release view
    [diamond releaseView];

    // allow interruptions again
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];

    [super viewDidUnload];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) dealloc
{
    NSLog(@"Game: dealloc");

    [diamond release];

    // unbind session (going back to menu)
    if (session) {
        [session release];
        session = nil;
    }

    // release active alert view
    if (alert) {
        [alert release];
    }

    // allow interruptions again
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];

    [super dealloc];
}

#pragma mark - Game actions

- (void) highlightCurrentPlayer
{
    if (currentPlayer == ownPlayer) {
        ownSquare.enabled = YES;
        enemySquare.enabled = NO;
    } else {
        ownSquare.enabled = NO;
        enemySquare.enabled = YES;
    }
}

- (void) handleDiamondTap:(UITapGestureRecognizer *)recognizer
{
    // check turn (FIXME single player)
    if (!session || (currentPlayer == ownPlayer)) {

        // gesture dispatched by inner view
        CGPoint point = [recognizer locationOfTouch:0 inView:diamond.innerView];

        // update model
        MarkItem item;
        if ([diamond convertPoint:point toMark:&item]) {

            // update model
            const int filledSquares = [diamond mark:&item forOwner:currentPlayer sound:prefSoundEffects];
            [self updateWithFilledSquares:filledSquares];

            // pan to marked location
            //[diamondController panToMark:&item];

            // send move remotely
            if (session) {
                NSLog(@"Game: move sent");
                [session sendPacket:[NSData dataWithBytes:&item length:sizeof(MarkItem)]];
            }
        }
    }
}

- (void) handleAddedItem:(const MarkItem *)item
{
    // check turn (FIXME single player)
    if (!session || (currentPlayer != ownPlayer)) {

        // update model
        const int filledSquares = [diamond mark:item forOwner:currentPlayer sound:prefSoundEffects];
        [self updateWithFilledSquares:filledSquares];

        // pan to marked location
        [diamond panToMark:(const MarkItem *)item];
    }
}

- (void) updateWithFilledSquares:(NSInteger)filledSquares
{
    // update players count
    unsigned squareCount = [diamond.model squareCountForOwner:currentPlayer];
    if (currentPlayer == ownPlayer) {
        ownLabel.text = [NSString stringWithFormat:@"You: %d", squareCount];
    } else {
        enemyLabel.text = [NSString stringWithFormat:@"Enemy: %d", squareCount];
    }

    // squares left to fill
    const unsigned emptyCount = diamond.model.emptySquaresCount;

    // game over?
    if (!emptyCount) {
        gameOver = YES;

        NSLog(@"Game: match is over!");

        const unsigned ownCount = [diamond.model squareCountForOwner:ownPlayer];
        const unsigned enemyCount = [diamond.model squareCountForOwner:enemyPlayer];

        NSString *title, *msg;
        if (ownCount > enemyCount) {
            title = @"Congratulations";
            msg = @"You won!";
        } else if (ownCount < enemyCount) {
            title = @"Sorry";
            msg = @"You lost!";
        } else {
            title = @"Tie";
            msg = @"Match tied!";
        }

        alert = [[UIAlertView alloc] initWithTitle:title
                                           message:msg
                                          delegate:nil
                                 cancelButtonTitle:@"Dismiss"
                                 otherButtonTitles:nil];
        [alert show];
        [alert release];
        alert = nil;
    } else {
        NSLog(@"Game: still empty: %d", emptyCount);

        // pass if no square was filled
        if (!filledSquares) {
            switch (currentPlayer) {
                case kMarkP1:
                    currentPlayer = kMarkP2;
                    break;
                case kMarkP2:
                    currentPlayer = kMarkP1;
                    break;
                default:
                    break;
            }

            [self highlightCurrentPlayer];
        }
    }
}

- (void) showOptions
{
    NSString *nibName;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        nibName = @"OptionsView_iPad";
    } else {
        nibName = @"OptionsView_iPhone";
    }
    
    OptionsController *controller = [[OptionsController alloc] initWithNibName:nibName bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void) backToMenu
{
    // visible alert = disconnected already
    if (!alert) {

        // game is over, no need for confirmation
        if (gameOver) {
            [self quitGame];
        } else {
            alert = [[UIAlertView alloc] initWithTitle:@"Quit"
                                               message:@"Do you really want to quit?"
                                              delegate:self
                                     cancelButtonTitle:@"No"
                                     otherButtonTitles:@"Yes", nil];
            alert.tag = ALERT_QUIT;
            [alert show];
        }
    }
}

- (void) quitGame
{
    // disconnect if online match
    if (session) {
        [session disconnect];
    }
    
    // otherwise leave immediately
    else {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

#pragma mark - PeerGameDelegate

- (void) session:(PeerSession *)peerSession didReceivePacket:(NSData *)data
{
    // TODO read configuration from START packet (who starts, model size...)

    MarkItem item;
    [data getBytes:&item length:sizeof(MarkItem)];
    NSLog(@"Game: received item: (%d, %d), direction=%d", item.gx, item.gy, item.direction);

    [self handleAddedItem:&item];
}

- (void) peerDidDisconnect:(PeerSession *)peerSession
{
    if (alert.visible) {
        [alert dismissWithClickedButtonIndex:0 animated:NO];
        [alert release];
        alert = nil;
    }

    // show message on peer disconnection before match end
    if (!gameOver) {
        NSString *msg = [NSString stringWithFormat:@"%@ disconnected", [peerSession connectedPeerName]];
        alert = [[UIAlertView alloc] initWithTitle:@"Disconnection"
                                           message:msg
                                          delegate:nil
                                 cancelButtonTitle:@"OK"
                                 otherButtonTitles:nil];
        alert.tag = ALERT_DISCONNECTION;
        [alert show];
        [alert release];
        alert = nil;
    }
}

- (void) willDisconnect:(PeerSession *)peerSession
{
    if (appeared) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else {
        popLater = YES;
    }
}

#pragma mark - UIAlertViewDelegate

// quit confirmation
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
        case ALERT_QUIT:
            if (buttonIndex == 1) {
                [self quitGame];
            }
            break;
        case ALERT_DISCONNECTION:
            break;
    }
    [alert release];
    alert = nil; 
}

@end
