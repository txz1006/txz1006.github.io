js导出导入excel

### 使用组件：

在package.json中添加三个组件

```js
//xlsx为excel组件主体，内部封装的是sheetjs
//"xlsx": "^0.11.19", 这个组件无法添加单元格样式，慎用
//文档可见https://github.com/protobi/js-xlsx/tree/beta#readme
"js-xlsx": "^0.8.22",
//将数据生成文件，配合Blob.js使用    
"file-saver": "^2.0.5",
```

在src文件夹下创建两个js文件

![image-20201125150713301](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201125150738.png)

Blob.js：负责转换输出文件流

```js
/* eslint-disable */
/* Blob.js
 * A Blob implementation.
 * 2014-05-27
 *
 * By Eli Grey, http://eligrey.com
 * By Devin Samarin, https://github.com/eboyjr
 * License: X11/MIT
 *   See LICENSE.md
 */

/*global self, unescape */
/*jslint bitwise: true, regexp: true, confusion: true, es5: true, vars: true, white: true,
 plusplus: true */

/*! @source http://purl.eligrey.com/github/Blob.js/blob/master/Blob.js */

(function (view) {
    "use strict";

    view.URL = view.URL || view.webkitURL;

    if (view.Blob && view.URL) {
        try {
            new Blob;
            return;
        } catch (e) {}
    }

    // Internally we use a BlobBuilder implementation to base Blob off of
    // in order to support older browsers that only have BlobBuilder
    var BlobBuilder = view.BlobBuilder || view.WebKitBlobBuilder || view.MozBlobBuilder || (function(view) {
            var
                get_class = function(object) {
                    return Object.prototype.toString.call(object).match(/^\[object\s(.*)\]$/)[1];
                }
                , FakeBlobBuilder = function BlobBuilder() {
                    this.data = [];
                }
                , FakeBlob = function Blob(data, type, encoding) {
                    this.data = data;
                    this.size = data.length;
                    this.type = type;
                    this.encoding = encoding;
                }
                , FBB_proto = FakeBlobBuilder.prototype
                , FB_proto = FakeBlob.prototype
                , FileReaderSync = view.FileReaderSync
                , FileException = function(type) {
                    this.code = this[this.name = type];
                }
                , file_ex_codes = (
                    "NOT_FOUND_ERR SECURITY_ERR ABORT_ERR NOT_READABLE_ERR ENCODING_ERR "
                    + "NO_MODIFICATION_ALLOWED_ERR INVALID_STATE_ERR SYNTAX_ERR"
                ).split(" ")
                , file_ex_code = file_ex_codes.length
                , real_URL = view.URL || view.webkitURL || view
                , real_create_object_URL = real_URL.createObjectURL
                , real_revoke_object_URL = real_URL.revokeObjectURL
                , URL = real_URL
                , btoa = view.btoa
                , atob = view.atob

                , ArrayBuffer = view.ArrayBuffer
                , Uint8Array = view.Uint8Array
                ;
            FakeBlob.fake = FB_proto.fake = true;
            while (file_ex_code--) {
                FileException.prototype[file_ex_codes[file_ex_code]] = file_ex_code + 1;
            }
            if (!real_URL.createObjectURL) {
                URL = view.URL = {};
            }
            URL.createObjectURL = function(blob) {
                var
                    type = blob.type
                    , data_URI_header
                    ;
                if (type === null) {
                    type = "application/octet-stream";
                }
                if (blob instanceof FakeBlob) {
                    data_URI_header = "data:" + type;
                    if (blob.encoding === "base64") {
                        return data_URI_header + ";base64," + blob.data;
                    } else if (blob.encoding === "URI") {
                        return data_URI_header + "," + decodeURIComponent(blob.data);
                    } if (btoa) {
                        return data_URI_header + ";base64," + btoa(blob.data);
                    } else {
                        return data_URI_header + "," + encodeURIComponent(blob.data);
                    }
                } else if (real_create_object_URL) {
                    return real_create_object_URL.call(real_URL, blob);
                }
            };
            URL.revokeObjectURL = function(object_URL) {
                if (object_URL.substring(0, 5) !== "data:" && real_revoke_object_URL) {
                    real_revoke_object_URL.call(real_URL, object_URL);
                }
            };
            FBB_proto.append = function(data/*, endings*/) {
                var bb = this.data;
                // decode data to a binary string
                if (Uint8Array && (data instanceof ArrayBuffer || data instanceof Uint8Array)) {
                    var
                        str = ""
                        , buf = new Uint8Array(data)
                        , i = 0
                        , buf_len = buf.length
                        ;
                    for (; i < buf_len; i++) {
                        str += String.fromCharCode(buf[i]);
                    }
                    bb.push(str);
                } else if (get_class(data) === "Blob" || get_class(data) === "File") {
                    if (FileReaderSync) {
                        var fr = new FileReaderSync;
                        bb.push(fr.readAsBinaryString(data));
                    } else {
                        // async FileReader won't work as BlobBuilder is sync
                        throw new FileException("NOT_READABLE_ERR");
                    }
                } else if (data instanceof FakeBlob) {
                    if (data.encoding === "base64" && atob) {
                        bb.push(atob(data.data));
                    } else if (data.encoding === "URI") {
                        bb.push(decodeURIComponent(data.data));
                    } else if (data.encoding === "raw") {
                        bb.push(data.data);
                    }
                } else {
                    if (typeof data !== "string") {
                        data += ""; // convert unsupported types to strings
                    }
                    // decode UTF-16 to binary string
                    bb.push(unescape(encodeURIComponent(data)));
                }
            };
            FBB_proto.getBlob = function(type) {
                if (!arguments.length) {
                    type = null;
                }
                return new FakeBlob(this.data.join(""), type, "raw");
            };
            FBB_proto.toString = function() {
                return "[object BlobBuilder]";
            };
            FB_proto.slice = function(start, end, type) {
                var args = arguments.length;
                if (args < 3) {
                    type = null;
                }
                return new FakeBlob(
                    this.data.slice(start, args > 1 ? end : this.data.length)
                    , type
                    , this.encoding
                );
            };
            FB_proto.toString = function() {
                return "[object Blob]";
            };
            FB_proto.close = function() {
                this.size = this.data.length = 0;
            };
            return FakeBlobBuilder;
        }(view));

    view.Blob = function Blob(blobParts, options) {
        var type = options ? (options.type || "") : "";
        var builder = new BlobBuilder();
        if (blobParts) {
            for (var i = 0, len = blobParts.length; i < len; i++) {
                builder.append(blobParts[i]);
            }
        }
        return builder.getBlob(type);
    };
}(typeof self !== "undefined" && self || typeof window !== "undefined" && window || this.content || this));

```

Export2Excel.js：负责创建workBook对象，并引用file-saver输出excel文件

```js
/* eslint-disable */
import 'file-saver';
import './Blob';
import XLSX from 'js-xlsx';

function generateArray(table) {
    var out = [];
    var rows = table.querySelectorAll('tr');
    var ranges = [];
    for (var R = 0; R < rows.length; ++R) {
        var outRow = [];
        var row = rows[R];
        var columns = row.querySelectorAll('td');
        for (var C = 0; C < columns.length; ++C) {
            var cell = columns[C];
            var colspan = cell.getAttribute('colspan');
            var rowspan = cell.getAttribute('rowspan');
            var cellValue = cell.innerText;
            if (cellValue !== "" && cellValue == +cellValue) cellValue = +cellValue;

            //Skip ranges
            ranges.forEach(function (range) {
                if (R >= range.s.r && R <= range.e.r && outRow.length >= range.s.c && outRow.length <= range.e.c) {
                    for (var i = 0; i <= range.e.c - range.s.c; ++i) outRow.push(null);
                }
            });

            //Handle Row Span
            if (rowspan || colspan) {
                rowspan = rowspan || 1;
                colspan = colspan || 1;
                ranges.push({s: {r: R, c: outRow.length}, e: {r: R + rowspan - 1, c: outRow.length + colspan - 1}});
            }

            //Handle Value
            outRow.push(cellValue !== "" ? cellValue : null);

            //Handle Colspan
            if (colspan) for (var k = 0; k < colspan - 1; ++k) outRow.push(null);
        }
        out.push(outRow);
    }
    return [out, ranges];
};

function datenum(v, date1904) {
    if (date1904) v += 1462;
    var epoch = Date.parse(v);
    return (epoch - new Date(Date.UTC(1899, 11, 30))) / (24 * 60 * 60 * 1000);
}

function sheet_from_array_of_arrays(sheet, data, headerRowNum, headerColNum) {
    var ws = sheet?sheet:{};
    headerColNum = headerColNum?headerColNum:0;
    var range = {s: {c: 10000000, r: 10000000}, e: {c: 0, r: 0}};
    for (var R = headerRowNum; R != data.length+headerRowNum; ++R) {
        for (var C = headerColNum; C != data[R].length+headerColNum; ++C) {
          if (range.s.r > R) range.s.r = R;
          if (range.s.c > C) range.s.c = C;
          if (range.e.r < R) range.e.r = R;
          if (range.e.c < C) range.e.c = C;
          var cell = {v: data[R-headerRowNum][C-headerColNum]};
          if (cell.v == null) continue;
          var cell_ref = XLSX.utils.encode_cell({c: C, r: R});

            if (typeof cell.v === 'number') cell.t = 'n';
            else if (typeof cell.v === 'boolean') cell.t = 'b';
            else if (cell.v instanceof Date) {
                cell.t = 'n';
                cell.z = XLSX.SSF._table[14];
                cell.v = datenum(cell.v);
            }
            else cell.t = 's';
            ws[cell_ref] = cell;
        }
    }
    if (range.s.c < 10000000) ws['!ref'] = XLSX.utils.encode_range(range);
    return ws;
}

function Workbook() {
    if (!(this instanceof Workbook)) return new Workbook();
    this.SheetNames = [];
    this.Sheets = {};
}

function s2ab(s) {
    var buf = new ArrayBuffer(s.length);
    var view = new Uint8Array(buf);
    for (var i = 0; i != s.length; ++i) view[i] = s.charCodeAt(i) & 0xFF;
    return buf;
}

export function export_table_to_excel(id) {
    var theTable = document.getElementById(id);
    console.log('a')
    var oo = generateArray(theTable);
    var ranges = oo[1];

    /* original data */
    var data = oo[0];
    var ws_name = "SheetJS";
    console.log(data);

    var wb = new Workbook(), ws = sheet_from_array_of_arrays(data);

    /* add ranges to worksheet */
    // ws['!cols'] = ['apple', 'banan'];
    ws['!merges'] = ranges;

    /* add worksheet to workbook */
    wb.SheetNames.push(ws_name);
    wb.Sheets[ws_name] = ws;

    var wbout = XLSX.write(wb, {bookType: 'xlsx', bookSST: false, type: 'binary'});

    saveAs(new Blob([s2ab(wbout)], {type: "application/octet-stream"}), "test.xlsx")
}

function formatJson(jsonData) {
    console.log(jsonData)
}

//考核模板导入
export function importExcel(file, dataSource, that){
  var wb;//读取完成的数据
  var rABS = true; //是否将文件读取为二进制字符串
  var excelArr; //读取结果
  if(!file) {
    return;
  }
  var f = file;
  var reader = new FileReader();
  //异步解析excel数据
  reader.onload = function(e) {
    var data = e.target.result;
    if(rABS) {
      wb = XLSX.read(btoa(fixdata(data)), {//手动转化
        type: 'base64'
      });
    } else {
      wb = XLSX.read(data, {
        type: 'binary'
      });
    }
    /**
     * wb.SheetNames[0]是获取Sheets中第一个Sheet的名字
     * wb.Sheets[Sheet名]获取第一个Sheet的数据
     */
    //将excel内容解析为数组
    excelArr = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
    //查询第一个非标题行的索引
    let indexs = excelArr.findIndex((x,index) => (index != 0 && (x.areaKey && (x.areaKey.includes('市')||x.areaKey.includes('区')||x.areaKey.includes('县')))));
    excelArr = excelArr.slice(indexs);
    if(excelArr.length != dataSource.length){
      that.$message.warning('导入模板和当前列表内容不对应，请检测!');
      return false;
    }
    console.log(excelArr)
    //清空列表
    dataSource.length = 0;
    //将excel中的内容导入
    excelArr.map(x =>{
      dataSource.push(x);
    })
  };
  //数据读取
  if(rABS) {
    reader.readAsArrayBuffer(f);
  } else {
    reader.readAsBinaryString(f);
  }
}

//文件流转BinaryString
function fixdata(data) {
  var o = "",
    l = 0,
    w = 10240;
  for(; l < data.byteLength / w; ++l) o += String.fromCharCode.apply(null, new Uint8Array(data.slice(l * w, l * w + w)));
  o += String.fromCharCode.apply(null, new Uint8Array(data.slice(l * w)));
  return o;
}

//考核模板导出
export function export_json_to_excel(th, cityData, record, defaultTitle, sheetName) {
    //sheet名称
    var ws_name = sheetName?sheetName:"Sheet1";

    //wb为一个excel单位，ws为一个sheet页单位，merge为单元格合并对象
    let wb = new Workbook(), ws = {}, merge = [];
    //获取标题占用的行数
    let rowSpan = th.length+1;
    //生成使用单元格范围
    ws['!ref'] = XLSX.utils.encode_range({s: {c: 0, r: 0}, e: {c: 300, r: 100}});
    //首行需要放置关系对应数据
    for(let v = 0; v < record.length; v++){
      createCell(ws, record[v], merge, 0, v, 0, v);
    }
    //处理首行数据(实际为excel第二行)
    let startCol = 0;
    for(let k = 0; k< th[0].length; k++){
      if("市区,扣分总和,得分".includes(th[0][k].v)){
        if(k==0){
          startCol = k;
          createCell(ws, th[0][k].v, merge, 1, startCol, rowSpan-1, startCol);
        }else{
          startCol += th[0][k-1].cm;
          createCell(ws, th[0][k].v, merge, 1, startCol, rowSpan-1, startCol);
        }
      }else{
        startCol += th[0][k-1].cm;
        createCell(ws, th[0][k].v, merge, 1, startCol, 1, startCol+th[0][k].cm-1)
      }
    }
    //处理首行之下的行
    for(let i = 1; i< th.length; i++){
      startCol = 0;
      for(let j = 0; j< th[i].length; j++){
        if(j == 0){
          startCol += 1;
          createCell(ws, th[i][j].v, merge, i+1, startCol, i+1, startCol+th[i][j].cm-1)
        }else{
          startCol += th[i][j-1].cm;
          if(th[i][j-1].cm > 1){
            createCell(ws, th[i][j].v, merge, i+1, startCol, i+1, startCol+th[i][j].cm-1)
          }else{
            createCell(ws, th[i][j].v, merge, i+1, startCol, i+1, startCol)
          }
        }
      }
    }
    //处理首列地市信息
    cityData.map((x,index) =>{
      createCell(ws, x.areaKey, merge, rowSpan+index, 0, rowSpan+index, 0);
    });

    //将ws信息放入wb中导出
    ws['!merges'] = merge;
    //XLSX.utils.sheet_add_aoa(ws, [[{v:8989},{v:666}]], { origin: { r: 2, c: 1 }})
    /* add worksheet to workbook */
    wb.SheetNames.push(ws_name);
    wb.Sheets[ws_name] = ws;

    var wbout = XLSX.write(wb, {bookType: 'xlsx', bookSST: false, type: 'binary'});
    var title = defaultTitle || '模板';
    saveAs(new Blob([s2ab(wbout)], {type: "application/octet-stream"}), title + ".xlsx")
}

//创建单元格并处理单元格合并范围
//ws:sheet页对象, text:单元格内容, merge:单元格合并范围,
// sRowIndex:合并开始单元格横坐标, sColIndex:合并开始单元格纵坐标, eRowIndex:合并结束单元格横坐标, eColIndex:合并结束单元格纵坐标
function createCell(ws, text, merge, sRowIndex, sColIndex, eRowIndex, eColIndex){
  merge.push({ s: { r: sRowIndex, c: sColIndex }, e: { r: eRowIndex, c: eColIndex} });

  for(let v = sRowIndex; v <= eRowIndex; v++){
    for(let k = sColIndex; k <= eColIndex; k++){
      var cell_ref = XLSX.utils.encode_cell({ r: v,c: k});
      var cell = {v: ''};
      if(v == sRowIndex && k == sColIndex){
        cell.v = text
      }
      // 横向合并，范围是第rowIndex行的列colIndex到列colIndex+obj.cm-1
      if (typeof cell.v === 'number') cell.t = 'n';
      else if (typeof cell.v === 'boolean') cell.t = 'b';
      else if (cell.v instanceof Date) {
        cell.t = 'n';
        cell.z = XLSX.SSF._table[14];
        cell.v = datenum(cell.v);
      }
      else {
        cell.t = 's';
      }
      //单元格式
      cell.s ={
        font: {
          color: {
            rgb: "00000000"
          }
        },
        alignment:{
          horizontal: "center",
          vertical: "center",
          wrap_text: true
        },
        border:{
          top: {style: "thin"},
          bottom: {style: "thin"},
          left: {style: "thin"},
          right: {style: "thin"}
        }
      };
      ws[cell_ref] = cell;
    }
  }
}
```

### 导出excel

```js
import {export_json_to_excel, importExcel} from '@/vendor/Export2Excel'

function exportExcel(){
                //导出
            require.ensure([], () => {
              let wbName = that.agentCheck.agentCompanyName+that.agentCheck.checkTypeName+"考核模板";
              let sheetName = that.agentCheck.checkMonth?that.agentCheck.checkMonth+'月考核':'sheet1';
              export_json_to_excel(excelHeader,that.dataSource, record, wbName, sheetName);
            })
}



//考核模板导出
export function export_json_to_excel(th, cityData, record, defaultTitle, sheetName) {
    //sheet名称
    var ws_name = sheetName?sheetName:"Sheet1";

    //wb为一个excel单位，ws为一个sheet页单位，merge为单元格合并对象
    let wb = new Workbook(), ws = {}, merge = [];
    //获取标题占用的行数
    let rowSpan = th.length+1;
    //生成使用单元格范围
    ws['!ref'] = XLSX.utils.encode_range({s: {c: 0, r: 0}, e: {c: 300, r: 100}});
    //首行需要放置关系对应数据
    for(let v = 0; v < record.length; v++){
      createCell(ws, record[v], merge, 0, v, 0, v);
    }
    //处理首行数据(实际为excel第二行)
    let startCol = 0;
    for(let k = 0; k< th[0].length; k++){
      if("市区,扣分总和,得分".includes(th[0][k].v)){
        if(k==0){
          startCol = k;
          createCell(ws, th[0][k].v, merge, 1, startCol, rowSpan-1, startCol);
        }else{
          startCol += th[0][k-1].cm;
          createCell(ws, th[0][k].v, merge, 1, startCol, rowSpan-1, startCol);
        }
      }else{
        startCol += th[0][k-1].cm;
        createCell(ws, th[0][k].v, merge, 1, startCol, 1, startCol+th[0][k].cm-1)
      }
    }
    //处理首行之下的行
    for(let i = 1; i< th.length; i++){
      startCol = 0;
      for(let j = 0; j< th[i].length; j++){
        if(j == 0){
          startCol += 1;
          createCell(ws, th[i][j].v, merge, i+1, startCol, i+1, startCol+th[i][j].cm-1)
        }else{
          startCol += th[i][j-1].cm;
          if(th[i][j-1].cm > 1){
            createCell(ws, th[i][j].v, merge, i+1, startCol, i+1, startCol+th[i][j].cm-1)
          }else{
            createCell(ws, th[i][j].v, merge, i+1, startCol, i+1, startCol)
          }
        }
      }
    }
    //处理首列地市信息
    cityData.map((x,index) =>{
      createCell(ws, x.areaKey, merge, rowSpan+index, 0, rowSpan+index, 0);
    });

    //将ws信息放入wb中导出
    ws['!merges'] = merge;
    //XLSX.utils.sheet_add_aoa(ws, [[{v:8989},{v:666}]], { origin: { r: 2, c: 1 }})
    /* add worksheet to workbook */
    wb.SheetNames.push(ws_name);
    wb.Sheets[ws_name] = ws;

    var wbout = XLSX.write(wb, {bookType: 'xlsx', bookSST: false, type: 'binary'});
    var title = defaultTitle || '模板';
    saveAs(new Blob([s2ab(wbout)], {type: "application/octet-stream"}), title + ".xlsx")
}

//创建单元格并处理单元格合并范围
//ws:sheet页对象, text:单元格内容, merge:单元格合并范围,
// sRowIndex:合并开始单元格横坐标, sColIndex:合并开始单元格纵坐标, eRowIndex:合并结束单元格横坐标, eColIndex:合并结束单元格纵坐标
function createCell(ws, text, merge, sRowIndex, sColIndex, eRowIndex, eColIndex){
  merge.push({ s: { r: sRowIndex, c: sColIndex }, e: { r: eRowIndex, c: eColIndex} });

  for(let v = sRowIndex; v <= eRowIndex; v++){
    for(let k = sColIndex; k <= eColIndex; k++){
      var cell_ref = XLSX.utils.encode_cell({ r: v,c: k});
      var cell = {v: ''};
      if(v == sRowIndex && k == sColIndex){
        cell.v = text
      }
      // 横向合并，范围是第rowIndex行的列colIndex到列colIndex+obj.cm-1
      if (typeof cell.v === 'number') cell.t = 'n';
      else if (typeof cell.v === 'boolean') cell.t = 'b';
      else if (cell.v instanceof Date) {
        cell.t = 'n';
        cell.z = XLSX.SSF._table[14];
        cell.v = datenum(cell.v);
      }
      else {
        cell.t = 's';
      }
      //单元格式
      cell.s ={
        font: {
          color: {
            rgb: "00000000"
          }
        },
        alignment:{
          horizontal: "center",
          vertical: "center",
          wrap_text: true
        },
        border:{
          top: {style: "thin"},
          bottom: {style: "thin"},
          left: {style: "thin"},
          right: {style: "thin"}
        }
      };
      ws[cell_ref] = cell;
    }
  }
}

function s2ab(s) {
    var buf = new ArrayBuffer(s.length);
    var view = new Uint8Array(buf);
    for (var i = 0; i != s.length; ++i) view[i] = s.charCodeAt(i) & 0xFF;
    return buf;
}
```

### 导入excel


```js
import {export_json_to_excel, importExcel} from '@/vendor/Export2Excel'

//导入excel模板
function handleImportExcel(obj){
        if (obj.event) {
          importExcel(obj.file.originFileObj, this.dataSource, this);
        }
}

    
    
//考核模板导入
export function importExcel(file, dataSource, that){
  var wb;//读取完成的数据
  var rABS = true; //是否将文件读取为二进制字符串
  var excelArr; //读取结果
  if(!file) {
    return;
  }
  var f = file;
  var reader = new FileReader();
  //异步解析excel数据
  reader.onload = function(e) {
    var data = e.target.result;
    if(rABS) {
      wb = XLSX.read(btoa(fixdata(data)), {//手动转化
        type: 'base64'
      });
    } else {
      wb = XLSX.read(data, {
        type: 'binary'
      });
    }
    /**
     * wb.SheetNames[0]是获取Sheets中第一个Sheet的名字
     * wb.Sheets[Sheet名]获取第一个Sheet的数据
     */
    //将excel内容解析为数组
    excelArr = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
    //查询第一个非标题行的索引
    let indexs = excelArr.findIndex((x,index) => (index != 0 && (x.areaKey && (x.areaKey.includes('市')||x.areaKey.includes('区')||x.areaKey.includes('县')))));
    excelArr = excelArr.slice(indexs);
    if(excelArr.length != dataSource.length){
      that.$message.warning('导入模板和当前列表内容不对应，请检测!');
      return false;
    }
    console.log(excelArr)
    //清空列表
    dataSource.length = 0;
    //将excel中的内容导入
    excelArr.map(x =>{
      dataSource.push(x);
    })
  };
  //数据读取
  if(rABS) {
    reader.readAsArrayBuffer(f);
  } else {
    reader.readAsBinaryString(f);
  }
}

//文件流转BinaryString
function fixdata(data) {
  var o = "",
    l = 0,
    w = 10240;
  for(; l < data.byteLength / w; ++l) o += String.fromCharCode.apply(null, new Uint8Array(data.slice(l * w, l * w + w)));
  o += String.fromCharCode.apply(null, new Uint8Array(data.slice(l * w)));
  return o;
}    
```

对应html：

```html
<a-upload name="file" :showUploadList="false" :multiple="false" headers="tokenHeader"
          style="float: left;"  action="###" @change="handleImportExcel($event)">
  <a-button type="primary" ghost>模板导入</a-button>
```

参考资料：

导出：

https://www.jb51.net/article/137422.htm

https://www.cnblogs.com/vicky-li/p/11469100.html

导入：

https://www.cnblogs.com/kawhileonardfans/p/10966043.html

https://blog.csdn.net/a736755244/article/details/99568133

样式文档：

https://www.jianshu.com/p/869375439fee