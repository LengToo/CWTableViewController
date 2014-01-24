

//
//  CWTableViewController.h
//  lengtucao
//
//  Created by ly on 13-12-20.
//  Copyright (c) 2013年 ly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

typedef void (^LazyLoadingImageCompleteBlockType)(UITableViewCell *tableCell, UIImage *image, BOOL isPlaceholder);

@class CWRefreshTableHeaderView;
@interface CWTableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
    UITableView *_tableView;
    UITableViewCell *_loadingMoreCell;
    CWRefreshTableHeaderView *_refreshHeaderView;
    
    NSFetchedResultsController *_fetchedResultController;
}

@property (strong, nonatomic) UITableView *tableView;

/** 下拉刷新视图 
 @discussion 子类应该覆盖 getter 方法返回具体的下拉刷新视图
 */
@property (strong, nonatomic) CWRefreshTableHeaderView *refreshHeaderView;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultController;

/** Estimated row height */
@property (assign, nonatomic) CGFloat estimatedRowHeight NS_AVAILABLE_IOS(7_0);

@property (assign, nonatomic) BOOL usingEstimatedRowHeight;

/** Allow lazy loading, default is YES */
@property (assign, nonatomic) BOOL allowLazyLoading;

/** Lazy loading complete call back 
 @discussion 为了性能和内存占用优化暂时延迟加载的完成回调使用统一的block。子类在实现时需要设置 block，block 使用 copy。
 */
@property (copy, nonatomic) LazyLoadingImageCompleteBlockType cwLazyLoadingImageCompleteBlock;

/** Default: NO */
@property (assign, nonatomic) BOOL allowLoadingMore;

/** Default：44.0 */
@property (assign, nonatomic) CGFloat loadingMoreCellHeight;

/** 加载更多的 cell  */
@property (strong, nonatomic) UITableViewCell *loadingMoreCell;

/** 异步加载时的占位图 */
@property (strong, nonatomic) UIImage *placeholder;

/** 是否显示调试的信息
 @discussion 默认为 NO， 调试时可以打开此开关
 */
@property (assign, nonatomic) BOOL showDebugInfo;


#pragma mark -  Table view
- (Class)classOfTableViewCell;
- (CGFloat)heightOfCellAtIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)didSelectLoadingMoreCellForTableView:(UITableView *)tableView;
- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView;

// 单独调用此方法性能损耗非常大，如果只是要更新 cell 中的数据，不涉及行高的改变
// 建议使用 - (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath 获取 cell 的引用然后再更新数据
- (void)reloadVisiableCells;


#pragma mark - Loading more
- (BOOL)canTriggerLoadingMore;
- (void)onLoadingMore;
/** 开始加载更多 */
- (void)tableViewDidStartLoadingMore;
/** 结束加载更多 */
- (void)tableViewDidStopLoadingMore;
- (void)startLoadingMore;
- (void)stopLoadingMore;


#pragma mark - Lazy loading image
- (void)lazyLoadingImage:(NSURL *)imgURL atIndexPath:(NSIndexPath *)indexPath;
- (NSURL *)imageURLAtIndexPath:(NSIndexPath *)indexPath;


#pragma mark - Pull refresh
- (void)stopRefresh;
- (void)refreshHeaderViewDidTriggerRefresh:(CWRefreshTableHeaderView *)view;


#pragma mark - Scroll view delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

@end
