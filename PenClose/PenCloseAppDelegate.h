//
//  PenCloseAppDelegate.h
//  PenClose
//
//  Created by Davide De Rosa on 6/9/11.
//  Copyright 2011 Davide De Rosa. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PenCloseAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@end
