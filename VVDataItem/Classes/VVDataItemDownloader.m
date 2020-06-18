//
//  VVDataItemDownloader.m
//  MvBox
//
//  Created by jufan wang on 2020/2/28.
//  Copyright © 2020 mvbox. All rights reserved.
//

#import "VVDataItemDownloader.h"

#import "VVDataItemReceiptorManager.h"
#import "VVDataItemIdentifier.h"


static NSString * kVVDataItemDownloaderError = @"kVVDataItemDownloaderError";
#define kVVDataItemDownloaderErrorCodeParaIlegal 1001


@interface VVDataResponseHandler : NSObject<VVDataItemIdentifier>
@property (nonatomic, copy) NSString *dataItemID;
@property (nonatomic, copy) NSString *dataItemVersion;
@property (nonatomic, copy) void (^successBlock)(id<VVDataItemIdentifier> data);
@property (nonatomic, copy) void (^failureBlock)(NSString *dataItemID, NSError* error);
@end
@implementation VVDataResponseHandler
- (instancetype)initWithSuccess:(nullable void (^)(id<VVDataItemIdentifier> data))success
                     failure:(nullable void (^)(NSString *dataItemID, NSError* error))failure {
    if (self = [self init]) {
        self.successBlock = success;
        self.failureBlock = failure;
    }
    return self;
}
- (NSString *)description {
    return [NSString stringWithFormat: @"<VVDataResponseHandler>requesterID: %@", self.dataItemID];
}
@end

@interface VVDataDownloaderMergedTask : NSObject<VVDataItemIdentifier>
@property (nonatomic, copy) NSString *dataItemID;
@property (nonatomic, copy) NSString *dataItemVersion;

@property (nonatomic, strong) NSMutableArray <VVDataResponseHandler*> *responseHandlers;
@end
@implementation VVDataDownloaderMergedTask
- (instancetype)init {
    if (self = [super init]) {
        self.responseHandlers = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)addResponseHandler:(VVDataResponseHandler*)handler {
    [self.responseHandlers addObject:handler];
}
- (void)removeResponseHandler:(VVDataResponseHandler*)handler {
    [self.responseHandlers removeObject:handler];
}
@end


@interface VVDataItemDownloader()

@property (class, nonatomic, strong) NSMutableDictionary<NSString *, VVDataItemDownloader *> *downloaders;
@property (nonatomic, strong) NSMutableDictionary<NSString *, VVDataDownloaderMergedTask *> *queuedMergedTasks;
@property (nonatomic, strong) NSMutableDictionary<NSString *, VVDataDownloaderMergedTask *> *mergedTasks;

@property (nonatomic, strong) id<VVDataItemDownloaderDelegate> dataLoaderDelegate;

@property (nonatomic, strong) dispatch_queue_t requestQueue;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) dispatch_queue_t responseQueue;
@property (nonatomic, strong) dispatch_semaphore_t semphore;

@property (nonatomic, assign) NSInteger maxHTTPConnection;
@property (nonatomic, assign) NSInteger currentHTTPConnection;
@property (nonatomic, assign) NSInteger pageSize;

@property (nonatomic, assign) NSTimeInterval preTimeInterval;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) NSString *categoryID;

@property (nonatomic, weak) VVDataItemReceiptorManager *receiptorManager;

@end


@implementation VVDataItemDownloader

@synthesize dataLoaderDelegate = _dataLoaderDelegate;


static NSMutableDictionary<NSString *, VVDataItemDownloader *> *_downloaders;

+ (NSMutableDictionary<NSString *, VVDataItemDownloader *> *)downloaders {
    
    if (!_downloaders) {
        _downloaders = [NSMutableDictionary dictionary];
    }
    return _downloaders;
}
+ (void)setDownloaders:(NSMutableDictionary<NSString *, VVDataItemDownloader *> *)downloaders {
    _downloaders = downloaders;
}

+ (instancetype)creatDownloaderWithDelegate:(id<VVDataItemDownloaderDelegate>)delegate
                             dataCategoryID:(NSString *)dataCategoryID {
    if (!delegate || !dataCategoryID) {
        return nil;
    }
    VVDataItemDownloader *downloader = nil;
    @synchronized (self) {
        downloader = [[self downloaders] objectForKey:dataCategoryID];
        if (!downloader) {
            downloader = [[VVDataItemDownloader alloc] init];
            downloader.dataLoaderDelegate = delegate;
            downloader.categoryID = dataCategoryID;
            [[self downloaders] setObject:downloader forKey:dataCategoryID];
        } else {
            NSAssert(0, @"VVDataItemDownloader for %@ existed already !", delegate);
        }
    }
    return downloader;
}
+ (void)removeDownloaderWithDataCategoryID:(NSString *)dataCategoryID {
    if (!dataCategoryID) {
        return;
    }
    @synchronized (self) {
        [[self downloaders] removeObjectForKey:dataCategoryID];
    }
}
+ (instancetype)getDownloaderWithDataCategoryID:(NSString *)dataCategoryID {
    VVDataItemDownloader *downloader = nil;
    @synchronized (self) {
        downloader = [[self downloaders] objectForKey:dataCategoryID];
    }
    return downloader;
}

- (instancetype)init {
    if (self = [super init]) {
        _semphore = dispatch_semaphore_create(1);
        _queuedMergedTasks = [[NSMutableDictionary alloc] init];
        _mergedTasks = [[NSMutableDictionary alloc] init];

        _requestQueue = dispatch_queue_create("com.51vv.dataItemRequestQueue", DISPATCH_QUEUE_SERIAL);
        _responseQueue = dispatch_queue_create("com.51vv.dataItemResponseQueue", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_queue_create("com.51vv.dataItemCallbackQueue", DISPATCH_QUEUE_SERIAL);
        
        _minTimeInterval = 1;
        _preTimeInterval = CACurrentMediaTime();
        _maxHTTPConnection = 1;
        _currentHTTPConnection = 0;
    }
    return self;
}

- (void)startTimer {
    if (!self.timer) {
        self.timer = [NSTimer timerWithTimeInterval:self.minTimeInterval target:self selector:@selector(timerDispatch) userInfo:nil repeats:true];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
        [self.timer fire];
    }
}

- (void)timerDispatch {
    __weak typeof(self) wself = self;
    dispatch_async(self.requestQueue, ^{
        __strong typeof(wself) self = wself;
        [self tryDispatch];
    });
}

- (void)finishTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)setDataLoaderDelegate:(id<VVDataItemDownloaderDelegate>)dataLoaderDelegate {
    _dataLoaderDelegate = dataLoaderDelegate;
    self.maxHTTPConnection = [_dataLoaderDelegate dataDownLoaderMaxHTTPConnection:self];
    self.pageSize = [_dataLoaderDelegate dataDownLoaderPageSize:self];
}

- (void)downloaderLock {
    dispatch_semaphore_wait(self.semphore, DISPATCH_TIME_FOREVER);
}

- (void)downloaderUnlock {
    dispatch_semaphore_signal(self.semphore);
}

- (id<VVDataItemIdentifier>)memoryDataItemWithID:(NSString *)dataID {
    return (id<VVDataItemIdentifier>)[self.cache memoryObjectForKey:dataID];
}

- (VVDataItemReceiptorManager *)receiptorManager {
    if (!_receiptorManager) {
        _receiptorManager = [VVDataItemReceiptorManager managerForDataCategoryID:self.categoryID];
    }
    return _receiptorManager;
}

- (void)getDataItemWithID:(nonnull NSString *)dataItemID
                  success:(nonnull void (^)(id<VVDataItemIdentifier> data))success
                  failure:(nonnull void (^)(NSString *dataItemID, NSError* error))failure {
    if (!dataItemID || !success || !failure) {
        if (failure) {
            NSError *error = [NSError errorWithDomain:kVVDataItemDownloaderError code:kVVDataItemDownloaderErrorCodeParaIlegal userInfo:nil];
            dispatch_async(self.callbackQueue, ^{
                 failure(dataItemID, error);
            });
        }
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_sync(self.requestQueue, ^{
        __strong typeof(wself) self = wself;
        if (!self) {
            return;
        }
        
        [self downloaderLock];
        
        id<VVDataItemIdentifier> wrapper = (id<VVDataItemIdentifier>)[self.cache objectForKey:dataItemID];
        if (wrapper) {
            if (success) {
                dispatch_async(self.callbackQueue, ^{
                    success(wrapper);
                });
            }
            [self downloaderUnlock];
            return;
        }
        
        VVDataDownloaderMergedTask *mergedTask = nil;
        mergedTask = self.mergedTasks[dataItemID];
        if (!mergedTask) {
            mergedTask = self.queuedMergedTasks[dataItemID];
        }
        
        if (mergedTask) {
            VVDataResponseHandler *responseHandler = [[VVDataResponseHandler alloc] initWithSuccess:success failure:failure];
            responseHandler.dataItemID = dataItemID;
            [mergedTask addResponseHandler:responseHandler];
            [self downloaderUnlock];
            dispatch_async(self.requestQueue, ^{
                [self tryDispatch];
            });
            return;
        };
                
        mergedTask = [[VVDataDownloaderMergedTask alloc] init];
        mergedTask.dataItemID = dataItemID;
        self.mergedTasks[dataItemID] = mergedTask;
        
        VVDataResponseHandler *handler = [[VVDataResponseHandler alloc] initWithSuccess:success failure:failure];
        handler.dataItemID = dataItemID;
        [mergedTask addResponseHandler:handler];
                
        [self downloaderUnlock];
        dispatch_async(self.requestQueue, ^{
            [self tryDispatch];
        });
    });
}

- (void)tryDispatch {
    NSArray * requestIDs = [self requestDataIDs];
    if (requestIDs.count) {
        [self downloaderLock];
        self.currentHTTPConnection++;
        [self downloaderUnlock];
        
        __weak typeof(self) wself = self;
        [self.dataLoaderDelegate dataDownLoader:self
                                       loadData:requestIDs
                                   successBlock:^(NSArray<NSString *> *dataItemIDs, NSArray<id<VVDataItemIdentifier, NSCoding>> * _Nonnull response) {
            __strong typeof(wself) self = wself;
            if (!self) {
                return ;
            }
            dispatch_async(self.responseQueue, ^{
                [self downloaderLock];
                self.currentHTTPConnection--;
                NSMutableArray<VVDataResponseHandler *> *finishTasks = [NSMutableArray array];
                for (id<VVDataItemIdentifier, NSCoding> data in response) {
                    [self.cache setObject:data forKey:[data dataItemID]];
                    VVDataDownloaderMergedTask *mergedTask = self.queuedMergedTasks[[data dataItemID]];
                    if (mergedTask) {
                         self.queuedMergedTasks[[data dataItemID]] = nil;
                        [finishTasks addObjectsFromArray:mergedTask.responseHandlers];
                    }
                }
                for (NSString *dataID in dataItemIDs) {
                    if (self.queuedMergedTasks[dataID]) {
                        self.queuedMergedTasks[dataID] = nil;
                    }
                    if (self.mergedTasks[dataID]) {
                        self.mergedTasks[dataID] = nil;
                    }
                }
                [self downloaderUnlock];

                dispatch_async(self.requestQueue, ^{
                    [self tryDispatch];
                });
                dispatch_async(self.callbackQueue, ^{
                    for (VVDataResponseHandler *handler in finishTasks) {
                        id<VVDataItemIdentifier> dataItem = (id<VVDataItemIdentifier>)[self.cache objectForKey:handler.dataItemID];
                        if (handler.successBlock) {
                            handler.successBlock(dataItem);
                        }
                    }
                    [self.receiptorManager dataItemsUpdated:[response copy]];
                });
            });
        } failureBlock:^(NSArray<NSString *> * _Nonnull dataItemIDs,
                         NSError * _Nullable error) {
            __strong typeof(wself) self = wself;
            if (!self) {
                return ;
            }
            dispatch_async(self.responseQueue, ^{
                [self downloaderLock];
                self.currentHTTPConnection--;
                NSMutableArray<VVDataResponseHandler *> *finishTasks = [NSMutableArray array];
                
                for (NSString *dataItemID in dataItemIDs) {
                    VVDataDownloaderMergedTask *mergedTask = self.queuedMergedTasks[dataItemID];
                    if (mergedTask) {
                        self.queuedMergedTasks[dataItemID] = nil;
                        [finishTasks addObjectsFromArray:mergedTask.responseHandlers];
                    }
                    if (self.queuedMergedTasks[dataItemID]) {
                        self.queuedMergedTasks[dataItemID] = nil;
                    }
                    if (self.mergedTasks[dataItemID]) {
                        self.mergedTasks[dataItemID] = nil;
                    }
                }
                [self downloaderUnlock];
                
                dispatch_async(self.callbackQueue, ^{
                    for (VVDataResponseHandler *handler in finishTasks) {
                        id<VVDataItemIdentifier> dataItem = (id<VVDataItemIdentifier>)[self.cache objectForKey:handler.dataItemID];
                        if (handler.failureBlock) {
                            handler.failureBlock(dataItem.dataItemID, error);
                        }
                    }
                    
                });
            });
        }];
    }
}

- (NSArray *)requestDataIDs {
    NSMutableArray *dataIDs = [NSMutableArray array];
    [self downloaderLock];
    NSTimeInterval currentTimeInterval = CACurrentMediaTime();
    if (currentTimeInterval - self.preTimeInterval >= self.minTimeInterval) {
        self.preTimeInterval = currentTimeInterval;
        if (self.currentHTTPConnection < self.maxHTTPConnection) {
            NSArray *keys = [self.mergedTasks allKeys];
            int couter = 0;
            for (NSString *dataID in keys) {
                if (couter++ > self.pageSize) {
                    break;
                }
                [dataIDs addObject:dataID];
                self.queuedMergedTasks[dataID] = self.mergedTasks[dataID];
                self.mergedTasks[dataID] = nil;
            }
        }
        if (!dataIDs.count) {
            [self finishTimer];
        }
    } else {
        [self startTimer];
    }
    [self downloaderUnlock];
    return [dataIDs copy];
}

- (void)updateData:(NSArray<id<VVDataItemIdentifier>> *)dataIDsList {
    __weak typeof(self) wself = self;
    dispatch_async(self.requestQueue, ^{
        __strong typeof(wself) self = wself;
        if (!self) {
            return;
        }
        for (id<VVDataItemIdentifier> data in dataIDsList) {
            if (!data.dataItemID) {
                continue;
            }
            [self downloaderLock];
            if (self.mergedTasks[data.dataItemID]
                || self.queuedMergedTasks[data.dataItemID]) {
                [self downloaderUnlock];
                continue;
            }
            [self downloaderUnlock];
            id<VVDataItemIdentifier> storeData = (id<VVDataItemIdentifier>)[self.cache objectForKey:[data dataItemID]];
            if ([storeData.dataItemVersion compare:data.dataItemVersion] == NSOrderedAscending
                || !storeData) {
                VVDataDownloaderMergedTask *mergedTask = [[VVDataDownloaderMergedTask alloc] init];
                mergedTask.dataItemVersion = data.dataItemVersion;
                mergedTask.dataItemID = data.dataItemID;
                self.mergedTasks[data.dataItemID] = mergedTask;
            }
        }
        dispatch_async(self.requestQueue, ^{
            [self tryDispatch];
        });
    });
}

- (void)saveDataItem:(nullable id<VVDataItemIdentifier,NSCopying>)model dataItemID:(nullable id<VVDataItemIdentifier>)dataItemID {
    __weak typeof(self) wself = self;
    dispatch_async(self.requestQueue, ^{
        __strong typeof(wself) self = wself;
        id<VVDataItemIdentifier> wrapper = (id<VVDataItemIdentifier>)[self.cache objectForKey:dataItemID.dataItemID];
        if (wrapper) {
            model.dataItemVersion = wrapper.dataItemVersion;
        }
        id<VVDataItemIdentifier, NSCoding> data = (id<VVDataItemIdentifier, NSCoding>)model;
        [self.cache setObject:data forKey:[data dataItemID]];
    });
}

@end

