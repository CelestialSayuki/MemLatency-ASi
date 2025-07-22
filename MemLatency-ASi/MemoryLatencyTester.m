//
//  MemoryLatencyTester.m
//  MemLatency-ASi
//
//  Created by Celestial紗雪 on 2025/7/22.
//

#import "MemoryLatencyTester.h"
#import <mach/mach_time.h>
#import <pthread/sched.h>
#import <pthread.h>

@implementation MemoryLatencyTester

- (void)stopTest {
    self.isCancelled = YES;
}

- (void)runLatencyTestsWithParameters:(NSDictionary<NSNumber *, NSNumber *> *)testParameters
                        testOnECore:(BOOL)testOnECore
                           progress:(TestProgressBlock)progress
                         completion:(TestCompletionBlock)completion {
    
    self.isCancelled = NO;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if (testOnECore) {
            pthread_set_qos_class_self_np(9, 0);
        } else {
            pthread_set_qos_class_self_np(33, 0);
        }

        NSArray<NSNumber *> *sortedSizes = [[testParameters allKeys] sortedArrayUsingSelector:@selector(compare:)];

        for (NSNumber *sizeNumber in sortedSizes) {
            if (self.isCancelled) {
                break;
            }
            
            NSInteger sizeKb = [sizeNumber integerValue];
            NSInteger currentIterations = [testParameters[sizeNumber] integerValue];
            
            mach_timebase_info_data_t timebase;
            mach_timebase_info(&timebase);

            long listSize = sizeKb * 1024 / sizeof(uint32_t);
            uint32_t *testArr = malloc(listSize * sizeof(uint32_t));
            if (!testArr) continue;

            for (uint32_t i = 0; i < listSize; i++) {
                testArr[i] = i;
            }

            for (long i = listSize - 1; i > 0; i--) {
                long j = arc4random_uniform((uint32_t)i + 1);
                uint32_t temp = testArr[i];
                testArr[i] = testArr[j];
                testArr[j] = temp;
            }

            uint64_t startTime = mach_absolute_time();
            
            volatile uint32_t current = testArr[0];
            for (NSInteger i = 0; i < currentIterations; i++) {
                if ((i & 0xFFFFF) == 0 && self.isCancelled) {
                    break;
                }
                current = testArr[current];
            }

            uint64_t endTime = mach_absolute_time();

            free(testArr);

            if (self.isCancelled) {
                break;
            }
            
            uint64_t elapsed = endTime > startTime ? endTime - startTime : 0;
            uint64_t elapsedNanos = elapsed * timebase.numer / timebase.denom;
            double latency = (double)elapsedNanos / currentIterations;

            if (latency > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(latency, (int)sizeKb);
                });
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    });
}
@end
