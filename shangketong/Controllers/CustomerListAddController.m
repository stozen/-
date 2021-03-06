//
//  CustomerListAddController.m
//  shangketong
//
//  Created by sungoin-zbs on 15/11/2.
//  Copyright (c) 2015年 sungoin. All rights reserved.
//

#import "CustomerListAddController.h"
#import "CustomerListAddSelectedController.h"

#import "MJRefresh.h"
#import "CustomTitleView.h"
#import "CustomerTableViewCell.h"

#import "Customer.h"
#import "IndexCondition.h"

#define kCellIdentifier @"CustomerTableViewCell"

@interface CustomerListAddController ()<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) CustomTitleView *titleView;
@property (strong, nonatomic) NSMutableArray *sourceArray;
@property (strong, nonatomic) NSMutableArray *selectedArray;
@property (strong, nonatomic) NSMutableArray *searchArray;
@property (strong, nonatomic) NSMutableArray *indexArray;       // 索引数组
@property (strong, nonatomic) NSMutableDictionary *params;
@property (strong, nonatomic) NSMutableDictionary *searchParams;

@property (strong, nonatomic) UIButton *selectedButton;
@property (strong, nonatomic) UILabel *selectedLabel;
@property (strong, nonatomic) UIImageView *selectedAccessory;

@property (strong, nonatomic) IndexCondition *curIndex;
@property (assign, nonatomic) NSInteger selectedCount;
@property (assign, nonatomic) BOOL isSearch;        // 是否搜索状态

- (void)sendRequestForIndex;     // 获取索引数据
- (void)sendRequest;
@end

@implementation CustomerListAddController

- (void)loadView {
    [super loadView];
    
    self.automaticallyAdjustsScrollViewInsets = NO;

    UIBarButtonItem *confireItem = [UIBarButtonItem itemWithBtnTitle:@"确定" target:self action:@selector(confireItemPress)];
    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spaceItem.width = 20;
    UIBarButtonItem *selectedItem = [UIBarButtonItem itemWithBtnTitle:@"反选" target:self action:@selector(reverseSelectPress)];
    self.navigationItem.rightBarButtonItems = @[confireItem, spaceItem, selectedItem];
    
    @weakify(self);
    self.navigationItem.titleView = self.titleView;
    _titleView.valueBlock = ^(NSInteger index) {
        @strongify(self);
        self.curIndex = self.indexArray[index];
    };
    
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.selectedButton];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _selectedArray = [[NSMutableArray alloc] initWithCapacity:0];
    
    _params = [[NSMutableDictionary alloc] initWithDictionary:COMMON_PARAMS];
    [_params setObject:@1 forKey:@"pageNo"];
    [_params setObject:@20 forKey:@"pageSize"];
    
    _searchParams = [[NSMutableDictionary alloc] initWithDictionary:COMMON_PARAMS];
    [_searchParams setObject:@1 forKey:@"pageNo"];
    [_searchParams setObject:@20 forKey:@"pageSize"];
    
    self.selectedCount = _selectedArray.count;
    
    // 初始化
    [self.view beginLoading];
    [[Net_APIManager sharedManager] request_Customer_Init_WithBlock:^(id data, NSError *error) {
        if (data) {
            [self sendRequestForIndex];
        }
        else if (error.code == STATUS_SESSION_UNAVAILABLE) {
            CommonLoginEvent *comRequest = [[CommonLoginEvent alloc] init];
            comRequest.RequestAgainBlock = ^(){
                [[Net_APIManager sharedManager] request_Customer_Init_WithBlock:^(id data, NSError *error) {
                    if (data) {
                        [self sendRequestForIndex];
                    }
                }];
            };
            [comRequest loginInBackground];
        }
        else {
            [self.view endLoading];
        }
    }];
    
    [_tableView addHeaderWithTarget:self action:@selector(sendRequestForRefresh)];
    [_tableView addFooterWithTarget:self action:@selector(sendRequestForReloadMore)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - event response
- (void)confireItemPress {
    if (!_selectedCount) return;
    
    NSString *customerIds = @"";
    for (int i = 0; i < _selectedArray.count; i ++) {
        Customer *item = _selectedArray[i];
        if (i) {
            customerIds = [NSString stringWithFormat:@"%@,%@", customerIds, item.id];
        }else {
            customerIds = [NSString stringWithFormat:@"%@", item.id];
        }
    }
    
    [_params setObject:customerIds forKey:@"customerIds"];
    [_params setObject:_activityId forKey:@"activityId"];
    [self.view beginLoading];
    [[Net_APIManager sharedManager] request_Customer_AddCustomerFromActivity_WithParams:_params block:^(id data, NSError *error) {
        [self.view endLoading];
        if (data) {
            if (self.refreshBlock) {
                self.refreshBlock();
            }
            [self.navigationController popViewControllerAnimated:YES];
        }
    }];
}

- (void)reverseSelectPress {
    for (Customer *tempItem in _sourceArray) {
        if (tempItem.isSelected) {
            tempItem.isSelected = NO;
            [_selectedArray removeObject:tempItem];
        }else {
            [_selectedArray addObject:tempItem];
            tempItem.isSelected = YES;
        }
    }
    
    self.selectedCount = _selectedArray.count;
    
    [_tableView reloadData];
}

- (void)selectedButtonPress {
    
    if (!_selectedCount)
        return;
    
    CustomerListAddSelectedController *selectedController = [[CustomerListAddSelectedController alloc] init];
    selectedController.title = @"已选择客户";
    selectedController.sourceArray = [_selectedArray mutableCopy];
    selectedController.refleshBlock = ^(Customer *item) {

        if (item.isSelected) {
            [_selectedArray addObject:item];
        }else {
            for (int i = 0; i < _selectedArray.count; i ++) {
                Customer *tempItem = _selectedArray[i];
                if ([tempItem.id isEqualToNumber:item.id]) {
                    [_selectedArray removeObjectAtIndex:i];
                    break;
                }
            }
        }
        
        self.selectedCount = _selectedArray.count;
        
        if (_isSearch) {
            for (int i = 0; i < _searchArray.count; i ++) {
                Customer *tempItem = _searchArray[i];
                if ([tempItem.id isEqualToNumber:item.id]) {
                    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                    break;
                }
            }
            
            return;
        }
        
        for (int i = 0; i < _sourceArray.count; i ++) {
            Customer *tempItem = _sourceArray[i];
            if ([tempItem.id isEqualToNumber:item.id]) {
                [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
        }
    };
    [self.navigationController pushViewController:selectedController animated:YES];
}

- (void)nextButtonPress {
    
}

#pragma mark - private method
- (void)sendRequestForIndex {
    [[Net_APIManager sharedManager] request_Customer_Menu_List_WithParams:COMMON_PARAMS andBlock:^(id data, NSError *error) {
        NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:0];
        for (NSDictionary *tempDict in data[@"conditions"]) {
            IndexCondition *item = [NSObject objectOfClass:@"IndexCondition" fromJSON:tempDict];
            [tempArray addObject:item];
            
            if ([item.id isEqualToNumber:data[@"id"]] && !_curIndex) {
                _curIndex = item;
            }
        }
        self.indexArray = tempArray;
        self.titleView.sourceArray = self.indexArray;
        for (int i = 0; i < self.indexArray.count; i ++) {
            IndexCondition *tempIndex = self.indexArray[i];
            if ([tempIndex.id isEqualToNumber:_curIndex.id]) {
                self.titleView.index = i;
                break;
            }
        }
        
        // 请求列表数据
        [self.params setObject:_curIndex.id forKey:@"retrievalId"];
        [self sendRequest];
    }];
}

- (void)sendRequest {
    [[Net_APIManager sharedManager] request_Customer_List_WithParams:_params andBlock:^(id data, NSError *error) {
        [self.view endLoading];
        [_tableView headerEndRefreshing];
        [_tableView footerEndRefreshing];
        if (data) {
            NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:0];
            for (NSDictionary *tempDict in data[@"customers"]) {
                Customer *customer = [NSObject objectOfClass:@"Customer" fromJSON:tempDict];
                
                for (Customer *selectedItem in _selectedArray) {
                    if ([selectedItem.id isEqualToNumber:customer.id]) {
                        customer.isSelected = YES;
                        break;
                    }
                }
                
                [tempArray addObject:customer];
            }
            
            if ([_params[@"pageNo"] isEqualToNumber:@1]) {
                _sourceArray = tempArray;
            }
            else {
                [_sourceArray addObjectsFromArray:tempArray];
            }
            
            if (tempArray.count == 20) {
                _tableView.footerHidden = NO;
            }
            else {
                _tableView.footerHidden = YES;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_tableView reloadData];
            });
        }
        
        [_tableView configBlankPageWithTitle:@"暂无客户" hasData:_sourceArray.count hasError:NO reloadButtonBlock:nil];
    }];
}

- (void)sendRequestForRefresh {
    if (_isSearch) {
        [_searchParams setObject:@1 forKey:@"pageNo"];
    }
    else {
        [_params setObject:@1 forKey:@"pageNo"];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (_isSearch) {
            [self sendRequestForSearch];
        }
        else {
            [self sendRequest];
        }
    });
}

- (void)sendRequestForReloadMore {
    if (_isSearch) {
        [_searchParams setObject:@([self.params[@"pageNo"] integerValue] + 1) forKey:@"pageNo"];
    }
    else {
        [_params setObject:@([self.params[@"pageNo"] integerValue] + 1) forKey:@"pageNo"];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (_isSearch) {
            [self sendRequestForRefresh];
        }
        else {
            [self sendRequest];
        }
    });
}

- (void)sendRequestForSearch {
    [[Net_APIManager sharedManager] request_Customer_List_WithParams:_searchParams andBlock:^(id data, NSError *error) {
        [self.view endLoading];
        [_tableView headerEndRefreshing];
        [_tableView footerEndRefreshing];
        if (data) {
            NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:0];
            for (NSDictionary *tempDict in data[@"customers"]) {
                Customer *item = [NSObject objectOfClass:@"Customer" fromJSON:tempDict];
                for (Customer *selectedItem in _selectedArray) {
                    if ([selectedItem.id isEqualToNumber:item.id]) {
                        item.isSelected = YES;
                        break;
                    }
                }
                [tempArray addObject:item];
            }
            
            if ([_searchParams[@"pageNo"] isEqualToNumber:@1]) {
                _searchArray = tempArray;
            }
            else {
                [_searchArray addObjectsFromArray:tempArray];
            }
            
            if (tempArray.count == 20) {
                _tableView.footerHidden = NO;
            }
            else {
                _tableView.footerHidden = YES;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_tableView reloadData];
            });
        }
        [_tableView configBlankPageWithTitle:@"无结果" hasData:_searchArray.count hasError:NO reloadButtonBlock:nil];
    }];
}

#pragma mark - UITableView_M
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_isSearch) {
        return _searchArray.count;
    }
    return _sourceArray.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [CustomerTableViewCell cellHeight];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
    
    Customer *item;
    if (_isSearch) {
        item = _searchArray[indexPath.row];
    }else {
        item = _sourceArray[indexPath.row];
    }
    [cell configWithModel:item];
    cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@", item.isSelected ? @"tenant_agree_selected" : @"tenant_agree"]]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    Customer *item;
    if (_isSearch) {
        item = _searchArray[indexPath.row];
    }else {
        item = _sourceArray[indexPath.row];
    }
    
    if (item.isSelected) {
        for (int i = 0; i < _selectedArray.count; i ++) {
            Customer *tempItem = _selectedArray[i];
            if ([tempItem.id isEqualToNumber:item.id]) {
                [_selectedArray removeObjectAtIndex:i];
                break;
            }
        }
        item.isSelected = NO;
        
        if (_isSearch) {
            for (Customer *tempItem in _sourceArray) {
                if ([tempItem.id isEqualToNumber:item.id]) {
                    tempItem.isSelected = NO;
                    break;
                }
            }
        }
    }else {
        [_selectedArray addObject:item];
        item.isSelected = YES;
        
        if (_isSearch) {
            for (Customer *tempItem in _sourceArray) {
                if ([tempItem.id isEqualToNumber:item.id]) {
                    tempItem.isSelected = YES;
                    break;
                }
            }
        }
    }
    
    self.selectedCount = _selectedArray.count;
    
    CustomerTableViewCell *cell = (CustomerTableViewCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@", item.isSelected ? @"tenant_agree_selected" : @"tenant_agree"]]];
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [_searchBar resignFirstResponder];
}

#pragma mark - UISearchBarDelegate
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    _isSearch = YES;
    [_tableView reloadData];
    [searchBar setShowsCancelButton:YES animated:YES];
    
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    searchBar.text = nil;
    [searchBar setShowsCancelButton:NO animated:YES];
    _isSearch = NO;
    [_searchParams setObject:@1 forKey:@"pageNo"];
    [_tableView.blankPageView removeFromSuperview];
    [_tableView reloadData];
    
    [_tableView configBlankPageWithTitle:@"暂无客户" hasData:_sourceArray.count hasError:NO reloadButtonBlock:nil];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [_searchParams setObject:searchBar.text forKey:@"name"];
    
    [self.view beginLoading];
    [self sendRequestForSearch];
}

#pragma mark - setters and getters
- (void)setSelectedCount:(NSInteger)selectedCount {
    _selectedCount = selectedCount;
    
    _selectedLabel.text = [NSString stringWithFormat:@"已选择客户: %ld", (long)_selectedCount];
}

- (void)setCurIndex:(IndexCondition *)curIndex {
    if (_curIndex == curIndex) {
        return;
    }
    
    _curIndex = curIndex;
    
    [_params setObject:_curIndex.id forKey:@"retrievalId"];
    [self.view beginLoading];
    [self sendRequest];
}

- (UITableView*)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        [_tableView setY:64];
        [_tableView setWidth:kScreen_Width];
        [_tableView setHeight:kScreen_Height - CGRectGetMinY(_tableView.frame) - 44];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        [_tableView registerClass:[CustomerTableViewCell class] forCellReuseIdentifier:kCellIdentifier];
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.tableHeaderView = self.searchBar;
    }
    return _tableView;
}

- (UISearchBar*)searchBar {
    if (!_searchBar) {
        _searchBar = [[UISearchBar alloc] init];
        [_searchBar sizeToFit];
        _searchBar.placeholder = @"搜索客户";
        _searchBar.delegate = self;
    }
    return _searchBar;
}

- (CustomTitleView*)titleView {
    if (!_titleView) {
        _titleView = [[CustomTitleView alloc] init];
        _titleView.cellType = CellTypeDefault;
        _titleView.defalutTitleString = self.title;
        _titleView.superViewController = self;
    }
    return _titleView;
}


- (UIButton*)selectedButton {
    if (!_selectedButton) {
        _selectedButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _selectedButton.backgroundColor = [UIColor colorWithHexString:@"0xf8f8f8"];
        [_selectedButton setWidth:kScreen_Width];
        [_selectedButton setHeight:44];
        [_selectedButton setY:kScreen_Height - 44];
        [_selectedButton addLineUp:YES andDown:NO];
        [_selectedButton addTarget:self action:@selector(selectedButtonPress) forControlEvents:UIControlEventTouchUpInside];
        
        [_selectedButton addSubview:self.selectedLabel];
        [_selectedButton addSubview:self.selectedAccessory];
    }
    return _selectedButton;
}

- (UILabel*)selectedLabel {
    if (!_selectedLabel) {
        _selectedLabel = [[UILabel alloc] init];
        [_selectedLabel setX:15];
        [_selectedLabel setWidth:kScreen_Width - 30];
        [_selectedLabel setHeight:CGRectGetHeight(_selectedButton.bounds)];
        _selectedLabel.font = [UIFont systemFontOfSize:15];
        _selectedLabel.textAlignment = NSTextAlignmentLeft;
        _selectedLabel.textColor = [UIColor iOS7darkGrayColor];
    }
    return _selectedLabel;
}

- (UIImageView*)selectedAccessory {
    if (!_selectedAccessory) {
        UIImage *image = [UIImage imageNamed:@"activity_Arrow"];
        _selectedAccessory = [[UIImageView alloc] initWithImage:image];
        [_selectedAccessory setWidth:image.size.width];
        [_selectedAccessory setHeight:image.size.height];
        [_selectedAccessory setX:kScreen_Width - image.size.width - 15];
        [_selectedAccessory setCenterY:CGRectGetHeight(_selectedButton.bounds) / 2];
    }
    return _selectedAccessory;
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
