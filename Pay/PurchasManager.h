//
//  STRIAPManager.h
//  Pay
//
//  Created by shen on 2019/9/20.
//  Copyright © 2019 mumu. All rights reserved.
//

#import <Foundation/Foundation.h>

//内购
typedef NS_ENUM(NSInteger, SIAPPurchType) {
    SIAPPurchSuccess = 0,       // 购买成功
    SIAPPurchFailed = 1,        // 购买失败
    SIAPPurchCancle = 2,        // 取消购买
    SIAPPurchVerFailed = 3,     // 订单校验失败
    SIAPPurchVerSuccess = 4,    // 订单校验成功
    SIAPPurchNotArrow = 5,      // 不允许内购
    SIAPPurchRestoreNotBuy = 6,      // 恢复购买数量为0
    SIAPPurchRestoreFailed = 7,      // 恢复失败
};


//内购恢复过程
typedef NS_ENUM(NSInteger, ENUMRestoreProgress) {
    ENUMRestoreProgressStop = 0, //尚未开始请求
    ENUMRestoreProgressStart = 1, //开始请求
    ENUMRestoreProgressUpdatedTransactions = 2, //更新了事务
    ENUMRestoreProgressFinish = 3, //完成请求
};

NS_ASSUME_NONNULL_BEGIN

typedef void (^IAPCompletionHandle)(SIAPPurchType type,NSData *data);

@interface PurchasManager : NSObject

+ (instancetype)shareSIAPManager;

//开始内购
- (void)startPurchWithID:(NSString *)purchID completeHandle:(IAPCompletionHandle)handle;

//恢复内购
-(void)restorePurchaseWithcompleteHandle:(IAPCompletionHandle)handle;


@end

NS_ASSUME_NONNULL_END
