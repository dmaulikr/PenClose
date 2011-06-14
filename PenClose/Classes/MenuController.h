//
//  MenuController.h
//  PenClose
//
//  Created by Davide De Rosa on 6/10/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SheetView.h"

@interface MenuController : UIViewController<UITableViewDataSource, UITableViewDelegate> {
    IBOutlet UITableView *menu;
    IBOutlet UIButton *website;
    SheetView *background;

    NSMutableArray *menuItems;
}

- (void) playSolo;
- (void) peopleAround;
- (void) peopleOnline;
- (void) showOptions;
- (IBAction) visitWebsite;

@end
