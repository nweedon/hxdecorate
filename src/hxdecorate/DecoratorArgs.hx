/*
Copyright 2015 Niall Frederick Weedon

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package hxdecorate;
import haxe.macro.Compiler;

class DecoratorArgs
{
	private var className : String;
	private var functionName : String;
	private var decoratorCall : String;
	
	/**
	 * DecoratorArg constructor. Verifies call syntax and
	 * splits syntax into their respective fields.
	 * @param	call String in the form of 'fullyQualifiedClasspath#functionName'
	 */
	public function new(call : String)
	{
		if (call != null && call.length > 0)
		{
			var callComponents = call.split("#");
			
			if (callComponents.length != 2)
			{
				throw 'Decorator call "${decoratorCall}" must be in the form "fullyQualifiedClasspath#functionName".';
			}
			
			this.decoratorCall = call;
			this.className = callComponents[0];
			this.functionName = callComponents[1];
		}
	}
	
	inline public function getClassName() : String
	{
		return className;
	}
	
	inline public function getFunctionName() : String
	{
		return functionName;
	}
	
	/**
	 * Generates decorator function call syntax dependent
	 * on the current compilation platform (i.e. JavaScript, Python etc.)
	 * @return
	 */
	public function getPlatformCall() : String
	{
		var modifiedCall = "";
		
		switch(Decorator.getCurrentPlatform())
		{
			case "js": 
				modifiedCall = decoratorCall.split("#").join(".");			
			// Transform decorator call, Haxe namespaces class names as such:
			// pack0_packN_className
			case "python": 
				modifiedCall = decoratorCall.split(".").join("_").split("#").join(".");
				
			case "cpp":
				var namespaces = className.split(".");
				var obj = namespaces.pop();
				// Example:
				// 'libraryTest.TestDecorators#decoratorOne' will become:
				// ::libraryTest::TestDecorators_obj::decoratorOne(...)
				modifiedCall = '::${namespaces.join("::")}::${obj}_obj::${functionName}';
			default: 
				throw 'Platform unsupported.';
		}
		
		modifiedCall = Platform.globalNamespace() + modifiedCall;
		
		return modifiedCall;
	}
}