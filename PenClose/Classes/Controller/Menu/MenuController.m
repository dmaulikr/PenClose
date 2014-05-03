//
//  MenuController.m
//  PenClose
//
//  Created by Davide De Rosa on 6/10/11.
//  Copyright 2011 algoritmico. All rights reserved.
//

#import "MenuController.h"
#import "GameController.h"
#import "PeopleController.h"
#import "OptionsController.h"

@implementation MenuController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
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
    [super viewDidLoad];

    menuItems = [[NSMutableArray alloc] init];
    [menuItems addObject:@"Side by Side"];
    [menuItems addObject:@"Look for Players"];
    //[menuItems addObject:@"People Online"];
    [menuItems addObject:@"Options"];

    menu.backgroundColor = [UIColor clearColor];
    menu.opaque = NO;
    menu.backgroundView = nil;
    menu.dataSource = self;
    menu.delegate = self;

    background = [[KSSheetView alloc] initWithFrame:self.view.frame];
    //background.alpha = 0.5;
    [self.view addSubview:background];
    [self.view sendSubviewToBack:background];

    // for launch images?
    //NSLog(@"cellSize = %d", background.cellSize);
    //NSLog(@"offset = %@", NSStringFromCGPoint(background.offset));
}

- (void) viewWillAppear:(BOOL)animated
{
    self.navigationController.navigationBarHidden = YES;
}

- (void) viewWillDisappear:(BOOL)animated
{
    self.navigationController.navigationBarHidden = NO;
}

- (void) viewDidUnload
{
    [background release];
    [menu release];
    [menuItems release];
    [website release];
    background = nil;
    menu = nil;
    menuItems = nil;
    website = nil;

    [super viewDidUnload];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) dealloc
{
    [background release];
    [menu release];
    [menuItems release];

    [super dealloc];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{    
    static NSString *identifier = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identifier] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSString *cellValue = [menuItems objectAtIndex:indexPath.row];
    cell.textLabel.text = cellValue;
    return cell;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [menuItems count];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Menu: didSelectRowAtIndexPath");

    const NSUInteger row = [indexPath row];
    switch (row) {
        case 0:
            [self playSolo];
            break;
        case 1:
            [self peopleAround];
            break;
        case 2:
            [self showOptions];
            break;
        default:
            break;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - Menu actions

- (void) playSolo
{
    NSString *nibName;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        nibName = @"GameView_iPad";
    } else {
        nibName = @"GameView_iPhone";
    }

    GameController *controller = [[GameController alloc] initWithNibName:nibName bundle:nil];
    [controller preparePlayersWithSession:nil];

    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void) peopleAround
{
    NSString *nibName;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        nibName = @"PeopleView_iPad";
    } else {
        nibName = @"PeopleView_iPhone";
    }

    PeopleController *controller = [[PeopleController alloc] initWithNibName:nibName bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void) peopleOnline
{
    // TODO unimplemented
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

- (IBAction) visitWebsite
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:website.titleLabel.text]];
}

@end
