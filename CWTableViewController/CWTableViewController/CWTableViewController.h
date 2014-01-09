

//
//  CWTableViewController.h
//  lengtucao
//
//  Created by ly on 13-12-20.
//  Copyright (c) 2013年 ly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CWRefreshTableHeaderView;
@interface CWTableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
    UITableView *_tableView;
    UITableViewCell *_loadingMoreCell;
    CWRefreshTableHeaderView *_refreshHeaderView;
    
    NSFetchedResultsController *_fetchedResultController;
}

@property (strong, nonatomic) UITableView *tableView;

@property (strong, nonatomic) CWRefreshTableHeaderView *refreshHeaderView;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultController;

/** Default: NO */
@property (assign, nonatomic) BOOL allowLoadingMore;

/** Default：44.0 */
@property (assign, nonatomic) CGFloat loadingMoreCellHeight;

/** 加载更多的 cell  */
@property (strong, nonatomic) UITableViewCell *loadingMoreCell;

/** 异步加载时的占位图 */
@property (strong, nonatomic) UIImage *placeholder;


#pragma mark -  Table view
- (Class)classOfTableViewCell;
- (CGFloat)heightOfCellAtIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)didSelectLoadingMoreCellForTableView:(UITableView *)tableView;
- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView;
- (void)reloadVisiableCells;


#pragma mark - Loading more
- (void)onLoadingMore;
/** 开始加载更多 */
- (void)tableViewDidStartLoadingMore;
/** 结束加载更多 */
- (void)tableViewDidStopLoadingMore;
- (void)startLoadingMore;
- (void)stopLoadingMore;


#pragma mark - Lazy loading image
- (void)lazyLoadingImage:(NSURL *)imgURL atIndexPath:(NSIndexPath *)indexPath withCompletionBlock:(void (^)(UIImage *image, BOOL isPlaceholder))block;
- (NSURL *)imageURLAtIndexPath:(NSIndexPath *)indexPath;


#pragma mark - Pull refresh
- (void)stopRefresh;
- (void)refreshHeaderViewDidTriggerRefresh:(CWRefreshTableHeaderView *)view;


#pragma mark - Scroll view delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

@end
