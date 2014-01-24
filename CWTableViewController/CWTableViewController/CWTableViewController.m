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
#import <NSString+MD5.h>

#if DEBUG_CWTableViewController
#define DEBUG_NUM_OF_ROWS       100
#endif

static NSString *identifier = @"Cell Identifier";

@interface CWTableViewController () <CWRefreshTableHeaderDelegate>

@property (strong, atomic, readonly) NSMutableSet *finishLoadedImageURLs;

@end

@implementation CWTableViewController
{
    BOOL isLoading;
    NSMutableSet *_finishLoadedImageURLs;
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
    _showDebugInfo = NO;
    _usingEstimatedRowHeight = NO;
    
    self.estimatedRowHeight = 44.0;
    self.allowLoadingMore = NO;
    self.loadingMoreCellHeight = 44.0;
    self.allowLazyLoading = YES;
    
    _finishLoadedImageURLs = [NSMutableSet setWithCapacity:100];
}

- (void)cw_initializeTableView
{
    [self.view addSubview:self.tableView];
    [self.tableView addSubview:self.refreshHeaderView];
    
    [self.tableView registerClass:[self classOfTableViewCell] forCellReuseIdentifier:identifier];
    self.refreshHeaderView.delegate = self;
}

- (void)setUsingEstimatedRowHeight:(BOOL)usingEstimatedRowHeight
{
    _usingEstimatedRowHeight = usingEstimatedRowHeight;
    
    if (_usingEstimatedRowHeight && [self.tableView respondsToSelector:@selector(setEstimatedRowHeight:)]) {
        [self.tableView setEstimatedRowHeight:self.estimatedRowHeight];
    }
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

- (void)lazyLoadingImage:(NSURL *)imgURL atIndexPath:(NSIndexPath *)indexPath
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        UIImage *cachedImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:[[imgURL absoluteString] MD5Digest]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            id cell = [self.tableView cellForRowAtIndexPath:indexPath];
            
            if ( !cachedImage )
            {
                if ( !self.tableView.dragging && !self.tableView.decelerating ) {
                    [self downloadImage:imgURL forIndexPath:indexPath];
                }
                
                if (cell) {
                    self.cwLazyLoadingImageCompleteBlock(cell, self.placeholder, YES);
                }
            } else {
                if (cell) {
                    self.cwLazyLoadingImageCompleteBlock(cell, cachedImage, NO);
                }
            }
        });
    });
}

- (void)downloadImage:(NSURL *)imgURL forIndexPath:(NSIndexPath *)indexPath
{
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // 每个图片链接只下载一次，失败后也重复尝试
        NSString *key = [[imgURL absoluteString] MD5Digest];
        if ([[self finishLoadedImageURLs] containsObject:key]) {
            return;
        }
        
        [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:imgURL
        options:SDWebImageDownloaderUseNSURLCache
        progress:^(NSUInteger receivedSize, long long expectedSize) {
            // Do nothing
        }
        completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
            
            if (!finished || error) {
                return;
            }
            
            // 保存图片
            [[SDImageCache sharedImageCache] storeImage:image forKey:[[imgURL absoluteString] MD5Digest] toDisk:YES];
            
            // 在主线程更新 cell 的高度
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(weakSelf) strongSelf = weakSelf;
                LazyLoadingImageCompleteBlockType block = [weakSelf cwLazyLoadingImageCompleteBlock];
                
                id cell = [[strongSelf tableView] cellForRowAtIndexPath:indexPath];
                if (cell && block) {
                    block(cell, image, NO);
                }
            });
        }];
    });
}

- (void)downloadImageForOnScreenRows
{
    NSArray *visiableIndexPathes = [self.tableView indexPathsForVisibleRows];
    
    for (NSIndexPath *indexPath in visiableIndexPathes)
    {
        @autoreleasepool {
            @try {
                NSURL *imgURL = [self imageURLAtIndexPath:indexPath];
                [self downloadImage:imgURL forIndexPath:indexPath];
            }
            @catch (NSException *exception) {
                if (self.showDebugInfo) {
                    NSLog(@"%@", exception);
                }
            }
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
    
    if (self.allowLazyLoading && !decelerate) {
        [self downloadImageForOnScreenRows];
    }
    
    // 触发加载更多事件
    if (self.allowLoadingMore)
    {
        CGFloat threshold = 20.0;
        CGFloat OffsetY = scrollView.contentOffset.y + CGRectGetHeight(scrollView.frame) - threshold;
        
        if (OffsetY > scrollView.contentSize.height)
        {
            if (![self canTriggerLoadingMore]) {
                return;
            }
            // 开始加载更多
            [self startLoadingMore];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (self.allowLazyLoading) {
        [self downloadImageForOnScreenRows];
    }
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
    [NSException raise:@"Invalidate Calling"
                format:@"Subclass <%@> should overwrite this method!", NSStringFromClass([self class])];
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

- (BOOL)canTriggerLoadingMore
{
    return YES;
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
        _tableView.delegate   = self;
        _tableView.backgroundColor  = [UIColor clearColor];
        _tableView.separatorStyle   = UITableViewCellSeparatorStyleNone;
        _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
