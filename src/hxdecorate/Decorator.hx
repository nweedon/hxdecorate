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
	private static var decorators : Map<String, DecoratorArgs>;
	private static var initialised : Bool = false;
	private static var currentPlatform;
	
	#if macro
	private static var platformsSupported = ["js", "python", "cpp"];
	#end
	
	private function new() { }

	public static function init()
	{
		decorators = new Map<String, DecoratorArgs>();		
		initialised = true;
	}
	
	public static function getCurrentPlatform()
	{
		if (!initialised)
		{
			throw "Decorator has not been initialised yet, so platform is null!";
		}
		
		return currentPlatform;
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
		var className : String = Context.getLocalClass().toString();
		
		// Check build macro is placed on main class
		var args = Sys.args();
		var mainClassName = args[args.indexOf("-main") + 1];
		
		if (mainClassName != className)
		{
			Context.fatalError("'hxdecorator.Decorator.build()' must be placed on the main class.", Context.currentPos());
		}
			
		if (!initialised)
		{
			// Detect current platform in macro mode
			for (define in Context.getDefines().keys())
			{
				if (platformsSupported.indexOf(define) > -1)
				{
					currentPlatform = define;
				}
			}
		
			init();
		}
		
		if (decoratorBindings != null)
		{	
			for (decorator in Reflect.fields(decoratorBindings))
			{
				var ident : String = Reflect.field(decoratorBindings, decorator);
				var args : DecoratorArgs = new DecoratorArgs(ident);
				
				// Add to the list of decorators and tell the compiler to
				// keep the class, so DCE does not get rid of it.
				decorators.set(decorator, args);
				CompilerExtension.expose(args.getClassName());
				Compiler.keep(args.getClassName());
			}
			
			for (cl in classesToDecorate)
			{
				CompilerExtension.build("hxdecorate.Decorator.decorate()", cl);
				CompilerExtension.expose(cl);
				Compiler.keep(cl);
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
		if (classType != null && decoratorFunctionName != null && decoratorFunctionName.length > 0)
		{
			for (fn in classType.statics.get())
			{
				if (fn.name == decoratorFunctionName)
				{
					return true;
				}
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
		var originalBlock : Array<Expr> = [];
		var decoratorStatement : Expr = null;
		var constructorField : Field = null;
		var fieldIndex : Int = 0;
		var newStatement : Expr;
		
		/*
		 * Step 1:
		 * 
		 * Initial run of the local metadata array. This will update the metadata
		 * list with any extra build-time metadata, such as :cppInclude (which will
		 * allow C++ builds to include the files which have their decorator definitions)
		*/
		for (meta in localMetadata)
		{
			if (decorators.exists(meta.name))
			{
				var args : DecoratorArgs = decorators[meta.name];
				
				switch(getCurrentPlatform())
				{
					case "cpp":
						// Add :cppInclude metadata
						// Example:
						// Class Name: libraryTest.TestDecorators
						// Header File: TestDecorators
						// Final Path: libraryTest/TestDecorators.h
						var headerFilePath = args.getClassName().split('.');
						var headerFileName = headerFilePath.pop();
						var finalPath = '${headerFilePath.join("/")}/${headerFileName}.h';
						
						localClass.meta.add(":cppInclude", 
											[Context.makeExpr(finalPath, Context.currentPos())], 
											Context.currentPos());
				
					default:		
				}				
			}
		}
		
		/*
		 * Step 2:
		 * 
		 * Run through metadata again, but this time process the decorators
		 * and produce the required macro information.
		*/
		for (meta in localMetadata)
		{
			// Add calls to decorator functions
			if (decorators.exists(meta.name))
			{
				var args : DecoratorArgs = decorators[meta.name];
				var decoratorCall : String = args.getPlatformCall();
				var underlyingType : Type = Context.getType(args.getClassName());
				
				if (underlyingType != null)
				{
					var classType = switch(underlyingType)
					{
						case TInst(r, _) : r.get();
						default: null;
					};
				
					// Check the referenced function is static.
					if (!isStatic(classType, args.getFunctionName()))
					{
						Context.fatalError('Function "${args.getFunctionName()}" in class "${args.getClassName()}" either does not exist or is not marked as static.', Context.currentPos());
					}
				}
				else
				{
					Context.fatalError('Class "${args.getClassName()}" does not exist.', Context.currentPos());
				}
				
				// Compile final build statement.
				if(decoratorStatement == null)
				{					
					// Build initial statement:
					// functionName(input, caller);
					decoratorStatement = macro untyped $i{decoratorCall}(untyped $b{meta.params}, $i{Platform.identSelf()});
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
		
		// Search for constructor field.
		while (fieldIndex < buildFields.length && originalBlock != null)
		{
			if (buildFields[fieldIndex].name == "new")
			{
				// Retrieve main function.
				var func : haxe.macro.Expr.Function = switch(buildFields[fieldIndex].kind)
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
			
			fieldIndex++;
		}
		
		// Add new constructor which has the new
		// decorator statement.
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