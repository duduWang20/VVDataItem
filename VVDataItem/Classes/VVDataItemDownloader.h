//
//  VVDataItemDownloader.h
//  MvBox
//
//  Created by jufan wang on 2020/2/28.
//  Copyright © 2020 mvbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VVDataItemProtocol.h"


@protocol VVDataItemIdentifier;

NS_ASSUME_NONNULL_BEGIN


@interface VVDataItemDownloader : NSObject

/*
 为某个数据类别创建下载管理器，使用前必须使用这个方法为数据分类配置 VVDataItemDownloader
 @para delegate 发起网络请求，下载数据项
 @para dataCategoryID 数据类别ID
 */
+ (instancetype)creatDownloaderWithDelegate:(id<VVDataItemDownloaderDelegate>)delegate
                             dataCategoryID:(NSString *)dataCategoryID;

/*
 获取已经创建的某类数据的 VVDataItemDownloader
 @para dataCategoryID 数据类别ID
*/
+ (instancetype)getDownloaderWithDataCategoryID:(NSString *)dataCategoryID;

/*
 删除已经创建的某类数据的 VVDataItemDownloader
 @para dataCategoryID 数据类别ID
*/
+ (void)removeDownloaderWithDataCategoryID:(NSString *)dataCategoryID;


/*
 本地缓存
*/
@property (nonatomic, strong) id<VVDataItemDownloaderCacher> cache;

/*
 网络请求委托，发起网络请求，下载数据项
*/
@property (nonatomic, strong, readonly) id<VVDataItemDownloaderDelegate> dataLoaderDelegate;

/*
 两次网络请求间隔的最短时长，默认为1秒，避免段时间多次请求
 */
@property (nonatomic, assign) NSTimeInterval minTimeInterval;

/*
 请求网络拉取数据项
 完成同类别的多个数据项请求的合并，避免段时间内多次调用dataLoaderDelegate加载数据
 */
- (void)getDataItemWithID:(nonnull NSString *)dataID
                  success:(nonnull void (^)(id<VVDataItemIdentifier> data))success
                  failure:(nonnull void (^)(NSString *dataItemID, NSError* error))failure;

/*
 数据项发生变更，通过 dataLoaderDelegate 刷新 dataIDsList 中的数据项
 @para dataIDsList 数据项ID和版本号列表
*/
- (void)updateData:(NSArray<id<VVDataItemIdentifier>> *)dataIDsList;

/*
 读取内存缓存中数据项
 */
- (id<VVDataItemIdentifier>)memoryDataItemWithID:(NSString *)dataID;

/*
 更新本地缓存中的数据项
*/
- (void)saveDataItem:(nullable id<VVDataItemIdentifier,NSCoding>)model
          dataItemID:(nullable id<VVDataItemIdentifier>)dataItemID;


@end

NS_ASSUME_NONNULL_END
