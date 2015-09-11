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
import haxe.macro.Type.ClassType;

using hxdecorate.ExprExtension;

class Decorator
{
	private static var decorators : Map<String, Dynamic>;
	private static var initialised : Bool = false;
	
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
		var decoratorStatement : Expr = null;
		
		for (meta in localMetadata)
		{
			// Add calls to decorator functions
			if (decorators.exists(meta.name))
			{
				if(decoratorStatement == null)
				{
					// Build initial statement:
					// functionName(input, caller);
					decoratorStatement = macro untyped $i { decorators[meta.name] } (untyped $b{meta.params}, this);
				}
				else
				{
					// Apply next decorator function:
					// functionNameN(input, functionName(input, caller)); // ..etc
					// functionName returns the caller
					decoratorStatement = macro untyped $i { decorators[meta.name] } (untyped $b{meta.params}, untyped $e { decoratorStatement } );
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