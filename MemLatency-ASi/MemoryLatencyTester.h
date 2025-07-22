//
//  MemoryLatencyTester.h
//  MemLatency-ASi
//
//  Created by Celestial紗雪 on 2025/7/22.
//

#import <Foundation/Foundation.h>

typedef void (^TestProgressBlock)(double latency, NSInteger sizeKb);
typedef void (^TestCompletionBlock)(void);

@interface MemoryLatencyTester : NSObject

@property (atomic) BOOL isCancelled;

- (void)stopTest;

- (void)runLatencyTestsWithParameters:(NSDictionary<NSNumber *, NSNumber *> *)testParameters
                        testOnECore:(BOOL)testOnECore
                           progress:(TestProgressBlock)progress
                         completion:(TestCompletionBlock)completion;

@end
