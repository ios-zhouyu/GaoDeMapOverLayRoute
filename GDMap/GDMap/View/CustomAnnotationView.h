//
//  CustomAnnotationView.h
//  project
//
//  Created by zhouyu on 2017/8/4.
//  Copyright © 2017年 zhouyu. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>
#import "CustomCalloutView.h"

@interface CustomAnnotationView : MAAnnotationView
@property (nonatomic, readonly) CustomCalloutView *calloutView;
@end
