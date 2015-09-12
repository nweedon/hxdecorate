# hxdecorate
Haxe library for creating decorators

### Aims
* Primarily, merge macros and metadata capabilities together to emulate decorators
* To be multiplatform
* Building from above, supporting as many Haxe exports as possible with the same config syntax

__Notes:__
* Very early development: ideas and suggestions are appreciated!
* This is currently working run-time only, but I'm really wanting to get build-time decorators working too (i.e. adding/modifying/deleting fields etc.)
* Haxelib will be available at some point
* Test infrastructure will follow shortly

### Supported Platforms
* JavaScript
* Python

__Use:__
Place on main class.

*Syntax:*
```haxe
@:build(hxdecorate.Decorator.build({
  decorator_name : path_to_static_function#functionName,
  ...
},
[
  path_to_classes_with_decorators
]))
```

*Example:*
```haxe
@:build(hxdecorate.Decorator.build({
	'DecoratorOne' : 'libraryTest.TestDecorators#decoratorOne',
	'DecoratorTwo' : 'libraryTest.TestDecorators#decoratorTwo'
}, [
	"libraryTest.ToDecorate"
]))
class Main
{
  // ...
}
```

### Example Output
The following example shows JavaScript export behaviour:

```haxe
package libraryTest;

@DecoratorOne({ one: 1 })
@DecoratorTwo({ two: 2 })
class ToDecorate
{
	public var annotations = [];
	public var parameters = [];
	
	public function new() 
	{
		
	}	
}

@:keep
@:expose
class TestDecorators
{
	private function new() 
	{
		
	}
	
	public static function decoratorOne(input : Dynamic, caller : ToDecorate) : ToDecorate
	{
		caller.annotations.push(input);
		return caller;
	}
	
	public static function decoratorTwo(input : Dynamic, caller : ToDecorate) : ToDecorate
	{
		caller.parameters.push(input);
		return caller;
	}
}
```

Outputs to:
```javascript
var libraryTest_ToDecorate = function() {
	this.parameters = [];
	this.annotations = [];
	libraryTest.TestDecorators.decoratorTwo({ two : 2},libraryTest.TestDecorators.decoratorOne({ one : 1},this));
};
```
*More info:* `src/libraryTest/ToDecorate.hx` and `src/libraryTest/TestDecorators.hx`
