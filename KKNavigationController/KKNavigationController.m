//
//  KKNavigationController.m
//  TS
//
//  Created by Coneboy_K on 13-12-2.
//  Copyright (c) 2013年 Coneboy_K. All rights reserved.  MIT
//  WELCOME TO MY BLOG  http://www.coneboy.com
//


#import "KKNavigationController.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

CGImageRef UIGetScreenImage();

@interface KKNavigationController () <UIGestureRecognizerDelegate>
{
    CGPoint startTouch;
    
    UIImageView *lastScreenShotView;
    UIView *blackMask;

}

@property (nonatomic, weak) UIPanGestureRecognizer *panGestureRecognizer;

@property (nonatomic,retain) UIView *backgroundView;
@property (nonatomic, weak) UIView *fakeTopView;
@property (nonatomic,retain) NSMutableArray *screenShotsList;

@property (nonatomic,assign) BOOL allowDismiss;
@property (nonatomic,assign) BOOL isMoving;

@property (nonatomic,assign) BOOL initFlag;
@end

@implementation KKNavigationController

+ (BOOL)_iOS7WithSDK7 {
    static BOOL indicator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        indicator = NO;
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
            indicator = YES;
        }
#endif
    });
    
    return indicator;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
        self.screenShotsList = [NSMutableArray new];
        self.canDragBack = YES;
        self.allowDismiss = NO;
        self.initFlag = NO;
        
    }
    return self;
}

- (void)dealloc
{
    self.screenShotsList = nil;
    
    [self.backgroundView removeFromSuperview];
    self.backgroundView = nil;
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIImageView *shadowImageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"leftside_shadow_bg"]];
    shadowImageView.frame = CGRectMake(-10, 0, 10, self.view.frame.size.height);
    [self.view addSubview:shadowImageView];
    
    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self
                                                                                action:@selector(paningGestureReceive:)];
    [recognizer delaysTouchesBegan];
    [self.view addGestureRecognizer:recognizer];
    recognizer.delegate = self;
    
    self.panGestureRecognizer = recognizer;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 由于涉及到self.view.bounds，所以放在这个函数内
    // 用initFlag来限制只执行一次
    if (!self.initFlag) {
        self.initFlag = YES;
        
        CALayer *shadowLayer = self.view.layer;
        UIBezierPath* newShadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds];
        shadowLayer.masksToBounds = NO;
        shadowLayer.shadowRadius = 4;
        shadowLayer.shadowOpacity = 0.3;
        shadowLayer.shadowColor = [[UIColor blackColor] CGColor];
        shadowLayer.shadowOffset = CGSizeZero;
        shadowLayer.shadowPath = [newShadowPath CGPath];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // 其它滑动手势必须等kkNavigationController识别失败，才允许启用
    // 这样就避免了卡片后退的途中，卡片内部还能上下滚动的问题
    // 该函数只针对iOS 7+有效
    
    // 注意要判断手势的类型，不能所有手势都返回NO，否则会造成iOS7上不能拷贝内容的问题
    
    if ([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.numberOfTouches > 0) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint translation = [pan velocityInView:pan.view];
        
        // 如果是向左滑动，或者y轴的分量过大，那么不启用效果
        if (translation.x < 0 || fabs(translation.y) > fabs(translation.x) / 2) {
            return NO;
        }
    }
    
    if (!self.canDragBack) {
        return NO;
    }
    
    // 只有当前viewController实现了kkNavigationControllerEnabled函数，并且返回YES，才可能继续判断
    UIViewController *viewController = [self.viewControllers lastObject];
    if (![viewController conformsToProtocol:@protocol(kkNavigationDelegate)]) {
        return NO;
    } else {
        id<kkNavigationDelegate> delegate = (id<kkNavigationDelegate>)viewController;
        if (![delegate respondsToSelector:@selector(kkNavigationControllerEnabled)]) {
            return NO;
        } else {
            BOOL enabled = [delegate kkNavigationControllerEnabled];
            if (!enabled) {
                return NO;
            }
        }
        
        if ([delegate respondsToSelector:@selector(allowDragBack)]) {
            BOOL enabled = [delegate allowDragBack];
            if (!enabled) {
                return NO;
            }
        }
    }
    
    UIView* view = gestureRecognizer.view;
    CGPoint loc = [gestureRecognizer locationInView:view];
    UIView* subview = [view hitTest:loc withEvent:nil];
    
    if (subview) {
        // 自底向上，检查view链中是否不允许卡片后退
        for (UIView *view = subview;view != nil; view = view.superview) {
            if ([view conformsToProtocol:@protocol(kkNavigationDelegate)]) {
                id<kkNavigationDelegate> delegate = (id<kkNavigationDelegate>)view;
                if ([delegate respondsToSelector:@selector(allowDragBack)]) {
                    return [delegate allowDragBack];
                }
                
                break;
            }
        }
    }
    
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // 只有当viewControllers里面有元素，拍照才有意义
    // 这样可以保证NavigationController初始化的时候，initWithRootViewController时不会无意义地拍照
    if (self.viewControllers.count > 0) {
        // 性能优化：
        // 如果压入的viewController不需要卡片后退，那么当前页面也不需要拍照了
        // 压入一个NSNull节省性能开销
        
        UIImage *capture;
        if ([viewController conformsToProtocol:@protocol(kkNavigationDelegate)]
            && [viewController respondsToSelector:@selector(kkNavigationControllerEnabled)]
            && [viewController performSelector:@selector(kkNavigationControllerEnabled)]) {
            capture = [self _captureForNavigationController:self];
        } else {
            capture = nil;
        }
        
        // 有时会获得nil，为防止crash使用[NSNull null]放入数组
        if (capture) {
            [self.screenShotsList addObject:capture];
        } else {
            [self.screenShotsList addObject:[NSNull null]];
        }
    }
    
    [super pushViewController:viewController animated:animated];
}

- (void)prepareForPresent:(UINavigationController *)nav
{
    // 不要重复拍照
    if (self.screenShotsList.count == 0) {
        [self.screenShotsList addObject:[self _captureForNavigationController:nav]];
    }
    
    // 表示还有上层navigationController，允许在栈底的viewController上右划dismiss
    self.allowDismiss = YES;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    [self.screenShotsList removeLastObject];
    
    return [super popViewControllerAnimated:animated];
}

#pragma mark - Utility Methods -

// 给present用的函数，如果你想让通过present初始化的
- (UIImage *)_captureForNavigationController:(UINavigationController *)navigationController
{
    UIImage *result = nil;
    UIView *view = navigationController.view;
    
//    原来的方法，性能不好
//    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 1.f);
//    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
//    result = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    
    // 用于去除截屏上部的状态栏
    CGFloat statusBarHeight;
    if ([UIApplication sharedApplication].statusBarHidden) {
        // 状态栏已经隐藏了，那么不需要去除
        statusBarHeight = 0.f;
    } else {
        // 状态栏会在截屏中出现，需要去除
        statusBarHeight = 40.f;
    }
    
    // 使用Apple允许的私有函数，提高截屏性能
    // @see http://www.tuaw.com/2009/12/15/apple-relents-and-is-now-allowing-uigetscreenimage-for-app-st/
    CGImageRef cgScreen = UIGetScreenImage();
    if (cgScreen) {
        CGFloat width = CGImageGetWidth(cgScreen);
        CGFloat height = CGImageGetHeight(cgScreen);
        CGImageRef croppedCgScreen = CGImageCreateWithImageInRect(cgScreen, CGRectMake(0, statusBarHeight, width, height - statusBarHeight));
        if (croppedCgScreen) {
            result = [UIImage imageWithCGImage:croppedCgScreen scale:2.f orientation:UIImageOrientationUp];
            CGImageRelease(croppedCgScreen);
        }
        CGImageRelease(cgScreen);
    }
    
    // iOS7上把状态栏后面的部位填充
    if (result && [[self class] _iOS7WithSDK7]) {
        CGRect targetBounds = view.bounds;
        UIGraphicsBeginImageContextWithOptions(targetBounds.size, NO, 2.f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        UIColor *color = [UIColor colorWithWhite:231.f / 255.f alpha:1.f];
        CGContextSetFillColorWithColor(context, [color CGColor]);
        CGContextFillRect(context, CGRectMake(0, 0, targetBounds.size.width, statusBarHeight));
        
        [result drawInRect:CGRectMake(0, targetBounds.size.height - result.size.height, result.size.width, result.size.height)];
        
        result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    return result;
}

- (void)moveViewWithX:(float)x
{
    x = x>320?320:x;
    x = x<0?0:x;
    
    CGRect frame = self.fakeTopView.frame;
    frame.origin.x = x;
    self.fakeTopView.frame = frame;
    
    float alpha = 0.4 - (x/800);

    blackMask.alpha = alpha;

    // 有的时候拍出来的照片是含状态栏的，有的时候不含，没找到规律，不过无所谓
    // 直接将照片贴着屏幕底边展示即可
    id lastScreenShotObject = [self.screenShotsList lastObject];
    UIImage *lastScreenShot;
    if (lastScreenShotObject == [NSNull null]) {
        lastScreenShot = nil;
    } else {
        lastScreenShot = lastScreenShotObject;
    }
    
    CGFloat lastScreenShotViewHeight = lastScreenShot.size.height;
    CGFloat superviewHeight = lastScreenShotView.superview.frame.size.height;
    CGFloat y = superviewHeight - lastScreenShotViewHeight;
    
    CGFloat gapScale = 0.04 * (kkBackViewWidth - x) / kkBackViewWidth;

    [lastScreenShotView setFrame:CGRectMake(gapScale * kkBackViewWidth,
                                            y + gapScale * lastScreenShotViewHeight,
                                            (1 - 2 * gapScale) * kkBackViewWidth,
                                            (1 - 2 * gapScale) * lastScreenShotViewHeight)];

}

-(BOOL)isBlurryImg:(CGFloat)tmp
{
    return YES;
}

#pragma mark - Gesture Recognizer -

- (void)paningGestureReceive:(UIPanGestureRecognizer *)recoginzer
{
    if (self.screenShotsList.count <= 0) return;
    
    CGPoint touchPoint = [recoginzer locationInView:KEY_WINDOW];
    
    if (recoginzer.state == UIGestureRecognizerStateBegan) {
        
        _isMoving = YES;
        startTouch = touchPoint;
        
        if (!self.backgroundView)
        {
            CGRect frame = self.view.frame;
            
            self.backgroundView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, frame.size.width , frame.size.height)];
            [self.view.superview insertSubview:self.backgroundView belowSubview:self.view];
            
            blackMask = [[UIView alloc]initWithFrame:CGRectMake(0, 0, frame.size.width , frame.size.height)];
            blackMask.backgroundColor = [UIColor blackColor];
            [self.backgroundView addSubview:blackMask];
        }
        
        if (self.fakeTopView == nil) {
            UIImage *snapshotTop = [self _captureForNavigationController:self];
            
            CGRect frame = self.view.frame;
            frame.origin.y += frame.size.height - snapshotTop.size.height;
            frame.size.height = snapshotTop.size.height;
            
            UIImageView *fakeTopView = [[UIImageView alloc] initWithFrame:frame];
            fakeTopView.image = snapshotTop;
            [self.view.superview addSubview:fakeTopView];
            [self.view.superview bringSubviewToFront:fakeTopView];
            self.fakeTopView = fakeTopView;
        }
        
        self.view.hidden = YES;
        self.backgroundView.hidden = NO;
        
        if (lastScreenShotView) [lastScreenShotView removeFromSuperview];
        
        id lastScreenShotObject = [self.screenShotsList lastObject];
        UIImage *lastScreenShot;
        if (lastScreenShotObject == [NSNull null]) {
            lastScreenShot = nil;
        } else {
            lastScreenShot = lastScreenShotObject;
        }
        
        lastScreenShotView = [[UIImageView alloc]initWithImage:lastScreenShot];
        
        startBackViewX = startX;
        [lastScreenShotView setFrame:CGRectMake(startBackViewX,
                                                lastScreenShotView.frame.origin.y,
                                                lastScreenShotView.frame.size.height,
                                                lastScreenShotView.frame.size.width)];

        [self.backgroundView insertSubview:lastScreenShotView belowSubview:blackMask];
    }else if (recoginzer.state == UIGestureRecognizerStateEnded){
        
        if (touchPoint.x - startTouch.x > 80)
        {
            [UIView animateWithDuration:0.3 animations:^{
                [self moveViewWithX:320];
            } completion:^(BOOL finished) {
                if (self.allowDismiss && self.viewControllers.count == 1) {
                    UIViewController *viewController = [self.viewControllers lastObject];
                    if ([viewController conformsToProtocol:@protocol(kkNavigationDelegate)]) {
                        id<kkNavigationDelegate> delegate = (id<kkNavigationDelegate>)viewController;
                        if ([delegate respondsToSelector:@selector(procedureBeforeExit)]) {
                            [delegate procedureBeforeExit];
                        }
                    }
                    
                    [self.fakeTopView removeFromSuperview];
                    [self dismissModalViewControllerAnimated:NO];
                } else if (self.viewControllers.count > 1) {
                    UIViewController *viewController = [self.viewControllers lastObject];
                    if ([viewController conformsToProtocol:@protocol(kkNavigationDelegate)]) {
                        id<kkNavigationDelegate> delegate = (id<kkNavigationDelegate>)viewController;
                        if ([delegate respondsToSelector:@selector(procedureBeforeExit)]) {
                            [delegate procedureBeforeExit];
                        }
                    }
                    
                    self.view.hidden = NO;
                    [self.fakeTopView removeFromSuperview];
                    [self popViewControllerAnimated:NO];
                } else {
                    NSLog(@"Fatal error");
                }
                
                CGRect frame = self.view.frame;
                frame.origin.x = 0;
                self.view.frame = frame;
                
                _isMoving = NO;
            }];
        }
        else
        {
            [UIView animateWithDuration:0.3 animations:^{
                [self moveViewWithX:0];
            } completion:^(BOOL finished) {
                _isMoving = NO;
                self.backgroundView.hidden = YES;
                self.view.hidden = NO;
                [self.fakeTopView removeFromSuperview];
            }];
            
        }
        return;
        
    }else if (recoginzer.state == UIGestureRecognizerStateCancelled){
        
        [UIView animateWithDuration:0.3 animations:^{
            [self moveViewWithX:0];
        } completion:^(BOOL finished) {
            _isMoving = NO;
            self.backgroundView.hidden = YES;
            self.view.hidden = NO;
            [self.fakeTopView removeFromSuperview];
        }];
        
        return;
    }
    
    if (_isMoving) {
        [self moveViewWithX:touchPoint.x - startTouch.x];
    }
}



@end



