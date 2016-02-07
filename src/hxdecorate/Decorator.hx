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

#if macro
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

    private static var platformsSupported = ["js", "python", "cpp", "java"];

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
    * Sets up build to parse decorator values. Proxies the build process to allow another
    * build macro to set up decorators.
    * @param	decoratorBindings {Dynamic} Decorator bindings object.
    * @param    classesToDecorate {Array<String>} Array of strings to fully-qualified class names to be decorated.
    * @return null. Adds no extra build fields to main class.
    */
    public static function proxyBuild(decoratorBindings : Dynamic, classesToDecorate : Array<String>) : Array<Field> {
        trace('Proxying decorator process');
        buildProcess(decoratorBindings, classesToDecorate);

        return null;
    }

    /**
    * Sets up build to parse decorator values.
    * @param	decoratorBindings {Dynamic} Decorator bindings object.
    * @param    classesToDecorate {Array<String>} Array of strings to fully-qualified class names to be decorated.
    * @return null. Adds no extra build fields to main class.
    */
    private static function buildProcess(decoratorBindings : Dynamic, classesToDecorate : Array<String>) : Array<Field> {
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
                trace('Creating decorator binding for "${ident}"');
                var args : DecoratorArgs = new DecoratorArgs(ident);

                // Add to the list of decorators and tell the compiler to
                // keep the class, so DCE does not get rid of it.
                decorators.set(decorator, args);
                CompilerExtension.expose(args.getClassName());
                Compiler.keep(args.getClassName());
            }

            for (cl in classesToDecorate) {
                trace('Preparing "${cl}" for building');
                CompilerExtension.build("hxdecorate.Decorator.decorate()", cl);
                CompilerExtension.expose(cl);
                Compiler.keep(cl);
            }
        }

        return null;
    }

    /**
    * Sets up build to parse decorator values. Function to use when
    * building from the main class.
    * @param	decoratorClassExpr {Expr} Decorator bindings expression.
    * @param    classesToDecorate {Expr} Expression representing an array of strings to fully-qualified class names.
    * @return null. Adds no extra build fields to main class.
    */
    macro public static function build(decoratorClassExpr : Expr, classesToDecorate : Expr) : Array<Field> {
        var decoratorBindings : Dynamic = decoratorClassExpr.value();
        var classesToDecorate : Array<String> = classesToDecorate.value();
        var className : String = Context.getLocalClass().toString();

        // Check build macro is placed on main class
        var args = Sys.args();
        var mainClassName = args[args.indexOf("-main") + 1];

        if (mainClassName != className) {
            Context.fatalError('"hxdecorate.Decorator.build()" must be placed on the main class.', Context.currentPos());
        }

        buildProcess(decoratorBindings, classesToDecorate);

        return null;
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

    private static function generateDefaultDecorator(decoratorStatement : Expr, decoratorCall : String, metaParams : Array<Expr>) : Expr {
        if(decoratorStatement == null) {
            // Build initial statement:
            // functionName(input, caller);
            decoratorStatement = macro untyped $i{ decoratorCall }($a{ metaParams }, $i{ Platform.identSelf() });
        } else {
            // Apply next decorator function:
            // functionNameN(input, functionName(input, caller)); // ..etc
            // functionName returns the caller
            decoratorStatement = macro untyped $i{ decoratorCall }($a{ metaParams }, $e{ decoratorStatement });
        }

        return decoratorStatement;
    }

    /**
    * Apply decorator generation code.
    * @return
    */
    macro public static function decorate() : Array<Field> {
        var buildFields : Array<Field> = Context.getBuildFields();      // Input fields, received from code.
        var updatedBuildFields : Array<Field> = [];                     // Output fields after build macro usage.
        var field : Field = null;                                       // Current field being analysed.
        var localClass : ClassType = Context.getLocalClass().get();     // Current class being analysed.

        trace('Decorating "${localClass.name}"');

        for(field in buildFields) {
            var decorateBefore : Bool = shouldDecorateBefore(field.meta);
            var originalBlock : Array<Expr> = [];       // Original code block to be modified.
            var meta : Metadata = null;

            // Variables used to store the decorator statement which will be written
            // to the current field. In most cases, 'decoratorStatement' will be used,
            // which in turn Haxe will use for parsing into target code. In some situations
            // (i.e. Java), the statement has to be built by hand due to incompatibilities
            // (see comments below for further explanation for each plaform affected).
            var decoratorStatement : Expr = null;
            var decoratorStatementIdentifier : String = null;
            var params : Array<Dynamic> = [];
            var fieldMetadata = field.meta;

            // Retrieve field definition.
            // Currently, only support functions.
            var fieldDef : haxe.macro.Expr.Function = switch(field.kind) {
                case FieldType.FFun(f): f;
                default: null;
            }

            if(fieldDef == null) {
                updatedBuildFields.push(field);
                continue;
            }

            /*
            * Step 1:
            *
            * Initial run of the local metadata array. This will update the metadata
            * list with any extra build-time metadata, such as :cppInclude (which will
            * allow C++ builds to include the files which have their decorator definitions)
            */
            CppCodeGenerator.generateInclude(decorators, field);

            /*
            * Step 2:
            *
            * Run through metadata again, but this time process the decorators
            * and produce the required macro information.
            */
            if(field.name == "new") {
                for(classMeta in localClass.meta.get()) {
                    fieldMetadata.push(classMeta);
                }
            }

            for (meta in fieldMetadata) {
                var name : String = meta.name;

                // Remove ':' from metadata (for comparison only)
                if(meta.name.charAt(0) == ':') {
                    name = meta.name.substr(1);
                }

                // Add calls to decorator functions
                if (decorators.exists(name)) {
                    var args : DecoratorArgs = decorators[name];
                    var decoratorCall : String = args.getPlatformCall();

                    args.checkDecoratorValidity();

                    // Compile final build statement.
                    switch(getCurrentPlatform()) {
                        case "java":
                            decoratorStatementIdentifier =
                                JavaCodeGenerator.generateDecorator(decoratorStatementIdentifier,
                                                                    decoratorCall,
                                                                    meta.params.map(function(param : Expr) {
                                                                        return param.value();
                                                                    }));

                        default:
                            // For every other target, use expressions.
                            decoratorStatement = generateDefaultDecorator(decoratorStatement,
                                                                            decoratorCall,
                                                                            meta.params);
                    }
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
                var decoratorLines : Array<Expr> = [];

                // Retrieve original code block. If an original
                // doesn't exist, create an empty block.
                originalBlock = switch(fieldDef.expr.expr) {
                    case EBlock(b): b;
                    default: [];
                }

                // Detect superclass. If class has superclass,
                // remove the statement and add it when the function
                // is rebuilt.
                if(field.name == "new" && localClass.superClass != null) {
                    originalBlock.splice(0, 1);
                }

                if(decoratorStatement != null) {
                    decoratorLines.push(macro untyped ${ decoratorStatement });
                } else if(decoratorStatementIdentifier != null) {
                    // Generate final code block. This is mainly the same as
                    // using the 'decoratorStatement' expression above, except this
                    // time the code is generated in a String, so use it as an
                    // identifier.
                    var selfName = JavaCodeGenerator.SELF_REFERENCE_VARIABLE_NAME;

                    decoratorLines.push(macro var $selfName = this);
                    decoratorLines.push(macro var __params : Array<Dynamic> = $v{ JavaCodeGenerator.getParams() });
                    decoratorLines.push(macro untyped $i{ decoratorStatementIdentifier });
                }

                if(decorateBefore) {
                    decoratorLines.push(macro $b{ originalBlock });
                } else {
                    decoratorLines.insert(0, macro $b{ originalBlock });
                }

                // If local class has a superclass,
                // insert supercall as it was removed
                // earlier.
                if(field.name == "new" && localClass.superClass != null) {
                    decoratorLines.insert(0, macro super());
                }

                // Set new function body
                fieldDef.expr = macro $b{ decoratorLines };
                field.kind = FieldType.FFun(fieldDef);
            }

            updatedBuildFields.push(field);
        }

        CppCodeGenerator.addFileCode(localClass);

        return updatedBuildFields;
    }

}
#end
