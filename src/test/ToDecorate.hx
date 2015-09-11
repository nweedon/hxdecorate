package test;

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