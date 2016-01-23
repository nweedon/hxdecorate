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
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Type.ClassType;

class DecoratorArgs {

    private var className : String;
    private var functionName : String;
    private var decoratorCall : String;
    private var alreadyCheckedDecorator : Bool;

    /**
    * DecoratorArg constructor. Verifies call syntax and
    * splits syntax into their respective fields.
    * @param	call String in the form of 'fullyQualifiedClasspath#functionName'
    */
    public function new(call : String) {
        if (call != null && call.length > 0) {
            var callComponents = call.split("#");

            if (callComponents.length != 2) {
                throw 'Decorator call "${decoratorCall}" must be in the form "fullyQualifiedClasspath#functionName".';
            }

            this.decoratorCall = call;
            this.className = callComponents[0];
            this.functionName = callComponents[1];
            this.alreadyCheckedDecorator = false;
        }
    }

    inline public function getClassName() : String {
        return className;
    }

    inline public function getFunctionName() : String {
        return functionName;
    }

    /**
    * Generates decorator function call syntax dependent
    * on the current compilation platform (i.e. JavaScript, Python etc.)
    * @return
    */
    public function getPlatformCall() : String {
        var modifiedCall = "";

        switch(Decorator.getCurrentPlatform()) {
            case "js":
                modifiedCall = decoratorCall.split("#").join(".");

            case "python":
                // Transform decorator call, Haxe namespaces class names as such:
                // pack0_packN_className
                modifiedCall = decoratorCall.split(".").join("_").split("#").join(".");

            case "cpp":
                var namespaces = className.split(".");
                var obj = namespaces.pop();
                // Example:
                // 'libraryTest.TestDecorators#decoratorOne' will become:
                // ::test::decorators::TestDecorators_obj::decoratorOne(...)
                modifiedCall = '::${namespaces.join("::")}::${obj}_obj::${functionName}';

            case "java":
                modifiedCall = decoratorCall.split("#").join(".");

            default:
                throw 'Platform unsupported.';
        }

        modifiedCall = Platform.globalNamespace() + modifiedCall;
        return modifiedCall;
    }

    /**
    * Checks whether following decorator information is valid:
    * Class name exists, function name exists, function is static.
    *
    * Throws a compiler fatal error if any of the checks fail.
    */
    public function checkDecoratorValidity() {
        if(!alreadyCheckedDecorator) {
            var underlyingType : Type = Context.getType(this.className);

            if (underlyingType != null) {
                var classType = switch(underlyingType) {
                    case TInst(r, _) : r.get();
                    default: null;
                };

                // Check the referenced function is static.
                if (!isStatic(classType, this.functionName)) {
                    Context.fatalError('Function "${this.functionName}" in class "${this.className}" either does not exist or is not marked as static.', Context.currentPos());
                }
            } else {
                Context.fatalError('Class "${this.className}" does not exist.', Context.currentPos());
            }

            alreadyCheckedDecorator = true;
        }
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
}
#end
