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

class JavaCodeGenerator {

    private static inline var DECORATOR_CALL_TAG = "%DECORATOR_CALL%";
    private static inline var ARGUMENT_TAG = "%ARGUMENT%";
    private static inline var CALLER_TAG = "%CALLER%";
    private static inline var JAVA_CODE_TEMPLATE : String
        = '${DECORATOR_CALL_TAG}(new haxe.root.Array(new java.lang.Object[]{ ${ARGUMENT_TAG} }), ${CALLER_TAG})';
    private static var metaIndex : Int = 0;
    private static var params : Array<Dynamic> = [];
    public static inline var SELF_REFERENCE_VARIABLE_NAME = "__self";

    public static function getParams() : Array<Dynamic> {
        return params;
    }

    /*
     * Manually builds a part of the Java decorator code.
     * As hxjava adds __hxinvoke2_o to all function calls,
     * the code needs to be built in a different way (as the
     * above doesn't work).
    */
    public static function generateDecorator(javaStatement : String, decoratorCall : String, metadataParams : Array<Dynamic>) : String {
        var newStatement : String = JAVA_CODE_TEMPLATE;
        var caller : String = javaStatement;

        // '__self' is defined in the final code block
        // definition. It points the the variable hxjava
        // gives 'this' in the static constructor function.
        if(caller == null || caller == "") {
            // Defined as the starting point for all new
            // decorator code generations.
            caller = SELF_REFERENCE_VARIABLE_NAME;
            metaIndex = 0;
            params = [];
        }

        newStatement = StringTools.replace(newStatement, DECORATOR_CALL_TAG, decoratorCall);
        newStatement = StringTools.replace(newStatement, CALLER_TAG, caller);

        // '__params_n' is defined in the final code block
        // deifnition. Each param variable in the Java code
        // corresponds to a parameter value in meta.params.
        if(metadataParams.length > 0) {
            for(i in 0...metadataParams.length) {
                if(i < metadataParams.length - 1) {
                    newStatement = StringTools.replace(newStatement, ARGUMENT_TAG, '__params_${metaIndex}, ${ARGUMENT_TAG}');
                } else {
                    newStatement = StringTools.replace(newStatement, ARGUMENT_TAG, '__params_${metaIndex}');
                }

                params.push(metadataParams[i]);
                metaIndex++;
            }
        } else {
            newStatement = StringTools.replace(newStatement, ARGUMENT_TAG, "null");
        }

        return newStatement;
    }

}
