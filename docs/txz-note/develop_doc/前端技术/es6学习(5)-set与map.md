es6学习(5)-set与map

#### 一、Set数据结构

1. set结构可以视为是特别数组结构，他的成员的值都是唯一的。Set本身是一个构造函数，可以使用new关键字来创建对象。

   ```javascript
   var a = [1, 1, 2, 3];
   var b = new Set();
   a.map(x => b.add(x));
   [...b]; //[1,2,3]
   
   //直接使用数组参数
   var a = new Set([1,2,2,33]);
a.size; //3
   
   //注意：set是通过类似===严格相等来判断元素是否相等的
   var a  = new Set([1,2,'2',3]);
   a.size; //4(这里2和'2'的类型是不同的)
   
   var b = new Set([1,NaN ,NaN , 3]);
   b.size; //3(这里NaN和NaN是相等的)
   
   var c = new Set([1, {}, {}, 3]);
   c.size;//4(两个空对象是不相等的)
   ```
   
2. Set结构操作方法

   ```javascript
   //Set操作方法
   var a  = new Set();
   //增加元素
   a.add(1);
   a.add(1);
   a.add(2);
   //查询元素数量
   a.size; //2
   //查询元素存在
   a.has(1); //true
   a.has(3); //false
   //删除元素
   a.delete(1); //返回true删除成功
   //清除所用元素
   a.clear();
   ```
   
3. Set结构遍历

   ```javascript
   //Set遍历方法
   var a  = new Set([1,2,3]);
   //a.keys()和a.values()的结果相同
   for(var i of a.keys()){
       console.log(i);
   }
   //1
   //2
   //3
   
   for(var i of a.entries()){
       console.log(i);
   }
   //[1, 1]
   //[2, 2]
   //[3, 3]
   
   //默认Set对象遍历的是values()
   for(var i of a){
       console.log(i);
   }
   
   //forEach()
   a.forEach((key,val)=>{console.log(val*2)})
   //2
   //4
   //6
   
   ```

3. Set结构应用

   ```javascript
   //Set应用
   //数组去重(转为Set后转回数组)
   var a = [1,2,3,4,4,5,1];
   var unique = [...new Set(a)];
   
   //可以转为数组后则可以使用map、filter运算
   var a = new Set([1,2,3,3,4]);
   a = new Set([...a].map(x => x*2)); //每个元素乘2
   a = new Set([...a].filter(x => (x%2) == 0)); //过滤得到偶数
   
   //可以用于求合集、交集、差集
   var a = new Set([2,3,4]);
   var b = new Set([4,5,6]);
   //合集
   var c = [...a, ...b];
   //交集
   var c = new Set([...a].filter(x => b.has(x)));
   //差集
   var c = new Set([...a].filter(x => !b.has(x)));
   
   //WeakSet
   //WeakSet是弱引用版的Set结构，只能存储对象，由于对象随时可能被回收所以无size属性和遍历方法
   ```

#### 二、Map数据结构

1. Map结构是Object对象的升级版本，在Object对象中，本质上也是键值集合，但是object对象的key只能是字符串获取，所以限制很多：

   ```javascript
   var a = {k: 111};
   //获取值
   a.k;  //111
   a["k"]; //111
   ```

2. Map结构可以使用除String类型外的类型作为key(包括NaN、undefined、null)

   ```javascript
   var m = new Map();
   var obj = {c: '11111'};
   //map设置/获取
   m.set(obj, "aaa");
   m.get(obj);  //"aaa"
   
   //常用方法
   m.has(obj); //true(是否存在某元素)
   m.delete(obj); //true(删除某元素)
   m.clear(); //清除全部元素
   
   //===================================
   //Map的数组参数
   var m = new Map([
       [true, 'foo'],
       ['true', 'bar']
   ]);
   m.get(true) //'foo'
   m.get('true') //'bar'
   m.get(123) //undefined(读取未定义值)
   
   //注意：非string类型做key时，一定要使用同一对象的引用
   var m = new Map();
   
   map.set(['a'], 111);
   map.get(['a']); //undefined(两个数组a非同一对象地址)
   
   //非常见情况
   map.set(undefined, 111);
   map.get(undefined); //111
   
   map.set(-0, 111);
   map.get(+0);  //111
   ```

3. Map的遍历方法

   ```javascript
   //keys()遍历
   var m = new Map();
   m.set('a', "aaa");
   m.set('b', "bbb");
   
   for(let obj of m.keys()){
       console.log(obj);
   }
   //'a'
   //'b'
   
   //values()遍历
   var m = new Map();
   m.set('a', "aaa");
   m.set('b', "bbb");
   
   for(let obj of m.values()){
       console.log(obj);
   }
   //'aaa'
   //'bbb'
   
   //entries()遍历
   var m = new Map();
   m.set('a', "aaa");
   m.set('b', "bbb");
   
   for(let obj of m.entries()){
       console.log(obj[0], obj[1]);
   }
   //或者
   for(let [key, val] of m.entries()){
       console.log(key, val);
   }
   //a aaa
   //b bbb
   
   //entries()实际可省略
   for(let [key, val] of m){
       console.log(key, val);
   }
   
   //forEach遍历
   map.forEach(fucntion(val, key, map){
      console.log(key, val);         
   })
   ```

4. Map和数组互转

   ```javascript
   //使用扩展运算符(Map转数组)
   var m = new Map().set('a', "aaa").set('b', "bbb");
   [...m]; //[['a', "aaa"],['b', "bbb"]]
   
   //数组转Map
   new Map([['a', "aaa"],['b', "bbb"]]) 
   //{"a" => "aaa", "b" => "bbb"}
   ```

5. Map和对象互转

   ```javascript
   //Map转对象(条件是Map的所有key是字符串类型)
   function mapToObj(map){
       let obj = Object.create(null);
       for(let [k, v] of map){
           obj[k] = v;
       }
       return obj;
   }
   var m = new Map().set('a', "aaa").set('b', "bbb");
   mapToObj(m);
   //{a: "aaa", b: "bbb"}
   
   //对象转map
   function objToMap(obj){
       let map = new Map();
       for(let k of Object.keys(obj)){
           map.set(k, obj[k]);
       }
       return map;
   }
   objToMap({a: "aaa", b: "bbb"});
   // {"a" => "aaa", "b" => "bbb"}
   ```

6. Map和JSON互转

   ```javascript
   //Map转JSON(全部字符串类型的key：转为对象JSON)
   //先转为对象，后转为JSON字符串
   function mapTOJson(map){
       return JSON.stringify(mapToObj(map));
   }
   var m = new Map().set('a', "aaa").set('b', "bbb");
   mapTOJson(m);
   //"{"a":"aaa","b":"bbb"}"
   
   //Map转JSON(存在非字符串类型的key：转为数组JSON)
   function mapTOArrayJson(map){
       return JSON.stringify([...map]);
   }
   var m = new Map().set('a', "aaa").set({'b':0}, "bbb");
   mapTOArrayJson(m);
   //"[["a","aaa"],[{"b":0},"bbb"]]"
   
   //=====================================
   //对象JSON转Map
   function jsonToMap(json){
       return objToMap(JSON.parse(json));
   }
   jsonToMap('{"a":"aaa","b":"bbb"}')
   //{"a" => "aaa", "b" => "bbb"}
   
   //数组JSON转Map
   function arrayJsonToMap(json){
       return new Map(JSON.parse(json));
   }
   arrayJsonToMap('[["a","aaa"],[{"b":0},"bbb"]]')
   //{"a" => "aaa", {"b":0} => "bbb"}
   ```

7. WeakMap

   弱引用版的Map，只接受对象作为key(null除外)，无Map的size属性和一系列遍历的操作。


