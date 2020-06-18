# VVDataItem

[![CI Status](https://img.shields.io/travis/wangjufan/VVDataItem.svg?style=flat)](https://travis-ci.org/wangjufan/VVDataItem)
[![Version](https://img.shields.io/cocoapods/v/VVDataItem.svg?style=flat)](https://cocoapods.org/pods/VVDataItem)
[![License](https://img.shields.io/cocoapods/l/VVDataItem.svg?style=flat)](https://cocoapods.org/pods/VVDataItem)
[![Platform](https://img.shields.io/cocoapods/p/VVDataItem.svg?style=flat)](https://cocoapods.org/pods/VVDataItem)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

我们把数据分为各种类别。每种类别的数据又包含多个数据项，并用一个唯一ID去标识。

一个页面内可能在多处展示同样的信息（如IM应用中的聊天页面的用户信息），
对于先后发起的请求很容易拿到不一样的值，保证数据的同步比较困难。
在底层数据刷新后，需要及时更新页面（如限时的付费服务）也要很多努力。

VVDataItem 消除了业务层对数据项请求的复杂性和数据项变更后刷新的复杂性，
并通过请求合并，提高网络的访问效率和数据库的查询效率。

一个 VVDataItemReceiptorManager（接收管理器） 管理一类数据的所有数据项订阅者。
订阅者之间彼此独立，只需要向接收管理器其注册数据项回调block即可。
接收管理器会为订阅者请求数据，并返回最新的数据项给订阅者。

VVDataItem 比 ReactiveObjC 更加高效。
ReactiveObjC 占用了过多系统资源，不适用于高频的业务场景。
测试表明，ReactiveObjC 比 VVDataItem 多占用10倍左右的资源。

## Requirements

## Installation

VVDataItem is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'VVDataItem'
```

## Author

wangjufan, wangjufan@126.com

## License

VVDataItem is available under the MIT license. See the LICENSE file for more info.
