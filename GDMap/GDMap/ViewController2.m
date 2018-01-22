//
//  ViewController2.m
//  GDMap
//
//  Created by 臣陈 on 2018/1/22.
//  Copyright © 2018年 guidekj. All rights reserved.
//

#import "ViewController2.h"
#import "ViewController.h"

@interface ViewController2 ()

@end

@implementation ViewController2

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"高德地图定位";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(next)];
}

- (void)next {
    [self.navigationController pushViewController:[[ViewController alloc] init] animated:YES];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self next];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:YES animated:animated];
}

@end
