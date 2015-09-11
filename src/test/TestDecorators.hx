package test;

import test.ToDecorate;

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