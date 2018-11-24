//
//  WebSocketManager.h
//  WebSocketLinkForiOS
//
//  Created by 曾宪杰 on 2018/11/24.
//  Copyright © 2018 zengxianjie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SocketRocket/SocketRocket.h>

extern NSString * const kNeedPayOrderNote;
extern NSString * const kWebSocketDidOpenNote;
extern NSString * const kWebSocketDidCloseNote;
extern NSString * const kWebSocketdidReceiveMessageNote;
NS_ASSUME_NONNULL_BEGIN

@interface WebSocketManager : NSObject
// 获取连接状态
@property (nonatomic,assign,readonly) SRReadyState socketReadyState;

+ (WebSocketManager *)shareManager;

-(void)SRWebSocketOpenWithURLString:(NSString *)urlString;//开启连接
-(void)SRWebSocketClose;//关闭连接
- (void)sendData:(id)data;//发送数据

@end

NS_ASSUME_NONNULL_END
