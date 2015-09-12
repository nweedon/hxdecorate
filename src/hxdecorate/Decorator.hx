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
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Context;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;

using hxdecorate.ExprExtension;

class Decorator
{
	private static var decorators : Map<String, Dynamic>;
	private static var initialised : Bool = false;
	
	#if macro
	private static var platformsSupported = ["js", "python"];
	#end
	
	private function new() { }

	public static function init()
	{
		decorators = new Map<String, Dynamic>();
		initialised = true;
	}
	
	/**
	 * Sets up build to parse decorator values.
	 * @param	decoratorClassExpr
	 * @return
	 */
	#if macro
	macro public static function build(decoratorClassExpr : Expr, classesToDecorate : Expr) : Array<Field>
	{
		var decoratorBindings : Dynamic = decoratorClassExpr.value();
		var classesToDecorate : Array<String> = classesToDecorate.value();
		
		if (!initialised)
		{
			init();
		}
		
		if (decoratorBindings != null)
		{	
			for (decorator in Reflect.fields(decoratorBindings))
			{
				var ident = Reflect.field(decoratorBindings, decorator);
				decorators.set(decorator, ident);
			}
			
			for (cl in classesToDecorate)
			{
				Compiler.addMetadata("@:build(hxdecorate.Decorator.decorate())", cl);
			}
		}
		
		return null;
	}
	
	
	
	/**
	 * Checks whether the referenced function name is
	 * within the list of static fields.
	 * @param	classType				The class type to be inspected.
	 * @param	decoratorFunctionName	The function name to search for in the class type's list of static fields.
	 * @return	True if [decoratorFunctionName] is contained in list of static fields.
	 */
	private static function isStatic(classType : ClassType, decoratorFunctionName : String) : Bool
	{
		for (fn in classType.statics.get())
		{
			if (fn.name == decoratorFunctionName)
			{
				return true;
			}
		}
		
		return false;
	}
	#end
	
	/**
	 * Apply decorator generation code.
	 * @return
	 */
	macro public static function decorate() : Array<Field>
	{
		var buildFields : Array<Field> = Context.getBuildFields();
		var localClass : ClassType = Context.getLocalClass().get();
		var localMetadata : Metadata = localClass.meta.get();
		var newStatement : Expr;
		var currentPlatform : String;
		var decoratorStatement : Expr = null;
		
		// Detect current platform in macro mode
		for (define in Context.getDefines().keys())
		{
			if (platformsSupported.indexOf(define) > -1)
			{
				currentPlatform = define;
			}
		}
					
		for (meta in localMetadata)
		{
			// Add calls to decorator functions
			if (decorators.exists(meta.name))
			{
				var decoratorCall : String = decorators[meta.name];
				var callComponents : Array<String> = decoratorCall.split('#');
				var underlyingType : Type = Context.getType(callComponents[0]);
				// Variable used to store how a programming language
				// defines a self-owned object (i.e., 'this' in JavaScript)
				var identSelf : String;
				
				if (callComponents.length != 2)
				{
					Context.fatalError('Decorator call "${decoratorCall}" must be in the form "fullyQualifiedClasspath#functionName".', Context.currentPos());
				}
				
				// Configure platform-related syntax. If the platform is
				// unsupported, an exception is thrown.
				switch(currentPlatform)
				{
					case "js":
						identSelf = "this";
						
					case "python":
						identSelf = "self";
						// Transform decorator call, Haxe namespaces class names as such:
						// pack0_packN_className
						decoratorCall = decoratorCall.split(".").join("_");
					default:
						throw "Platform unsupported.";
				}
				
				// Function call preceeded by a '#'
				decoratorCall = decoratorCall.split("#").join(".");
				
				if (underlyingType != null)
				{
					var classType = switch(underlyingType)
					{
						case TInst(r, _) : r.get();
						default: null;
					};
				
					// Check the referenced function is static.
					if (!isStatic(classType, callComponents[1]))
					{
						Context.fatalError('Function "${callComponents[1]}" in class "${callComponents[0]}" either does not exist or is not marked as static.', Context.currentPos());
					}
				}
				else
				{
					Context.fatalError('Class "${callComponents[0]}" does not exist.', Context.currentPos());
				}
				
				if(decoratorStatement == null)
				{					
					// Build initial statement:
					// functionName(input, caller);
					decoratorStatement = macro untyped $i{decoratorCall}(untyped $b{meta.params}, $i{identSelf});
				}
				else
				{
					// Apply next decorator function:
					// functionNameN(input, functionName(input, caller)); // ..etc
					// functionName returns the caller
					decoratorStatement = macro untyped $i{decoratorCall}(untyped $b{meta.params}, untyped $e{decoratorStatement});
				}
			}
		}
		
		var fieldIndex = 0;
		
		for (i in 0...buildFields.length)
		{
			if (buildFields[i].name == "new")
			{
				fieldIndex = i;
			}
		}
		
		var constructorField : Field = buildFields[fieldIndex];
		var originalBlock : Array<Expr>;
		
		if (constructorField != null)
		{
			// Retrieve main function.
			var func : haxe.macro.Expr.Function = switch(constructorField.kind)
			{
				case FFun(f): f;
				default: null;
			};
			
			// Retrieve original code block. If an original
			// doesn't exist, create an empty block.
			originalBlock = switch(func.expr.expr)
			{
				case EBlock(b): b;
				default: [];
			}
			
			// Remove old constructor
			buildFields.splice(fieldIndex, 1);
		}
		
		buildFields.push({
			name: "new",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FieldType.FFun({ 
				ret: macro : Void,
				params: [],
				expr: macro {
					$b { originalBlock };
					$decoratorStatement;
				},
				args: []
			}),
			pos: Context.currentPos()
		});
		
		return buildFields;
	}
}