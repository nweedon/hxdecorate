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

class Platform {

    private function new() { }

    /**
    * Defines platform-related syntax, in this case, how a programming
    * language defines the current object (i.e. 'this' in JavaScript).
    * @param	currentPlatform The platform that is currently being compiled for.
    * @return
    */
    public static function identSelf() : String {
        // Configure platform-related syntax. If the platform is
        // unsupported, an exception is thrown.
        return switch(Decorator.getCurrentPlatform()) {
            case "js": "this";
            case "python": "self";
            case "cpp": "this";
            case "java": "this";
            default: throw "Platform unsupported.";
        }
    }

    /**
    * Defines the global namespace syntax for the
    * current platform.
    * @param	asName	Return the namespace variable without the namespace separator.
    * @return
    */
    public static function globalNamespace(?asName : Bool = false) : String {
        var name = switch(Decorator.getCurrentPlatform()) {
            case "js": "$hx_exports";
            case "python": "";
            case "cpp": "";
            case "java": "";
            default: throw "Platform unsupported.";
        }

        if (!asName && name != "") {
            name += namespaceSeparator();
        }

        return name;
    }

    /**
    * Defines the namespace separator used in the
    * current platform.
    * @return
    */
    public static function namespaceSeparator() : String {
        return switch(Decorator.getCurrentPlatform()) {
            case "js": ".";
            case "python": "_";
            case "cpp": "::";
            case "java": ".";
            default: throw "Platform unsupported.";
        }
    }

}
