//
//  PeopleController.h
//  PenClose
//
//  Created by Davide De Rosa on 6/11/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PeerSession.h"

@interface PeopleController : UIViewController<UITableViewDataSource,
                                               UITableViewDelegate,
                                               PeerLobbyDelegate,
                                               UIAlertViewDelegate> {
    IBOutlet UITableView *peersView;
    UIAlertView *alert;

    PeerSession *session;
    NSMutableArray *peersList;
}

- (void) startMatchWithPeer:(NSString *)peerID;

@end
