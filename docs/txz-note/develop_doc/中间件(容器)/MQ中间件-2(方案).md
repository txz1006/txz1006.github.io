### 一、如何设计一个秒杀方案

1. 活动开始前，秒杀产品的页面做静态化处理，然后设置多级缓存策略，例如CDN缓存，nginx缓存、redis缓存、本地缓存等，尽量减少请求到源服务的请求。
2. 秒杀订单服务独立出来，专门处理秒杀业务，和常规订单支付系统隔离
3. 活动开始时，设置验证码答题等用户验证策略，用户下单需要先进行答题验证，一方面拦截各种脚本请求，另一方面减少用户请求的频次。
4. 活动中，使用redis进行活动库存扣减，扣减的活动可以通过MQ，异步写入数据库（活动扣减redis需要加锁，这里建议，对商品请求次数做分端加锁，避免过多请求竞争同一个锁）
5. 活动完成，当redis的库存数降到0时，通过注册中心向nginx发送活动结束标记，拦截之后大量的无效用户请求，此时用户会看到活动已结束的页面。
6. 活动结束，产生的秒杀订单写入MQ，然后由常规订单支付系统慢慢消费处理这些订单数据



### redis库存扣减分端加锁

先incr获取次数值，然后对活动id+次数进行分布式加锁，即使incr获取次数值重复也不会存在超库存问题。当然也可以将加锁和incr合并为一个lua事务脚本来执行，但是这样性能会稍差一些。

```java
//stockCount为中库存数
public Result subActivityBillByRedis(String uid, long activityId, Integer stockCount) {
    //1.获取活动库存key
    String stockKey = RedisKey.KEY_LOTTERY_ACTIVITY_STOCK_COUNT(activityId);

    //2.扣减库存（redis服务端是单线程处理，一般是线程安全的，但是redis集群和redis客户端在并发情况下会有线程安全问题）
    Integer usedCount = redisUtils.incr(stockKey, 1);

    //3.超出库存，则进行恢复
    if(usedCount > stockCount){
        redisUtils.decr(stockKey, 1);
        return Result.buildResult(ResponseCode.OUT_OF_STOCK.getCode(), ResponseCode.OUT_OF_STOCK.getMsg());
    }

    //4.生成活动锁key
    String stock_count_lock = RedisKey.KEY_LOTTERY_ACTIVITY_STOCK_COUNT_LOCK(activityId, usedCount);

    //5.加锁（再次使用redis加分布式锁，保证每次请求的唯一性）
    boolean lockToken = redisUtils.setNx(stock_count_lock, 350L);
    if(!lockToken){
        //避免极端情况下出现重复产生usedCount的情况
        logger.warn("抽奖活动{}用户秒杀{}扣减库存，分布式锁失败：{}", activityId, uid, stock_count_lock);
        return Result.buildResult(ResponseCode.ERR_LOCK.getCode(), ResponseCode.ERR_LOCK.getMsg());
    }
	//返回剩余库存数
    return new StockRes(ResponseCode.SUCCESS.getCode(), ResponseCode.SUCCESS.getMsg(), stock_count_lock, stockCount - usedCount);
}
```

加锁后创建订单，并释放锁

```
redisUtils.del(tokenKey);
```

将剩余库存通过MQ异步入库，stockSurplusCount参数为加锁的stockCount - usedCount

```
    //异步mq减少库存，只有设置的stock_surplus_count小于当前库存数才会减少库存
    @Update("UPDATE activity SET stock_surplus_count = #{stockSurplusCount} " +
            " WHERE activity_id = #{activityId} AND stock_surplus_count > #{stockSurplusCount} ")
```

