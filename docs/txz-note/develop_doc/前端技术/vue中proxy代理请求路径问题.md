在前后端分离的项目中，前端项目的访问地址和后端接口的访问地址通常是不同。所以，通常会配置一个代理请求，将某个固定前缀的url代理替换成服务器的接口前缀，如下图所示。

```js
const proxy = require('http-proxy-middleware');

module.exports = {   
devServer:{
    host: 'localhost',//target host
    port: 8080,   //前端的访问地址是localhost:8080
    //proxy:{'/api':{}},代理器中设置/api,项目中请求路径为/api的替换为target
    proxy:{
        //访问localhost:8080/api/XXXXXXX地址的请求会被代理
        '/api':{
            target: 'http://192.168.1.30:8085',//代理地址，这里设置的地址会代替axios中设置的baseURL
            changeOrigin: true,// 如果接口跨域，需要进行这个参数配置
            //ws: true, // proxy websockets
            //pathRewrite方法重写url
            pathRewrite: {
                '^/api': '/' 
                //pathRewrite: {'^/api': '/'} 重写之后url为 http://192.168.1.16:8085/xxxx
                //pathRewrite: {'^/api': '/api'} 重写之后url为 http://192.168.1.16:8085/api/xxxx
           }
    }}
},
//...
}
```

通过上图中配置devServer.proxy代理属性，我们可以在访问http://localhost:8080/api/XXXXXXX地址时，将请求代理访问到http://192.168.1.30:8085/XXXXXXX后端接口地址，而且不会出现CROS跨域访问问题。

```
需要注意的是，这个代理请求功能只在本地开发时才会生效。也就是通过vue-cli-service serve启动一个devServer服务器时才会有这个代理功能，如果打包后devServer会被剥离，所以代理会失效，需要通过nginx代理拦截对应的请求前缀转发给后端地址。

以上述事例的/api为例，我们可以在nginx的配置文件中配置如下代理，
location / {
     root   /usr/local/java/project; #vue打包存放路径
	 try_files $uri $uri/ /index.html;
     index  index.html index.htm;
}
location /api/{
	proxy_set_header Host $http_host;
	proxy_set_header X-Real-IP $remote_addr;
	proxy_set_header REMOTE-HOST $remote_addr;
	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_pass http://192.168.1.16:8085/;
}
```

在如若依项目的前端vue项目中，vue.config.js中一般会有项目的打包、代理等路径配置参数：

```js
module.exports = {
  // 部署生产环境和开发环境下的URL。
  // 默认情况下，Vue CLI 会假设你的应用是被部署在一个域名的根路径上
  // 以生产环境打包，如果以/manager为公共路径，则可以直接将生成的manager文件放入服务器中，通过locahost:port/manager访问
  //如果以/为公共路径，则可以以nginx直接路由到manager文件夹：root  D://newcampus-server//newcampus-ui//manager;
  publicPath: process.env.NODE_ENV === "production" ? "/manager" : "/",
  // 在npm run build 或 yarn build 时 ，生成文件的目录名称（要和baseUrl的生产环境路径一致）（默认dist）
  outputDir: 'manager',
  // 用于放置生成的静态资源 (js、css、img、fonts) 的；（项目打包之后，静态资源会放在这个文件夹下）
  assetsDir: 'static',
  // 是否开启eslint保存检测，有效值：ture | false | 'error'
  lintOnSave: process.env.NODE_ENV === 'development',
  // 如果你不需要生产环境的 source map，可以将其设置为 false 以加速生产环境构建。
  productionSourceMap: false,
  // webpack-dev-server 相关配置
  devServer: {
    host: '0.0.0.0',
    port: port,
    open: true,
    proxy: {
      // detail: https://cli.vuejs.org/config/#devserver-proxy
      [process.env.VUE_APP_BASE_API]: {
        //公测地址：47.97.59.173:9080
        target: `http://localhost:8080`,
        changeOrigin: true,
        pathRewrite: {
          ['^' + process.env.VUE_APP_BASE_API]: '/'
        }
      }
    },
    disableHostCheck: true
  }
}
```

配置上多环境时，可以通过.env.development、.env.production、.env.staging来配置不同的process.env参数，如：

```
# 生产环境配置
ENV = 'production'

# 生产环境配置
NODE_ENV='production'

# 微信小程序管理系统/生产环境
#VUE_APP_BASE_API = '//newcampus.59wanmei.com'
VUE_APP_BASE_API = '/dev-api'
```

在打包时选择不同环境的配置即可：

```
"build:prod": "vue-cli-service build",
"build:stage": "vue-cli-service build --mode staging",
```

