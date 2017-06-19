# ZeroBraneStudio(Xlua)配置方法
* 相比于tolua，xlua上因为基本是基于事件的，所以一般使用xlua的环境下都不需要用到面向对象（因为主逻辑还是使用C#），基于这个原因，在xlua框架下
使用ZeroBraneStuido调试只要做基本配置即可，不需要对编辑器做很多工作，是比较接近编辑器的原生思路的，只是配置的时候注意几个点即可。下面会具体描述到。

* 下面就是配置基本涉及到代码:  
首先第一步就是要让lua require到 mobdebug脚本

```C#
_luaEnv.AddLoader ((ref string filename) => {
	//可以lua时候不传全路径 在C#这边处理 自己衡量怎么搞
	if (filename == "mobdebug") {
		string path = LuaConst.zbDir + "/mobdebug.lua";
		byte[] fileBytes = System.IO.File.ReadAllBytes (path);
		return fileBytes;
	}
	return null;
 });
```
文档已经有说明，这里进一步描述，filename参数是lua代码 require(“xxx”) xxx就是在C#中addLoader的filename参数，
所以具体做法就是获取到对应的mobdebug.lua中的内容以byte返回即可。

第二步就是读取lua脚本（不清楚流程请看:02_U3DScripting）
```C#
string path = LuaConst.luaDir;
string realPath = path + "/" + filePath + ".lua";
byte[] fileBytes = System.IO.File.ReadAllBytes (realPath);

//注意这里第二个参数要传全路径(否则zb编辑器无法激活对应的lua文本)
_luaEnv.DoString (fileBytes, realPath, scriptEnv);
```

唯独DoString第二个参数要说明下，如果发现运行时候ZeroBraneStudio报错，提示无法激活文件，那么就是因为没有传入全路径原因了。因为该参数本身就是用于传入调试信息的。

第三步就是在lua文件上 哪个文件需要调试就加上 require("mobdebug").start() 这句即可

最后记得编辑器Project->Start Debugger Server 勾上 运行unity  

* 因为最近旧项目预计要搞更新，所以选择xlua来做这事情。顺便搞下zb编辑器的配置，放出来分享下。
