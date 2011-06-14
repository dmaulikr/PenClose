//
//  PeersViewController.m
//  PenClose
//
//  Created by Davide De Rosa on 6/11/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import "PeopleController.h"
#import "GameController.h"

#define SESSION_ID                  @"PenCloseOnline"

#define ALERT_INVITATION            1
#define ALERT_WAITING               2
#define ALERT_REFUSED               3
#define ALERT_DISCONNECTED          4

@implementation PeopleController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.title = @"People";

        NSLog(@"People: initWithNibName");

        // network session initialization
        session = [[PeerSession alloc] initWithSessionID:SESSION_ID];
        session.lobbyDelegate = self;

        // multitasking notifications
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        UIDevice *currentDevice = [UIDevice currentDevice];
        if ([currentDevice respondsToSelector:@selector(isMultitaskingSupported)] && [currentDevice isMultitaskingSupported]) {
            [nc addObserver:self
                   selector:@selector(applicationDidEnterBackground:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
        }
    }
    return self;
}

- (void) didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - Application notifications

- (void) applicationDidEnterBackground:(BOOL)animated
{
    NSLog(@"People: applicationDidEnterBackground (%@)", alert);

    // dismiss any pending alert
    if (alert) {
        [alert dismissWithClickedButtonIndex:0 animated:NO];
        [alert release];
        alert = nil;
    }
}

#pragma mark - View lifecycle

- (void) viewDidLoad
{
    NSLog(@"People: viewDidLoad");
    [super viewDidLoad];

    // declare controller as peers view data source and delegate
    peersView.dataSource = self;
    peersView.delegate = self;

    // start session and load available peers
    [session start];    
    peersList = [[NSMutableArray alloc] initWithArray:session.availablePeers];
    //peersList = [[NSArray alloc] initWithObjects:@"Uno", @"Due", @"Tre", nil];
}

- (void) viewDidUnload
{
    NSLog(@"People: viewDidUnload");

    [session stop];

    [peersView release];
    [peersList release];
    peersView = nil;
    peersList = nil;

    [super viewDidUnload];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) dealloc
{
    NSLog(@"People: dealloc");

    // possibly nil here
    [session release];

    if (alert.visible) {
        [alert dismissWithClickedButtonIndex:0 animated:NO];
        [alert release];
        alert = nil;
    }

    [peersList release];

    [super dealloc];
}

#pragma mark - Actions

- (void) startMatchWithPeer:(NSString *)peerID
{
    NSString *nibName;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        nibName = @"GameView_iPad";
    } else {
        nibName = @"GameView_iPhone";
    }

    // stop listening to session events
    session.lobbyDelegate = nil;

    // give session ownership to game controller
    GameController *gameController = [[GameController alloc] initWithNibName:nibName bundle:nil];
    [gameController preparePlayersWithSession:session];
    [session release];
    session = nil;

    // show game view
    [self.navigationController pushViewController:gameController animated:YES];
    [gameController release];
}

#pragma mark - UITableViewDataSource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [peersList count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"People: cellForRowAtIndexPath(%d)", [indexPath row]);

    static NSString *identifier = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero
                                       reuseIdentifier:identifier] autorelease];
    }

    const NSUInteger row = [indexPath row];
    cell.textLabel.text = [session displayNameForPeer:[peersList objectAtIndex:row]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"People: didSelectRowAtIndexPath");

    const NSUInteger row = [indexPath row];
    NSString *peerID = [peersList objectAtIndex:row];
    NSLog(@"People: selected %d (%@)", [indexPath row], [session displayNameForPeer:peerID]);
    //NSLog(@"People: selected %d (%@)", [indexPath row], peerID);

    // send invitation
    [session connect:peerID];

    // always invisible
    alert = [[UIAlertView alloc] initWithTitle:@"Invitation"
                                           message:@"Waiting for connection..."
                                          delegate:self
                                 cancelButtonTitle:@"Cancel"
                                 otherButtonTitles:nil];
    alert.tag = ALERT_WAITING;
    [alert show];
}

#pragma mark - PeerLobbyDelegate

- (void) connectedPeersDidChange:(PeerSession *)peerSession
{
    NSArray *oldPeersList = peersList;
    peersList = [peerSession.availablePeers copy];
    [oldPeersList release];
    [peersView reloadData]; 
}

- (void) didReceiveInvitation:(PeerSession *)peerSession fromPeer:(NSString *)peerName
{
    NSLog(@"People: didReceiveInvitation (from '%@')", peerName);

    if (alert.visible) {
        [alert dismissWithClickedButtonIndex:0 animated:NO];
        [alert release];
    }
    NSString *msg = [NSString stringWithFormat:@"%@ wants to play with you", peerName];

    alert = [[UIAlertView alloc] initWithTitle:@"Invitation"
                                           message:msg
                                          delegate:self
                                 cancelButtonTitle:@"Decline"
                                 otherButtonTitles:nil];
    [alert addButtonWithTitle:@"Accept"];
    alert.tag = ALERT_INVITATION;
    [alert show];
}

- (void) invitationDidFail:(PeerSession *)peerSession fromPeer:(NSString *)peerName
{
    NSLog(@"People: invitationDidFail (from '%@')", peerName);

    // save tag
    NSInteger tag = alert.tag;

    // an alert view is always a visible at this point
    [alert dismissWithClickedButtonIndex:0 animated:NO];
    [alert release];

    NSString *msgFormat;
    if (tag == ALERT_INVITATION) {
        msgFormat = @"%@ cancelled invitation";
    } else {
        msgFormat = @"%@ declined your invitation";
    }

    // do nothing on dismiss
    alert = [[UIAlertView alloc] initWithTitle:@"Invitation"
                                           message:[NSString stringWithFormat:msgFormat, peerName]
                                          delegate:nil
                                 cancelButtonTitle:@"OK"
                                 otherButtonTitles:nil];
    alert.tag = ALERT_REFUSED;
    [alert show];
}

- (void) peerDidAcceptInvitation:(PeerSession *)peerSession
{
    // dismiss waiting alert view
    if (alert.visible) {
        [alert dismissWithClickedButtonIndex:0 animated:NO];
        [alert release];
        alert = nil;
    }

    // start playing
    [self startMatchWithPeer:session.connectedPeerID];
}

#pragma mark - UIAlertViewDelegate

- (void) alertView:(UIAlertView *)aAlertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (aAlertView.tag) {
        case ALERT_INVITATION:
            if (buttonIndex == 1) {
                if ([session acceptInvitation]) {
                    //[self startMatchWithPeer:session.connectedPeerID];
                }
            } else {
                [session declineInvitation];
            }
            break;
        case ALERT_WAITING:

            // only disconnect a connection is pending
            if (session.state == SessionStateConnecting) {
                [session disconnect];
            }
            break;
        default:
            break;
    }
    [alert release];
    alert = nil;
}

@end
