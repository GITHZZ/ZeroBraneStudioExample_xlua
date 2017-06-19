using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class LuaConst
{
	public static string luaDir = Application.dataPath + "/Lua"; //lua逻辑代码目录

//Zerobrane Studio 路径
#if UNITY_EDITOR_WIN || NITY_STANDALONE_WIN
	public static string zbsDir = "D:/ZeroBraneStudio/lualibs/mobdebug";
#elif UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
	public static string zbDir = "/Users/apple/Develop/unity/xLua-client/ZeroBraneStudio-master/lualibs/mobdebug";
#else
	public static string zbDir = luaDir + "/mobdebug";
#endif

	public static bool openZbsDebugger = true;
}