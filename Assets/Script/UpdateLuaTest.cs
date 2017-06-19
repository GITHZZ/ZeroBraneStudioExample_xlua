using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using XLua;
using System;

public class UpdateLuaTest : Base
{
	LuaClient _luaClient;

	string _test = "_test";
	public string test
	{
		get{
			return _test;
		}
	}

	public UpdateLuaTest()
	{
		_luaClient = LuaClient.GetInstance ();
	}

	public void Description()
	{
		Print1 ();
	} 
		
	public void Print1()
	{
		Debug.Log ("Print1");
	}

	public void Print2()
	{
		Debug.Log ("Print2");
	}

	public void OnGUI()
	{
		if (GUI.Button(new Rect(10, 100, 100, 100), "调用方法"))
		{
//			LuaTable scriptEnv = _luaClient.DoFile ("TestClass2");
//			Action Description = scriptEnv.Get<Action>("Description");
//			if (Description != null)

			Description ();
		}

		if (GUI.Button (new Rect (10, 250, 100, 100), "更新代码")) 
		{
			_luaClient.DoFile ("UpdateLuaTest", this);
		}
	}
}
