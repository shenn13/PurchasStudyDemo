//
//  ViewController.h
//  Pay
//
//  Created by shen on 2019/9/20.
//  Copyright © 2019 mumu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

//1.首先在项目工程中加入“storekit.framework”，加入头文件#import <StoreKit/StoreKit.h>
//2.在.h文件中加入“SKPaymentTransactionObserver,SKProductsRequestDelegate”监听机制

@interface ViewController : UIViewController<SKPaymentTransactionObserver,SKProductsRequestDelegate>

@property (weak, nonatomic) IBOutlet UITextField *productId;

@property (weak, nonatomic) IBOutlet UIButton *purchaseBtn;

- (IBAction)purchaseBtnCliclked:(id)sender;

@end

