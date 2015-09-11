package test;

import haxe.unit.TestCase;
import test.ToDecorate;
import test.TestDecorators;

class ConversionTestSuite extends TestCase
{
	public function testConversion()
	{
		var a : ToDecorate = new ToDecorate();
		
		assertEquals(1, a.annotations.length);
		assertTrue(Reflect.hasField(a.annotations[0], "one"));
		assertEquals(1, Reflect.field(a.annotations[0], "one"));
	}
}