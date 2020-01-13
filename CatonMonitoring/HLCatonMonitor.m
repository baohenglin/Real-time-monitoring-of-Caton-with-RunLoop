//
//  SMLagMonitor.m
//  CatonMonitoring
//
//  Created by BaoHenglin on 2019/8/27.
//  Copyright © 2019 BaoHenglin. All rights reserved.
//

#import "HLCatonMonitor.h"
#import <CrashReporter/CrashReporter.h>
#import <CrashReporter/PLCrashReportTextFormatter.h>
//连续卡顿次数
#define ContinuousNumberOfCycles  3
@interface HLCatonMonitor() {
    int timeoutCount;
    CFRunLoopObserverRef runLoopObserver;
@public
    dispatch_semaphore_t dispatchSemaphore;
    CFRunLoopActivity runLoopActivity;
}
@end

@implementation HLCatonMonitor

#pragma mark - Interface
+ (instancetype)shareInstance {
    static id instance = nil;
    static dispatch_once_t dispatchOnce;
    dispatch_once(&dispatchOnce, ^{
        instance = [[self alloc] init];
    });
    return instance;
}
//监测卡顿
- (void)beginMonitor {
    if (runLoopObserver) {
        return;
    }
    //创建信号量，参数表示信号量的初始值，如果小于0则会返回NULL
    dispatchSemaphore = dispatch_semaphore_create(0); //Dispatch Semaphore保证同步
    //创建一个观察者的上下文 CFRunLoopObserverContext
    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    /*
     CF_EXPORT CFRunLoopObserverRef CFRunLoopObserverCreate(CFAllocatorRef allocator, CFOptionFlags activities, Boolean repeats, CFIndex order, CFRunLoopObserverCallBack callout, CFRunLoopObserverContext *context);
     
     第1个参数allocator：用于分配observer对象的内存；
     第2个参数activities：用以设置observer所要关注的事件；
     第3个参数repeats：用于标识该observer是在第一次进入runloop时执行还是每次进入runloop处理时均执行。
     第4个参数order：用于设置该observer的优先级；
     第5个参数callout：用于设置该observer的回调函数；
     第6个参数context：设置该observer的上下文
     */
    // 创建观察者 runLoopObserver
    runLoopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                              kCFRunLoopAllActivities,
                                              YES,
                                              0,
                                              &runLoopObserverCallBack,
                                              &context);
    //将创建好的观察者 runLoopObserver 添加到主线程 runloop 的 kCFRunLoopCommonModes 模式下的观察中
    CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    //创建一个持续的子线程专门用来监控主线程的 RunLoop 状态。
    // dispatch_get_global_queue 全局并发队列
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //子线程开启一个持续的 loop 用来进行实时监控。
        while (YES) {
            /*
        dispatch_semaphore_wait：该方法首先会将信号量值减一，如果大于等于0就立即返回(不休眠)，否则等待信号量唤醒或者等待超时；当首次执行到dispatch_semaphore_wait方法时，由于此时信号量的初始值为0，减1之后值为-1，所以线程会进入休眠状态等待信号量唤醒。如果等待了20ms，仍然无法唤醒该线程，即超时，此时返回的semaphoreWait的值为非0；如果20ms的时间内信号量唤醒了该线程，则semaphoreWait=0。
             */
            //dispatch_semaphore_wait 成功时返回0，如果超时，则返回非0.
            //20*NSEC_PER_MSEC 表示20毫秒(ms)，此处将监控卡顿的时间阀值设置为20ms。
            long semaphoreWait = dispatch_semaphore_wait(self->dispatchSemaphore, dispatch_time(DISPATCH_TIME_NOW, 20*NSEC_PER_MSEC));
            //信号量超时了，即 runloop 的状态长时间没有发生变更,长时间处于某一个状态。
            if (semaphoreWait != 0) {
                if (!self->runLoopObserver) {
                    self->timeoutCount = 0;
                    self->dispatchSemaphore = 0;
                    self->runLoopActivity = 0;
                    return;
                }
                NSString *runloopStatusStr = @"";
                if (self->runLoopActivity == kCFRunLoopEntry) {  // 即将进入RunLoop
                    runloopStatusStr = @"kCFRunLoopEntry";
                } else if (self->runLoopActivity == kCFRunLoopBeforeTimers) {    // 即将处理Timer
                    runloopStatusStr = @"kCFRunLoopBeforeTimers";
                } else if (self->runLoopActivity == kCFRunLoopBeforeSources) {   // 即将处理Source
                    runloopStatusStr = @"kCFRunLoopBeforeSources";
                } else if (self->runLoopActivity == kCFRunLoopBeforeWaiting) {   //即将进入休眠
                    runloopStatusStr = @"kCFRunLoopBeforeWaiting";
                } else if (self->runLoopActivity == kCFRunLoopAfterWaiting) {    // 刚从休眠中唤醒
                    runloopStatusStr = @"kCFRunLoopAfterWaiting";
                } else if (self->runLoopActivity == kCFRunLoopExit) {    // 即将退出RunLoop
                    runloopStatusStr = @"kCFRunLoopExit";
                } else if (self->runLoopActivity == kCFRunLoopAllActivities) {
                    runloopStatusStr = @"kCFRunLoopAllActivities";
                }
                //两个runloop的状态，BeforeSources和AfterWaiting这两个状态区间时间能够检测到是否卡顿
            /*
                 问题1：为什么监控kCFRunLoopBeforeSources和kCFRunLoopAfterWaiting这两个RunLoop的状态就可以判断是否卡顿呢？
           答：因为RunLoop进入休眠之前(kCFRunLoopBeforeWaiting)会执行source0等方法，唤醒(kCFRunLoopAfterWaiting)后要接收mach_port消息。如果在执行source0或者接收mach_port消息的时候太耗时，那么就会导致卡顿。我们把kCFRunLoopBeforeSources作为执行Source0S等方法的开始时间点，将kCFRunLoopAfterWaiting作为接收mach_port消息的开始时间点，所以只需要监控这两个状态是否超过设定的时间阀值。如果连续超过3次或者5次那么就可以判断产生了卡顿。（如果监控kCFRunLoopBeforeWaiting状态，能执行到此状态，说明已经执行完了source0，所以无法监控source0的耗时长短。）
                 **/
                if (self->runLoopActivity == kCFRunLoopBeforeSources || self->runLoopActivity == kCFRunLoopAfterWaiting) {
                //判断卡顿采用了“一个时间段内卡顿的次数累计大于 n 时才触发采集和上报”的判定策略。假设连续3次超时20ms认为卡顿(当然也包含了单次超时60ms)
                    //出现三次超时的话
                    if (++self->timeoutCount < ContinuousNumberOfCycles) {
                        NSLog(@"连续卡顿次数=%d*******%@",self->timeoutCount,runloopStatusStr);
                        continue;
                    }
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        NSLog(@"monitor trigger--------卡卡卡卡");
                        // 收集导致卡顿的函数调用堆栈信息
                        [self collecteCatonMsgWithRunLoopStatus:runloopStatusStr];
                    });
                } //end activity
            }// end semaphore wait
            self->timeoutCount = 0;
        }// end while
    });
    
}
//结束监控卡顿操作
- (void)endMonitor {
    if (!runLoopObserver) {
        return;
    }
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    CFRelease(runLoopObserver);
    runLoopObserver = NULL;
}
/*
 kCFRunLoopEntry = (1UL << 0),              // 进入 loop
 kCFRunLoopBeforeTimers = (1UL << 1),       // 触发 Timer 回调
 kCFRunLoopBeforeSources = (1UL << 2),      //触发 Source0 回调
 kCFRunLoopBeforeWaiting = (1UL << 5),      //即将进入休眠状态，休眠时等待 mach_port 消息
 kCFRunLoopAfterWaiting = (1UL << 6),       //唤醒后接收 mach_port 消息（唤醒线程后的状态）
 kCFRunLoopExit = (1UL << 7),               // 退出 loop
 kCFRunLoopAllActivities = 0x0FFFFFFFU      // loop 所有状态改变
 */
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    HLCatonMonitor *lagMonitor = (__bridge HLCatonMonitor*)info;
    lagMonitor->runLoopActivity = activity;
    
    dispatch_semaphore_t semaphore = lagMonitor->dispatchSemaphore;
    //dispatch_semaphore_signal 会将信号量值加一，如果value大于0立即返回，否则唤醒某个等待中的线程
    dispatch_semaphore_signal(semaphore);
    //打印RunLoop状态
    if (activity == kCFRunLoopEntry) {  // 即将进入RunLoop
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopEntry");
    } else if (activity == kCFRunLoopBeforeTimers) {    // 即将处理Timer
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopBeforeTimers");
    } else if (activity == kCFRunLoopBeforeSources) {   // 即将处理Source
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopBeforeSources");
    } else if (activity == kCFRunLoopBeforeWaiting) {   //即将进入休眠
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopBeforeWaiting");
    } else if (activity == kCFRunLoopAfterWaiting) {    // 刚从休眠中唤醒
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopAfterWaiting");
    } else if (activity == kCFRunLoopExit) {    // 即将退出RunLoop
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopExit");
    } else if (activity == kCFRunLoopAllActivities) {
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopAllActivities");
    }
}
//利用PLCrashReporter三方库收集导致卡顿的函数调用栈信息
- (void)collecteCatonMsgWithRunLoopStatus:(NSString *)runLoopStatus{
    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll];
    PLCrashReporter *crashReporter = [[PLCrashReporter alloc] initWithConfiguration:config];
    NSData *data = [crashReporter generateLiveReport];
    PLCrashReport *reporter = [[PLCrashReport alloc] initWithData:data error:NULL];
    NSString *report = [PLCrashReportTextFormatter stringValueForCrashReport:reporter withTextFormat:PLCrashReportTextFormatiOS];
    // 将导致卡顿的堆栈信息上报服务端
    NSLog(@"---------卡顿信息%@\n%@\n--------------",runLoopStatus,report);
}
@end
