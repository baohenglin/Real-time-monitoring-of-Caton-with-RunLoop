
## RunLoop监控卡顿的原理

RunLoop的各种状态：

```
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    kCFRunLoopEntry , // 进入 loop
    kCFRunLoopBeforeTimers , // 触发 Timer 回调
    kCFRunLoopBeforeSources , // 触发 Source0 回调（进入休眠前的状态）
    kCFRunLoopBeforeWaiting , // 即将进入休眠，等待 mach_port 消息
    kCFRunLoopAfterWaiting  , // 接收 mach_port 消息（唤醒线程后的状态）
    kCFRunLoopExit , // 退出 loop
    kCFRunLoopAllActivities  // loop 所有状态改变
}
```

**RunLoop监控卡顿的原理如下**：

如果RunLoop的线程，**进入睡眠前方法的执行时间过长**而导致无法进入睡眠，或者**线程唤醒后接收消息时间过长**而无法进入下一步的话，就可以认为是线程受阻了。如果这个线程是主线程的话，表现出来的就是出现了卡顿。所以，如果我们要利用RunLoop原理来监控卡顿的话，就是要关注这两个阶段。RunLoop在进入睡眠之前和唤醒后的两个loop状态定义的值，分别是**kCFRunLoopBeforeSource**和**kCFRunLoopAfterWaiting**，也就是用来触发Source0回调和接收mach_port消息的这两个状态。

**那么为什么监听kCFRunLoopBeforeSource和kCFRunLoopAfterWaiting这两个状态而不是kCFRunLoopBeforeWaiting和kCFRunLoopAfterWaiting呢？**因为RunLoop进入休眠之前(kCFRunLoopBeforeWaiting)会执行source0等方法，唤醒(kCFRunLoopAfterWaiting)后要接收mach_port消息。如果在执行source0或者接收mach_port消息的时候太耗时，那么就会导致卡顿。我们把kCFRunLoopBeforeSources作为执行Source0S等方法的开始时间节点，将kCFRunLoopAfterWaiting作为接收mach_port消息的开始时间节点，所以只需要监控这两个状态是否超过设定的时间阀值。而如果监控kCFRunLoopBeforeWaiting状态，当监听到kCFRunLoopBeforeWaiting状态时，其实已经执行完了source0，无法监控source0的耗时长短，故不能监听kCFRunLoopBeforeWaiting这个状态。

## 使用方法

(1)导入头文件

```
#import "HLCatonMonitor.h"
```

(2)创建HLCatonMonitor对象并调用“开启监控卡顿”的方法：

```
[[HLCatonMonitor shareInstance] beginMonitor];
```


