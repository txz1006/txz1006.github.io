### 生产者在支付情况中异步发送MQ给其他系统，如何保证信息的不丢失？

RocketMQ提供了一种两阶段提交的事务式消息，需要生产者先发送一条half信息给MQ中，MQ回应一个发送成功信息给生产者，生产者处理完本地业务后再发送一个commit信息给MQ，MQ收到提交确认信息后，修改half信息的状态，这时消费者才能消费这条数据。

![image-20230329174134577](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303291741558.png)

如果第一步发送half数据都失败了，说明MQ可能处于不可用状态，此时直接回滚数据，将当前订单设置为已关闭状态，然后通知支付平台给支付用户进行退款。

同理如果第三步，生产者在执行本地事务时异常了，但是此时已经发生过half信息了，这种情况，就需要生产者回滚代码时，给MQ发生一条rollback信息，让MQ删除掉之前发送的half信息即可。

![image-20230329174659365](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303291746434.png)

如果期间的第二步或者第四步发生了异常，生产者直接就回滚了，导致MQ没有收到half信息后续的确认状态，这种情况需要MQ调用生产者的一个回调接口来主动获取这条信息是回滚或是提交（MQ自己的half信息超时机制），至于判断条件可以是生产者本地当前订单的状态而定，如果订单被关闭了，那么就需要回滚，如果订单状态是已支付，那么就进行提交事务。

### Half消息未提交前对应消费者是如何不可见的？

half消息作为事务式消息，在没有提交之前，是如何实现对于消费者不可见的呢？这是RocketMQ做了相关的基础设计，在MQ中有一个内部Topic，叫做RMQ_SYS_TRANS_HALF_TOPIC，这个Topic只用于存储half信息，当生产者发送half信息到MQ后，MQ把half信息放入RMQ_SYS_TRANS_HALF_TOPIC，并持久化到对应CustomerQueueLog日志后，才会给生产者回应发送结果。

因为half消息并没有直接放到发送给消费者的Topic中，所以消费者看不到half信息。那么half信息是如何被提交回滚呢？在MQ中每个RMQ_SYS_TRANS_HALF_TOPIC对应还有一个OP_TOPIC主题队列，用于记录每一条half信息的最终状态，如果生产者提交了回滚信息给MQ，那么MQ并不会真的去RMQ_SYS_TRANS_HALF_TOPIC持久化文件中找到这条half消息，然后删除它；而是会在将这条half标记rollback状态，然后将状态信息写入到OP_TOPIC中，这条信息之后就不会再使用了。

![image-20230330163918883](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303301639950.png)

如果生产者发送了half信息给MQ，但是后续的某次数据交互异常了，导致MQ没有收到这条half信息的最终状态请求，那么MQ会有一个half信息超时机制，定时扫描RMQ_SYS_TRANS_HALF_TOPIC中的信息，如果超时了还没有收到生产者发送的half信息状态，Broker就会去回调当前生产者的一个接口，主动拉取当前half信息的状态来选择提交，或是回滚当前half信息。

![image-20230330164733975](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303301647070.png)

如果half信息被标记为commit状态放入OP_TOPIC中，那么就可以去RMQ_SYS_TRANS_HALF_TOPIC获取完整的half信息，将其写入到消费者可见的TOPIC。

### 可以基于重试机制保证消息发送的零丢失吗？

上面我们介绍了RocketMQ的half消息事务发送机制，如果现在我们用的不是RocketMQ，可以使用重试机制实现发送消息的零丢失？示例代码如下：

![image-20230331093908440](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303310939644.png)

这个代码看着好像没有什么问题，完成本地订单后，发送消息给MQ，如果过程中发送异常，则进行发送重试，如果多次重试还是失败，则回滚本地事务。

但是如果当前代码在执行完本地事务orderService.finishOrderPay()之后，生产者机器立马宕机了，没有发送数据到MQ中，但是本地事务数据已经入库了，这就会导致后续MQ业务链路断掉了。

为了解决这个问题，我们是否可以使用事务方法来执行这个代码？就像下面的代码一样，当执行本地订单事务之后，如何机器突然宕机，但是由于整个事务还没有提交，就会直接回滚不让代码入库。

![image-20230331095121755](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303310951800.png)

这个代码看着好像是保证了方法的事务一致性了，但是真的没有问题吗？如果这个事务方法中包含了其他数据容器的写入呢，比如Redis、ES，这些操作就没法使用方法事务了。方法事务目前只对于应用数据库才有用。

更关键的一点是，如果真的需要使用重试机制，那么这个重试的时间是需要用户等待的，对于用户体验是比较差的。

所以有什么好的解决方法吗？

当然有，一方面需要在生产者端构建一张MQ发送记录表，生产者执行本地业务后，插入一条新的记录，来记录每条信息的发送状态；另一方面，可以使用MQ的异步发送策略来进行发送和重试。

MQ发送记录表和本地订单信息都受方法事务控制，可以保证执行后一定存在一条MQ的发送记录，当MQ异步发送成功后，会执行生产者回调代码，来将MQ的发送记录更新为已成功状态；如果超时或发送失败，则进行发送重试，如果重试也失败，则更新MQ的发送记录更新为失败状态，由人工介入补偿发送机制。

但是以上操作为了保证数据的一致性耗费了大量功夫，如果直接使用RocketMQ的half事务消息，则可以不需要处理这些问题，如果工作中使用MQ需要考虑数据的零丢失，就可以优先考虑使用RocketMQ，这样可以节省很多的时间。

RocketMQ的half事务消息，一般是在业务前先执行的，执行不成功直接回滚，所以可以保证half信息一定发送成功，如果后续出现异常， RocketMQ也能主动去回调拉取生产者half信息状态，这个时间也能手动进行数据回滚删除操作。

### 使用Half信息示例代码

![image-20230331102847359](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303311028414.png)

构建一条信息

![image-20230331102916961](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303311029010.png)

发送Half信息

![image-20230331103009707](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303311030738.png)

如果一直没有收到half消息发送成功的通知呢？

针对这个问题，我们可以把发送出去的half消息放在内存里，或者写入本地磁盘文件，后台开启一个线程去检查，如果一个half消息超过比如10分钟都没有收到响应，那就自动触发回滚逻辑。

**如果half消息成功了，如何执行订单本地事务？**

![image-20230331103047836](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303311030887.png)

**如果没有返回commit或者rollback，如何进行回调？**

![image-20230331103109335](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303311031391.png)
