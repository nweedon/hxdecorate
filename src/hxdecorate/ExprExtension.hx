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
import haxe.macro.Expr;

@:dce
class ExprExtension {

    private static var QUOTED_FIELD_PREFIX = "@$__hx__";

    /**
    * Extract value from expression. Credit to nadako:
    * https://gist.github.com/nadako/9081608
    * @param	e
    * @return
    */
    public static function value(e : Expr) : Dynamic {
        switch (e.expr) {
            case EConst(c):
                switch (c) {
                    case CInt(s):
                        var i = Std.parseInt(s);
                        return (i != null) ? i : Std.parseFloat(s); // if the number exceeds standard int return as float
                    case CFloat(s):
                        return Std.parseFloat(s);
                    case CString(s):
                        return s;
                    case CIdent("null"):
                        return null;
                    case CIdent("true"):
                        return true;
                    case CIdent("false"):
                        return false;
                    case CIdent(s):
                        return s;
                    default:
                }

            case EBlock([]):
                return {};

            case EObjectDecl(fields):
                var object = {};
                for (field in fields)
                Reflect.setField(object, unquoteField(field.field), value(field.expr));
                return object;

            case EArrayDecl(exprs):
                return [for (e in exprs) value(e)];

            case EField(e, f):
                var pack = value(e);
                return '${pack}.${f}';

            default:
        }

        throw new Error("Invalid JSON expression", e.pos);
    }

    /**
    * Strips "@$__hx__" from all object declarations.
    * see https://github.com/HaxeFoundation/haxe/issues/2642
    * @param	name
    * @return
    */
    private static function unquoteField(name:String) : String {
        return (name.indexOf(QUOTED_FIELD_PREFIX) == 0) ? name.substr(QUOTED_FIELD_PREFIX.length) : name;
    }

}
#end
