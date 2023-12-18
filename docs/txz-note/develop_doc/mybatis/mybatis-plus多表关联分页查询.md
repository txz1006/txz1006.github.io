mybatis-plus多表关联分页查询

**1.指定分页插件**

```java
@EnableTransactionManagement
@Configuration
@MapperScan("com.web.member.mapper")
public class MybatisPlusConfig {
    /**
     * mybatis-plus SQL执行效率插件【生产环境可以关闭】
     */
    @Bean
    public PerformanceInterceptor performanceInterceptor() {
        return new PerformanceInterceptor();
    }

    /*
     * 分页插件，自动识别数据库类型 多租户，请参考官网【插件扩展】
     */
    @Bean
    public PaginationInterceptor paginationInterceptor() {
        return new PaginationInterceptor();
    }
}
```

创建关联表的VO实体对象

```java
public class DvlpAgentCheckComplainVo extends DvlpAgentCheckComplain {

    @Excel(name = "代维公司id", width = 15)
    @ApiModelProperty(value = "代维公司id")
    private java.lang.String agentCompanyId;
    /**代维公司名称*/
    @Excel(name = "代维公司名称", width = 15)
    @ApiModelProperty(value = "代维公司名称")
    private java.lang.String agentCompanyName;
    /**考核专业*/
    @Excel(name = "考核专业", width = 15)
    @ApiModelProperty(value = "考核专业")
    private java.lang.String checkTypeId;
    /**考核专业*/
    @ApiModelProperty(value = "考核专业名称")
    private java.lang.String checkTypeName;
    /**考核地市*/
    @Excel(name = "考核地市", width = 15)
    @ApiModelProperty(value = "考核地市")
    private java.lang.String checkCity;
    /**考核月份*/
    @Excel(name = "考核月份", width = 15)
    @ApiModelProperty(value = "考核月份")
    private java.lang.String checkMonth;
    /**考核附件*/
    @Excel(name = "考核附件", width = 15)
    @ApiModelProperty(value = "考核附件")
    private java.lang.String checkFile;
}
```

**2.Mapper接口指定查询sql**

```java
public interface DvlpAgentCheckComplainMapper extends BaseMapper<DvlpAgentCheckComplain> {


    @Select("select c.*, " +
            "a.agent_company_id, " +
            "a.agent_company_name, " +
            "a.check_type_id, " +
            "a.check_type_name, " +
            "a.check_city, " +
            "a.check_month, " +
            "a.check_file " +
            " from dvlp_agent_check_complain c left join dvlp_agent_check a on a.id = c.check_main_id ${ew.customSqlSegment}")
    public List<DvlpAgentCheckComplainVo> getAgentCheckComplainVoList(Page<DvlpAgentCheckComplainVo> page, @Param(Constants.WRAPPER) Wrapper queryWrapper);
}
```

该接口有两个参数：Page参数会自动给sql加上limit x X语句，Wrapper参数会给sql加上查询条件(注意要使用@Param注解和sql中使用${ew.customSqlSegment}占位符，不能加where关键字)

注意，这里Wrapper条件对象一定最好要是和数据表对应的实体类，不然会出现ew.customSqlSegment报错的问题。如果非要用自定义参数对象，可以通过如下的代码初始化：

```java
TableInfoHelper.initTableInfo(new MapperBuilderAssistant(new MybatisConfiguration(), ""), PayOrderCheckAggregateDTO.class);
```



**3.service层查询**

```java
public interface IDvlpAgentCheckComplainService extends IService<DvlpAgentCheckComplain> {

    public Page<DvlpAgentCheckComplainVo> getAgentCheckComplainList(Page<DvlpAgentCheckComplainVo> agentCheckComplainVoPage, QueryWrapper queryWrapper);
}
//============================================

@Service
public class DvlpAgentCheckComplainServiceImpl extends ServiceImpl<DvlpAgentCheckComplainMapper, DvlpAgentCheckComplain> implements IDvlpAgentCheckComplainService {

    @Override
    public Page<DvlpAgentCheckComplainVo> getAgentCheckComplainList(Page<DvlpAgentCheckComplainVo> agentCheckComplainVoPage,
                                                                    QueryWrapper queryWrapper) {
        return agentCheckComplainVoPage.setRecords(this.baseMapper.getAgentCheckComplainVoList(agentCheckComplainVoPage, queryWrapper));
    }
}
```

直接使用mybatis-plus的`this.baseMapper`对象查询Mapper接口的sql，返回一个分页的Page对象

**4.controller查询**

```java
@GetMapping(value = "/list")
public Result<?> queryPageList(DvlpAgentCheckComplain dvlpAgentCheckComplain,
                        @RequestParam(name="pageNo", defaultValue="1") Integer pageNo,
                        @RequestParam(name="pageSize", defaultValue="10") Integer pageSize,
                        HttpServletRequest req) {
   QueryWrapper<DvlpAgentCheckComplainVo> queryWrapper = new QueryWrapper<>();
   queryWrapper.eq("agent_company_id","11");
   Page<DvlpAgentCheckComplainVo> pages = new Page<DvlpAgentCheckComplainVo>(pageNo, 5);
   IPage<DvlpAgentCheckComplainVo> pageList =  dvlpAgentCheckComplainService.getAgentCheckComplainList(pages, queryWrapper);
   return Result.ok(pageList);
}
```

指定分页对象pages和查询条件对象queryWrapper，之后调用service接口进行查询。查询结果如下：

```xml
==>  Preparing: SELECT c.*, a.agent_company_id, a.agent_company_name, a.check_type_id, a.check_type_name, a.check_city, a.check_month, a.check_file FROM dvlp_agent_check_complain c LEFT JOIN dvlp_agent_check a ON a.id = c.check_main_id WHERE (agent_company_id = ?) LIMIT ?,? 
==> Parameters: 11(String), 0(Long), 5(Long)
<==    Columns: id, check_main_id, complain_code, complain_state, complain_reason, current_approver_id, comlain_file, attr1, attr2, attr3, create_by, create_time, update_by, update_time, del_flag, agent_company_id, agent_company_name, check_type_id, check_type_name, check_city, check_month, check_file
<==        Row: 111, 1303604953090306049, 1212, 0, null, null, null, null, null, null, null, null, null, null, 0, 11, 测试组织1, quota4, 网优重保站物理站址, 郑州市, 2020-09, temp/sp20190612_155329_412_1599639846861.png
<==        Row: 1111212, 1303604953090306049, 1212, 0, null, null, null, null, null, null, null, null, null, null, 0, 11, 测试组织1, quota4, 网优重保站物理站址, 郑州市, 2020-09, temp/sp20190612_155329_412_1599639846861.png
<==        Row: 11122, 1303604953090306049, 1212, 0, null, null, null, null, null, null, null, null, null, null, 0, 11, 测试组织1, quota4, 网优重保站物理站址, 郑州市, 2020-09, temp/sp20190612_155329_412_1599639846861.png
<==        Row: 111333, 1303604953090306049, 1212, 0, null, null, null, null, null, null, null, null, null, null, 0, 11, 测试组织1, quota4, 网优重保站物理站址, 郑州市, 2020-09, temp/sp20190612_155329_412_1599639846861.png
<==        Row: 111333212121, 1303604953090306049, 1212, 0, null, null, null, null, null, null, null, null, null, null, 0, 11, 测试组织1, quota4, 网优重保站物理站址, 郑州市, 2020-09, temp/sp20190612_155329_412_1599639846861.png
<==      Total: 5
```



**5.其他**

此方法的查询条件必须是关联表双方其一独有的字段，若要查询多表都有的字段，则需要将sql写成Mapper.xml中的sql查询对象