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

- (void)runLatencyTestsWithParameters:(NSDictionary<NSNumber *, NSNumber *> *)testParameters
                          testOnECore:(BOOL)testOnECore
                             progress:(TestProgressBlock)progress
                           completion:(TestCompletionBlock)completion {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        
        if (testOnECore) {
            struct sched_param param;
            param.sched_priority = 6;
            pthread_setschedparam(pthread_self(), SCHED_OTHER, &param);
        }
        
        NSArray<NSNumber *> *sortedSizes = [[testParameters allKeys] sortedArrayUsingSelector:@selector(compare:)];

        for (NSNumber *sizeNumber in sortedSizes) {
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
                current = testArr[current];
            }

            uint64_t endTime = mach_absolute_time();

            free(testArr);

            uint64_t elapsed = endTime > startTime ? endTime - startTime : 0;
            uint64_t elapsedNanos = elapsed * timebase.numer / timebase.denom;
            double latency = (double)elapsedNanos / currentIterations;

            if (latency > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(latency, sizeKb);
                });
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    });
}
@end
