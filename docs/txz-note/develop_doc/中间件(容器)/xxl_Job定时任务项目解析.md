### xxl_job项目解析

#### 1.项目中用到的设计模式

单例模式

```java
@Component
public class XxlJobAdminConfig implements InitializingBean, DisposableBean {

    private static XxlJobAdminConfig adminConfig = null;
    public static XxlJobAdminConfig getAdminConfig() {
        return adminConfig;
    }

    private XxlJobScheduler xxlJobScheduler;

    @Override
    public void afterPropertiesSet() throws Exception {
        adminConfig = this;
		//项目初始化，init会开启多个线程初始化项目功能
        xxlJobScheduler = new XxlJobScheduler();
        xxlJobScheduler.init();
    }
    
	@Resource
    private XxlJobLogReportDao xxlJobLogReportDao;
    @Resource
    private JavaMailSender mailSender;
    
    public XxlJobLogReportDao getXxlJobLogReportDao() {
        return xxlJobLogReportDao;
    }

    public JavaMailSender getMailSender() {
        return mailSender;
    }
}


//使用
XxlJobAdminConfig.getAdminConfig().getXxlJobInfoDao().scheduleJobQuery(...)
```

客户端整合xxljob到Spring

```java
public class XxlJobSpringExecutor extends XxlJobExecutor implements ApplicationContextAware, SmartInitializingSingleton, DisposableBean {
    private static final Logger logger = LoggerFactory.getLogger(XxlJobSpringExecutor.class);


    // start，当前方法在IOC容器启动完成后会执行当前方法
    @Override
    public void afterSingletonsInstantiated() {
        // init JobHandler Repository (for method)
        initJobHandlerMethodRepository(applicationContext);
        // refresh GlueFactory
        GlueFactory.refreshInstance(1);
        super.start();
    }
    
    private void initJobHandlerMethodRepository(ApplicationContext applicationContext) {
        String[] beanDefinitionNames = applicationContext.getBeanNamesForType(Object.class, false, true);
        for (String beanDefinitionName : beanDefinitionNames) {
            Object bean = applicationContext.getBean(beanDefinitionName);
            //获取xxljob注解的bean方法
            Map<Method, XxlJob> annotatedMethods =  MethodIntrospector.selectMethods(bean.getClass(),
                        new MethodIntrospector.MetadataLookup<XxlJob>() {
                            @Override
                            public XxlJob inspect(Method method) {
                                return AnnotatedElementUtils.findMergedAnnotation(method, XxlJob.class);
                            }
                        });
            //...
            //用一个MethodJobHandler对象记录bean中和xxljob注解相关的Method，并注册存放到一个全局Map中
            registJobHandler(name, new MethodJobHandler(bean, executeMethod, initMethod, destroyMethod));
        }
    }
}


```

适配器模式

```
IJobHandler originJobHandler = GlueFactory.getInstance().loadNewInstance(triggerParam.getGlueSource());
jobHandler = new GlueJobHandler(originJobHandler, triggerParam.getGlueUpdatetime());
```

策略模式

```
IJobHandler.execute()
```

工厂模式

```java
@Component
public class JobAlarmer implements ApplicationContextAware, InitializingBean {
    private ApplicationContext applicationContext;
    private List<JobAlarm> jobAlarmList;
    
    @Override
    public void afterPropertiesSet() throws Exception {
        Map<String, JobAlarm> serviceBeanMap = applicationContext.getBeansOfType(JobAlarm.class);
        if (serviceBeanMap != null && serviceBeanMap.size() > 0) {
            jobAlarmList = new ArrayList<JobAlarm>(serviceBeanMap.values());
        }
    }    

    public boolean alarm(XxlJobInfo info, XxlJobLog jobLog) {

        boolean result = false;
        if (jobAlarmList!=null && jobAlarmList.size()>0) {
            result = true;  // success means all-success
            for (JobAlarm alarm: jobAlarmList) {
                boolean resultItem = false;
                try {
                    resultItem = alarm.doAlarm(info, jobLog);
                } catch (Exception e) {
                    logger.error(e.getMessage(), e);
                }
                if (!resultItem) {
                    result = false;
                }
            }
        }

        return result;
    }
}
```

大量使用缓存

```java
//实例1
private static ConcurrentMap<Integer, JobThread> jobThreadRepository = new ConcurrentHashMap<Integer, JobThread>();
public static JobThread registJobThread(int jobId, IJobHandler handler, String removeOldReason){
    JobThread newJobThread = new JobThread(jobId, handler);
    newJobThread.start();

    JobThread oldJobThread = jobThreadRepository.put(jobId, newJobThread);	// putIfAbsent | oh my god, map's put method return the old value!!!
    if (oldJobThread != null) {
        oldJobThread.toStop(removeOldReason);
        oldJobThread.interrupt();
    }
    return newJobThread;
}

public static JobThread loadJobThread(int jobId){
    JobThread jobThread = jobThreadRepository.get(jobId);
    return jobThread;
}    
//实例2
private static ConcurrentMap<String, ExecutorBiz> executorBizRepository = new ConcurrentHashMap<String, ExecutorBiz>();
public static ExecutorBiz getExecutorBiz(String address) throws Exception {
    // valid
    if (address==null || address.trim().length()==0) {
        return null;
    }
    // load-cache
    address = address.trim();
    ExecutorBiz executorBiz = executorBizRepository.get(address);
    if (executorBiz != null) {
        return executorBiz;
    }

    // set-cache
    executorBiz = new ExecutorBizClient(address, XxlJobAdminConfig.getAdminConfig().getAccessToken());

    executorBizRepository.put(address, executorBiz);
    return executorBiz;
}
```

语言国际化

```java
public class I18nUtil {
    private static Logger logger = LoggerFactory.getLogger(I18nUtil.class);

    private static Properties prop = null;
    public static Properties loadI18nProp(){
        if (prop != null) {
            return prop;
        }
        try {
            // build i18n prop
            String i18n = XxlJobAdminConfig.getAdminConfig().getI18n();
            String i18nFile = MessageFormat.format("i18n/message_{0}.properties", i18n);

            // load prop
            Resource resource = new ClassPathResource(i18nFile);
            EncodedResource encodedResource = new EncodedResource(resource,"UTF-8");
            prop = PropertiesLoaderUtils.loadProperties(encodedResource);
        } catch (IOException e) {
            logger.error(e.getMessage(), e);
        }
        return prop;
    }
    
    public static String getString(String key) {
        return loadI18nProp().getProperty(key);
    }
}
//XxlJobAdminConfig
public String getI18n() {
    if (!Arrays.asList("zh_CN", "zh_TC", "en").contains(i18n)) {
        return "zh_CN";
    }
    return i18n;
}
```

使用英文标识做key，本地语言做val

![image-20220708113633338](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202207081136654.png)







