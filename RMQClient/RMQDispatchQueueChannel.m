#import "RMQDispatchQueueChannel.h"
#import "AMQMethodDecoder.h"
#import "AMQProtocolValues.h"
#import "AMQProtocolMethods.h"

@interface RMQDispatchQueueChannel ()
@property (nonatomic, copy, readwrite) NSNumber *channelID;
@property (nonatomic, readwrite) id <RMQSender> sender;
@property (nonatomic, copy, readwrite) void (^lastConsumer)(id<RMQMessage>);
@end

@implementation RMQDispatchQueueChannel

- (instancetype)init:(NSNumber *)channelID sender:(id<RMQSender>)sender {
    self = [super init];
    if (self) {
        self.channelID = channelID;
        self.sender = sender;
        self.lastConsumer = ^(id<RMQMessage> m){};
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (RMQExchange *)defaultExchange {
    return [RMQExchange new];
}

- (RMQQueue *)queue:(NSString *)queueName
         autoDelete:(BOOL)shouldAutoDelete
          exclusive:(BOOL)isExclusive {
    AMQShort *ticket          = [[AMQShort alloc] init:0];
    AMQShortstr *amqQueueName = [[AMQShortstr alloc] init:queueName];
    AMQTable *arguments       = [[AMQTable alloc] init:@{}];

    AMQProtocolQueueDeclareOptions options = AMQProtocolQueueDeclareDurable;
    if (isExclusive)            { options |= AMQProtocolQueueDeclareExclusive; }
    if (shouldAutoDelete)       { options |= AMQProtocolQueueDeclareAutoDelete; }

    AMQProtocolQueueDeclare *method = [[AMQProtocolQueueDeclare alloc] initWithReserved1:ticket
                                                                                   queue:amqQueueName
                                                                                 options:options
                                                                               arguments:arguments];
    [self.sender sendMethod:method channelID:self.channelID];
    return [[RMQQueue alloc] initWithName:queueName
                                  channel:(id <RMQChannel>)self
                                   sender:self.sender];
}

- (void)basicConsume:(NSString *)queueName consumer:(void (^)(id<RMQMessage> _Nonnull))consumer {
    AMQProtocolBasicConsume *method = [[AMQProtocolBasicConsume alloc] initWithReserved1:[[AMQShort alloc] init:0]
                                                                                   queue:[[AMQShortstr alloc] init:queueName]
                                                                             consumerTag:[[AMQShortstr alloc] init:@""]
                                                                                 options:AMQProtocolBasicConsumeNoOptions
                                                                               arguments:[[AMQTable alloc] init:@{}]];
    [self.sender sendMethod:method channelID:self.channelID];

    NSError *error = NULL;
    [self.sender waitOnMethod:[AMQProtocolBasicConsumeOk class] channelID:self.channelID error:&error];
    self.lastConsumer = consumer;
}

- (void)handleFrameset:(AMQFrameset *)frameset {
    NSString *content = [[NSString alloc] initWithData:frameset.contentData encoding:NSUTF8StringEncoding];
    RMQContentMessage *message = [[RMQContentMessage alloc] initWithDeliveryInfo:@{@"consumer_tag" : @"foo"}
                                                                        metadata:@{@"foo" : @"bar"}
                                                                         content:content];
    self.lastConsumer(message);
}
@end

@interface RMQUnallocatedDispatchQueueChannel ()
@property (nonatomic, copy, readwrite) NSNumber *channelID;
@end

@implementation RMQUnallocatedDispatchQueueChannel

- (instancetype)init {
    self = [super init];
    if (self) {
        self.channelID = @(-1);
    }
    return self;
}

- (void)basicConsume:(NSString *)queueName consumer:(void (^)(id<RMQMessage> _Nonnull))consumer {
}
- (RMQExchange *)defaultExchange {
    return nil;
}
- (RMQQueue *)queue:(NSString *)queueName autoDelete:(BOOL)shouldAutoDelete exclusive:(BOOL)isExclusive {
    return nil;
}
- (void)handleFrameset:(AMQFrameset *)frameset {

}
@end