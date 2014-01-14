//
//  KKNavigationController.h
//  TS
//
//  Created by Coneboy_K on 13-12-2.
//  Copyright (c) 2013年 Coneboy_K. All rights reserved. MIT
//  WELCOME TO MY BLOG  http://www.coneboy.com
//

#import <UIKit/UIKit.h>

#define KEY_WINDOW  [[UIApplication sharedApplication]keyWindow]
#define kkBackViewWidth [UIScreen mainScreen].bounds.size.width

#define iOS7  ( [[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending )

// 背景视图起始frame.x
#define startX 0;


@protocol kkNavigationDeleagte <NSObject>

@optional
// 对于每个viewController，如果它想在自己的页面上启用kkNavigationController的特性，必须显示地实现下面这个函数，并且返回YES
// viewController可以自由控制本页面上是否启用，默认不启用（不实现也不启用)
// only for viewController
- (BOOL)kkNavigationControllerEnabled;

// 这个函数粒度最细，在kkNavigationControllerEnabled的情况下，可以根据条件暂时性的关闭滑动后退
// 例如含有缩放功能的view，它们可以在处于放大模式下，返回NO，以禁用右划返回
// for viewController and view
- (BOOL)allowDragBack;

// 在返回前做一些清理工作
- (void)procedureBeforeExit;

@end

@interface KKNavigationController : UINavigationController
{
    CGFloat startBackViewX;
}

// 默认为特效开启
@property (nonatomic, assign) BOOL canDragBack;

- (void)prepareForPresent:(UINavigationController *)nav;

@end
