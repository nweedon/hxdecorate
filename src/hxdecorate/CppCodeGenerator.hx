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
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Type.ClassType;

class CppCodeGenerator {

    public static var includeStatement(default, null) : String = "";
    private static var headersIncluded : Array<String> = [];

    public static function generateInclude(decorators : Map<String, DecoratorArgs>, field : Field) {
        if(Decorator.getCurrentPlatform() == "cpp") {
            for (meta in field.meta) {
                var name : String = meta.name;

                // Remove ':' from metadata (for comparison only)
                if(meta.name.charAt(0) == ':') {
                    name = meta.name.substr(1);
                }

                if (decorators.exists(name)) {
                    var args : DecoratorArgs = decorators[name];
                    // Add :cppInclude metadata
                    // Example:
                    // Class Name: test.decorators.TestDecorators
                    // Header File: TestDecorators
                    // Final Path: test/decorators/TestDecorators.h
                    var headerFile : String = '${args.getClassName().split('.').join("/")}.h';

                    if(headersIncluded.indexOf(headerFile) < 0) {
                        includeStatement += '#include "${headerFile}"\n';
                        headersIncluded.push(headerFile);
                    }
                }
            }
        }
    }

    public static function addFileCode(localClass : ClassType) {
        // Workaround for multi-header includes.
        if(Decorator.getCurrentPlatform() == "cpp") {
            localClass.meta.add(":cppFileCode",
                [Context.makeExpr(includeStatement, Context.currentPos())],
                Context.currentPos());
        }
    }
}
#end
