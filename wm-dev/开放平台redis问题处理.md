### 开放平台redis现有状况

开放平台使用的redis是64G内存的集群版本，现有4个分片节点，目前的内存使用率达到了95%。

需要对内存使用分布情况进行占用分析，尝试对redis内存数据进行占用优化和有效期优化，尽可能保证每个缓存数据得到充分的访问利用；

对于缓存有效期非常长、访问频率非常低的数据进行优化处理，在保证不影响业务的前提下，删除这些缓存数据或者减小其有效存活时长，以达到提供redis内存空间高使用率的目的。

![image-20230615172118996](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306151721059.png)

在开放平台中，主要的用户信息缓存key及有效时间信息如下代码所示，有效期单位为秒。

```xml
<!--三种合作开发者等级，等级越高，refreshToken缓存时间越长 -->
<!--14天 -->
<v:v3-cache name="refreshTokenCache" type="redis" expire="1296000"/>
<!--30天 -->
<v:v3-cache name="refreshTokenCacheL2" type="redis" expire="2592000"/>
<!-- 90天 -->
<v:v3-cache name="refreshTokenCacheL3" type="redis" expire="7776000"/>

<!-- 用户accessToken缓存时间 1小时 -->
<v:v3-cache name="accessTokenCache" type="redis" expire="3600"/>
<v:v3-cache name="jsTokenCache" type="redis" expire="3600"/>
<!-- 登录信息缓存 -->
<v:v3-cache name="loginInfoCache" type="redis" expire="3600"/>
<v:v3-cache name="grantCache" type="redis" expire="3600"/>
<v:v3-cache name="appKeyFlagCache" type="redis" expire="-1"/>
<v:v3-cache name="personCache" type="redis" expire="129600"/>
<v:v3-cache name="qrcodeCache" type="redis" expire="120"/>
<v:v3-cache name="formTokenCache" type="redis" expire="1800"/>
<v:v3-cache name="accessTokenNeverExpireCache" type="redis" expire="-1"/>
```

其中有效时间最长的是三个refreshTokenCache缓存，refreshTokenCache缓存是用于开放平台应用缓存accessTokenCache过期时，需要通过refreshTokenCache缓存生成新的accessTokenCache，用于accessToken令牌续期使用的，由于accessTokenCache缓存缓存使用只有1个小时，所以要获一个新的可用accessToken要么重新走一遍OAuth2流程获取，要么通过refreshToken接口获取。

### redis内存占用分析

现有开放平台64G内存redis的内存使用情况分析：

![image-20230615171807674](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306151718750.png)

以上图阿里云redis离线分析可以得到如下信息：三个refreshTokenCache缓存占用了80%的内存空间，由于refreshTokenCacheL3缓存的过期时间为90天，所以这个缓存key是数量最多的，由于这些key只有自然过期一种删除方式，所以随着用户量的不断增加，这个缓存key的占用空间也随着增长。

目前没有refreshTokenCacheL2缓存的数据。

同样，refreshTokenCache的过期时间是14天，这个缓存占用空间只有refreshTokenCacheL3缓存的一般，但也有近16G。所以我们可以先对refreshTokenCacheL3缓存进行处理，基本可以短时间内空出很多空间来。



### 分析refreshTokenCacheL3来源

首先accessTokenCache和refreshTokenCache的成对创建的，如果有一个用户访问开放平台的认证接口，那么就会在redis中创建一个accessTokenCache数据和一个refreshTokenCache数据，具体来说会根据开发者合作等级创建过期时间不同的refreshTokenCache数据：

![image-20230616095946322](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306160959222.png)

其中L1等级创建redis key为refreshTokenCache，L2等级创建的redis key为refreshTokenCacheL2，L3等级创建的redis key为refreshTokenCacheL3。

而合作等级是开放平台应用对应开发者的一个属性，默认为L1等级，用户实际访问开放平台授权接口就会根据开发者的合作等级来设置不同有效期的refreshToken缓存，具体代码如下：

![image-20230616100139570](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306161001615.png)

### 寻找合作等级L3的开发者应用

直接在开放平台数据库中查询开发者等级为L3的用户信息，得到如下数据：

```sql
SELECT * FROM `oauth2_user`  where LEVEL_ =2
```

![image-20230616102507987](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306161025021.png)

实际上只有前三条数据是在用数据，最后一条是测试数据，并没有创建开放平台应用。

下面我们查询这三个开发者创建的开放平台应用信息：

```sql
select * from oauth2_client where USERID_ 
in (SELECT ID_ FROM `oauth2_user`  where LEVEL_ =2) and CLIENTSTATE_ =1
```

**一共得到183个应用信息**，下面是部分应用截图：

![image-20230616103802359](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306161038401.png)

由于这些应用数量并不少，也不清楚每个应用对接开放平台是否会调用refreshToken换取accessToken接口，所以需要进一步查询用户请求接口日志信息，分析有多少开放平台应用调用了这个接口。

经过表关系的整理，得到如下查询SQL语句，作用是查询调用refreshToken换取accessToken接口日志记录

```sql
select * from ifaceserver_log_20230616 a where REQUESTTYPE_ = 3 and REQUESTURL_ like "%accessToken%"
and REQUESTDATA_ like '%refresh_token%' and
EXISTS(
select CLIENTKEY_ from oauth2_client where USERID_ 
in (SELECT ID_ FROM `oauth2_user`  where LEVEL_ =2) and CLIENTSTATE_ =1 and
a.APPID_ = CLIENTKEY_
)
```

由于开放平台日志每天一张数据表，所以这里只选择查询了三天数据，分别是20230616、20230615和上周五20230609。得到结果经过分类后，只有如下应用信息：

![image-20230616131847397](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306161318438.png)

从上述结果可以得出结论，虽然L3级开放平台应用有183三个，但是近期实际使用了refreshToken换取accessToken接口的只有上述三个应用。



### 优化方案

1. 将3个L3级开发者应用等级从L3降为L1，不再产生90天有效期的缓存。废弃L3合作等级，尚不清楚相关业务使用场景，refreshToken的有效期只需要比accessToken长一些就可以了，没必要设置90天那么长

2. 修复现有refreshToken换取accessToken接口存在问题：该接口在生成新的accessToken、refreshToken时，理应删除旧的accessToken和refreshToken，但是在下面的删除逻辑中只删除了L1基本的refreshToken，如果当前应用是L2、L3级别的合作等级，就没有删除对应的refreshTokenCacheL2、refreshTokenCacheL3缓存。
   ![image-20230619100346330](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306191003626.png)
   修复后的代码如下：
   ![image-20230619100659760](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306191006802.png)
3. 增加refreshToken换取accessToken接口实时同步合作者等级数据，这样在下一次调用refreshToken换取accessToken接口时，创建的refreshToken缓存等级是可控的
   ![image-20230619103732940](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306191037984.png)
4. 使用脚本，删除L3级refreshTokenCacheL3缓存中有效期小于40天的数据，如果一个用户经常访问，则有效期小于40天的数据大概率不会再被使用。同时将有效期大于40天的缓存有效期修改为30~31天之间。
   



