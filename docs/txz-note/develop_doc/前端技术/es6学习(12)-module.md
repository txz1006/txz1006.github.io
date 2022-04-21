es6学习(12)-module

### 一、js的模块化

#### 1. 模块化的使用

es6标准中，对于模块化的引用与输出进行了优化，可以进行静态化的加载了(即在编译时就完成模块加载)。

```javascript
//简述es6模块引用差异
//es5 CommonJS模块引用
let {exists, readFile} = require('fs');
//等同于加载一个fs对象,并从对象中获取方法，属于运行时加载
let _fs = require('fs');
let exists = _fs.exists;
let readFile = _fs.readFile;

//es6引用
let {exists, readFile} from 'fs';
//实指是从fs对象中加载2个方法，其他方法不加载，属于静态加载

//需要注意的是，es6中使用模块引用会自动采用严格模式
//所以对于this、arguments、eval等关键字的用法会受到限制
```

#### 2. `export`和`import`关键字

模块化主要是`export`和`import`两个关键字的使用，`export`表示输出当前模块的内容，`import`表示从其他模块引入`export`的内容。

```javascript
//export输出实例(export.js)
var name = 1;
var nick = 2;
export {name, nick as username} //输出name和nick(nick输出别名username)

//注意输出内容必须是接口(引用对象)，不能是实际的常量和对象
export '123'  //error
export {a:'123'}  //error
function c(){}
export c //error

//正确写法
export var a ='123'; //输出a
export var b ={a:'123'}; //输出b
export function c(){}; //输出c
function c(){} 
export {c}  //输出c

//======================
//import引入实例(以上文export.js为基础)
import {name, username as nick} from './export.js';
console.log(name);  //1
console.log(nick); //2
//或者直接导入一个export.js的输出对象
import * as obj from './export.js';
console.log(obj.name);  //1
console.log(obj.nick); //2

//要点1：import引入接口多是只读对象，一般不做修改
import {name, username as nick} from './export.js';
name = "123"; //"name" is read-only
//若name是一个对象，是可以添加属性的
name.age = 12;  //这样操作很难查错，一般不建议这些写

//要点2：import语句一般位于js文件的最开头，因为要静态执行，不能放入函数对象中
//要点3：import语句引用可以是相对地址，可以是绝对地址，还可以是模块名(需要配置模块名指向的资源路径)，.js后缀能省略不写。
```

#### 3. `default`关键字

上文中，`export`的输出接口名必须要和`import`输入名称相同，实际上可以使用`default`关键字来自定义`export`输出接口。

```javascript
export default function aa(){console.log('msg')}  //(export.js)
//等同于将输出函数aa重命名为default，在import时默认将default赋值给自定义名称，此时不需要加{}
import fun from 'export'
fun();  //打印msg

//等同于
function aa(){console.log('msg')
export {aa as default}
import {default as fun} from 'export'
              
//要点1：由于export default相当于输出一个default变量，所以可以直接输出常量，反而不能在跟var等变量声明
export '123'; //error
export default '123';  //ok
              
export var a = '666';  //ok
export default var a = '666'; //error
```

模块的继承使用，在一个js文件中可以使用多个export语句输出多个接口对象，所以可以进行接口之间的嵌套使用

```javascript
//在son.js中转接输出father.js的输出接口
export * as objA from 'father.js'
export var i = 3.14;
export default function(x){Math.exp(x)}

//使用文件中
import * as obj from 'son.js'; //导入son的输出接口，不包含默认函数
import exp from 'son.js';  //导入默认函数
console.log(exp(obj.i)); //调用Math.exp(3.14)
```

