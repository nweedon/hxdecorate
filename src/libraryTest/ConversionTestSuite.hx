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
package libraryTest;

import haxe.unit.TestCase;
import libraryTest.ToDecorate;
import libraryTest.TestDecorators;

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