using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Main : MonoBehaviour 
{
	UpdateLuaTest _t;

	void Start () {
		_t = new UpdateLuaTest();
	}
	
	void Update () 
	{
		
	}

	void OnGUI()
	{
		_t.OnGUI ();
	}
}
