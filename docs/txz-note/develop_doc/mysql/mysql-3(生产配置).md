mysql-3(生产配置)

#### 一、机器选项

在生产环境中，java环境一般选用4核8G内存的机器，每秒大约可抗500左右的并发,具体还要看每个请求用到的时间，请求时间越短并发量就可以越高，当并发量高到一个度时，会受到CPU线程切换上限、服务器软件并发上限的限制。

而数据库由于在并发环境中IO操作会非常的频繁，所以配置一般要高于java环境的机器，可以选用8核16G的机器(大约能抗一两千的并发)，16核32G的机器(大约能抗四五千的并发)

#### 二、数据库测压的关注点

数据库性能相关：

QPS(query per second)：即数据库每秒能执行多少条sql；对java系统而言就是每秒能执行多少请求

TPS(transaction per second)：即数据库每秒能执行多少个事务提交/事务回滚，例如交易系统每秒完成多少笔交易

**系统IO相关**：

IOPS：指机器每秒的随机IO处理能力，即每秒能处理多少随机IO读写次数，如mysql会有IO线程随机将buffer pool中的脏数据写入磁盘

吞吐量：一般指每秒中能完成多少字节的信息写入磁盘(磁盘读写效率)

latency：往磁盘写入一条数据的延迟

**其他系统指标**：

CPU负载：每秒钟CPU使用率

内存负载：每秒钟内存的使用量

网络负载：每秒钟网卡的上传下载量

#### 三、使用测压工具sysbench测试mysql

sysbench是一个开源的的测压工具，能帮助我们更好的了解一台机器的cpu、多线程、磁盘IO等方面的极限负载，在测试完成后还能生成测试结果，让我们能直观的了解到当前环境的大概负载数(每秒能处理多少的数据量)；此外，还可以对数据库的相关读写性能进行压测，下面就是sysbench测试mysql的实例：

这里我们准备了一台1核2G的linux机器，使用yum install -y sysbench命令安装sysbench软件，之后使用sysbench -version查询是否安装成功。

若出现libmysqlclient.so.18: cannot open等异常，则需要找到对应该文件，将其加入到动态链接库中

```
将libmysqlclient.so.18文件加入到/usr/lib64文件夹下
ln -s /usr/local/mysql/lib/libmysqlclient.so.18 /usr/lib64

验证安装是否成功：
sysbench -version
```

安装后就可以测压了，下面来分析下一条测压语句

```sh
sysbench --db-driver=mysql --time=300 --threads=10 --report-interval=1 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=test_user --mysql-password=test_user --mysql-db=test_db --tables=20 --table_size=1000000 oltp_read_write --db-ps-mode=disable prepare
```

这条命令的参数不少，但是很容易理解大概的意思是在300秒内开10个线程去test_db数据库中创建20张表，每张表插入100万条数据，我们来逐一分析下各个参数：

- --db-driver=mysql：指数据库驱动是mysql

- --time=300：测试时间一共300秒

- --threads=10：开10个线程来并发测试

- --report-interval=1：每一秒钟打印输出一条测试结果

- --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root --mysql-password=123456：数据库的连接信息

- --mysql-db=test_db：测试的哪个数据库

- --table=20：创建几个测试表

- --table_size=1000000：每个表创建100万条测试数据

- oltp_read_write：oltp数据库测试读写

- --db-ps-mode=disable：禁用ps模式

- prepare：这个参数会按照上面的表配置，去数据库中自动创建20张表，每个表写入100万条数据

  

测试数据构建好后就可以正式开始测试了，一般的测试的测试语句如下：

1.测试数据库的综合读写TPS性能，注意prepare改为了run，就是正式测试了

```sh
sysbench --db-driver=mysql --time=300 --threads=10 --report-interval=1 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=test_user --mysql-password=test_user --mysql-db=test_db --tables=20 --table_size=1000000 oltp_read_write --db-ps-mode=disable run
```

2.测试只读性能，使用的是oltp_read_only模式

```sh
sysbench --db-driver=mysql --time=300 --threads=10 --report-interval=1 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=test_user --mysql-password=test_user --mysql-db=test_db --tables=20 --table_size=1000000 oltp_read_only --db-ps-mode=disable run
```

3.测试数据写入性能，使用的oltp_write_only模式

```sh
sysbench --db-driver=mysql --time=300 --threads=10 --report-interval=1 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=test_user --mysql-password=test_user --mysql-db=test_db --tables=20 --table_size=1000000 oltp_write_only --db-ps-mode=disable run
```

4.测试数据(非索引)更新性能，使用的oltp_update_non_index 模式(测试索引模式使用oltp_update_index)

```sh
sysbench --db-driver=mysql --time=300 --threads=10 --report-interval=1 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=test_user --mysql-password=test_user --mysql-db=test_db --tables=20 --table_size=1000000 oltp_update_non_index --db-ps-mode=disable run
```

每隔一秒测试输出的结果格式如下：

```sh
[ 296s ] thds: 10 tps: 78.99 qps: 1628.89 (r/w/o: 1158.92/311.98/157.99) lat (ms,95%): 200.47 err/s: 0.00 reconn/s: 0.00
[ 296s ]代表是测试的第296秒输出的结果

thds: 10代表测试使用了10个线程
tps: 78.99 代表每秒处理了78.99个事务
qps: 1628.89代表每秒处理了1628.89条数据
r/w/o: 1158.92/311.98/157.99代表这一秒中读的请求有1158.92条，写的请求有311.98条，其他请求有157.99条(对qps的分析)

lat (ms,95%): 200.47代表95%的请求延迟是在200.47ms以下
err/s: 0.00 reconn/s: 0.00代表每秒有0个请求请求失败，有0个请求重试失败
```

上面的测试结果会根据服务器的硬件和配置的不同而变化，在整个测试进行完成后还有一个最终测试结果格式如下：

```sh
SQL statistics:
    queries performed:
        
        read:            379722//300秒内一共执行了379722次读请求
        write:           108492//300秒内一共执行了108492次写请求
        other:           54246//300秒内一共执行了54246次其他请求
        total:           542460//共计
    transactions:        27123  (90.39 per sec.) //共执行事务27123个(平均90.39个每秒)
    queries:             542460 (1807.84 per sec.) //共执行请求542460个(平均1807.84个每秒)
    ignored errors:      0      (0.00 per sec.)
    reconnects:          0      (0.00 per sec.)

General statistics:
    total time:                          300.0575s //测试所用时间
    total number of events:              27123 //共执行事务27123个

Latency (ms):
         min:                                   11.49  //请求最小延迟
         avg:                                  110.61  //请求平均延迟
         max:                                  400.87  //请求最大延迟
         95th percentile:                      193.38  //95%请求的平均延迟
         sum:                              3000032.01

//线程公平性
Threads fairness:
    events (avg/stddev):           2712.3000/6.71
    execution time (avg/stddev):   300.0032/0.02

```

#### 四、服务器监控参数

在进行数据库测试时，可以开启一个新的ssh连接来观察服务器的IOPS负载、吞吐量、网络负载、CPU负载等情况

##### 监控cpu负载

使用top命令查询cpu使用情况，我们能在第一行看好cpu总览信息

```sh
top - 14:29:17 up 41 days, 21:53,  2 users,  load average: 2.07, 0.69, 0.33
=====================
14:29:17 up 41 days, 21:53是当前时间和服务器已经运行时间(已运行41天21小时)
2 users是当前有两个用户正常访问服务器
 load average: 2.07, 0.69, 0.33是cpu在之前一段时间的负载信息(1分钟内的负载，5分钟内的负载，15分钟的负载)；由于当前服务器是1核的cpu，达到最大的负载值为1，而上面的top信息1分钟内的负载是2.07，所以cpu已经处于超负荷状态，超出1的部分是等待中的待处理数据(一般几核，最大负载就是几；而一台机器的最大CPU负载最好控制在60%-80%)
```

##### 监控内存使用率

在top信息往下看几行就是当前内存的负载信息(测试用的服务器为2G内存)

```
KiB Mem :  1882352 total,    80884 free,   557232 used,  1244236 buff/cache
1882352 total是服务器内存共有1.8G内存
80884 free是当前约有80M的内存可以使用
557232 used是当前约有540M的内存已经使用
1244236buff/cache是服务器设置的OS cache内存缓冲区，大约1.2G大小
```

#### 五、使用dstat监控IO信息

输入dstat命令，若提示错误，则表示未安装dstat软件，可使用yum install -y dstat安装软件

##### 监控IO吞吐量

使用dstat -d命令监控磁盘的吞吐量

```sh
-dsk/total-
 read  writ
8688B   46k
8312k   18M
7468k   20M
9524k   17M
  13M   17M
.....
```

每秒钟监控一次，左边的是磁盘每秒读取量速度，右边是每秒磁盘写入速度

##### 监控IOPS量(次数)

```sh
--io/total-
 read  writ
0.18  5.01 
 259   782 
 306   841 
 255   958 
 217   900 
 204   975 
 308   839 
.....
```

左边的是每秒读IOPS次数，右边是每秒写IOPS次数

##### 监控网络使用率

```sh
-net/total-
 recv  send
   0     0 
 815B 2381B
2939B 5539B
 540B  776B
1671B 3920B
1242B 4109B
....
```

左边是网络下载速率，右边是网络上传速率

#### 六、搭建可视化监控平台

我们不可能一直通过命令来监控服务器负载信息，所以最好能有一个直观的方式通过图表将负载表现出来，这就需要将负载信息可视化了；在linux中可以通过prometheus和grafana两个软件搭建负载可视化平台。

其中prometheus是监控数据采集平台，node_exporter可以采集服务器信息导入到prometheus的时许数据库中，grafana是监控平台本身，可以将prometheus中的监控数据以图表展示出来。

##### 安装prometheus

到http://cactifans.hi-www.com/prometheus/下载prometheus相关安装包

```
prometheus-2.14.0.linux-amd64.tar.gz    和node_exporter-0.18.0.linux-amd64.tar.gz   
```

到https://github.com/prometheus/mysqld_exporter/releases/download/v0.10.0/mysqld_exporter-0.10.0.linux-amd64.tar.gz下载mysql的数据采集插件

```
mysqld_exporter-0.10.0.linux-amd64.tar
```

将三个文件上传到服务器中解压执行，命令如下：

```
tar zxvf prometheus-2.14.0.linux-amd64.tar.gz  -C /data
tar xf node_exporter-0.18.0.linux-amd64.tar.gz  -C /root
tar xf mysqld_exporter-0.10.0.linux-amd64.tar.gz  -C /root
```

到/data文件夹下修改prometheus文件夹名，并修改配置文件：

```
 cd /data
 mv prometheus-2.14.0.linux-amd64/ prometheus
 cd prometheus/
 vim prometheus.yml
```

修改prometheus.yml配置文件为：

```yml
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
#设置获取服务器时序数据(对应node_exporter，9100端口)
  - job_name: 'Host'
    file_sd_configs:
    - files:
      - 'host.yml'
    metrics_path: /metrics
    relabel_configs:
    - source_labels: [__address__]
      regex: (.*)
      target_label: instance
      replacement: $1
    - source_labels: [__address__]
      regex: (.*)
      target_label: __address__
      replacement: $1:9100
#设置获取mysql的时序数据(对应mysqld_exporter，9104)
  - job_name: 'MySQL'
    file_sd_configs:
    - files:
        - 'mysql.yml'
    metrics_path: /metrics
    relabel_configs:
    - source_labels: [__address__]
      regex: (.*)
      target_label: instance
      replacement: $1
    - source_labels: [__address__]
      regex: (.*)
      target_label: __address__
      replacement: $1:9104
#9090端口是prometheus使用的端口，下面是示例
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

配置好后就可以启动prometheus了，启动命令如下：

```sh
./prometheus --storage.tsdb.retention=30d --web.enable-lifecycle &
--storage.tsdb.retention=30 //参数指监控信息只保留前30天的
--web.enable-lifecycle //参数可以开启配置热更新和项目关闭
例如：
刷新配置 curl -XPOST localhost:9090/-/reload
健康检测 curl -XGET localhost:9090/-/healthy
项目关闭 curl -XPOST localhost:9090/-/quit
```

启动后可以通过9090端口访问到prometheus了：

![image-20201224174802131](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201224174903.png)

##### 安装运行node_exporter

node_exporter是prometheus监控平台下的一个系统信息采集器，我们只需要启动它，并在prometheus.yml中配置好采集器的信息输出地址，那么prometheus平台就可以存储到node_exporter收集的信息。

之前我们已经将node_exporter-0.18.0解压到了root文件夹下，我们可以直接进入解压目录下启动项目：

```
cd node_exporter-0.18.0
nohup ./node_exporter &
若出现nohup输出日志警告，则可以使用./node_exporter >/dev/null 2>&1 &
```

启动项目后，我们可以验证一下是否node_exporter是否在正常工作：

```
//node_exporter项目的端口是9100
curl 127.0.0.1:9100 
curl 127.0.0.1:9100/metrics |grep node_time
//若能正常查询到数据，则采集器工作正常
```

下面我们要将node_exporter的信息导入到prometheus中，之前我们在prometheus.yml中已经将9100端口的信息配置到了host.yml中

所以，在prometheus.yml同级文件夹下创建host.yml,指向node_exporter的地址内容如下：

```yml
- targets:
  - 127.0.0.1:9100
  labels:
    service: app
```

之后刷新prometheus配置

```
curl -XPOST localhost:9100/-/reload
```

再次访问项目，在status->target中可以看到node_exporter的信息已经输出到prometheus了

![image-20201225152608378](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225152616.png)

此时，我们可以使用prometheus的**PromQL**语法，来计算获取服务器的信息了：

下面就是查询的CPU使用率

![image-20201225153115329](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225153115.png)

此时，系统的信息通过node_exporter存储到了prometheus的时许数据库中了，下面就要通过grafana软件，将prometheus的数据可视化了

##### 安装grafana

下载grafana文件，地址如下：

https://mirrors.huaweicloud.com/grafana/6.7.5/grafana-6.7.5.linux-amd64.tar.gz

这是grafana的主体文件，我们下载后将之解压到/data/prometheus文件夹下

```sh
-- 解压
tar xvf grafana-6.7.5.linux-amd64.tar.gz -C /data/prometheus
cd /data/prometheus
--重命名
mv grafana-6.7.5 grafana
cd grafana/bin
-- 启动grafana
./grafana-server &
```

之后我们就可以通过3000端口，访问grafana了：

![image-20201225153745607](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225153745.png)

grafana的默认账号密码是admin/admin，登陆成功后我们需要将prometheus的数据输出到grafana中，所以需要在grafana中配置一个prometheus数据源：

![image-20201225154025680](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225154025.png)

添加的表单如下：

![image-20201225154111225](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225154111.png)

输入Name和prometheus的地址，其他的默认就好了，点击保存，若成功则出现数据库正在工作的绿色提示.

下面，我们就可以配置仪表盘json文件，展示数据了。

##### 配置展示仪表盘

添加展示仪表盘有三种方式：

![image-20201225154646429](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225154646.png)

常见的仪表盘配置json可以到https://github.com/percona/grafana-dashboards/archive/v1.6.1.tar.gz项目下载，在其dashboards文件夹下的json文件都是仪表盘信息。

![image-20201225154817949](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225154818.png)

json文件中配置有prometheus的**PromQL**查询语句，会将结果渲染成可视图形。

=================

PS：注意，由于各个服务器的操作系统是有差异的，可能node_exporter采集的信息名称会有一些不同，此时，json文件的查询参数名称一定要和node_exporter采集参数一一对应。

```
个人遇到的参数名称的变化
* node_cpu ->  node_cpu_seconds_total
* node_memory_MemTotal -> node_memory_MemTotal_bytes
* node_memory_MemFree -> node_memory_MemFree_bytes
* node_filesystem_avail -> node_filesystem_avail_bytes
* node_filesystem_size -> node_filesystem_size_bytes
* node_disk_io_time_ms -> node_disk_io_time_seconds_total
* node_disk_reads_completed -> node_disk_reads_completed_total
* node_disk_sectors_written -> node_disk_written_bytes_total
* node_time -> node_time_seconds
* node_boot_time -> node_boot_time_seconds
* node_intr -> node_intr_total
* node_filesystem_free -> node_filesystem_free_bytes
* node_filesystem_size -> node_filesystem_size_bytes
* node_disk_bytes_read-> node_disk_read_bytes_total
* node_disk_bytes_written -> node_disk_written_bytes_total
* node_disk_reads_completed->node_disk_reads_completed_total
* node_disk_writes_completed  ->
		node_disk_writes_completed_total
* node_network_receive_bytes  ->
		node_network_receive_bytes_total
* node_network_transmit_bytes ->
		node_network_transmit_bytes_total
* node_network_receive_errs   ->
		node_network_receive_errs_total
```

=================

下面我们使用方式2来导入仪表盘信息，我们在grafana.com官网中寻找dashborad模块，找到一个node-exporter的信息输出的仪表盘：https://grafana.com/grafana/dashboards/8919

![image-20201225155903513](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225155903.png)

上图有三个信息是我们需要关注的，右边的8919是方式2的下载码，也可以下载json到本地再进行导入；由于我们安装的grafana版本是6.7.5，所以需要有个table-old的改动，所以我们下载下来按这个要求修改json文件。

修改后就可以导入了，导入后会有一个确认页面，我们选择我们当前的配置信息后点击确认就完成了。（其中的DataSource要和时许请求的job名称相对应）

![image-20201225160402020](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225160402.png)

之后，我们就可以看到机器美观的监控页面了：

![image-20201225160603814](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225160604.png)

##### 安装mysql_exporter

项目我们来安装mysql信息采集插件，之前我们已经将其解压到了/root文件夹下，我们将其移动到/data/prometheus下，并将其重命名为mysqld_exporter

之后我们需要创建一个mysql配置文件，用于mysql_exporter能够成功访问数据。在mysqld_exporter文件夹下创建一个my.cnf配置文件，内容如下：

```
[client]
host=127.0.0.1
port=3306
user=root
password=pengwenbo
```

之后就可以使用这个配置文件启动mysql_exporter了，命令如下：

```
/data/prometheus/mysqld_exporter/mysqld_exporter --config.my-cnf=/data/prometheus/mysqld_exporter/my.cnf &
```

mysql_exporter的默认端口是9104，我们可以访问这个端口，验证mysqld_exporter是否工作正常：

```
curl 127.0.0.1:9104
curl 127.0.0.1:9104/metrics
```

如果正常输出信息则采集器正常。

下面我们需要在prometheus.yml中添加mysql_exporter的访问路径，这个工作之前已经做过了，需要我们增加一个mysql.yml（和之前的host.yml类似）

mysql.yml的内容如下：

```yml
- targets:
  - 127.0.0.1
  labels:
    service: mysql_app
```

刷新prometheus配置，就可以看到mysql_exporter的采集信息了：

![image-20201225163901872](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225163902.png)

最后，我们到grafana官网找一个仪表盘导入到grafana中(下载码为7362)：

![image-20201225164149261](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201225164149.png)

##### 安装jvm_exporter

下面我们来监控tomcat及其JVM的信息。

首先我们需要下载一个jvm_exporter来获取tomcat的各种信息，这个可以通过https://github.com/prometheus/jmx_exporter下载，下载下来是个jar包(jmx_prometheus_javaagent-0.15.0.jar)，我们需要在tomcat的启动参数中加入这个jar包，让他跟随tomcat一起启动来同步获取tomcat的各种信息。

首先，我们使用这个jar时，需要一个创建一个启动配置文件，这个可以参考https://github.com/prometheus/jmx_exporter/tree/master/example_configs，我们在/usr/local/目录创建一个jmx文件夹，在其中创建一个config.yaml文件写入如内容：

```yml
---   
lowercaseOutputLabelNames: true
lowercaseOutputName: true
rules:
- pattern: 'Catalina<type=GlobalRequestProcessor, name=\"(\w+-\w+)-(\d+)\"><>(\w+):'
  name: tomcat_$3_total
  labels:
    port: "$2"
    protocol: "$1"
  help: Tomcat global $3
  type: COUNTER
- pattern: 'Catalina<j2eeType=Servlet, WebModule=//([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), name=([-a-zA-Z0-9+/$%~_-|!.]*), J2EEApplication=none, J2EEServer=none><>(requestCount|maxTime|processingTime|errorCount):'
  name: tomcat_servlet_$3_total
  labels:
    module: "$1"
    servlet: "$2"
  help: Tomcat servlet $3 total
  type: COUNTER
- pattern: 'Catalina<type=ThreadPool, name="(\w+-\w+)-(\d+)"><>(currentThreadCount|currentThreadsBusy|keepAliveCount|pollerThreadCount|connectionCount):'
  name: tomcat_threadpool_$3
  labels:
    port: "$2"
    protocol: "$1"
  help: Tomcat threadpool $3
  type: GAUGE
- pattern: 'Catalina<type=Manager, host=([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), context=([-a-zA-Z0-9+/$%~_-|!.]*)><>(processingTime|sessionCounter|rejectedSessions|expiredSessions):'
  name: tomcat_session_$3_total
  labels:
    context: "$2"
    host: "$1"
  help: Tomcat session $3 total
  type: COUNTER
```

 **收集tomcat信息**

如果项目是一个jar包，则使用如下命令启动jar包：

```yaml
java -javaagent:./jmx_prometheus_javaagent-0.3.0.jar=9151:config.yaml -jar yourJar.jar
//其中9151是监控对外的端口号
//可以的话，jmx_prometheus_javaagent.jar和config.yaml可以使用绝对路径
```

如果项目是war包，或者直接放在tomcat中其中，那么就需要在容器的其中参数添加javaagent配置参数了。

以tomcat为例，我们在tomcat/bin下找到setenv.sh(如果没有就在catalina.sh中加)，在其中加入JAVA_OPTS配置参数：

```yaml
JAVA_OPTS="-javaagent:/usr/local/jmx/jmx_prometheus_javaagent-0.3.1.jar=39081:/usr/local/jmx/config.yaml"
//对外暴露39081端口
```

加入后，通过service tomcat restart 命令重启tomcat

重启后使用ss -atnlp |grep java命令来查询jvm_exporter释放工作正常，如果查询到39081端口进程则收集器工作正常：

![image-20210220162218641](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210220162420.png)

进一步通过请求来验证收集器的工作是否正常（curl 127.0.0.1:39081/metrics）：

![image-20210220162559828](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210220162559.png)

收集到数据后，下一步就要将这些数据导入到prometheus的时序数据库中：

我们在prometheus.xml中添加tomcat收集器数据配置：

```yml
  - job_name: 'tomcat'
    static_configs:
      - targets: ['127.0.0.1:39081']
```

之后通过curl -XPOST localhost:9090/-/reload命令刷新prometheus配置，我们就可以在界面中看到tomcat信息已经被收集进了时许数据库中。

![image-20210220162941125](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210220162941.png)

最后我们通过grafana官网找一个仪表盘(8563)导入其中，并指定数据源为tomcat：

![image-20210220163214900](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210220163214.png)

添完成后就可以看到图表数据了：

![image-20210220163253391](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210220163253.png)

node_exporter是否成功配置参考：https://www.cnblogs.com/bigberg/p/10118137.html

prometheus常见查询语句参考：http://www.linuxe.cn/post-503.html

prometheus的配置文件解析：https://soulchild.cn/1965.html

jvm监控解析：https://www.cnblogs.com/you-men/p/13216976.html 

https://www.cnblogs.com/zgz21/p/12054518.html

其他：如果想在监控面板基础上配置阈值报警通知功能，则需要按照AlterManager软件(prometheus的独立报警服务)，可以参考：https://www.cnblogs.com/chenqionghe/p/10494868.html