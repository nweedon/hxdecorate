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

class CompilerExtension {

    /**
    * Adds "@:expose" build metadata to target className
    * @param 	className 		Target class to have metadata attached to.
    */
    inline public static function expose(className : String) {
        if (className != null && className.length > 0) {
            Compiler.addMetadata("@:expose", className);
        }
    }

    /**
    * Adds "@:build" compiler metadata to target className
    * @param	buildSyntax		Build syntax to add to the :build compiler metadata.
    * @param 	className 		Target class to have metadata attached to.
    */
    inline public static function build(buildSyntax : String, className : String) {
        if (buildSyntax != null && buildSyntax.length > 0 && className != null && className.length > 0) {
            Compiler.addMetadata('@:build(${buildSyntax})', className);
        }
    }
    
}
