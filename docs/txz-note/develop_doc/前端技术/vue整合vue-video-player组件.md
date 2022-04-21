vue整合vue-video-player组件

#### **vue整合vue-video-player组件**

添加npm依赖：

```js
//视频播放组件
"vue-video-player": "^4.0.6"
//使播放组件支持hls直播
"videojs-contrib-hls": "5.15.0",
//使播放组件支持flv等视频文件(默认组件只支持mp4/ogg/webm)
"videojs-flash": "2.1.0",
//播放组件扩展功能按钮    
"videojs-hotkeys": "^0.2.20",
```

引入项目页面(这里采用局部引用)：

```js
//引入js依赖
import { videoPlayer } from 'vue-video-player'
import 'videojs-flash';
import 'videojs-contrib-hls';
import SWF_URL from 'videojs-swf/dist/video-js.swf';
import zhCN from 'video.js/dist/lang/zh-CN.js';

//注册videoPlayer组件
Vue.use(videoPlayer)

//引入css
<style scoped>
  @import '~video.js/dist/video-js.css';
  @import '~vue-video-player/src/custom-theme.css';
</style>

//引入videoPlayer组件元素
<videoPlayer class="video-player vjs-custom-skin"
             ref="videoPlayer"
             :options="playerOptions"
             :playsinline="true"
             @play="onPlayerPlay($event)"
             @pause="onPlayerPause($event)"
             @ended="onPlayerEnded($event)">
</videoPlayer>

//注册播放组件对象(必要)
computed:{
  player () {
    return this.$refs.videoPlayer.player
  }
}
```

配置播放组件数据：

```js
//在data中添加playerOptions属性
playerOptions: {
    // videojs options
    techOrder: ['html5', 'flash'], // 兼容顺序,使用flash播放，可以播放flv格式的文件
    notSupportedMessage: '此视频暂无法播放!',
    autoplay: true,  //是否自动播放
    muted: true,
    height: '360',
    playbackRates: [0.7, 1.0, 1.5, 2.0],
    language: 'zh-CN',
    preload: 'auto', // 建议浏览器在<video>加载元素后是否应该开始下载视频数据。auto浏览器选择最佳行为,立即开始加载视频（如果浏览器支持）
    fluid: true, // 当true时，Video.js player将拥有流体大小。换句话说，它将按比例缩放以适应其容器。
    hls: true,  //启用hls？
    flash: {
      hls: { withCredentials: false },
      swf: SWF_URL//放在static或着public下面文件夹中的videojs文件夹中 当引入js文件中统一定义时此处可省略
    },
    html5: { hls: { withCredentials: false } },
    //视频源数组
    /*
    //hls直播数据源实例
    {
      type: "application/x-mpegURL",
      src: "http://ivi.bupt.edu.cn/hls/cctv1hd.m3u8"
    }
    //flv视频文件源实例
    {
      type: "video/flv",
      src: "http://localhost/sys/common/video/files/20200730/216117699-1-208_1596090394443.flv"
    }
    //mp4视频文件源实例
    {
      type: "video/mp4",
      src: "http://localhost/sys/common/video/files/20200730/216117699-1-208_1596090394443.mp4"
    }
    */ 
    sources: [],
    //播放器按钮配置
    controlBar: {
      timeDivider: true,
      durationDisplay: true,
      remainingTimeDisplay: false,
      fullscreenToggle: true  //全屏按钮
    }
  },
}

//============================相关方法
//动态切换视频源
initVideo:function(url){
    let type = "video/";
    if(url.includes("http")){
      type = "application/x-mpegURL"; 
    }else{
      type += url.substring(url.lastIndexOf(".")+1);
      url = window._CONFIG['domianURL']+"/sys/common/video/" + url;
    }
    let sourceObj = {type: type, src: url};
    this.playerOptions.sources.push(sourceObj);
},
//暂停事件
onPlayerPause (player) {
    //监听暂停
    console.log('暂停');
    // 暂停时时间
    console.log(player.duration());
},
//播放事件
onPlayerPlay(player) {
},
//结束事件
onPlayerEnded(player) {
    console.log('the player is readied', player)
    // you can use it to do something...
    // player.[methods]
},
```

//后台视频流方式请求视频文件

```java
private static String extractPathFromPattern(final HttpServletRequest request) {
		String path = (String) request.getAttribute(HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE);
		String bestMatchPattern = (String) request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
		return new AntPathMatcher().extractPathWithinPattern(bestMatchPattern, path);
}

@GetMapping(value = "/video/**")
public void video(HttpServletRequest request, HttpServletResponse response) {
   // ISO-8859-1 ==> UTF-8 进行编码转换
   String videoPath = extractPathFromPattern(request);
   String rangeString = request.getHeader("Range");
   long range = StringUtils.isEmpty(rangeString)?0:Long.valueOf(rangeString.substring(rangeString.indexOf("=") + 1, rangeString.indexOf("-")));
   // 其余处理略
   InputStream inputStream = null;
   OutputStream outputStream = null;
   try {
      videoPath = videoPath.replace("..", "");
      if (videoPath.endsWith(",")) {
         videoPath = videoPath.substring(0, videoPath.length() - 1);
      }
      String localPath = uploadpath;
      String imgurl = localPath + File.separator + videoPath;
      inputStream = new BufferedInputStream(new FileInputStream(imgurl));
       //此配置后播放进度可拖动
      response.setContentType("video/mp4;charset=utf-8");
      response.setContentLength(inputStream.available());
      response.setHeader("Accept-Ranges", "bytes");
      response.setHeader("Content-Range", String.valueOf(range + (10000-1)));
      outputStream = response.getOutputStream();
      byte[] buf = new byte[inputStream.available()];
      int len;
      while ((len = inputStream.read(buf)) > 0) {
         outputStream.write(buf, 0, len);
      }
      response.flushBuffer();
   } catch (IOException e) {
      log.error("视频失败" + e.getMessage());
      // e.printStackTrace();
   } finally {
      if (inputStream != null) {
         try {
            inputStream.close();
         } catch (IOException e) {
            log.error(e.getMessage(), e);
         }
      }
      if (outputStream != null) {
         try {
            outputStream.close();
         } catch (IOException e) {
            log.error(e.getMessage(), e);
         }
      }
   }

}
```



#### **普通js调用方法**

引入相关的依赖脚本

```js
//引入css
<link href="${base}/bigscreen/template3/css/video-js.min.css" rel="stylesheet">
//引入js
<script src="${base}/bigscreen/template3/js/video.min.js"></script>
<script src="${base}/bigscreen/template3/js/videojs-flash.js"></script>
<script src="${base}/bigscreen/template3/js/videojs-contrib-hls.js"></script>
```

初始化

```js
//播放器html
<video id="video_1" controls class="video-js vjs-default-skin"></video>

//播放器初始化
var player = videojs('video_1', {
    techOrder: ['html5', 'flash'], // 兼容顺序,使用flash播放，可以播放flv格式的文件
    notSupportedMessage: '此视频暂无法播放!',
    autoplay: true,  //是否自动播放
    muted: true,
    //height: '360',
    //playbackRates: [0.7, 1.0, 1.5, 2.0],
    language: 'zh-CN',
    preload: 'auto', // 建议浏览器在<video>加载元素后是否应该开始下载视频数据。auto浏览器选择最佳行为,立即开始加载视频（如果浏览器支持）
    fluid: true, // 当true时，Video.js player将拥有流体大小。换句话说，它将按比例缩放以适应其容器。
    hls: true,  //启用hls？
    flash: {
        hls: { withCredentials: false },
        //swf: SWF_URL//放在static或着public下面文件夹中的videojs文件夹中 当引入js文件中统一定义时此处可省略
    },
    html5: { hls: { withCredentials: false } },
    sources: [		  {
        type: "application/x-mpegURL",
        src: "http://ivi.bupt.edu.cn/hls/cctv1hd.m3u8"
    }],
    controlBar: {
        fullscreenToggle: true  //全屏按钮
    }
}, function () {
    this.on('loadedmetadata',function(){
        console.log('loadedmetadata');
        //加载到元数据后开始播放视频
        startVideo();
    })

    this.on('ended',function(){
        console.log('ended')
    })
    this.on('firstplay',function(){
        console.log('firstplay')
    })
    this.on('loadstart',function(){
        //开始加载
        console.log('loadstart')
    })
    this.on('loadeddata',function(){
        console.log('loadeddata')
    })
    this.on('seeking',function(){
        //正在去拿视频流的路上
        console.log('seeking')
    })
    this.on('seeked',function(){
        //已经拿到视频流,可以播放
        console.log('seeked')
    })
    this.on('waiting',function(){
        console.log('waiting')
    })
    this.on('pause',function(){
        console.log('pause')
    })
    this.on('play',function(){
        console.log('play')
    })
});

function startVideo(){
    player.play();
}

//动态切换数据源
function changeVideo(url){
    player.src(url);
    player.load(url);
}
```

**自定义工具栏按钮**

```js
addNewButton(id, btnName, font, css, fun) {
  var controlBar, flagNode,
    newElement = document.createElement('div');

  newElement.id = id;
  newElement.className = 'vjs-control';
  let button =
    '<button class="vjs-control vjs-button" type="button" title="'+btnName+'" aria-disabled="false"">'+
    '<span class="vjs-icon-'+font+' " style="'+css+'"></span><span class="vjs-control-text" aria-live="polite"></span>'+
    '</button>';

  newElement.innerHTML = button;
  controlBar = document.getElementsByClassName('vjs-control-bar')[0];
  flagNode = document.getElementsByClassName('vjs-fullscreen-control')[0];
  controlBar.insertBefore(newElement, flagNode);
  this.$nextTick(() => {
    document.getElementById(id).onclick = fun;
  })
}

//调用(参数：id(不重复)，title，按钮font，按钮颜色，按钮点击事件)
this.addNewButton('bRecord', '开始录制', 'circle-inner-circle', 'color:green;', this.startRecord);
//videojs内置按钮如下url
//https://videojs.github.io/font/
```


**报错问题**：

问题：关闭或跳转离开播放器页面后会一直报this.el_.vjs_getProperty is not a function错误

处理：在离开播放器页面后对播放器进行销毁和重新初始化

```js
closeVideo: function(){
  this.videoVisible = false;
  this.$refs.videoPlayer.dispose();
  this.$refs.videoPlayer.initialize();
  this.player.pause();
  this.$emit('close');
}
```


#### **参考**

https://blog.csdn.net/weixin_39593730/article/details/101622937

https://www.jb51.net/article/173816.htm

https://www.jb51.net/article/136858.htm

https://www.jianshu.com/p/677c0125124f