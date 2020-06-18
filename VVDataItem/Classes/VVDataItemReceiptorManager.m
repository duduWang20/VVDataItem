//
//  VVDataItemReceiptorManager.m
//  MvBox
//
//  Created by jufan wang on 2020/2/29.
//  Copyright © 2020 mvbox. All rights reserved.
//

#import "VVDataItemReceiptorManager.h"

#import "VVDataItemIdentifier.h"
#import "VVDataItemDownloader.h"

static NSString * kVVDataItemReceiptorError = @"kVVDataItemReceiptorError";
#define kVVDataItemReceiptorErrorCodeCancel 1001


@interface VVDataItemReceiptorHandler : NSObject
@property (nonatomic, copy) NSString *dataItemID;
@property (nonatomic, weak) id<VVDataItemReceiptor> dataReceiptor;
@property (nonatomic, copy) VVDataItemReceiptorSuccessBlock successBlock;
@property (nonatomic, copy) VVDataItemReceiptorFailureBlock failureBlock;
@end
@implementation VVDataItemReceiptorHandler
- (NSString *)description {
    return [NSString stringWithFormat: @"<VVDataItemReceiptorHandler>: %@", self];
}
@end


@interface VVDataItemReceiptorHandlersManager : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSString *,NSNumber *> *requestPinnings;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<VVDataItemReceiptorHandler *> *> *request2Handlers;
@end
@implementation VVDataItemReceiptorHandlersManager

- (instancetype)init {
    if (self = [super init]) {
        _request2Handlers = [NSMutableDictionary dictionary];
    }
    return self;
}
- (NSMutableArray *)handlesForDataItemID:(NSString *)dataItemID {
    if (!dataItemID) {
        return nil;
    }
    NSMutableArray *handlers = [self.request2Handlers objectForKey:dataItemID];
    if (!handlers) {
        handlers = [NSMutableArray array];
        [self.request2Handlers setObject:handlers forKey:[dataItemID copy]];
    }
    return handlers;
}

- (void)addHandler:(VVDataItemReceiptorHandler *)handler
     forDataItemID:(NSString *)dataItemID {
    if (!handler || !dataItemID) {
        return;
    }
    [[self handlesForDataItemID:[dataItemID copy]] addObject:handler];
}
- (NSArray<id<VVDataItemReceiptor>> *)removeHandlersForDataItemID:(NSString *)dataItemID {
    if (!dataItemID) {
        return nil;
    }
    NSArray *handlers = [[self.request2Handlers objectForKey:dataItemID] copy];
    handlers = [handlers valueForKey:@"dataReceiptor"];
    [self.request2Handlers removeObjectForKey:dataItemID];
    return handlers;
}

- (BOOL)pinningForDataItemID:(NSString *)dataItemID {
    return [[self.requestPinnings objectForKey:dataItemID] boolValue];
}
- (void)updatePinning:(BOOL)pinning forDataItemID:(NSString *)dataItemID {
    if (!dataItemID) {
        return;
    }
    [self.requestPinnings setObject:@(pinning) forKey:[dataItemID copy]];
}

- (void)cancel:(NSString *)dataItemID forRecceipter:(id)receiptor {
    if (!dataItemID || !receiptor) {
        return;
    }
    NSMutableArray *handlers = [self handlesForDataItemID:dataItemID];
    NSArray *ihandlers = [handlers copy];
    for (VVDataItemReceiptorHandler *handler in ihandlers) {
        if ([handler.dataItemID isEqualToString:dataItemID]
            && [handler.dataReceiptor isEqual:receiptor]) {
            NSError *error = [NSError errorWithDomain:kVVDataItemReceiptorError
                                                 code:kVVDataItemReceiptorErrorCodeCancel
                                             userInfo:nil];
            if (handler.failureBlock) {
                handler.failureBlock(dataItemID, error);
            }
        }
    }
    if (!handlers.count) {
        [self removeHandlersForDataItemID:dataItemID];
    }
}

@end


@interface VVDataItemReceiptorManager()
@property (class, nonatomic, strong) NSMutableDictionary<NSString *, VVDataItemReceiptorManager *> *receiptorsManager;
@property (nonatomic, strong) NSHashTable<id<VVDataItemReceiptor>> *receiptors;
@property (nonatomic, strong) VVDataItemReceiptorHandlersManager *handlersManager;
@property (nonatomic, strong) dispatch_queue_t requestQueue;
@property (nonatomic, strong) dispatch_queue_t responseQueue;

@property (nonatomic, copy) NSString * dataCategoryID;

@property (nonatomic, weak) VVDataItemDownloader * downLoader;

@end

@implementation VVDataItemReceiptorManager

static NSMutableDictionary<NSString *, VVDataItemReceiptorManager *> *_receiptorsManager;

+ (NSMutableDictionary<NSString *, VVDataItemReceiptorManager *> *)receiptorsManager {
    if (!_receiptorsManager) {
        _receiptorsManager = [NSMutableDictionary dictionary];
    }
    return _receiptorsManager;
}
+ (void)setReceiptorsManager:(NSMutableDictionary<NSString *,VVDataItemReceiptorManager *> *)receiptorsManager {
    _receiptorsManager = receiptorsManager;
}

+ (instancetype)managerForDataCategoryID:(NSString *)dataCategoryID {
    if (!dataCategoryID) {
        return nil;
    }
    VVDataItemReceiptorManager *mananger = nil;
    @synchronized (self) {
        mananger = [[[self class] receiptorsManager] objectForKey:dataCategoryID];
        if (!mananger) {
            mananger = [[VVDataItemReceiptorManager alloc] init];
            [[[self class] receiptorsManager] setObject:mananger
                                                 forKey:[dataCategoryID copy]];
            mananger.dataCategoryID = dataCategoryID;
        }
    }
    return mananger;
}
+ (void)removeManagerForDataCategoryID:(NSString *)dataCategoryID {
    if (!dataCategoryID) {
        return ;
    }
    @synchronized (self) {
        [[[self class] receiptorsManager] removeObjectForKey:dataCategoryID];
    }
}

- (instancetype)init {
    if (self = [super init]) {
        _handlersManager = [[VVDataItemReceiptorHandlersManager alloc] init];
        _requestQueue = dispatch_queue_create("com.51vv.dataItemReceiptorRequestQueue", DISPATCH_QUEUE_SERIAL);
        _receiptors = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return self;
}

- (dispatch_queue_t)responseQueue {
    if (self.weakResponseQueue) {
        return self.weakResponseQueue;
    }
    if (!_responseQueue) {
        _responseQueue = dispatch_queue_create("com.51vv.dataItemReceiptorResponseQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _responseQueue;
}

- (VVDataItemDownloader *)downLoader {
    if (!_downLoader) {
        _downLoader = [VVDataItemDownloader getDownloaderWithDataCategoryID:self.dataCategoryID];
    }
    return _downLoader;
}

- (void)dataItemForID:(NSString *)dataItemID
           recceipter:(id<VVDataItemReceiptor>)receiptor
         successBlock:(VVDataItemReceiptorSuccessBlock)successBlock
         failureBlock:(VVDataItemReceiptorFailureBlock)failureBlock {
    if (!dataItemID || !receiptor || !successBlock || !failureBlock) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:kVVDataItemReceiptorError code:kVVDataItemReceiptorErrorCodeCancel userInfo:nil];
            dispatch_async(self.responseQueue, ^{
                 failureBlock(dataItemID, error);
            });
        }
        return;
    }
    id<VVDataItemIdentifier> dataItem = [self.downLoader memoryDataItemWithID:dataItemID];
    if (successBlock && dataItem) {
        successBlock(dataItem);
        __weak typeof(self) wself = self;
        dispatch_async(self.requestQueue, ^{
            __strong typeof(wself) self = wself;
            [self.receiptors addObject:receiptor];
        });
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_async(self.requestQueue, ^{
        __strong typeof(wself) self = wself;
        if (!self) {
            return ;
        }
        
        [self.receiptors removeObject:receiptor];
        
        VVDataItemReceiptorHandler *handler = [[VVDataItemReceiptorHandler alloc] init];
        handler.successBlock = successBlock;
        handler.failureBlock = failureBlock;
        handler.dataReceiptor = receiptor;
        handler.dataItemID = dataItemID;
        [self.handlersManager addHandler:handler forDataItemID:dataItemID];
        if ([self.handlersManager pinningForDataItemID:dataItemID]) {
            return;
        }
        [self.handlersManager updatePinning:YES forDataItemID:dataItemID];
        
        [[VVDataItemDownloader getDownloaderWithDataCategoryID:self.dataCategoryID] getDataItemWithID:dataItemID success:^(id<VVDataItemIdentifier>  _Nonnull dataItem) {
            __strong typeof(wself) self = wself;
            if (!self) {
                return ;
            }
            dispatch_async(self.requestQueue, ^{
                NSString *dataItemID = dataItem.dataItemID;
                NSArray *handlers = [[self.handlersManager handlesForDataItemID:dataItemID] copy];
                [self.handlersManager updatePinning:NO forDataItemID:dataItemID];
                NSArray *receiptors = [self.handlersManager removeHandlersForDataItemID:dataItemID];
                for (id<VVDataItemReceiptor> receiptor in receiptors) {
                    [self.receiptors addObject:receiptor];
                }
                dispatch_async(self.responseQueue, ^{
                    for (VVDataItemReceiptorHandler *handler in handlers) {
                        if (handler.successBlock) {
                            handler.successBlock(dataItem);
                        }
                    }
                });
            });
        } failure:^(NSString * _Nonnull dataItemID, NSError * _Nonnull error) {
            __strong typeof(wself) self = wself;
            if (!self) {
                return ;
            }
            dispatch_async(self.requestQueue, ^{
                NSArray *handlers = [[self.handlersManager handlesForDataItemID:dataItemID] copy];
                [self.handlersManager updatePinning:NO forDataItemID:dataItemID];
                NSArray *receiptors = [self.handlersManager removeHandlersForDataItemID:dataItemID];
                for (id<VVDataItemReceiptor> receiptor in receiptors) {
                    [self.receiptors addObject:receiptor];
                }
                dispatch_async(self.responseQueue, ^{
                    for (VVDataItemReceiptorHandler *handler in handlers) {
                        if (handler.failureBlock) {
                            handler.failureBlock(dataItemID, error);
                        }
                    }
                });
            });
        }];
    });
}

- (void)cancel:(NSString *)dataItemID forRecceipter:(id<VVDataItemReceiptor>)receiptor {
    if (!dataItemID || !receiptor) {
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_async(self.requestQueue, ^{
        __weak typeof(wself) self = wself;
        [self.handlersManager cancel:dataItemID forRecceipter:receiptor];
        [self.receiptors removeObject:receiptor];
    });
}

- (void)dataItemsUpdated:(NSArray<id<VVDataItemIdentifier>> *)dataItems {
    __weak typeof(self) wself = self;
    dataItems = [dataItems copy];
    dispatch_async(self.requestQueue, ^{
        __weak typeof(wself) self = wself;
        if (!self) {
            return;
        }
        NSHashTable *receiptors = [self.receiptors copy];
        dispatch_async(self.responseQueue, ^{
            for (id<VVDataItemReceiptor> receiptor in receiptors) {
                if ([receiptor respondsToSelector:@selector(dataItemID)]
                    && [receiptor respondsToSelector:@selector(dataItemUpdated:)]) {
                    for (id<VVDataItemIdentifier> dataItem in dataItems) {
                        if ([dataItem.dataItemID isEqualToString:receiptor.dataItemID]) {
                            if ([receiptor respondsToSelector:@selector(dataItemUpdated:)]) {
                                [receiptor dataItemUpdated:dataItem];
                            }
                            break;
                        }
                    }
                }
            }
        });
    });
}

@end

