es6学习(9)-promise函数

#### 一、promise对象

1. Promise是es6中一种新的异步请求解决方案，相比于ajax更加完整与强大；他主要有两个特点：1.创建Promise对象就会执行请求。2.请求完成就会返回Resolved或Rejected回调函数，而且这个过程不可逆，发生就无法再变。

   ```javascript
   //Promise有两个请求转变状态，resolve为请求成功，reject为请求失败
   function request(){
       return new Promise(function(resolve, reject){
           resolve();
       })
   }
   //then方法接受回调函数(第一个参数为resolve函数，第二个为reject函数)
   request().then(function(){
       console.log(value);
   })
   
   //封装ajax
   var getJSON = function(url){
       var pms = new Promise(function(res, rej){
           var client = new XMLHttpRequest();
           client.open("get", url);
           client.onreadystatechange = handler;
           client.responseType = 'json';
           //client.setRequsetHeader('Accept', 'application/json');
           client.send();
           
           //requset回调
           function handler(){
               if(this.status == 200){
                   res(this.response);
               }else{
                   rej(new Error(this.statusText));
               }
           }
       })
   
       return pms;
   }
   
   //调用
   getJSON("/xml.json").then(function(res){
       console.log(res);             
   },function(err){
       console.error(err);
   })
   ```

2. promise方法

   then方法可以给promise对象添加改变状态的回调函数，then方法返回一个新的Promise实例，所以可以采用链式写法

   ```javascript
   //第一个回调函数完成后将结果作为第二个回调函数的参数
   getJSON("/xml.json").then(function(res){
       console.log(res);    
       return res.postUrl;
   }).then(function(res){
       console.log(res); 
   })
   ```

   catch方法等同于`.then(null,reject)`，用于返回请求失败数据。

   ```javascript
   getJSON("/xml.json").then(function(res){
       console.log(res);             
   }).catch(err){
       console.log(err);   
   }
   
//注意下面的代码会执行什么
   getJSON("/xml.json").catch(err){
       console.log("err");   
   }.then(function(res){
       console.log("res");             
   })
   //跳过catch打印res
   ```
   
   Promise.all()方法用于进行批量数组请求
   
   ```javascript
   //制造Promise数组
   var list = [1,2,3].map(x => getJSON('/post/'+x+'.json'));
   //进行数组请求
   //只要其中有一个请求返回reject，或全部元素变为fulfilled，才调用回调函数
   //实际就是，要么所有请求都通过，返回一个数组调用回调函数；要么存在一个reject错误请求，也会调用回调函数
   Promise.all(list).then(function(post){
       //...
   }).catch(function(){
       //...
   })
   ```
   
   Promise.race()方法用于选择最快的请求
   
   ```javascript
   var p = Promise.race([p1, p2, p3]);
   //p1, p2, p3那个请求最先返回，就将最快的那个返回值作为参数进行回调
   ```
   
   Promise.resolve()用于将参数转化为promise对象,分4种情况
   
   ```javascript
   //情况1：非对象，也不具有then方法
   Promise.resolve('foo');
   //等价于
   new Promise(resolve => resolve('foo'));
   //打印foo(由于字符串不是对象，也不具有then方法,所以转化后状态直接为resolve，并返回结果)
   
   //情况2：可以不带参数，创建一个Promise对象
   var p = Promise.resolve();
   
   //注意Promise请求的执行顺序
   setTimeout(function () {
     console.log('three');
   }, 0);
   
   Promise.resolve().then(function () {
     console.log('two');
   });
   
   console.log('one');
   //one
   //two
   //three
   
   //情况3：具有then方法的对象
   let obj = {
       then: function(res, rej){
           resolve(12);
       }
   }
   
   Promise.resolve(obj).then(function(val){
      console.log(val); //12 
   });
   
   //情况4：参数为另一个Promise对象，会直接返回参数对象
   ```
   
   Promise.reject()方法用于返回一个rejected状态的Promise实例
   
   ```javascript
   var p = Promise.reject('error');
   p.catch(function(val){
       console.log(val); //error
   })
   ```
   
   done方法，位于Promise对象请求链的尾端，一般用于全局抛出异常(Promise内部的错误不会向上冒泡)
   
   ```javascript
   new Promise().then(fun1).catch(fun2).done();
   ```
   
   finally方法，和done方法类似，是Promise请求中必须执行的对象，可接受一个回调函数做参数，一般用于处理资源的关闭回收等问题。
   
   ```javascript
   server.then(val =>{
       //...
   }).finally(server.stop);
   ```
   
   