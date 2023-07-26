### 问题现状

![image-20230629141847553](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306291418188.png)

开放平台redis共有三千八百多万的数据，共占内存60G左右，其中以refreshTokenCacheL3开头的key数量达到了两千六百万之多，而且这个数据在业务处理中只能自然淘汰，但是因为其有效期为90天，所以淘汰速度远远小于新增速度。随着业务的正常运行会不断地进行堆积，一直到现在，导致refreshTokenCacheL3开头的key数量占到了总key数量的50%已上。

![image-20230615171807674](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306151718750.png)

在经过业务分析过，打算通过编写redis脚本，筛选出refreshTokenCacheL3开头的key中有效期小于30天的数据，这部分数据基本没有再被使用的可能，所以我们会在脚本中将这些key的过期时间修改为1个小时，让其在短时间内大量淘汰掉，以减少redis的内存占用。

### 执行脚本

编写的redis脚本如下，主要使用了jedis客户端工具包，使用了redis命令中的scan、批量处理Pipeline技术。

```java
public class RedisTest {

    private static BufferedWriter bw = null;

    public static void main(String[] args) throws IOException {
        Properties properties = new Properties();
        BufferedReader bufferedReader = new BufferedReader(new FileReader("./application.properties"));
        properties.load(bufferedReader);
        String host = "r-bp1skgykoyac2b7zkv.redis.rds.aliyuncs.com";
        String pwd = "r-bp1skgykoyac2b7zkv:A48d19366190";
        host = properties.getProperty("host");
        pwd = properties.getProperty("pwd");
        if(StringUtils.isAnyBlank(host, pwd)){
            log("没有获取到redis配置，请检查redis配置信息和配置文件位置");
            return;
        }
        log("============当前连接redis服务器地址："+ host);
        log("============脚本开始时间："+LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        StopWatch stopWatch = new StopWatch();
        stopWatch.start();
        // 连接Redis
        //公测
        String host = "r-bp1skgykoyac2b7zkv.redis.rds.aliyuncs.com";
        String pwd = "r-bp1skgykoyac2b7zkv:A48d19366190";
        Jedis jedis = new Jedis(host, 6379);
        jedis.auth(pwd);
        // 过期时间,秒为单位
        // 30天
        int expireTime = 60 * 60 * 24 * 30;

        // 一次查詢取出10万个key
        int countPerTime = 1000;

        //记录修改过期时间的key数量
        int dealTotalCount = 0;
        //遍历总数
        int totalCount = 0;

        // 只处理refreshTokenCacheL3开头的key
        String matchKey = "refreshTokenCacheL3*";

        // 扫描获取key
        String cursor = "0";
        do{
            ScanResult<String> scanResult = jedis.scan(cursor, (new ScanParams()).match(matchKey).count(countPerTime));
            List<String> keys = scanResult.getResult();
            if (keys.isEmpty()) {
                log("没有查询到refreshTokenCacheL3开头的数据，cursor="+ cursor);
                return;
            }
            //System.out.println(Arrays.toString(keys.toArray()));
            Pipeline pipe = jedis.pipelined();
            int index = 0;
            int dealCount = 0;

            for(String key : keys){
                pipe.ttl(key);
            }
            //批量获取10万数据的过期时间
            List<Object> ttls = pipe.syncAndReturnAll();
            for (String key : keys) {
                //设置过期时间小于30天的key在1-2小时内失效
                Long keyTtl = (Long) ttls.get(index);
                if(keyTtl < expireTime){
                    pipe.expire(key, RandomUtils.nextInt(3600, 7200));
                    dealCount++;
                }
                index++;
            }
            //每遍历完10万数据，将其中的命令同步执行一次
            pipe.sync();
            log("已遍历key数量" + index + "，其中1小时有效期key数量"+dealCount);
            totalCount += index;
            dealTotalCount += dealCount;

            cursor = scanResult.getStringCursor();
            log("====cursor:" + cursor);
        }while (!cursor.equals("0"));
        jedis.close();
        stopWatch.stop();
        String result = "共遍历key数量："+totalCount+",共修改key数量：" + dealTotalCount +"\n";
        result += "总耗时：" + stopWatch.getTime(TimeUnit.MILLISECONDS)+"ms";
        log(result);
        log("============脚本结束时间："+LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        bw.close();
    }

    private static void log(String str){
        System.out.println(str);
        try {
            BufferedWriter bw = getFileWriter();
            bw.write(str);
            bw.newLine();
            bw.flush();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static BufferedWriter getFileWriter() throws IOException {
        if(bw != null){
            return bw;
        }
        String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        File logFile = new File(dateStr + ".log");
        if(!logFile.exists()){
            logFile.createNewFile();
        }
        FileOutputStream fileOutputStream = new FileOutputStream(logFile, true);
        OutputStreamWriter opstw = new OutputStreamWriter(fileOutputStream, "UTF-8");
        bw = new BufferedWriter(opstw);
        return bw;
    }

    @Test
    public void addTestData(){
        StopWatch stopWatch = new StopWatch();
        stopWatch.start();
        // 连接Redis
        Jedis jedis = new Jedis("r-bp1swvqq7f9lhx5yhapd.redis.rds.aliyuncs.com", 6379);
        jedis.auth("bacasetest:LysFK532");
        //新增测试数据数量
        int dateCount = 5000;
        //批次执行命令数量
        int syncCount = 5000;
        int num =0;
        String matchKey = "refreshTokenCacheL3:";
        String testVal = "\\x00\\x016net.newcapec.campus.oauth2.entity.pojo.AccessTokenInfo\\xfa\\x01Fnet.newcapec.campus.oauth2.entity.pojo.AccessTokenInfo$AccessTokenType\\x00\\xfd\\xfd\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x18@\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x01\\x00\\x00\\xff\\xfc\\x0a3823538367\\xfc\\x0567023\\xfc\\x0214\\xfc\\x03142\\xfc\\x0800000000\\xfc\\x0c\\xff\\xb0e\\xff\\x00_\\xffnfNFC\\xff\\x14o\\xff:y\\xff\\xfb|\\xff\\xdf~-T\\xfc\\x06100002\\xfc\\x0b15866874052\\xfc\\x03\\xffAS\\xff\\x07N\\xff\\x8cN\\xfc\\x06100002\\xfc\\x08E3E690BF\\x00\\x00\\x10\\x01\\xfc\\x04base\\xfd\\x00\\x02\\x03\\x00\\x01\\x12java.sql.Timestamp7\\x82(\\xb5\\xbb\\x1cS\\x01\\x00\\x00B\\x00\\x00\\xf6\\x81\\xa1\\x86\\x01\\x00\\xfa\\x011net.newcapec.campus.oauth2.entity.OauthUser$STATE\\x00\\xfc\\x12\\xff\\xd1\\x90\\xff\\xde]\\xff\\x02^\\xff\\xd8\\x9a\\xff\\xb0e\\xff\\x80b\\xff/g\\xff\\xa7N\\xff\\x1aN\\xff\\x00_\\xff\\xd1S\\xff:S\\xff\\xce\\x8f\\xff%f\\xffW\\x8818\\xff\\xf7S\\xfc\\x1291410100721832659Y\\xff\\xfc\\x0b\\xff\\xb0e\\xff\\x00_\\xffnf\\xff5u\\xffP[\\xff\\xa1\\x80\\xff\\xfdN\\xff\\x09g\\xffP\\x96\\xfflQ\\xff\\xf8S\\xfc\\x16lihaofeng@newcapec.net\\xfc\\x0b13140199391\\xfc e10adc3949ba59abbe56e057f20f883e\\xfc\\x08Newcapec\\xfc\\x06100000\\x00\\xfd\\xfc\\x03485\\xfc\\x08\\xff-N\\xff\\x9fS\\xff\\x9cQ\\xff\\x1aN\\xff'Y\\xfff[\\xfflQ\\xffKm\\xfc\\x0b13183009652\\xfc\\x0816550288\\x00\\x00\\xfd \\x00\\x01Z\\xfa\\x013net.newcapec.campus.oauth2.entity.Client$AUDIT_TYPE\\x00\\xfa\\x015net.newcapec.campus.oauth2.entity.Client$CLIENT_STATE\\x01\\x00\\xff\\xea\\x037\\x82\\x88 jGr\\x01\\x00\\x00B\\x00\\x00\\xf6\\x81\\xa1\\x86\\x01\\x00\\xfc 503dca8675774e34b945ca06a6e267af\\xfc\\x09\\xff-N\\xff\\xf6\\x94app\\xffL]\\xffeQh5\\xfc 57193E617C1570DAC431F20E7CFEA87F\\xfc9https://exiaoyuan.17wanxiao.com:7778/ecardh5/bootcallback\\xff\\xff\\xff\\xff\\xff\\xff\\xfc\\x00\\xfc\\x06100000\\x00\\xfa\\x019net.newcapec.campus.ifaceserver.utils.Constants$GrantType\\x01\\xf6\\x82\\xc8\"\\xfc\\xd7\\x88\\x01\\x00\\x00\\xff\\xfc 5dd42fbe772a99433fbaffc062c79ee3\\xfc sGA2c2vwelRnyE4HHcJ/oUc4vLMMU9eD\\x00";
        Pipeline pipe = jedis.pipelined();
        for(int i=0; i < dateCount; i++){
            String uuid = UUID.randomUUID().toString().replaceAll("-", "");
            pipe.set(matchKey +uuid, testVal, "nx", "ex", RandomUtils.nextInt(60 * 60 * 24 * 20, 60 * 60 * 24 * 40));
            num++;
            if(i>0 && (i%syncCount==0)){
                pipe.sync();  // 执行
                pipe = jedis.pipelined();   // 重新创建Pipeline
                System.out.println("已新增key数量" + num);
            }
        }
        jedis.close();
        stopWatch.stop();
        String result = "共新增key数量：" + num ;
        result += "总耗时：" + stopWatch.getTime(TimeUnit.MILLISECONDS)+"ms";
        System.out.println(result);
    }
}
```

在脚本项目下增加application.properties配置文件，用于配置redis连接信息：

```properties
host=r-bp1skgykoyac2b7zkv.redis.rds.aliyuncs.com
pwd=r-bp1skgykoyac2b7zkv:A48d19366190
```

### 执行结果

在运维人员的协助下，搭建了一个生产环境redis的备份镜像环境，我们使用上述的脚本模拟在生产redis中执行，得到如下结果：

![image-20230629143453694](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306291434737.png)

执行耗时约8分钟，共遍历key数量：26422363，一共修改有效期小于30天的key数量：5396680。

在脚本执行期间所在服务器状况如下：

![image-20230629143710152](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306291437192.png)

从脚本日志得知执行时间在13:50~13:58期间，过程中CPU有轻微上升，在3%左右；而主要的消耗在于脚本命令和redis数据库的IO交互中，所以脚本执行中的内网带宽速率上升到了30M~40M左右；其他服务器数据指标并没有明显变化。

在redis服务器端，的主要性能指标如下，CPU使用率上升到9%左右，出入口的流量在4M~6M左右。

![image-20230629144636817](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306291446861.png)

由于redis是惰性删除，过期的数据不会在内存中马上比删除,所以需要在redis后台管理直接删除下已过期的数据：

![image-20230630114253869](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306301143242.png)

然后观察redis内存变化，发现内存很快就降下来了：

![image-20230630114333500](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202306301143593.png)