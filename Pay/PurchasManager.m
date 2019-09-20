//
//  STRIAPManager.m
//  Pay
//
//  Created by shen on 2019/9/20.
//  Copyright © 2019 mumu. All rights reserved.
//

#import "PurchasManager.h"
#import <StoreKit/StoreKit.h>


@interface PurchasManager () <SKPaymentTransactionObserver, SKProductsRequestDelegate> {
    NSString *_purchID;
    IAPCompletionHandle _handle;
}

//判断一份交易获得验证的次数  key为随机值
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *transactionCountMap;

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<SKPaymentTransaction *> *> *transactionFinishMap;

@property(nonatomic,assign)ENUMRestoreProgress restoreProgress;

@end

@implementation PurchasManager {
    
}

#pragma mark - init

+ (instancetype)shareSIAPManager {
    static PurchasManager *IAPManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        IAPManager = [[PurchasManager alloc] init];
    });
    return IAPManager;
}

- (instancetype)init {
    if (self = [super init]) {
        // 购买监听写在程序入口,程序挂起时移除监听,这样如果有未完成的订单将会自动执行并回调 paymentQueue:updatedTransactions:方法
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - public method

//开始购买
- (void)startPurchWithID:(NSString *)purchID completeHandle:(IAPCompletionHandle)handle {
    
    
    if (purchID) {
        if ([SKPaymentQueue canMakePayments]) {
            _purchID = purchID;
            _handle = handle;
            NSSet *set = [NSSet setWithArray:@[purchID]];
            SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
            request.delegate = self;
            [request start];
        } else {
            [self handleActionWithType:SIAPPurchNotArrow data:nil];
        }
    }
}

//恢复购买
- (void)restorePurchaseWithcompleteHandle:(IAPCompletionHandle)handle {
    
    //开始恢复
    _restoreProgress = ENUMRestoreProgressStart;
    
    _handle = handle;
    
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}



/*
 SKPaymentTransactionStatePurchasing,    // Transaction is being added to the server queue.
 SKPaymentTransactionStatePurchased,     // Transaction is in queue, user has been charged.  Client should complete the transaction.
 SKPaymentTransactionStateFailed,        // Transaction was cancelled or failed before being added to the server queue.
 SKPaymentTransactionStateRestored,      // Transaction was restored from user's purchase history.  Client should complete the transaction.
 */

#pragma mark - SKPaymentTransactionObserver

//队列操作后的回调
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    
    //判断是否为恢复购买的请求
    if (_restoreProgress == ENUMRestoreProgressStart) {
        _restoreProgress = ENUMRestoreProgressUpdatedTransactions;
    }
    
    NSString *operationId = [[NSUUID UUID] UUIDString];
    
    [self.transactionFinishMap setValue:[NSMutableSet set] forKey:operationId];
    [self.transactionCountMap setValue:@(transactions.count) forKey:operationId];
    
    for (int i = 0; i < transactions.count; i++) {
        
        SKPaymentTransaction *tran = transactions[i];
        
        //购买成功
        
        if (tran.transactionState == SKPaymentTransactionStatePurchased) {
            [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            [self completeTransaction:tran operationId:operationId];
        }
        //购买中
        else if (tran.transactionState == SKPaymentTransactionStatePurchasing) {
#if DEBUG
            NSLog(@"正在购买");
#endif
        }
        //恢复购买
        else if (tran.transactionState == SKPaymentTransactionStateRestored) {
#if DEBUG
            NSLog(@"已经购买过商品");
#endif
            [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            [self restoreTransaction:tran operationId:operationId];
            
        }
        //购买失败
        else if (tran.transactionState == SKPaymentTransactionStateFailed) {
            [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            [self failedTransaction:tran];
        }
        
        
    }
    
}

//恢复购买结束回调
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue NS_AVAILABLE_IOS(3_0){
    
    //没有进入- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions 方法
    //恢复产品数量为0  提前结束
    if(_restoreProgress != ENUMRestoreProgressUpdatedTransactions){
        [self handleActionWithType:SIAPPurchRestoreNotBuy data:nil];
    }
    
    _restoreProgress = ENUMRestoreProgressFinish;
    
}

//恢复购买失败
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error NS_AVAILABLE_IOS(3_0){
    
    //恢复失败
    if(_restoreProgress != ENUMRestoreProgressUpdatedTransactions){
        [self handleActionWithType:SIAPPurchRestoreFailed data:nil];
    }
    
    _restoreProgress = ENUMRestoreProgressFinish;
    
}
#pragma mark - transaction action

//恢复购买
- (void)restoreTransaction:(SKPaymentTransaction *)transaction operationId:(NSString *)operationId {
    
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO operationId:operationId];
    
}

// 完成交易
- (void)completeTransaction:(SKPaymentTransaction *)transaction operationId:(NSString *)operationId {
    
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO operationId:operationId];
}


// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:SIAPPurchFailed data:nil];
    } else {
        [self handleActionWithType:SIAPPurchCancle data:nil];
    }
}

- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction isTestServer:(BOOL)flag operationId:(NSString *)operationId {
    
    //    // Your application should implement these two methods.
    //    NSString *productId = transaction.payment.productIdentifier;
    //    NSString *receipt = [transaction.transactionReceipt base64Encoding];
    //    if ([productId length] > 0) {
    //        // 向自己的服务器验证购买凭证
    //    }
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    
    if (!receipt) {
        // 交易凭证为空验证失败
        [self handleActionWithType:SIAPPurchVerFailed data:nil];
        return;
    }
    // 购买成功将交易凭证发送给服务端进行再次校验
    [self handleActionWithType:SIAPPurchSuccess data:receipt];
    
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": [receipt base64EncodedStringWithOptions:0]
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    
    if (!requestData) { // 交易凭证为空验证失败
        [self handleActionWithType:SIAPPurchVerFailed data:nil];
        return;
    }
    
    //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
    //In the real environment, use https://buy.itunes.apple.com/verifyReceipt
    
    NSString *serverString = @"https://buy.itunes.apple.com/verifyReceipt";
    if (flag) {
        serverString = @"https://sandbox.itunes.apple.com/verifyReceipt";
    }
    NSURL *storeURL = [NSURL URLWithString:serverString];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   // 无法连接服务器,购买校验失败
                                   [self handleActionWithType:SIAPPurchVerFailed data:nil];
                               } else {
                                   NSError *error;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                   if (!jsonResponse) {
                                       // 苹果服务器校验数据返回为空校验失败
                                       [self handleActionWithType:SIAPPurchVerFailed data:nil];
                                   }
                                   
                                   // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
                                   NSString *status = [NSString stringWithFormat:@"%@", jsonResponse[@"status"]];
                                   if (status && [status isEqualToString:@"21007"]) {
                                       [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:YES operationId:operationId];
                                   } else if (status && [status isEqualToString:@"0"]) {
                                       //订单校验成功
                                       
                                       //APP添加商品
                                       NSString *productId = transaction.payment.productIdentifier;
                                       
//                                       for (PurchProductModel *model in [[AuthManager sharedManager] getAllProductList]) {
//                                           if ([model.productId isEqualToString:productId]) {
//                                               [[AuthManager sharedManager] addProduct:model.productType];
//                                               break;
//                                           }
//                                       }
                                       //总数量
                                       NSInteger totalCount = [[self.transactionCountMap valueForKey:operationId] integerValue];
                                       
                                       //已执行数量
                                       NSMutableSet *finishSet = [self.transactionFinishMap valueForKey:operationId];
                                       [finishSet addObject:transaction];
                                       
                                       //需在添加对象后获得对象数量 不然有极低的可能遇到并发问题 而导致不执行回调
                                       [self handleActionWithType:SIAPPurchVerSuccess data:nil invokeHandle:[finishSet count]  == totalCount];
                                   }
#if DEBUG
                                   NSLog(@"----验证结果 %@", jsonResponse);
#endif
                               }
                           }];
    
    
    // 验证成功与否都注销交易,否则会出现虚假凭证信息一直验证不通过,每次进程序都得输入苹果账号
}


#pragma mark - SKProductsRequestDelegate

//发送请求后 会回调  执行这个方法
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSArray *products = response.products;
    if ([products count] <= 0) {
#if DEBUG
        NSLog(@"--------------没有商品------------------");
#endif
        return;
    }
    
    SKProduct *p = nil;
    for (SKProduct *pro in products) {
        if ([pro.productIdentifier isEqualToString:_purchID]) {
            p = pro;
            break;
        }
    }
    
#if DEBUG
    NSLog(@"productID:%@", response.invalidProductIdentifiers);
    NSLog(@"产品付费数量:%lu", (unsigned long) [products count]);
    NSLog(@"%@", [p description]);
    NSLog(@"%@", [p localizedTitle]);
    NSLog(@"%@", [p localizedDescription]);
    NSLog(@"%@", [p price]);
    NSLog(@"%@", [p productIdentifier]);
    NSLog(@"发送购买请求");
#endif
    
    SKPayment *payment = [SKPayment paymentWithProduct:p];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
#if DEBUG
    NSLog(@"------------------错误-----------------:%@", error);
#endif
}

- (void)requestDidFinish:(SKRequest *)request {
#if DEBUG
    NSLog(@"------------反馈信息结束-----------------");
#endif
}


#pragma mark - private method

//适配器模式
- (void)handleActionWithType:(SIAPPurchType)type data:(NSData *)data invokeHandle:(Boolean)invoke {
    
#ifdef DEBUG
    switch (type) {
        case SIAPPurchSuccess:
            NSLog(@"购买成功");
            break;
        case SIAPPurchFailed:
            NSLog(@"购买失败");
            break;
        case SIAPPurchCancle:
            NSLog(@"用户取消购买");
            break;
        case SIAPPurchVerFailed:
            NSLog(@"订单校验失败");
            break;
        case SIAPPurchVerSuccess:
            NSLog(@"订单校验成功");
            break;
        case SIAPPurchNotArrow:
            NSLog(@"不允许程序内付费");
            break;
        case SIAPPurchRestoreNotBuy:
            NSLog(@"购买数量为0");
            break;
        default:
            break;
    }
#endif
    
    //因为购买成功并不是最后一个步骤 没有意义 不进行处理
    if (type == SIAPPurchSuccess) {
        return;
    }
    
    
    if (invoke && _handle) {
        _handle(type, data);
    }
    
}

//完成回调 自己的block
- (void)handleActionWithType:(SIAPPurchType)type data:(NSData *)data {
    
    [self handleActionWithType:type data:data invokeHandle:true];
    
}

#pragma mark - getter & setter


- (NSMutableDictionary *)transactionFinishMap {
    if (!_transactionFinishMap) {
        _transactionFinishMap = [NSMutableDictionary dictionary];
    }
    return _transactionFinishMap;
}


- (NSMutableDictionary *)transactionCountMap {
    if (!_transactionCountMap) {
        _transactionCountMap = [NSMutableDictionary dictionary];
    }
    return _transactionCountMap;
}

@end
