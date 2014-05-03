//
//  PeerSession.m
//  PenClose
//
//  Created by Davide De Rosa on 6/11/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import "PeerSession.h"

@implementation PeerSession

@synthesize state;
@synthesize availablePeers;
@synthesize connectedPeerID;

@synthesize isInitiator = initiator;

@synthesize lobbyDelegate;
@synthesize gameDelegate;

#pragma mark - init/dealloc

- (id) initWithSessionID:(NSString *)aSessionID
{
    if ((self = [super init])) {
        sessionID = [aSessionID retain];
        state = SessionStateDisconnected;

        // listen to global notifications
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        // termination works everywhere
        [nc addObserver:self
               selector:@selector(applicationWillTerminate:)
                   name:UIApplicationWillTerminateNotification
                 object:nil];

        // these ones require multitasking
        UIDevice *currentDevice = [UIDevice currentDevice];
        if ([currentDevice respondsToSelector:@selector(isMultitaskingSupported)] && [currentDevice isMultitaskingSupported]) {
            [nc addObserver:self
                   selector:@selector(applicationDidEnterBackground:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
            [nc addObserver:self
                   selector:@selector(applicationWillEnterForeground:)
                       name:UIApplicationWillEnterForegroundNotification
                     object:nil];
        }
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"PeerSession: dealloc");

    [self stop];
    [sessionID release];

    // stop listening
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];

    [super dealloc];
}

#pragma mark - Public interface

- (void) start
{
    availablePeers = [[NSMutableArray alloc] init];
    gks = [[GKSession alloc] initWithSessionID:sessionID
                                   displayName:nil
                                   sessionMode:GKSessionModePeer];
    gks.delegate = self;
    [gks setDataReceiveHandler:self withContext:nil];
    gks.available = YES;
}

- (void) connect:(NSString *)peerID
{
    // did invite
    initiator = YES;

    [gks connectToPeer:peerID withTimeout:10.0];
    connectedPeerID = [peerID retain];
    state = SessionStateConnecting;
}

- (BOOL) acceptInvitation
{
    NSError *error = nil;
    if (![gks acceptConnectionFromPeer:connectedPeerID error:&error]) {
        NSLog(@"PeerSession: acceptInvitation (error = '%@')", [error localizedDescription]);
        return NO;
    }

    // was invited
    initiator = NO;

    return YES;
}

- (void) sendPacket:(NSData *)data
{
    if (connectedPeerID) {
        NSError *error;
        if (![gks sendData:data
                   toPeers:[NSArray arrayWithObject:connectedPeerID]
              withDataMode:GKSendDataReliable
                     error:&error]) {

            NSLog(@"PeerSession: sendPacket (error = '%@')", [error localizedDescription]);
        }
    }
}

- (void) declineInvitation
{
    [gks denyConnectionFromPeer:connectedPeerID];
    [connectedPeerID release];
    connectedPeerID = nil;
    state = SessionStateDisconnected;
}

- (void) disconnect
{
    if (state != SessionStateDisconnected) {

        // cancel pending connection
        if (state == SessionStateConnecting) {
            [gks cancelConnectToPeer:connectedPeerID];
        }

        // close active game
        else if (state == SessionStateConnected) {
            [gameDelegate willDisconnect:self];
        }

        // forget connected peer
        [connectedPeerID release];
        connectedPeerID = nil;

        // available for next connection
        [gks disconnectFromAllPeers];
        gks.available = YES;
        state = SessionStateDisconnected;
    }
}

- (void) stop
{
    if (gks) {
        [self disconnect];

        [gks setDataReceiveHandler:nil withContext:nil];
        gks.delegate = nil;
        [gks release];
        gks = nil;
        [availablePeers release];
        availablePeers = nil;
    }
}

- (NSString *) displayNameForPeer:(NSString *)peerID
{
    return [gks displayNameForPeer:peerID];
}

- (NSString *) connectedPeerName
{
    return [gks displayNameForPeer:connectedPeerID];
}

#pragma mark - Application notifications

- (void) applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"PeerSession: applicationDidEnterBackground");
    [self stop];
}

- (void) applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"PeerSession: applicationDidEnterForeground");
    [self start];
}

- (void) applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"PeerSession: applicationWillTerminate");
    [self stop];
}

#pragma mark - GKSessionDelegate

- (void) session:(GKSession *)aSession peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)peerState
{
    switch (peerState) { 
        case GKPeerStateAvailable:
            if (![availablePeers containsObject:peerID]) {
                NSLog(@"PeerSession: added '%@'", peerID);
                [availablePeers addObject:peerID];
                [lobbyDelegate connectedPeersDidChange:self];
            }
            break;
        case GKPeerStateUnavailable:
            NSLog(@"PeerSession: removed '%@' (unavailable)", peerID);
            [availablePeers removeObject:peerID];
            [lobbyDelegate connectedPeersDidChange:self];
            break;
        case GKPeerStateConnecting:
            NSLog(@"PeerSession: connecting '%@'", peerID);
            break;
        case GKPeerStateConnected:
            NSLog(@"PeerSession: connected '%@'", peerID);
            gks.available = NO;
            state = SessionStateConnected;
            [lobbyDelegate peerDidAcceptInvitation:self];
            break;
        case GKPeerStateDisconnected:
            NSLog(@"PeerSession: removed '%@' (disconnected)", peerID);

            // raise additional event if remote disconnected
            if ([peerID isEqualToString:connectedPeerID]) {
                [gameDelegate peerDidDisconnect:self];
            }

            [self disconnect];
            [availablePeers removeObject:peerID];
            [lobbyDelegate connectedPeersDidChange:self];
            break;
        default:
            break;
    }
}

- (void) session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID
{
    // deny if connecting or connected
    if (connectedPeerID) {
        [gks denyConnectionFromPeer:peerID];
    } else {
        connectedPeerID = [peerID retain];
        state = SessionStateConnecting;
        [lobbyDelegate didReceiveInvitation:self fromPeer:[gks displayNameForPeer:peerID]];
    }
}

- (void) session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error
{
    NSLog(@"PeerSession: connectionWithPeerFailed (error = '%@')", [error localizedDescription]);
    if (state != SessionStateDisconnected) {
        [lobbyDelegate invitationDidFail:self fromPeer:[gks displayNameForPeer:peerID]];

        // accept new connections
        [connectedPeerID release];
        connectedPeerID = nil;
        gks.available = YES;
        state = SessionStateDisconnected;
    }
}

- (void) session:(GKSession *)session didFailWithError:(NSError*)error
{
    NSLog(@"PeerSession: didFailWithError (error = '%@')", [error localizedDescription]);
    [self disconnect];
}

#pragma mark - GKSession data receive handler

- (void) receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)gkSession context:(void *)context
{
    [gameDelegate session:self didReceivePacket:data];
}

@end
