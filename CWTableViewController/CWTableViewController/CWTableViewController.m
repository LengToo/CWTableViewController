//
//  CWTableViewController.m
//  lengtucao
//
//  Created by ly on 13-12-20.
//  Copyright (c) 2013年 ly. All rights reserved.
//

#import "CWTableViewController.h"
#import "CWRefreshTableHeaderView.h"
#import "SDImageCache.h"
#import "SDWebImageDownloader.h"

#if DEBUG_CWTableViewController
#define DEBUG_NUM_OF_ROWS       10
#endif

static NSString *identifier = @"Cell Identifier";

@interface CWTableViewController () <CWRefreshTableHeaderDelegate>

@end

@implementation CWTableViewController
{
    BOOL isLoading;
}

#pragma mark - Life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self cw_initializeVariables];
    [self cw_initializeTableView];
}

- (void)cw_initializeVariables
{
    self.allowLoadingMore = NO;
    self.loadingMoreCellHeight = 44.0;
}

- (void)cw_initializeTableView
{
    [self.view addSubview:self.tableView];
    [self.tableView addSubview:self.refreshHeaderView];
    
    [self.tableView registerClass:[self classOfTableViewCell] forCellReuseIdentifier:identifier];
    self.refreshHeaderView.delegate = self;
}


#pragma mark - Layout

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGFloat w = CGRectGetWidth(self.view.frame);
    CGFloat h = CGRectGetHeight(self.view.frame);
    self.tableView.frame = CGRectMake(0, 0, w, h);
}

- (void)viewDidLayoutSubviews
{
    CGFloat w = CGRectGetWidth(self.view.frame);
    UIEdgeInsets edgeInsets = self.tableView.contentInset;
    
    self.refreshHeaderView.frame = CGRectMake(0, -300 - edgeInsets.top, w, 300);
}


#pragma mark - Table view datasource and delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSUInteger count = 0;
    
#if DEBUG_CWTableViewController
    count = DEBUG_NUM_OF_ROWS;
#else
    count = [[self.fetchedResultController fetchedObjects] count];
#endif
    
    if ( self.allowLoadingMore && (count > 0) ) {
        return (count + 1); // 加载更多
    }
    return count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 加载更多 cell
    if (self.allowLoadingMore)
    {
        NSUInteger count = 0;
        
#if DEBUG_CWTableViewController
        count = DEBUG_NUM_OF_ROWS;
#else
        count = [[self.fetchedResultController fetchedObjects] count];
#endif
        
        if ( (NSUInteger)indexPath.row == count ) {
            return self.loadingMoreCellHeight;
        }
    }
    
    // 正常的 cell
    CGFloat height = [self heightOfCellAtIndexPath:indexPath forTableView:tableView];
    
    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    NSInteger count = 0;
    
#if DEBUG_CWTableViewController
    count = DEBUG_NUM_OF_ROWS;
#else
    count = [[self.fetchedResultController fetchedObjects] count];
#endif
    
    if ((NSUInteger)indexPath.row == count)
    {
        if (self.allowLoadingMore)
        {
            cell = self.loadingMoreCell;
        }    
    }
    else
    {
        cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        [self configureCell:cell atIndexPath:indexPath];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.allowLoadingMore)
    {
        NSInteger count = 0;
        
#if DEBUG_CWTableViewController
        count = DEBUG_NUM_OF_ROWS;
#else
        count = [[self.fetchedResultController fetchedObjects] count];
#endif
        
        // 加载更多
        if ((NSUInteger)indexPath.row == count)
        {
            [self didSelectLoadingMoreCellForTableView:tableView];
            return;
        }
    }
    
    [self didSelectRowAtIndexPath:indexPath forTableView:tableView];
}


#pragma mark - Loading more

- (void)startLoadingMore
{
    if ([self.loadingMoreCell respondsToSelector:@selector(startAnimating)]) {
        [(id)self.loadingMoreCell startAnimating];
    }
    [self tableViewDidStartLoadingMore];
}

- (void)stopLoadingMore
{
    if ([self.loadingMoreCell respondsToSelector:@selector(stopAnimating)]) {
        [(id)self.loadingMoreCell stopAnimating];
    }
    [self tableViewDidStopLoadingMore];
}


#pragma mark - Lazy loading

- (void)lazyLoadingImage:(NSURL *)imgURL atIndexPath:(NSIndexPath *)indexPath withCompletionBlock:(void (^)(UIImage *image, BOOL isPlaceholder))block
{
    UIImage *cachedImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:[imgURL absoluteString]];
    
    if ( !cachedImage )
    {
        if ( !self.tableView.dragging && !self.tableView.decelerating ) {
            [self downloadImage:imgURL forIndexPath:indexPath];
        }
        
        block(self.placeholder, YES);
    } else {
        block(cachedImage, NO);
    }
}

- (void)downloadImage:(NSURL *)imgURL forIndexPath:(NSIndexPath *)indexPath
{
    __weak id target = self;
    
    [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:imgURL
    options:SDWebImageDownloaderUseNSURLCache
    progress:^(NSUInteger receivedSize, long long expectedSize) {
        // Do nothing
    }
    completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {

        // 保存图片
        [[SDImageCache sharedImageCache] storeImage:image forKey:[imgURL absoluteString] toDisk:YES];

        // 延迟在主线程更新 cell 的高度
        [target performSelectorOnMainThread:@selector(reloadCellAtIndexPath:)
                             withObject:indexPath waitUntilDone:NO];
    }];
}

- (void)loadImageForOnScreenRows
{
    NSArray *visiableIndexPathes = [self.tableView indexPathsForVisibleRows];
    
    for (NSIndexPath *indexPath in visiableIndexPathes)
    {
        NSURL *imgURL = [self imageURLAtIndexPath:indexPath];
        [self downloadImage:imgURL forIndexPath:indexPath];
    }
}

- (void)reloadCellAtIndexPath:(NSIndexPath *)indexPath
{
    /* 
     * 如果 indexPath 当前可见，则立即刷新数据
     */
    
    NSArray *indexPaths = [self.tableView indexPathsForVisibleRows];
    
    for (NSIndexPath *aIndexPath in indexPaths)
    {
        if (aIndexPath.row == indexPath.row)
        {
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            return;
        }
    }
}

- (void)reloadVisiableCells
{
    NSArray *indexPaths = [self.tableView indexPathsForVisibleRows];
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}


#pragma mark - Scroll view delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.refreshHeaderView cwRefreshScrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self.refreshHeaderView cwRefreshScrollViewDidEndDragging:scrollView];
    
    if (!decelerate) {
        [self loadImageForOnScreenRows];
    }
    
    // 触发加载更多事件
    if (self.allowLoadingMore)
    {
        CGFloat threshold = 20.0;
        CGFloat OffsetY = scrollView.contentOffset.y + CGRectGetHeight(scrollView.frame) - threshold;
        
        if (OffsetY > scrollView.contentSize.height)
        {
            // 开始加载更多
            [self startLoadingMore];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self loadImageForOnScreenRows];
}

#pragma mark - Pull refresh delegate
- (void)cwRefreshTableHeaderDidTriggerRefresh:(CWRefreshTableHeaderView *)view
{
    isLoading = YES;
    [self refreshHeaderViewDidTriggerRefresh:view];
}

- (BOOL)cwRefreshTableHeaderDataSourceIsLoading:(CWRefreshTableHeaderView *)view
{
    return isLoading;
}

- (NSDate*)cwRefreshTableHeaderDataSourceLastUpdated:(CWRefreshTableHeaderView *)view
{
    return [NSDate date];
}

- (void)stopRefresh
{
    isLoading = NO;
    [self.refreshHeaderView cwRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
}

#pragma mark - Subclass overwriting

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
    
}

- (void)didSelectLoadingMoreCellForTableView:(UITableView *)tableView
{
    
}

- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView
{
    
}

- (NSURL *)imageURLAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (void)refreshHeaderViewDidTriggerRefresh:(CWRefreshTableHeaderView*)view
{
    
}

- (void)tableViewDidStartLoadingMore
{
    
}

- (void)tableViewDidStopLoadingMore
{
    
}

- (void)onLoadingMore
{
    
}


#pragma mark - Property

- (UITableView *)tableView
{
    if ( _tableView == nil ) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _tableView;
}

- (CWRefreshTableHeaderView *)refreshHeaderView
{
    if ( _refreshHeaderView == nil ) {
        _refreshHeaderView = [[CWRefreshTableHeaderView alloc] init];
    }
    return _refreshHeaderView;
}

- (UITableViewCell *)loadingMoreCell
{
    if ( _loadingMoreCell == nil ) {
        _loadingMoreCell = [[UITableViewCell alloc] init];
    }
    return _loadingMoreCell;
}

@end
