//
//  QRScanViewController.m
//  QRScanViewController
//
//  Created by 王右 on 16/8/21.
//  Copyright © 2016年 王右. All rights reserved.
//

#import "QRScanViewController.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width

#define kScreenHeight [UIScreen mainScreen].bounds.size.height


@interface QRScanViewController ()

@property (nonatomic, strong) dispatch_queue_t globalQueue;//异步加载队列

@property (nonatomic, assign) BOOL isFirstCome;//是否是第一次进入此Controller

@property (nonatomic, strong) AVCaptureSession *captureSession;//画面捕捉器

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *viedoPreviewLayer;//视频捕捉预览层

@property (nonatomic, strong) UIView *boxView;//画面捕捉区域容器

@property (nonatomic, strong) CALayer *scanLayer;//捕捉区域

@property (nonatomic, strong) UIImageView *boxImageView;//扫描线框

@property (nonatomic, strong) UIImageView *scanImageView;//扫描线

@property (nonatomic, strong) NSTimer *timer;//扫描线移动定时器

@property (nonatomic, strong) UILabel *titleLabel;//扫描标题

@property (nonatomic, strong) UILabel *tipsLabel;//扫描说明

@property (nonatomic, strong) UIButton *useTipsButton;//如何使用

@end

@implementation QRScanViewController


- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if (_isFirstCome) {
        [self startReading];//第一次进入,初始化页面
        _isFirstCome = NO;
    }else{
        [self reStartReading];//其他进入,重新捕捉画面,初始化定时器
    }
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _isFirstCome = YES;
    
    _globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reStartReading) name:@"reStartReading" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeReading) name:@"removeReading" object:nil];
}

//初始化捕捉画面
- (BOOL )startReading{
    
    NSError *error;
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (!input) {
        return NO;
    }

    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    [_captureSession addInput:input];
    
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:captureMetadataOutput];
    
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    _viedoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_viedoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_viedoPreviewLayer setFrame:self.view.layer.bounds];
    [self.view.layer addSublayer:_viedoPreviewLayer];
    
    captureMetadataOutput.rectOfInterest = CGRectMake(self.view.bounds.size.height * 0.3 / kScreenHeight, self.view.bounds.size.width * 0.15 / kScreenWidth, self.view.bounds.size.width * 0.7 / kScreenHeight, self.view.bounds.size.width * 0.7 / kScreenWidth);
    
    _boxView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.15, self.view.bounds.size.height * 0.25, self.view.bounds.size.width * 0.7, self.view.bounds.size.width * 0.7)];
    [self.view addSubview:_boxView];
    
    //10.2 扫描线
    _scanLayer = [[CALayer alloc] init];
    _scanLayer.frame = CGRectMake(0, 0, _boxView.bounds.size.width, 1);
    _scanLayer.backgroundColor = [UIColor brownColor].CGColor;
    
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(moveScanLayer:) userInfo:nil repeats:YES];
    [_timer fire];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"xiankuang.png"]];
    imageView.frame = CGRectMake(0, 0, _boxView.bounds.size.width, _boxView.bounds.size.height);
    [_boxView addSubview:imageView];
    imageView.backgroundColor = [UIColor clearColor];
    _boxView.backgroundColor = [UIColor clearColor];
    
    
    self.scanImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"saomiaoxian"]];
    self.scanImageView.frame = CGRectMake(- 5, 0, _boxView.bounds.size.width  + 10, 5);
    [_boxView addSubview:self.scanImageView];
    self.scanImageView.backgroundColor = [UIColor clearColor];
    
    dispatch_sync(_globalQueue, ^{
        [_captureSession startRunning];
    });
    
    _titleLabel = [UILabel new];
    _titleLabel.frame = CGRectMake(0, _boxView.frame.origin.y - 50, kScreenWidth, kScreenHeight * 0.05);
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.font = [UIFont systemFontOfSize:15];
    _titleLabel.text = @"标题";
    [self.view addSubview:_titleLabel];
    
    
    _tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0.25 * kScreenHeight + 0.7 * kScreenWidth + 15, kScreenWidth, 30)];
    _tipsLabel.center = CGPointMake(_boxView.center.x, _tipsLabel.center.y);
    [self.view addSubview:_tipsLabel];
    _tipsLabel.layer.cornerRadius = 5;
    _tipsLabel.backgroundColor = [UIColor clearColor];
    _tipsLabel.textAlignment = NSTextAlignmentCenter;
    _tipsLabel.text = @"请将二维码对准扫描框进行扫描";
    _tipsLabel.font = [UIFont systemFontOfSize:15];
    _tipsLabel.textColor = [UIColor whiteColor];
    
    
    _useTipsButton = [UIButton buttonWithType:(UIButtonTypeCustom)];
    _useTipsButton.frame = CGRectMake(0, _tipsLabel.frame.origin.y + _tipsLabel.bounds.size.height + 10, 80, 24);
    _useTipsButton.center = CGPointMake(_tipsLabel.center.x, _useTipsButton.center.y);
    _useTipsButton.layer.cornerRadius = 10;
    _useTipsButton.layer.masksToBounds = YES;
    _useTipsButton.titleLabel.font = [UIFont systemFontOfSize:14];
    _useTipsButton.layer.borderWidth = 0.5;
    _useTipsButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
    _useTipsButton.backgroundColor = [UIColor clearColor];
    [_useTipsButton setTitle:@"如何使用?" forState:(UIControlStateNormal)];
    //使用说明按钮点击事件
    [_useTipsButton addTarget:self action:@selector(userTipsButtonAction:) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:_useTipsButton];

    return YES;
}
//停止捕捉
- (void)stopReading{
    dispatch_sync(_globalQueue, ^{
        if (_captureSession.running) {
            [_captureSession stopRunning];
        }
    });
    [_timer invalidate];
    _timer = nil;
}
//重新捕捉画面
- (void)reStartReading{
    //除了在此页面的其他调用,此方法从后台进入前台也会调用一次
    // applicationDidBecomeActive: 发送 reStartReading 通知
    [_timer invalidate];
    _timer = nil;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(moveScanLayer:) userInfo:nil repeats:YES];
    [_timer fire];
    dispatch_sync(_globalQueue, ^{
        if (!_captureSession.running) {
            [_captureSession startRunning];
        }
    });
}

//停止捕捉:仅在app从前台进入后台时调用
- (void)removeReading{
    //此方法只在从前台进入后台调用.
    //由 applicationDidEnterBackground: 发送 removeReading 通知
    [_timer invalidate];
    _timer = nil;
    dispatch_sync(_globalQueue, ^{
        [_captureSession stopRunning];
    });
}

//使用说明按钮点击事件
- (void)userTipsButtonAction:(UIButton *)button{
    
}

- (void)moveScanLayer:(NSTimer *)time{
    CGRect frame = self.scanImageView.frame;
    if (_boxView.frame.size.height < self.scanImageView.frame.origin.y + 10) {
        frame.origin.y = 0;
        _scanImageView.frame = frame;
        [_scanImageView removeFromSuperview];
        [_boxView addSubview:_scanImageView];
    }else{
        frame.origin.y += 3;
        [UIView animateWithDuration:0.1 animations:^{
            _scanImageView.frame = frame;
        }];
    }

}

#pragma mark - AVCaptureMetadataOutputObjectsDelgate 捕捉代理
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metaObject = metadataObjects[0];
        if ([[metaObject type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            NSString *result = [metaObject stringValue];
            [self dealWithResult:result];
        }
    }
}
//扫描结果处理
- (void)dealWithResult:(NSString *)result{
    
}

- (void)dealloc{
    [_timer invalidate];
    _timer = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




@end
