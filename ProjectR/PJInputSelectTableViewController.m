//
//  PJInputSelectTableViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 8/8/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJInputSelectTableViewController.h"
#import "PJInputInfo.h"
#import "PJProjector.h"

@interface PJInputSelectTableViewController ()

@property(nonatomic,assign) NSInteger pendingSelectionIndex;

@end

@implementation PJInputSelectTableViewController

- (void)dealloc {
    [_projector removeObserver:self forKeyPath:@"activeInputIndex"];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _pendingSelectionIndex = -1;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.pendingSelectionIndex = -1;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)setProjector:(PJProjector *)projector {
    if (_projector != projector) {
        [_projector removeObserver:self forKeyPath:@"activeInputIndex"];
        _projector = projector;
        [_projector addObserver:self
                     forKeyPath:@"activeInputIndex"
                        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                        context:NULL];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.projector.inputs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"inputCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    PJInputInfo* inputInfo = [self.projector.inputs objectAtIndex:indexPath.row];
    cell.textLabel.text = [inputInfo description];

    // Determine what accessory view we want
    if (indexPath.row == self.projector.activeInputIndex) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if (indexPath.row == self.pendingSelectionIndex) {
        UIActivityIndicatorView* activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [activityView startAnimating];
        cell.accessoryView = activityView;
    } else {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // De-select the row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // Did we select a new row?
    if (indexPath.row != self.projector.activeInputIndex) {
        // Save the pending selection index
        self.pendingSelectionIndex = indexPath.row;
        // Request an input change to the projector
        [self.projector requestInputChangeToInputIndex:indexPath.row];
        // Reload this row
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - PJInputSelectTableViewController private methods

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"activeInputIndex"]) {
        NSInteger newValue = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        NSInteger oldValue = [[change objectForKey:NSKeyValueChangeOldKey] integerValue];
        if (newValue != oldValue) {
            self.pendingSelectionIndex = -1;
            NSArray* indexPathsToReload = @[[NSIndexPath indexPathForRow:oldValue inSection:0],
                                            [NSIndexPath indexPathForRow:newValue inSection:0]];
            [self.tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

@end
