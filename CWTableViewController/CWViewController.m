//
//  CWViewController.m
//  CWTableViewController
//
//  Created by ly on 14-1-9.
//  Copyright (c) 2014年 ly. All rights reserved.
//

#import "CWViewController.h"
#import <LXHRefreshTableHeaderView.h>

@interface CWViewController ()

@end

@implementation CWViewController

#pragma mark - Pull refresh delegate

- (void)refreshHeaderViewDidTriggerRefresh:(CWRefreshTableHeaderView*)view
{
    [self performSelector:@selector(stopRefresh) withObject:nil afterDelay:2.0];
}


#pragma mark - Table view datasource and delegate

- (Class)classOfTableViewCell
{
    return [UITableViewCell class];
}

- (CGFloat)heightOfCellAtIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView
{
    return 44.0;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    cell.textLabel.text = [NSString stringWithFormat:@"%d", indexPath.row];
}

- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}


#pragma mark - Loading More

- (void)tableViewDidStartLoadingMore
{
    [self performSelector:@selector(stopLoadingMore) withObject:nil afterDelay:2.0];
}

- (void)tableViewDidStopLoadingMore
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)didSelectLoadingMoreCellForTableView:(UITableView *)tableView
{
    [self startLoadingMore];
    
    [self performSelector:@selector(stopLoadingMore) withObject:nil afterDelay:2.0];
}


#pragma mark - Property

- (CWRefreshTableHeaderView *)refreshHeaderView
{
    if ( _refreshHeaderView == nil ) {
        UIImage  *placeholder = [UIImage imageNamed:@"pull_refresh_logo"];
        UIImage *animationImage = [UIImage imageNamed:@"fan"];
        _refreshHeaderView = [[LXHRefreshTableHeaderView alloc] initWithPlaceholder:placeholder animationImage:animationImage];
    }
    return _refreshHeaderView;
}


@end
