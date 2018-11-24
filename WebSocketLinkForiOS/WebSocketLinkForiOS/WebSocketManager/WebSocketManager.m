//
//  WebSocketManager.m
//  WebSocketLinkForiOS
//
//  Created by 曾宪杰 on 2018/11/24.
//  Copyright © 2018 zengxianjie. All rights reserved.
//

#import "WebSocketManager.h"
#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

NSString * const kNeedPayOrderNote               = @"kNeedPayOrderNote";
NSString * const kWebSocketDidOpenNote           = @"kWebSocketdidReceiveMessageNote";
NSString * const kWebSocketDidCloseNote          = @"kWebSocketDidCloseNote";
NSString * const kWebSocketdidReceiveMessageNote = @"kWebSocketdidReceiveMessageNote";

@interface WebSocketManager ()<SRWebSocketDelegate>
{
    int _index;
    NSTimeInterval reConnectTime;
}
@property (nonatomic,strong) SRWebSocket *socket;
@property (nonatomic,copy) NSString *urlString;
@property (nonatomic,strong) NSTimer *heartBeat;

@end

@implementation WebSocketManager

+(WebSocketManager *)shareManager{
    static WebSocketManager *Instance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        Instance = [[WebSocketManager alloc] init];
    });
    return Instance;
}

#pragma mark - **************** public methods
-(void)SRWebSocketOpenWithURLString:(NSString *)urlString {
    
    //如果是同一个url return
    if (self.socket) {
        return;
    }
    
    if (!urlString) {
        return;
    }
    
    self.urlString = urlString;
    
    self.socket = [[SRWebSocket alloc] initWithURLRequest:
                   [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
    
    NSLog(@"请求的websocket地址：%@\n",self.socket.url.absoluteString);
    
    self.socket.delegate = self;   //SRWebSocketDelegate 协议
    
    [self.socket open];     //开始连接
}

-(void)SRWebSocketClose{
    if (self.socket){
        [self.socket close];
        self.socket = nil;
        //断开连接时销毁心跳
        [self destoryHeartBeat];
    }
}

#define WeakSelf(ws) __weak __typeof(&*self)weakSelf = self
- (void)sendData:(id)data {
    NSLog(@"socketSendData --------------- %@\n",data);
    
    WeakSelf(ws);
    dispatch_queue_t queue =  dispatch_queue_create("socket", NULL);
    
    dispatch_async(queue, ^{
        if (weakSelf.socket != nil) {
            // 只有 SR_OPEN 开启状态才能调 send 方法啊，不然要崩
            if (weakSelf.socket.readyState == SR_OPEN) {
                [weakSelf.socket sendData:data error:nil];    // 发送数据
                
            } else if (weakSelf.socket.readyState == SR_CONNECTING) {
                NSLog(@"正在连接中，重连后其他方法会去自动同步数据\n");
                // 每隔2秒检测一次 socket.readyState 状态，检测 10 次左右
                // 只要有一次状态是 SR_OPEN 的就调用 [ws.socket send:data] 发送数据
                // 如果 10 次都还是没连上的，那这个发送请求就丢失了，这种情况是服务器的问题了，小概率的
                // 代码有点长，我就写个逻辑在这里好了
                [self reConnect];
                
            } else if (weakSelf.socket.readyState == SR_CLOSING || weakSelf.socket.readyState == SR_CLOSED) {
                // websocket 断开了，调用 reConnect 方法重连
                
                NSLog(@"重连~~~~\n");
                
                [self reConnect];
            }
        } else {
            NSLog(@"没网络，发送失败，一旦断网 socket 会被我设置 nil 的\n");
            NSLog(@"其实最好是发送前判断一下网络状态比较好，我写的有点晦涩，socket==nil来表示断网\n");
        }
    });
}

#pragma mark - **************** private mothodes
//重连机制
- (void)reConnect
{
    [self SRWebSocketClose];
    
    //超过一分钟就不再重连 所以只会重连5次 2^5 = 64
    if (reConnectTime > 64) {
        //您的网络状况不是很好，请检查网络后重试
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.socket = nil;
        [self SRWebSocketOpenWithURLString:self.urlString];
        NSLog(@"重连~~~\n");
    });
    
    //重连时间2的指数级增长
    if (reConnectTime == 0) {
        reConnectTime = 2;
    }else{
        reConnectTime *= 2;
    }
}


//取消心跳
- (void)destoryHeartBeat
{
    __weak WebSocketManager *weakSelf = self;
    dispatch_main_async_safe(^{
        if (weakSelf.heartBeat) {
            if ([weakSelf.heartBeat respondsToSelector:@selector(isValid)]){
                if ([weakSelf.heartBeat isValid]){
                    [weakSelf.heartBeat invalidate];
                    weakSelf.heartBeat = nil;
                }
            }
        }
    })
}

//初始化心跳
- (void)initHeartBeat
{
     __weak WebSocketManager *weakSelf = self;
    dispatch_main_async_safe(^{
        [self destoryHeartBeat];
        //心跳设置为3分钟，NAT超时一般为5分钟
        weakSelf.heartBeat = [NSTimer timerWithTimeInterval:3 target:self selector:@selector(sentheart) userInfo:nil repeats:YES];
        //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
        [[NSRunLoop currentRunLoop] addTimer:weakSelf.heartBeat forMode:NSRunLoopCommonModes];
    })
}

-(void)sentheart{
    //发送心跳 和后台可以约定发送什么内容  一般可以调用ping  我这里根据后台的要求 发送了data给他
    [self sendData:@"heart"];
}

//pingPong WebSocket协议已经设计了心跳
- (void)ping{
    if (self.socket.readyState == SR_OPEN) {
        NSString *pingStr = @"心跳";
        NSData *data = [pingStr dataUsingEncoding:NSUTF8StringEncoding];
        
        [self.socket sendPing:data error:nil];
    }
}

#pragma mark - socket delegate
- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    //每次正常连接的时候清零重连时间
    reConnectTime = 0;
    //开启心跳
    [self initHeartBeat];
    if (webSocket == self.socket) {
        NSLog(@"\n************************** socket 连接成功************************** \n");
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebSocketDidOpenNote object:nil];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    
    if (webSocket == self.socket) {
        NSLog(@"\n************************** socket 连接失败************************** \n");
        _socket = nil;
        //连接失败就重连
        [self reConnect];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    
    if (webSocket == self.socket) {
        NSLog(@"\n************************** socket连接断开************************** \n");
        NSLog(@"被关闭连接，code:%ld,reason:%@,wasClean:%d\n",(long)code,reason,wasClean);
        [self SRWebSocketClose];
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebSocketDidCloseNote object:nil];
    }
}

/*该函数是接收服务器发送的pong消息，其中最后一个是接受pong消息的，
 在这里就要提一下心跳包，一般情况下建立长连接都会建立一个心跳包，
 用于每隔一段时间通知一次服务端，客户端还是在线，这个心跳包其实就是一个ping消息，
 我的理解就是建立一个定时器，每隔十秒或者十五秒向服务端发送一个ping消息，这个消息可是是空的
 */
-(void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload{
    NSString *reply = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
    NSLog(@"reply===%@\n",reply);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message  {
    
    if (webSocket == self.socket) {
        NSLog(@"\n************************** socket收到数据了************************** \n");
        NSLog(@"我这后台约定的 message 是 json 格式数据收到数据，就按格式解析吧，然后把数据发给调用层\n");
        NSLog(@"message:%@\n",message);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebSocketdidReceiveMessageNote object:message];
    }
}

#pragma mark - **************** setter getter
- (SRReadyState)socketReadyState{
    return self.socket.readyState;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
