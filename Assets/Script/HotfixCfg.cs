using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using XLua;
using System;

public static class HotfixCfg
{
	[Hotfix]
	public static List<Type> CustomClass = new List<Type>()
	{
		typeof(Base),
		typeof(UpdateLuaTest),
	};

}