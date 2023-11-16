### 开放平台redis现有状况

近期发现开放平台使用的redis内存又快满了，使用率达到了91%。当前开放平台Redis是64G内存的集群版本，现有4个分片节点。

![image-20231103134733819](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202311031347861.png)

此前已经通过增加访问完校用户和开放平台授权token的映射缓存，保证了在授权token有效期内，只有一对accessToken和refreshToken存在，其中accessToken有效期为一个小时，refreshToken有效期从14天到90天不等；如果在accessToken有效期内，同一个完校用户进行授权访问时，会删除上一次生成的授权token。

![image-20231103134905519](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202311031349557.png)

### Redis内存占用分析

本次Redis内存使用分布情况进行占用分析如下，基本和上一次内存分布占用基本一致：

![image-20231103133454207](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202311031335468.png)

根据上图key的占用分享可知，三个refreshTokenCache缓存占用了70%的内存空间，由于refreshTokenCacheL3缓存的过期时间为90天，所以这个缓存key是数量最多的，所以随着用户量和用户访问量的不断增加，这个缓存key的占用空间也随着增长。

同样，refreshTokenCache的过期时间是14天，这个缓存占用空间只有refreshTokenCacheL3缓存的1/3左右，但也有近14G。所以我们可以先对refreshTokenCacheL3缓存进行处理，基本可以短时间内空出很多空间来。

### 分析refreshTokenCacheL3来源

经过上次的优化后，那么用户在授权访问一个小时内，不会产生重复的的accessToken和refreshTokenCacheL3，同一用户最多只会存在一对授权token缓存，所以问题不会出在这里。

refreshTokenCacheL3缓存占用会增加到现在这个状态，一定是缺失了业务数据删除机制，所以只能依赖自然淘汰的方式，等待90天之后才会被Redis惰性删除掉。

从此前新增的完校用户和授权token的授权缓存userTokenCache来看，访问用户量排名前列的授权应用列表如下：

| Clientid                         | 应用名称                            | 是否refreshTokenCacheL3级别 |
| -------------------------------- | :---------------------------------- | --------------------------- |
| 361f12f058e544e2b9ee50e821e0eb56 | 玩校轻应用-标准校园卡H5-李晓航-周南 | 是                          |
| 716ed348e1764409995b539090cc89be | 完美校园app标准校园卡H5专用         | 否                          |
| 82505185e09042bc9cdb98eb2ede9b02 | 物联网-智能水电                     | 是                          |
| 83160632f6ac4237994ef5fd57a244d9 | 完美校园洗澡和完美校园热水          | 是                          |
| d421c51fe9834501a5166c84f53ebfb5 | 人脸采集H5                          | 是                          |
| db4236d2ef0743b9ba501c7c64adbd11 | 缴费--上海建行                      | 否                          |
| 7c38cdaef1f047b980b01838d41b4919 | 蓝牙水控-小程序                     | 是                          |
| 9390bb32c19e40a084ce14d97981ab4c | 建行e码通                           | 是                          |
| 577472956de74e459a19d27b058edd1f | 咸宁建行微应用校园卡H5              | 是                          |
| 64ad9b46c7604a119a11b9e22113f9e0 | 海亮教育集团                        | 否                          |

根据上表的信息可以发现，访问用户量排序靠前的开放平台授权应用基本都是refreshTokenCacheL3级的，从用户访问量来看，排名第一的应用361f12f058e544e2b9ee50e821e0eb56，在近1个小时的key数量就有近20万的用户访问数量，所以也会对应生成近20万的有效期为90天的refreshTokenCacheL3级别缓存。

如果是同一用户在授权信息存在的一小时内多次访问，按照之前的优化规则，不存在refreshTokenCacheL3累计问题。但是如果这个用户正常的访问周期间隔超过了一小时，那么就会存在refreshTokenCacheL3累计问题，比如用户张三在一天内早上7点访问了一次应用，中午12点访问一次应用，下午6点访问了一次应用，由于访问频率超过1小时，这些缓存对应的accessToken和userTokenCache早已过期，程序就无法正常删除refreshTokenCacheL3数据，这一天就会创建3条refreshTokenCacheL3缓存数据，而且只能等待90天后自然淘汰，这就存在数据累计问题了。

### 优化解决方案

在清楚问题原因后，下面就需要思考问题解决办法了。

首先是临时处理方案：由于内存占用马上要满了，所以需要删除一些基本不太可能被使用的refreshTokenCacheL3数据，来腾出足够的可用空间来。办法就是使用上一次优化的Redis操作脚本，这个脚本会删除那些已经存活了45天的refreshTokenCacheL3数据，经过执行后，redis内存占用第二天已经下降到了83%，基本在安全线内了。

![image-20231103142809861](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202311031428940.png)

方案二，代码优化。经过排查代码逻辑，分析访问日志，基本可以确定refreshTokenCacheL3的有效期设置的过长了，几乎很少有授权应用会使用存在时间超过30天以上的refreshTokenCacheL3数据，通过所以后期会将开放平台的refreshToken缓存时间进行减少，原本的refreshToken有效期如下：

![image-20230616095946322](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306160959222.png)

修改调整后的有效期如下：

![image-20231103152550674](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202311031525211.png)

整体缩短的有效期后，最多只会产生原本1/3的数据累积量，这个数量是可以达到数据新增与淘汰的动态平衡的
