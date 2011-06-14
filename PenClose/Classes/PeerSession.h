//
//  PeerSession.h
//  PenClose
//
//  Created by Davide De Rosa on 6/11/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

@protocol PeerLobbyDelegate;
@protocol PeerGameDelegate;

typedef enum {
    SessionStateDisconnected,
    SessionStateConnecting,
    SessionStateConnected
} SessionState;

@interface PeerSession : NSObject<GKSessionDelegate> {
    NSString *sessionID;
    GKSession *gks;
    SessionState state;
    NSMutableArray *availablePeers;
    NSString *connectedPeerID;

    BOOL initiator;

    id<PeerLobbyDelegate> lobbyDelegate;
    id<PeerGameDelegate> gameDelegate;
}

@property (nonatomic, readonly) SessionState state;
@property (nonatomic, readonly) NSArray *availablePeers;
@property (nonatomic, readonly) NSString *connectedPeerID;

@property (nonatomic, readonly) BOOL isInitiator;

@property (nonatomic, assign) id<PeerLobbyDelegate> lobbyDelegate;
@property (nonatomic, assign) id<PeerGameDelegate> gameDelegate;

- (id) initWithSessionID:(NSString *)aSessionID;

- (void) start;
- (void) connect:(NSString *)peerID;
- (BOOL) acceptInvitation;
- (void) declineInvitation;
- (void) sendPacket:(NSData *)data;
- (void) disconnect;
- (void) stop;
- (NSString *) displayNameForPeer:(NSString *)peerID;
- (NSString *) connectedPeerName;

@end

@protocol PeerLobbyDelegate

- (void) connectedPeersDidChange:(PeerSession *)peerSession;
- (void) didReceiveInvitation:(PeerSession *)peerSession fromPeer:(NSString *)peerName;
- (void) invitationDidFail:(PeerSession *)peerSession fromPeer:(NSString *)peerName;
- (void) peerDidAcceptInvitation:(PeerSession *)peerSession;

@end

@protocol PeerGameDelegate

- (void) session:(PeerSession *)peerSession didReceivePacket:(NSData *)data;
- (void) peerDidDisconnect:(PeerSession *)peerSession;
- (void) willDisconnect:(PeerSession *)peerSession;

@end
