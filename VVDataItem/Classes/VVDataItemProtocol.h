//
//  VVDataItemProtocol.h
//  MvBox
//
//  Created by jufan wang on 2020/6/18.
//  Copyright © 2020 mvbox. All rights reserved.
//

#ifndef VVDataItemProtocol_h
#define VVDataItemProtocol_h

/*
数据项标志协议
*/

@protocol VVDataItemIdentifier <NSObject>
@optional
@property (nonatomic, copy) NSString *dataItemID;
@property (nonatomic, copy) NSString *dataItemVersion;
@end

/*
数据项刷新接收对象协议
*/

@protocol VVDataItemReceiptor <VVDataItemIdentifier>
@optional
- (void)dataItemUpdated:(id<VVDataItemIdentifier>)dataItem;
@end

/*
数据项网络下载代理协议
*/

typedef void (^VVDataItemLoaderCompletion)(NSArray<NSString *> *dataItemIDs, NSArray<id<VVDataItemIdentifier, NSCoding>> *dataItemList);
typedef void (^VVDataItemDownloadFailureBlock)(NSArray<NSString *> *dataItemIDs, NSError * _Nullable error);

@class VVDataItemDownloader;

@protocol VVDataItemDownloaderDelegate <NSObject>

- (void)dataDownLoader:(VVDataItemDownloader *)dataDownLoader
              loadData:(NSArray *)dataItemIDs
          successBlock:(VVDataItemLoaderCompletion)successBlock
          failureBlock:(VVDataItemDownloadFailureBlock)failureBlock;

- (NSInteger)dataDownLoaderPageSize:(VVDataItemDownloader *)dataDownLoader;

- (NSInteger)dataDownLoaderMaxHTTPConnection:(VVDataItemDownloader *)dataDownLoader;

@end

/*
 数据项本地缓存协议
 */

typedef void (^VVDataItemReceiptorSuccessBlock)(_Nullable id<VVDataItemIdentifier> dataItem);
typedef void (^VVDataItemReceiptorFailureBlock)(NSString *dataItemID, NSError * _Nullable error);

@protocol VVDataItemDownloaderCacher

@property (nonatomic, assign) NSTimeInterval ageLimit;
@property (nonatomic, assign) NSTimeInterval invalidCachingTime;

- (void)setObject:(nullable id<NSCoding>)object forKey:(NSString *)key;
- (nullable id<NSCoding>)objectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;

- (nullable id<NSCoding>)memoryObjectForKey:(NSString *)key;

@end


#endif /* VVDataItemProtocol_h */
