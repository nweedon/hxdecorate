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

class Decorator {

    private static var decorators : Map<String, DecoratorArgs>;
    private static var initialised : Bool = false;
    private static var currentPlatform;

    #if macro
    private static var platformsSupported = ["js", "python", "cpp", "java"];
    #end

    private function new() { }

    public static function init() {
        decorators = new Map<String, DecoratorArgs>();
        initialised = true;
    }

    public static function getCurrentPlatform() {
        if (!initialised) {
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
    macro public static function build(decoratorClassExpr : Expr, classesToDecorate : Expr) : Array<Field> {
        var decoratorBindings : Dynamic = decoratorClassExpr.value();
        var classesToDecorate : Array<String> = classesToDecorate.value();
        var className : String = Context.getLocalClass().toString();

        // Check build macro is placed on main class
        var args = Sys.args();
        var mainClassName = args[args.indexOf("-main") + 1];

        if (mainClassName != className) {
            Context.fatalError("'hxdecorator.Decorator.build()' must be placed on the main class.", Context.currentPos());
        }

        if (!initialised) {
            // Detect current platform in macro mode
            for (define in Context.getDefines().keys()) {
                if (platformsSupported.indexOf(define) > -1) {
                    currentPlatform = define;
                }
            }

            init();
        }

        if (decoratorBindings != null) {
            for (decorator in Reflect.fields(decoratorBindings)) {
                var ident : String = Reflect.field(decoratorBindings, decorator);
                var args : DecoratorArgs = new DecoratorArgs(ident);

                // Add to the list of decorators and tell the compiler to
                // keep the class, so DCE does not get rid of it.
                decorators.set(decorator, args);
                CompilerExtension.expose(args.getClassName());
                Compiler.keep(args.getClassName());
            }

            for (cl in classesToDecorate) {
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
    private static function isStatic(classType : ClassType, decoratorFunctionName : String) : Bool {
        if (classType != null && decoratorFunctionName != null && decoratorFunctionName.length > 0) {
            for (fn in classType.statics.get()) {
                if (fn.name == decoratorFunctionName) {
                    return true;
                }
            }
        }

        return false;
    }

    public static function shouldDecorateBefore(classMetadata : Metadata) : Bool {
        if(classMetadata != null) {
            for(meta in classMetadata) {
                if(meta.name == ":decorateBefore") {
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
    macro public static function decorate() : Array<Field> {
        var buildFields : Array<Field> = Context.getBuildFields();
        var localClass : ClassType = Context.getLocalClass().get();
        var localMetadata : Metadata = localClass.meta.get();
        var originalBlock : Array<Expr> = [];
        var finalBlock : Expr;
        var decoratorStatement : Expr = null;
        var decoratorStatementIdentifier : String = null;
        var params : Array<Dynamic> = [];
        var constructorField : Field = null;
        var fieldIndex : Int = 0;
        var decorateBefore : Bool = shouldDecorateBefore(localMetadata);

        /*
        * Step 1:
        *
        * Initial run of the local metadata array. This will update the metadata
        * list with any extra build-time metadata, such as :cppInclude (which will
        * allow C++ builds to include the files which have their decorator definitions)
        */
        for (meta in localMetadata) {
            var name : String = meta.name;

            // Remove ':' from metadata (for comparison only)
            if(meta.name.charAt(0) == ':') {
                name = meta.name.substr(1);
            }

            if (decorators.exists(name)) {
                var args : DecoratorArgs = decorators[name];

                switch(getCurrentPlatform()) {
                    case "cpp":
                        // Add :cppInclude metadata
                        // Example:
                        // Class Name: test.decorators.TestDecorators
                        // Header File: TestDecorators
                        // Final Path: test/decorators/TestDecorators.h
                        var finalPath : String = '${args.getClassName().split('.').join("/")}.h';

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
        var metaIndex : Int = 0;

        for (meta in localMetadata) {
            var name : String = meta.name;

            // Remove ':' from metadata (for comparison only)
            if(meta.name.charAt(0) == ':') {
                name = meta.name.substr(1);
            }

            // Add calls to decorator functions
            if (decorators.exists(name)) {
                var args : DecoratorArgs = decorators[name];
                var decoratorCall : String = args.getPlatformCall();
                var underlyingType : Type = Context.getType(args.getClassName());

                if (underlyingType != null) {
                    var classType = switch(underlyingType) {
                        case TInst(r, _) : r.get();
                        default: null;
                    };

                    // Check the referenced function is static.
                    if (!isStatic(classType, args.getFunctionName())) {
                        Context.fatalError('Function "${args.getFunctionName()}" in class "${args.getClassName()}" either does not exist or is not marked as static.', Context.currentPos());
                    }
                } else {
                    Context.fatalError('Class "${args.getClassName()}" does not exist.', Context.currentPos());
                }

                // Compile final build statement.
                switch(getCurrentPlatform()) {
                    case "java":
                        // For Java, manually build the code. As hxjava adds
                        // __hxinvoke2_o to all function calls, the code needs to
                        // be built in a different way (as the above doesn't work).
                        var param = null;

                        if(decoratorStatementIdentifier == null) {
                            decoratorStatementIdentifier = '${decoratorCall}(';

                            // '__params_n' is defined in the final code block
                            // deifnition. Each param variable in the Java code
                            // corresponds to a parameter value in meta.params.
                            for(param in meta.params) {
                                params.push(ExprExtension.value(param));
                                decoratorStatementIdentifier += '__params_${metaIndex},';
                            }

                            // '__self' is defined in the final code block
                            // definition. It points the the variable hxjava
                            // gives 'this' in the static constructor function.
                            decoratorStatementIdentifier += '__self)';
                        } else {
                            var addedStatement : String = '${decoratorCall}(';

                            for(param in meta.params) {
                                params.push(ExprExtension.value(param));
                                addedStatement += '__params_${metaIndex},';
                            }

                            decoratorStatementIdentifier = '${addedStatement}${decoratorStatementIdentifier})';
                        }

                    default:
                        // For every other target, use expressions.
                        if(decoratorStatement == null) {
                            // Build initial statement:
                            // functionName(input, caller);
                            decoratorStatement = macro untyped $i{ decoratorCall }(untyped $b{ meta.params }, $i{ Platform.identSelf() });
                        } else {
                            // Apply next decorator function:
                            // functionNameN(input, functionName(input, caller)); // ..etc
                            // functionName returns the caller
                            decoratorStatement = macro untyped $i{ decoratorCall }(untyped $b{ meta.params }, untyped $e{ decoratorStatement });
                        }
                }

                metaIndex++;
            }
        }

        /*
         * Step 3:
         *
         * Regenerate constructor with new code body.
         * Only update build fields if the target has at
         * least one decorator.
        */
        if(decoratorStatement != null || decoratorStatementIdentifier != null) {
            // Search for constructor field.
            while (fieldIndex < buildFields.length && originalBlock != null) {
                if (buildFields[fieldIndex].name == "new") {
                    // Retrieve main function.
                    var func : haxe.macro.Expr.Function = switch(buildFields[fieldIndex].kind) {
                        case FFun(f): f;
                        default: null;
                    };

                    // Retrieve original code block. If an original
                    // doesn't exist, create an empty block.
                    originalBlock = switch(func.expr.expr) {
                        case EBlock(b): b;
                        default: [];
                    }

                    // Remove old constructor
                    buildFields.splice(fieldIndex, 1);

                    // Detect superclass. If class has superclass,
                    // remove the statement and add it when the function
                    // is rebuilt.
                    if(localClass.superClass != null) {
                        originalBlock.splice(0, 1);
                    }
                }

                fieldIndex++;
            }

            if(decoratorStatement != null) {
                // Generate final code block. With 'decorateBefore' set,
                // the calls to the decorator functions are placed before
                // the rest of the constructor code.
                if(decorateBefore) {
                    finalBlock = macro {
                        $decoratorStatement;
                        $b{ originalBlock }
                    }
                } else {
                    finalBlock = macro {
                        $b{ originalBlock }
                        $decoratorStatement;
                    }
                }
            } else if(decoratorStatementIdentifier != null) {
                // Generate final code block. This is mainly the same as
                // using the 'decoratorStatement' expression above, except this
                // time the code is generated in a String, so use it as an
                // identifier.
                if(decorateBefore) {
                    finalBlock = macro {
                        var __self = this;
                        var __params : Array<Dynamic> = $v{ params }
                        untyped $i{ decoratorStatementIdentifier };
                        $b{ originalBlock }
                    }
                } else {
                    finalBlock = macro {
                        var __self = this;
                        var __params : Array<Dynamic> = $v{ params }
                        $b{ originalBlock }
                        untyped $i{ decoratorStatementIdentifier };
                    }
                }
            } else {
                finalBlock = macro {
                    $b{ originalBlock };
                }
            }

            // If local class has a superclass,
            // insert supercall as it was removed
            // earlier.
            if(localClass.superClass != null) {
                finalBlock = macro {
                    super();
                    $e{ finalBlock }
                }
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
                    expr: finalBlock,
                    args: []
                }),
                pos: Context.currentPos()
            });
        }

        return buildFields;
    }

}
