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
package test;

#if macro
using hxdecorate.ExprExtension;

import hxdecorate.Decorator;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;

class Builder {
    macro public static function build(classesToDecorate : Expr) : Array<Field> {
        var classes : Array<String> = classesToDecorate.value();
        return Decorator.proxyBuild({
            'DecoratorOne' : 'test.decorators.TestDecorators#decoratorOne',
            'DecoratorTwo' : 'test.decorators.TestDecorators#decoratorTwo',
            'BDecoratorOne' : 'test.decorators.TestDecoratorsBuildMetadata#decoratorOne',
            'BDecoratorTwo' : 'test.decorators.TestDecoratorsBuildMetadata#decoratorTwo',
            'NotImplemented' : 'test.decorators.NotImplemented#impl'
        }, classes);
    }

}
#end
