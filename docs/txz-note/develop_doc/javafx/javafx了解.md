javaFx解决的问题：

1. 项目无法编译，显示申请内存不足
   解决：更换jdk11的版本

2. 项目启动失败，显示没有添加模块
   解决：在module-info.java中添加对接的java路径，如：
   ![image-20220606161049162](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206061610436.png)

3. 去掉windows自带的菜单栏，自己定义
   给stage设置style样式为StageStyle.TRANSPARENT

   ![image-20220606161618889](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206061616934.png)

4. 图片信息加载不出来

   解决：使用相对路径![image-20220606161822931](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206061618011.png)

5. 使用spring接管javafx对接

   在pom中引入springboot依赖：

   ```xml
           <dependency>
               <groupId>org.springframework.boot</groupId>
               <artifactId>spring-boot-starter</artifactId>
           </dependency>
           <dependency>
               <groupId>org.springframework.boot</groupId>
               <artifactId>spring-boot-starter-test</artifactId>
               <scope>test</scope>
           </dependency>
   ```

   在javafx的启动类中创建spring对象，并从spring中获取javafx的首页对象

   ![image-20220607182156346](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206071822840.png)

   

6. 主要组件代码

```java
public abstract class BaseStage extends Stage implements InitializingBean {

    protected Parent root;
    protected Scene scene;
    private double xOffset;
    private double yOffset;

    public BaseStage(){
        FXML fxml = this.getClass().getAnnotation(FXML.class);
        if(fxml == null || fxml.value() == null){
            throw new RuntimeException("BaseStage must use @FXML to fxml url!");
        }
        initialize(fxml.value());
    }

    /**
     * scene初始化
     * @param fxmlPath
     */
    public void initialize(String fxmlPath) {
        try {
            root = FXMLLoader.load(getClass().getResource(fxmlPath));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        scene = new Scene(root);
        initScene(root, scene);
    }

    /**
     * 获取场景组件元素
     * @param id
     * @return
     * @param <T>
     */
    public  <T> T $(String id) {
        return (T) root.lookup(getEleId(id));
    }

    protected String getEleId(String id){
        return "#" + id;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        Class clazz = getClass();
        Field[] fields = clazz.getDeclaredFields();
        for(Field field : fields){
            if(Parent.class.isAssignableFrom(field.getType())){
                String name = field.getName();
                field.setAccessible(true);
                field.set(this, $(name));
                field.setAccessible(false);
            }
        }

        //移动事件
        move(root);
        initEventHandler();
    }

    /**
     * 组件拖动
     * @param node
     */
    public void move(Node node) {
        node.setOnMousePressed(event -> {
            xOffset = getX() - event.getScreenX();
            yOffset = getY() - event.getScreenY();
           // node.setCursor(Cursor.DEFAULT);
        });
        node.setOnMouseDragged(event -> {
            setX(event.getScreenX() + xOffset);
            setY(event.getScreenY() + yOffset);
        });
        node.setOnMouseReleased(event -> {
           // node.setCursor(Cursor.DEFAULT);
        });
    }


    public InputStream getResStream(String path){
        return getClass().getResourceAsStream(path);
    }

    public String getFileUrl(String path){
        return Objects.requireNonNull(this.getClass().getResource(path)).toExternalForm();
    }

    public abstract void initScene(Parent root, Scene scene);

    /**
     * 组件事件初始化
     */
    public abstract void initEventHandler();

}
```

login bean代码：

```java
@Data
@Component
@FXML("/fxml/login/login.fxml")
public class Login extends BaseStage {

    @Autowired
    private Chat chat;

    private TextField username;
    private PasswordField password;
    private Button login_min;
    private Button login_close;
    private Button login_button;
    private Pane operation;

    @Override
    public void initScene(Parent root, Scene scene) {
        scene.setFill(Color.TRANSPARENT);
        this.setScene(this.scene);
        this.initStyle(StageStyle.TRANSPARENT);
        this.setResizable(true);
        this.getIcons().add(new Image(getResStream("/fxml/chat/img/head/logo.png")));
    }


    @Override
    public void initEventHandler() {
        //最小化点击
        login_min.setOnAction(actionEvent -> {
            this.setIconified(true);
        });
        //关闭点击
        login_close.setOnAction(actionEvent -> {
            this.close();
            System.exit(0);
        });

        //登录点击
        login_button.setOnAction(actionEvent -> {
            System.out.println("用户id：" + username.getText());
            System.out.println("用户密码：" + password.getText());
            this.close();

            chat.addTalkBox(-1, 0, "1000001", "小傅哥", "01_50", "我不是一个简单的男人", new Date(), true);
            chat.addTalkBox(-1, 0, "1000002", "铁锤", "02_50", "有本事现时里扎一下", new Date(), false);
            chat.addTalkBox(-1, 0, "1000003", "团团", "03_50", "秋风扫过树叶落，哪有棋盘哪有我", new Date(), false);
            chat.addTalkBox(-1, 0, "1000004", "哈尼克兔", "04_50", "你把爱放在我的心里", new Date(), false);
            chat.addTalkBox(0, 1, "5307397", "虫洞 · 技术栈 (1 区)", "group_1", "小傅哥：吉祥健康、如意安康", new Date(), false);
            chat.setUserData(new UserData("114514", "张三", "01_45"));
            chat.show();
            chat.addTalkUserMsg("1000004", "66666","沉淀、分享、成长，让自己和他人都有所收获！", new Date(), 1, true, false, true);
            chat.addTalkUserMsg("1000004", "66666","今年过年是放假时间最长的了！", new Date(), 1, true, false, true);
            chat.addTalkBox(-1, 0, "1000002", "铁锤", "03_50", "秋风扫过树叶落，哪有棋盘哪有我", new Date(), false);
            chat.addTalkUserMsg("1000002", "7777","秋风扫过树叶落，哪有棋盘哪有我", new Date(), 1, true, false, true);
            chat.addTalkUserMsg("1000002", "7777","我 Q，传说中的老头杀？", new Date(), 1, true, false, true);

        });

    }

}
```

