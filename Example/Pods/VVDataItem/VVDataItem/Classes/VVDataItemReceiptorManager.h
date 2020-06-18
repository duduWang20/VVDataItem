//
//  VVDataItemReceiptorManager.h
//  MvBox
//
//  Created by jufan wang on 2020/2/29.
//  Copyright © 2020 mvbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VVDataItemProtocol.h"


@class VVDataItemDownloader;

NS_ASSUME_NONNULL_BEGIN

@interface VVDataItemReceiptorManager : NSObject

+ (instancetype)managerForDataCategoryID:(NSString *)dataCategoryID;
+ (void)removeManagerForDataCategoryID:(NSString *)dataCategoryID;

@property (nonatomic, weak) dispatch_queue_t weakResponseQueue;

- (void)cancel:(NSString *)dataItemID forRecceipter:(id<VVDataItemReceiptor>)receiptor;

- (void)dataItemForID:(NSString *)dataItemID
           recceipter:(id<VVDataItemReceiptor>)receiptor
         successBlock:(VVDataItemReceiptorSuccessBlock)successBlock
         failureBlock:(VVDataItemReceiptorFailureBlock)failureBlock;

- (void)dataItemsUpdated:(NSArray<id<VVDataItemIdentifier>> *)dataItems;

@end

NS_ASSUME_NONNULL_END
