vue项目整合vue-full-calendar日程组件

### 一、整合vue-full-calendar日程组件

- **获取安装vue-full-calendar组件**

  到npm库(https://www.npmjs.com/package/vue-full-calendar)中获取最新vue-full-calendar组件信息：

  ```js
  //安装命令
  npm install --save vue-full-calendar
  ```

  在项目中使用上面的npm命令将vue-full-calendar下载下来，之后将vue-full-calendar引入项目：

  ```js
  //main.js(全局引用)
  import FullCalendar from 'vue-full-calendar'
  Vue.use(FullCalendar)
  
  //局部引用
  import { FullCalendar } from 'vue-full-calendar'
  export default {
    components: {
      FullCalendar,
    },
  }
  
  //配置css
  <style scoped>
    @import '~fullcalendar/dist/fullcalendar.css';
  </style>
  ```

- **配置vue-full-calendar组件**

  由于日程组件基本很少复用，这里采用上述局部引用的方式，引用后创建FullCalendar元素标签：

  ```html
  <full-calendar id="calendar"
                 ref="calendar"
                 @event-selected="eventSelected"
                 @event-created="eventCreated"
                 :event-sources="eventSources"
                 :config="config">
  </full-calendar>
  ```

  这个标签添加了两个配置项：config(组件配置对象)、event-sources(动态数据源对象)和两个触发方法：event-selected(事件选择方法)、event-created(事件创建方法)，配置了这四个属性，vue-full-calendar基本可以正常使用了，下面具体说明一下：

  - **config(组件配置对象)**

    这个属性基本是组件的必须配置的，也是我们自定义日程表显示形式的对象(如自定义表头、自定义按钮、自定义日程周期等)

    ```js
    //日历配置
    config: {
      locale: "zh-cn", //中文
      defaultView: "month",  //默认显示月
      height: 'auto',
      //表头元素设置
      header: {
        left: '',
        center: 'title',
        right: 'today, prev, next'
      },
      //按钮自定义
      buttonText: {
        today: '今天',
      }
    }
    ```
  
  - **event-sources(动态数据源对象)**
  
    这个属性是配置日程事件的，日历上显示的日程数据就是从此属性获取的。它是一个数组对象，也就是可以接受多个数据源：
  
    ```js
    eventSources: [
      {
        events(start, end, tinezone, callback){
          getAction(request.list).then((res) =>{
            if (res.success) {
              callback(res.result);
            }
          })
        },
        color: '#4d867e'
      },
      {
        events(start, end, tinezone, callback){
          getAction(request2.list).then((res) =>{
            if (res.success) {
              callback(res.result);
            }
          })
        },
        color: 'red'
      },
    ]
    ```
  
    获取到数据列表后通过callback函数设置数据源，数据的格式如下：
  
    ```js
    //注意日程范围实际展示出来是不包括end当天的，就是start到end-1天
    [{
        id: '123',
        title: '中秋节',
        start: '2020-08-14',
        end: '2020-08-17'
    },{
        id: '123',
        title: '国庆节',
        start: '2020-10-01',
        end: '2020-10-07'
    }]
    ```
  
    若有写死的日程信息需要设置可以给组件设置:events属性，日程格式和上述相同，且事件和:event-sources数据共存。
  
  - **event-selected(事件选择方法)**
  
    这个事件选择的触发方法，也就是日程事件的点击事件：
  
    ```js
    //事件选择事件
    eventSelected: function(event) {
      //通过event获取日程事件后，弹窗展示  
      this.modEvent(event);
    }
    ```
  
    该方法的参数为event对象，就是日程事件的存储对象(eventSources中的数据项)，event对象属性如下图所示：
  
    若日程事件只有一天，则该event对象只有start属性(moment对象)，没有end属性；此外，由于end当天是不算在日程内的，所以要注意处理。
  
    ![image-20200709202555714](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103731.png)
  
  - **event-created(事件创建方法)**
  
    事件创建方法，也就是日程事件外的天数点击事件触发方法，一般情况下也可以用day-click方法代替，若连续选择多个天数也可以触发此方法。
  
    ```js
    eventCreated(...test) {
      //test可为多个event对象，一般只取第一个event即可
      //获取到的event主要包括start和end属性
      this.modEvent(test[0]);
    }
    ```
  
    我们可通过此方法快速获取到选区的起止时间来创建新日程数据。
  
- **其他配置信息**

  1. 在动态增删改后可通过**this.$refs.calendar.$emit('refetch-events');**或者**this.$refs.calendar.fireMethod("refetchEvents");**来刷新日程组件

  2. 若要获取当前日历对象可以通过：**this.$refs.calendar.fireMethod("getView")**来获取view对象

- **相关参考资料**
  1. (使用方法)https://www.jianshu.com/p/8336f3f6941e
  2. (API列表)https://blog.csdn.net/lk1985021/article/details/90725595
  3. (API列表)https://www.jb51.net/article/104841.htm