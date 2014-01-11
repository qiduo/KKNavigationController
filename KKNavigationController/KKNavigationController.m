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

@interface KKNavigationController () <UIGestureRecognizerDelegate>
{
    CGPoint startTouch;
    
    UIImageView *lastScreenShotView;
    UIView *blackMask;

}

@property (nonatomic,retain) UIView *backgroundView;
@property (nonatomic,retain) NSMutableArray *screenShotsList;

@property (nonatomic,assign) BOOL allowDismiss;
@property (nonatomic,assign) BOOL isMoving;

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
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (!self.canDragBack) {
        return NO;
    }
    
    UIView* view = gestureRecognizer.view;
    CGPoint loc = [gestureRecognizer locationInView:view];
    UIView* subview = [view hitTest:loc withEvent:nil];
    
    if (subview) {
        for (UIView *view = subview;view != nil; view = view.superview) {
            if ([view conformsToProtocol:@protocol(kkNavigationSubviewDeleagte)]) {
                id<kkNavigationSubviewDeleagte> delegate = (id<kkNavigationSubviewDeleagte>)view;
                if ([delegate respondsToSelector:@selector(allowDragBack)]) {
                    BOOL enabled = [delegate allowDragBack];
                    if (!enabled) {
                        NSLog(@"!enabled");
                        return NO;
                    }
                }
                
                break;
            }
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // 这个事件可能会先于其它的GestureRecognizer执行。如果return NO， 很可能会屏蔽其它GestureRecoginzer
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
    if (self.viewControllers.count > 0) {
        [self.screenShotsList addObject:[self capture]];
    }
    
    [super pushViewController:viewController animated:animated];
}

- (void)prepareForPresent:(UINavigationController *)nav
{
    // 不要重复拍照
    if (self.screenShotsList.count == 0) {
        [self.screenShotsList addObject:[self captureForPresent:nav]];
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

- (UIImage *)capture
{
    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, self.view.opaque, 0.0);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

// 给present用的函数，如果你想让通过present初始化的
- (UIImage *)captureForPresent:(UINavigationController *)navigationController
{
    UIGraphicsBeginImageContextWithOptions(navigationController.view.bounds.size, navigationController.view.opaque, 0.0);
    [navigationController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

- (void)moveViewWithX:(float)x
{
    x = x>320?320:x;
    x = x<0?0:x;
    
    CGRect frame = self.view.frame;
    frame.origin.x = x;
    self.view.frame = frame;
    
    float alpha = 0.4 - (x/800);

    blackMask.alpha = alpha;

    CGFloat lastScreenShotViewHeight = kkBackViewHeight;
    CGFloat y = 0.f;
    
    //TODO: FIX self.edgesForExtendedLayout = UIRectEdgeNone  SHOW BUG
/**
 *  if u use self.edgesForExtendedLayout = UIRectEdgeNone; pls add

    if (!iOS7) {
        lastScreenShotViewHeight = lastScreenShotViewHeight - 20;
    }
 *
 */
    if ([[self class] _iOS7WithSDK7]) {
        
    } else {
        // 有的时候拍出来的照片是含状态栏的，有的时候不含，没找到规律，不过无所谓
        // 并且也不需要考虑wantFullScreenLayout变量, lastScreenShotView定位是全屏幕的
        UIImage *lastScreenShot = [self.screenShotsList lastObject];
        
        lastScreenShotViewHeight = lastScreenShot.size.height;
        y = kkBackViewHeight - lastScreenShotViewHeight;
    }
    [lastScreenShotView setFrame:CGRectMake(0,
                                            y,
                                            kkBackViewWidth,
                                            lastScreenShotViewHeight)];

}



-(BOOL)isBlurryImg:(CGFloat)tmp
{
    return YES;
}

#pragma mark - Gesture Recognizer -

- (void)paningGestureReceive:(UIPanGestureRecognizer *)recoginzer
{
    if (self.screenShotsList.count <= 0 || !self.canDragBack) return;
    
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
        
        self.backgroundView.hidden = NO;
        
        if (lastScreenShotView) [lastScreenShotView removeFromSuperview];
        
       
        UIImage *lastScreenShot = [self.screenShotsList lastObject];
        
        lastScreenShotView = [[UIImageView alloc]initWithImage:lastScreenShot];
        
        startBackViewX = startX;
        [lastScreenShotView setFrame:CGRectMake(startBackViewX,
                                                lastScreenShotView.frame.origin.y,
                                                lastScreenShotView.frame.size.height,
                                                lastScreenShotView.frame.size.width)];

        [self.backgroundView insertSubview:lastScreenShotView belowSubview:blackMask];
        
    }else if (recoginzer.state == UIGestureRecognizerStateEnded){
        
        if (touchPoint.x - startTouch.x > 50)
        {
            [UIView animateWithDuration:0.3 animations:^{
                [self moveViewWithX:320];
            } completion:^(BOOL finished) {
                if (self.allowDismiss && self.viewControllers.count == 1) {
                    [self dismissModalViewControllerAnimated:NO];
                } else if (self.viewControllers.count > 1) {
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
            }];
            
        }
        return;
        
    }else if (recoginzer.state == UIGestureRecognizerStateCancelled){
        
        [UIView animateWithDuration:0.3 animations:^{
            [self moveViewWithX:0];
        } completion:^(BOOL finished) {
            _isMoving = NO;
            self.backgroundView.hidden = YES;
        }];
        
        return;
    }
    
    if (_isMoving) {
        [self moveViewWithX:touchPoint.x - startTouch.x];
    }
}



@end



