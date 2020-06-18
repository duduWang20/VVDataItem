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

/*
 创建或是返回某类别数据项的订阅者管理器
 
 @param dataCategoryID 数据项的类别ID，用于区分不同的数据类别
 */
+ (instancetype)managerForDataCategoryID:(NSString *)dataCategoryID;

/*
删除某类别数据项的订阅者管理器
 
@param dataCategoryID 数据项的类别ID，用于区分不同的数据类别
*/
+ (void)removeManagerForDataCategoryID:(NSString *)dataCategoryID;

/*
数据项返回订阅者队列
 
@param weakResponseQueue 应用层传人队列，如果刷新UI的订阅者可以传人主队列
*/
@property (nonatomic, weak, nullable) dispatch_queue_t weakResponseQueue;

/*
订阅者通过这个方法取消订阅数据项
 
 @param dataItemID 数据项ID，唯一标识特定类别下的一个数据项
 @param receiptor  数据项变更订阅者
*/
- (void)cancel:(NSString *)dataItemID forRecceipter:(id<VVDataItemReceiptor>)receiptor;

/*
 订阅者通过这个方法订阅数据项
 
 @param dataItemID 数据项ID，唯一标识特定类别下的一个数据项
 @param receiptor  数据项变更订阅者
 @param successBlock  数据项刷新成功回调
 @param failureBlock  数据项刷新失败回调
 */
- (void)dataItemForID:(NSString *)dataItemID
           recceipter:(id<VVDataItemReceiptor>)receiptor
         successBlock:(VVDataItemReceiptorSuccessBlock)successBlock
         failureBlock:(VVDataItemReceiptorFailureBlock)failureBlock;

/*
 VVDataItemDownloader 通过这个方法通知订阅者，数据项发生变更
 
 @param dataItems  新的数据项列表
 */
- (void)dataItemsUpdated:(NSArray<id<VVDataItemIdentifier>> *)dataItems;

@end

NS_ASSUME_NONNULL_END
