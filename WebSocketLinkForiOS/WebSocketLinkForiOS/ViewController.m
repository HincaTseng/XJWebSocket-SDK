//
//  ViewController.m
//  WebSocketLinkForiOS
//
//  Created by 曾宪杰 on 2018/11/24.
//  Copyright © 2018 zengxianjie. All rights reserved.
//

#import "ViewController.h"
#import "WebSocketManager.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *tvLog;
@property (weak, nonatomic) IBOutlet UIButton *connectBtn;
@property (weak, nonatomic) IBOutlet UIButton *closeBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
  
}

- (IBAction)open:(id)sender {
    //获取端口号
    int port = XSocksOpen(0, kPort);
    //拼接端口号
    NSString *urlStr = [NSString stringWithFormat:@"ws://127.0.0.1:%d",port];
    
    [[WebSocketManager shareManager] SRWebSocketOpenWithURLString:urlStr];
    //j用来监听收发的信息
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidOpen) name:kWebSocketDidOpenNote object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidReceiveMsg:) name:kWebSocketDidCloseNote object:nil];
}

- (IBAction)close:(id)sender {
    [[WebSocketManager shareManager] SRWebSocketClose];
}


- (void)SRWebSocketDidOpen {
    NSLog(@"开启成功");
    //在成功后需要做的操作。。。
}

- (void)SRWebSocketDidReceiveMsg:(NSNotification *)note {
    //收到服务端发送过来的消息
    NSString * message = note.object;
    NSLog(@"%@",message);
}

//拼接打印
- (void)showMessageWithStr:(NSString *)obj {
    self.tvLog.text = [self.tvLog.text stringByAppendingFormat:@"%@\n", obj];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}
@end
