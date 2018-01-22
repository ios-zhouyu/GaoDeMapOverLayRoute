//
//  ViewController.m
//  GDMap
//
//  Created by 臣陈 on 2018/1/22.
//  Copyright © 2018年 guidekj. All rights reserved.
//

#import "ViewController.h"
#import <MAMapKit/MAMapKit.h>
#import "CustomAnnotationView.h"
#import <AMapLocationKit/AMapLocationKit.h>

#define kCalloutViewMargin -8

@interface ViewController ()<MAMapViewDelegate,AMapLocationManagerDelegate>
/*
 *
 */
@property (nonatomic, strong) MAMapView *mapView;

@property (nonatomic, strong) NSArray *distanceArray;
@property (nonatomic, assign) double sumDistance;

///全轨迹overlay
@property (nonatomic, strong) MAPolyline *fullTraceLine;
///走过轨迹的overlay
@property (nonatomic, strong) MAPolyline *passedTraceLine;
@property (nonatomic, assign) int passedTraceCoordIndex;

//定位的点经纬度和自定义视图routeAnno
@property (nonatomic, copy) NSMutableArray *coordsArrM;
@property (nonatomic, copy) NSMutableArray *routeAnnoArrM;

//定位数据管理
@property (nonatomic, strong) AMapLocationManager *locationManager;
/**
 *  后台定位是否返回逆地理信息，默认NO。
 */
@property (nonatomic, assign) BOOL locatingWithReGeocode;

// 定位
@property (nonatomic, strong) UIButton             *locationBtn;
// 用户自定义大头针
@property (nonatomic, strong) UIImage              *imageLocated;
@property (nonatomic, strong) UIImage              *imageNotLocate;

///车头方向跟随转动
@property (nonatomic, strong) MAAnimatedAnnotation *car1;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"地图定位";
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(cameraDegreeZeroAction)];
    
    ///地图需要v4.5.0及以上版本才必须要打开此选项（v4.5.0以下版本，需要手动配置info.plist）
    [AMapServices sharedServices].enableHTTPS = YES;
    
    ///把地图添加至view
    [self.view addSubview:self.mapView];
    self.mapView.delegate = self;
    
    [self initCoords];
    
    [self initToolBar];
    
    [self initZoom];
    
    [self initLocation];
    
    [self initCurrentPoint];
}

//旋转成3D立体地图是复位成3D平面模式
- (void)cameraDegreeZeroAction{
    self.mapView.cameraDegree = 0;
}

//弹出层自适应屏幕位置
- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view{
    /* Adjust the map center in order to show the callout view completely. */
    if ([view isKindOfClass:[CustomAnnotationView class]]) {
        CustomAnnotationView *cusView = (CustomAnnotationView *)view;
        CGRect frame = [cusView convertRect:cusView.calloutView.frame toView:self.mapView];
        frame = UIEdgeInsetsInsetRect(frame, UIEdgeInsetsMake(kCalloutViewMargin, kCalloutViewMargin, kCalloutViewMargin, kCalloutViewMargin));
        
        if (!CGRectContainsRect(self.mapView.frame, frame)){
            /* Calculate the offset to make the callout view show up. */
            CGSize offset = [self offsetToContainRect:frame inRect:self.mapView.frame];
            CGPoint theCenter = self.mapView.center;
            theCenter = CGPointMake(theCenter.x - offset.width, theCenter.y - offset.height);
            CLLocationCoordinate2D coordinate = [self.mapView convertPoint:theCenter toCoordinateFromView:self.mapView];
            [self.mapView setCenterCoordinate:coordinate animated:YES];
        }
    }
}
- (CGSize)offsetToContainRect:(CGRect)innerRect inRect:(CGRect)outerRect{
    CGFloat nudgeRight = fmaxf(0, CGRectGetMinX(outerRect) - (CGRectGetMinX(innerRect)));
    CGFloat nudgeLeft = fminf(0, CGRectGetMaxX(outerRect) - (CGRectGetMaxX(innerRect)));
    CGFloat nudgeTop = fmaxf(0, CGRectGetMinY(outerRect) - (CGRectGetMinY(innerRect)));
    CGFloat nudgeBottom = fminf(0, CGRectGetMaxY(outerRect) - (CGRectGetMaxY(innerRect)));
    return CGSizeMake(nudgeLeft ?: nudgeRight, nudgeTop ?: nudgeBottom);
}

//初始化经纬度数据--需要重后台获取
- (void)initCoords{
    
    int count = (int)self.coordsArrM.count;
    double sum = 0;
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:count];
    
    for (int i = 0;  i < count - 1; ++i) {
        NSArray *beginArr = self.coordsArrM[i];
        NSArray *endArr = self.coordsArrM[i+1];
        CLLocation *begin = [[CLLocation alloc] initWithLatitude:[beginArr[0] doubleValue]  longitude:[beginArr[1] doubleValue]];
        CLLocation *end = [[CLLocation alloc] initWithLatitude:[endArr[0] doubleValue]  longitude:[endArr[1] doubleValue]];
        CLLocationDistance distance = [end distanceFromLocation:begin];
        [arr addObject:[NSNumber numberWithDouble:distance]];
        sum += distance;
    }
    
    self.distanceArray = arr;
    self.sumDistance = sum;
}

#pragma mark - Map Delegate
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation{
   if([annotation isKindOfClass:[MAPointAnnotation class]]) {
        NSString *pointReuseIndetifier = @"pointReuseIndetifier3";
        CustomAnnotationView *annotationView = (CustomAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        if (annotationView == nil) {
            annotationView = [[CustomAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
            // 设置为NO，用以调用自定义的calloutView
            annotationView.canShowCallout = NO;
            // 设置中心点偏移，使得标注底部中间点成为经纬度对应点
//            annotationView.centerOffset = CGPointMake(0, -18);
        }
        //更换展示的图标
        if ([annotation.title isEqualToString:@"route"]) {
            annotationView.enabled = YES;
            annotationView.image = [UIImage imageNamed:@"trackingPoints"];
        } else if ([annotation.title isEqualToString:@"begin"]) {
           annotationView.image = [UIImage imageNamed:@"startPoint"];
       } else if ([annotation.title isEqualToString:@"end"]) {
           annotationView.image = [UIImage imageNamed:@"endPoint"];
       } else {
//           NSLog(@"%@",annotation);//当前定位点
           annotationView.image = [UIImage imageNamed:@"locate"];
       }
        return annotationView;
   }
    return nil;
}

//修改轨迹线宽颜色等
- (MAPolylineRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay {
    if(overlay == self.fullTraceLine) {
        MAPolylineRenderer *polylineView = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        polylineView.lineWidth   = 2.f;
        polylineView.strokeColor = [UIColor colorWithRed:0 green:0.47 blue:1.0 alpha:0.9];
        return polylineView;
    }
    return nil;
}

//初始化轨迹线路
- (void)mapInitComplete:(MAMapView *)mapView {
    int count = (int)self.coordsArrM.count;
    
    CLLocationCoordinate2D *pCoords = malloc(sizeof(CLLocationCoordinate2D) * self.coordsArrM.count);
    if(!pCoords) {
        return;
    }
    
    for(int i = 0; i < self.coordsArrM.count; ++i) {
        NSArray *arr = [self.coordsArrM objectAtIndex:i];
        CLLocationCoordinate2D *pCur = pCoords + i;
        pCur->latitude = [arr[0] doubleValue];
        pCur->longitude = [arr[1] doubleValue];
    }
    
    self.fullTraceLine = [MAPolyline polylineWithCoordinates:pCoords count:count];
    [self.mapView addOverlay:self.fullTraceLine];
    
    NSMutableArray * routeAnno = [NSMutableArray array];
    for (int i = 0 ; i < count; i++) {
        NSArray *arr = self.coordsArrM[i];
        MAPointAnnotation * a = [[MAPointAnnotation alloc] init];
        a.coordinate = CLLocationCoordinate2DMake([arr[0] doubleValue], [arr[1] doubleValue]);
        if (i == 0) {
            a.title = @"begin";
        } else if(i == self.coordsArrM.count - 1) {
            a.title = @"end";
        } else {
            a.title = @"route";
        }
        
        a.subtitle = [NSString stringWithFormat:@"%d+%@", i, [self getCurrentTimes]];
        [routeAnno addObject:a];
    }
    [self.routeAnnoArrM addObjectsFromArray:routeAnno];
    [self.mapView addAnnotations:self.routeAnnoArrM];
    [self.mapView showAnnotations:self.routeAnnoArrM animated:YES];
}

//获取当前的时间
- (NSString*)getCurrentTimes{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    NSDate *datenow = [NSDate date];
    NSString *currentTimeString = [formatter stringFromDate:datenow];
    return currentTimeString;
}

// MARK: 定位--到当前位置
- (void)actionLocation{
    if (self.mapView.userTrackingMode == MAUserTrackingModeFollow){
        [self.mapView setUserTrackingMode:MAUserTrackingModeNone animated:YES];
    } else {
        [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate animated:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // 因为下面这句的动画有bug，所以要延迟0.5s执行，动画由上一句产生
            [self.mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
        });
    }
}

#pragma mark - 后台定位和持续定位。
- (void)initCurrentPoint{
    self.imageLocated = [UIImage imageNamed:@"gpssearchbutton"];
    self.imageNotLocate = [UIImage imageNamed:@"gpsnormal"];
    self.locationBtn = [[UIButton alloc] initWithFrame:CGRectMake(10, CGRectGetHeight(self.mapView.bounds) - 20, 32, 32)];
    self.locationBtn.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    self.locationBtn.backgroundColor = [UIColor whiteColor];
    
    self.locationBtn.layer.cornerRadius = 3;
    [self.locationBtn addTarget:self action:@selector(actionLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.locationBtn setImage:self.imageNotLocate forState:UIControlStateNormal];
    
    [self.view addSubview:self.locationBtn];
}

#pragma mark - 后台定位和持续定位。
- (void)initLocation{
    self.locationManager = [[AMapLocationManager alloc] init];
    self.locationManager.delegate = self;//遵守代理,实现协议
    //设置定位最小更新距离方法如下，单位米。当两次定位距离满足设置的最小更新距离时，SDK会返回符合要求的定位结果。
    self.locationManager.distanceFilter = 0.1;
    
    //开启持续定位
    //iOS 9（不包含iOS 9） 之前设置允许后台定位参数，保持不会被系统挂起
    [self.locationManager setPausesLocationUpdatesAutomatically:NO];
    
    //iOS 9（包含iOS 9）之后新特性：将允许出现这种场景，同一app中多个locationmanager：一些只能在前台定位，另一些可在后台定位，并可随时禁止其后台定位。
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 9) {
        self.locationManager.allowsBackgroundLocationUpdates = YES;
    }
    
    //    如果需要持续定位返回逆地理编码信息
    [self.locationManager setLocatingWithReGeocode:YES];
    //开始持续定位
    [self.locationManager startUpdatingLocation];
}
#pragma mark - 在回调函数中，获取定位坐标，进行业务处理--传递给后台。
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode{
    NSLog(@"location:{纬度lat:%f; 经度lon:%f; accuracy:%f}", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
    if (reGeocode){
        NSLog(@"reGeocode:%@", reGeocode);
        
        //实时定位,实时绘制定位点连线
//        [self.mapView removeAnnotations:self.routeAnnoArrM];
//        [self.mapView removeOverlay:self.fullTraceLine];
//        [self.coordsArrM addObject:@[@(location.coordinate.latitude),@(location.coordinate.longitude)]];
//
//        int count = (int)self.coordsArrM.count;
//
//        CLLocationCoordinate2D *pCoords = malloc(sizeof(CLLocationCoordinate2D) * self.coordsArrM.count);
//        if(!pCoords) {
//            return;
//        }
//
//        for(int i = 0; i < self.coordsArrM.count; ++i) {
//            NSArray *arr = [self.coordsArrM objectAtIndex:i];
//            CLLocationCoordinate2D *pCur = pCoords + i;
//            pCur->latitude = [arr[0] doubleValue];
//            pCur->longitude = [arr[1] doubleValue];
//        }
//
//        self.fullTraceLine = [MAPolyline polylineWithCoordinates:pCoords count:count];
//        [self.mapView addOverlay:self.fullTraceLine];
//
//        MAPointAnnotation * a = [[MAPointAnnotation alloc] init];
//        a.coordinate = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
//        a.title = @"route";
//        a.subtitle = [NSString stringWithFormat:@"+%@", [self getCurrentTimes]];
//
//        [self.routeAnnoArrM addObject:a];
//        [self.mapView addAnnotations:self.routeAnnoArrM];
//        [self.mapView showAnnotations:self.routeAnnoArrM animated:YES];
    }
}

//切换地图显示级别
- (void)initZoom{
    UIView *zoomPannelView = [self makeZoomPannelView];
    zoomPannelView.center = CGPointMake(self.view.bounds.size.width -  CGRectGetMidX(zoomPannelView.bounds) - 10,
                                        self.view.bounds.size.height -  CGRectGetMidY(zoomPannelView.bounds) - 50);
    
    [self.view addSubview:zoomPannelView];
}
- (UIView *)makeZoomPannelView{
    UIView *ret = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 53, 98)];
    
    UIButton *incBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 53, 49)];
    [incBtn setImage:[UIImage imageNamed:@"increase"] forState:UIControlStateNormal];
    [incBtn sizeToFit];
    [incBtn addTarget:self action:@selector(zoomPlusAction) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *decBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 49, 53, 49)];
    [decBtn setImage:[UIImage imageNamed:@"decrease"] forState:UIControlStateNormal];
    [decBtn sizeToFit];
    [decBtn addTarget:self action:@selector(zoomMinusAction) forControlEvents:UIControlEventTouchUpInside];
    
    [ret addSubview:incBtn];
    [ret addSubview:decBtn];
    return ret;
}
//放大
- (void)zoomPlusAction{
    CGFloat oldZoom = self.mapView.zoomLevel;
    [self.mapView setZoomLevel:(oldZoom + 1) animated:YES];
}
//缩小
- (void)zoomMinusAction{
    CGFloat oldZoom = self.mapView.zoomLevel;
    [self.mapView setZoomLevel:(oldZoom - 1) animated:YES];
}

//切换地图类型
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.toolbar.barStyle      = UIBarStyleBlack;
    self.navigationController.toolbar.translucent   = YES;
    [self.navigationController setToolbarHidden:NO animated:animated];
}

//切换地图类型
- (void)mapTypeAction:(UISegmentedControl *)segmentedControl{
    self.mapView.mapType = segmentedControl.selectedSegmentIndex;
}
#pragma mark - 切换地图类型
- (void)initToolBar{
    UIBarButtonItem *flexbleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UISegmentedControl *mapTypeSegmentedControl = [[UISegmentedControl alloc] initWithItems: [NSArray arrayWithObjects:@"标准(Standard)",@"卫星(Satellite)",nil]];
    mapTypeSegmentedControl.selectedSegmentIndex  = self.mapView.mapType;
    [mapTypeSegmentedControl addTarget:self action:@selector(mapTypeAction:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *mayTypeItem = [[UIBarButtonItem alloc] initWithCustomView:mapTypeSegmentedControl];
    self.toolbarItems = [NSArray arrayWithObjects:flexbleItem, mayTypeItem, flexbleItem, nil];
}

#pragma mark 来加载
- (MAMapView *)mapView{
    if (_mapView == nil) {
        ///初始化地图
        MAMapView *mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, 44 + [UIApplication sharedApplication].statusBarFrame.size.height, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - 44 - [UIApplication sharedApplication].statusBarFrame.size.height)];
        _mapView = mapView;
        
        ///如果您需要进入地图就显示定位小蓝点，则需要下面两行代码
        mapView.showsUserLocation = YES;
        mapView.userTrackingMode = MAUserTrackingModeFollow;
        
        mapView.showsCompass= YES; // 设置成NO表示关闭指南针；YES表示显示指南针
        mapView.compassOrigin= CGPointMake(mapView.compassOrigin.x, 10); //设置指南针位置
        
        mapView.showsScale= YES;  //设置成NO表示不显示比例尺；YES表示显示比例尺
        mapView.scaleOrigin= CGPointMake(mapView.scaleOrigin.x - 60, 5);  //设置比例尺位置
        
        [mapView setZoomLevel:15.5 animated:YES];
        mapView.maxZoomLevel = 19;
        
        //手势事件
        mapView.scrollEnabled = YES;
        mapView.zoomEnabled = YES;
        mapView.rotateEnabled = YES;
        mapView.skyModelEnable = YES;
        
        // 后台持续定位 iOS9以上系统必须配置
        // 左侧目录中选中工程名，开启 TARGETS->Capabilities->Background Modes 在 Background Modes中勾选 Location updates
        mapView.allowsBackgroundLocationUpdates = YES;
    }
    return _mapView;
}

- (NSMutableArray *)routeAnnoArrM{
    if (_routeAnnoArrM == nil) {
        _routeAnnoArrM = [[NSMutableArray alloc] init];
    }
    return _routeAnnoArrM;
}

- (NSMutableArray *)coordsArrM{
    if (_coordsArrM == nil) {
        _coordsArrM = [@[
            @[@(39.97617053371078), @(116.3499049793749)],
            @[@(39.97619854213431), @( 116.34978804908442)],
            @[@(39.97623045687959), @( 116.349674596623)],
            @[@(39.976260803938594), @(116.34918981582413)],
            @[@(39.97623535890678), @(116.34906721558868)],
            @[@(39.976214717128855), @(116.34895185151584)],
            @[@(39.976280148755315), @(116.34886935936889)],
            @[@(39.97628182112874), @(116.34873954611332)],
            @[@(39.97626038855863), @(116.34860763527448)],
            @[@(39.97655231226543), @(116.34827643560175)],
            @[@(39.976658372925556), @(116.34824186261169)],
            @[@(39.9767570732376), @(116.34825080406188)],
            @[@(39.976869087779995), @(116.34825631960626)],
            @[@(39.97698451764595), @(116.34822111635201)],
            @[@(39.977079745909876), @(116.34822901510276)],
            @[@(39.97786190186833), @(116.3482045955917)],
            @[@(39.977958856930286), @(116.34822159449203)],
            @[@(39.97807288885813), @(116.3482256370537)],
            @[@(39.978170063673524), @(116.3482098441266)],
            @[@(39.978266951404066), @(116.34819564465377)],
            @[@(39.978380693859116), @(116.34820541974412)],
            @[@(39.97848741209275), @(116.34819672351216)],
            @[@(39.978593409607825), @(116.34816588867105)],
            @[@(39.97870216883567), @(116.34818489339459)],
            @[@(39.979308267469264), @(116.34809495907906)],
            @[@(39.97939658036473), @(116.34805113358091)],
            @[@(39.979491697188685), @(116.3480310509613)],
            @[@(39.979588529006875), @(116.3480082124968)],
            @[@(39.979685789111635), @(116.34799530586834)],
            @[@(39.979801430587926), @(116.34798818413954)],
            @[@(39.97990758587515), @(116.3479996420353)],
            @[@(39.980000796262615), @(116.34798697544538)],
            @[@(39.980116318796085), @(116.3479912988137)],
            @[@(39.98021407403913), @(116.34799204219203)],
            @[@(39.980325006125696), @(116.34798535084123)],
            @[@(39.98098214824056), @(116.3478962642899)],
            @[@(39.98108306010269), @(116.34782449883967)],
            @[@(39.98115277119176), @(116.34774758827285)],
            @[@(39.98115430642997), @(116.34761476652932)],
            @[@(39.98114590845294), @(116.34749135408349)],
            @[@(39.98114337322547), @(116.34734772765582)],
            @[@(39.98115066909245), @(116.34722082902628)],
            @[@(39.98112495260716), @(116.34658043260109)],
            @[@(39.9811107163792), @(116.34643721418927)],
            @[@(39.981085081075676), @(116.34631638374302)],
            @[@(39.981052294975264), @(116.34537348820508)],
            @[@(39.980956549928244), @(116.3453513775533)],
        ] mutableCopy];
    }
    return _coordsArrM;
}
@end
