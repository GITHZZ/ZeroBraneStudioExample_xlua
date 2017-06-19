using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using XLua;

public class LuaClient
{
	private static LuaClient _instance;
	private LuaEnv _luaEnv = new LuaEnv();

	public static LuaClient GetInstance()
	{	
		if (_instance == null)
			_instance = new LuaClient();

		return _instance;
	}

	public LuaClient()
	{
		Init ();
	}

	public void Init()
	{
		if (LuaConst.openZbsDebugger) {
			_luaEnv.AddLoader ((ref string filename) => {
				//可以lua时候不传全路径 在C#这边处理 自己衡量怎么搞
				if (filename == "mobdebug") {
					string path = LuaConst.zbDir + "/mobdebug.lua";
					byte[] fileBytes = System.IO.File.ReadAllBytes (path);
					return fileBytes;
				}
				return null;
			});
		}
	}

	public LuaTable DoFile(string filePath, Base bindClass = null)
	{
		LuaTable scriptEnv = _luaEnv.NewTable ();
		LuaTable meta = _luaEnv.NewTable ();
		meta.Set ("__index", _luaEnv.Global);
		scriptEnv.SetMetaTable (meta);
		meta.Dispose ();

		//将C# this绑定到 lua self中
		if(bindClass != null)
			scriptEnv.Set("self", bindClass);

		string path = LuaConst.luaDir;
		string realPath = path + "/" + filePath + ".lua";
		byte[] fileBytes = System.IO.File.ReadAllBytes (realPath);

		//注意这里第二个参数要传全路径(否则zb编辑器无法激活对应的lua文本)
		_luaEnv.DoString (fileBytes, realPath, scriptEnv);

		return scriptEnv;
	}

	public void Dispose()
	{
		_luaEnv.Dispose ();
		_luaEnv = null;

		_instance = null;
	}
}