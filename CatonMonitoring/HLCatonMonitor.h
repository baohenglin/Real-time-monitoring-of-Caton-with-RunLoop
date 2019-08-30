//
//  SMLagMonitor.h
//  CatonMonitoring
//
//  Created by BaoHenglin on 2019/8/27.
//  Copyright © 2019 BaoHenglin. All rights reserved.
//

/*
 1秒(s) =1000 毫秒(ms) = 1,000,000 微秒(μs) = 1,000,000,000 纳秒(ns)
 
 PER：每
 SEC：秒
 MSEC：毫秒
 USEC：微妙
 NSEC：纳秒
 
 #define NSEC_PER_SEC 1000000000ull     每秒有1000,000,000 纳秒
 #define NSEC_PER_MSEC 1000000ull       每毫秒有1000,000 纳秒
 #define USEC_PER_SEC 1000000ull        每秒有1000,000 微妙
 #define NSEC_PER_USEC 1000ull          每微妙有1000 纳秒
 */
#import <Foundation/Foundation.h>
//利用RunLoop来监控卡顿
NS_ASSUME_NONNULL_BEGIN

@interface HLCatonMonitor : NSObject
+ (instancetype)shareInstance;
- (void)beginMonitor;
@end

NS_ASSUME_NONNULL_END
