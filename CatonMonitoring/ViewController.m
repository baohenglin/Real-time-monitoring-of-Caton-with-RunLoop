//
//  ViewController.m
//  CatonMonitoring
//
//  Created by BaoHenglin on 2019/8/27.
//  Copyright © 2019 BaoHenglin. All rights reserved.
//

#import "ViewController.h"
#import "HLCatonMonitor.h"
#define DeviceWidth [UIScreen mainScreen].bounds.size.width
#define DeviceHeight [UIScreen mainScreen].bounds.size.height
@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *listTableView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.listTableView];
    [[HLCatonMonitor shareInstance] beginMonitor];
    // Do any additional setup after loading the view.
}
- (UITableView *)listTableView{
    _listTableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, DeviceWidth, DeviceHeight) style:UITableViewStylePlain];
    _listTableView.delegate = self;
    _listTableView.dataSource = self;
    _listTableView.rowHeight = 60;
    _listTableView.backgroundColor = [UIColor purpleColor];
    return _listTableView;
}
#pragma mark tableView delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 100;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *identifierStr = @"mycell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifierStr];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifierStr];
    }
    NSString *cellText = nil;
    if (indexPath.row % 5 == 0) {
        //滑动列表时，人为设置卡顿(休眠)，来测试我们实时监控卡顿的代码是否有效。
        //每5行休眠0.05s（50ms）
        usleep(50 * 1000);
        cellText = @"休眠：做一些耗时操作";
    } else {
        cellText = [NSString stringWithFormat:@"cell - %ld",indexPath.row];
    }
    cell.textLabel.text = cellText;
    return cell;
}
@end


