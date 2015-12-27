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

import haxe.unit.TestCase;
import test.classes.ToDecorateWithBeforeMetadata;
import test.classes.ToDecorateWithoutBeforeMetadata;
import test.decorators.TestDecorators;

class DecorateBeforeTestSuite extends TestCase {

    public function testBuildEffect() {
        var with : ToDecorateWithBeforeMetadata = new ToDecorateWithBeforeMetadata();
        var without : ToDecorateWithoutBeforeMetadata = new ToDecorateWithoutBeforeMetadata();
        // As the @:decorateBefore metadata is attached to
        // the ToDecorateWithMetadata class, the annotations
        // array should be cleared.
        assertEquals(0, with.annotations.length);
        // Without the @:decorateBefore metadata, the 'annotations'
        // array will:
        // 1. Be set with one entry (ToDecorate.hx), then
        // 2. Then cleared (ToDecorateWithoutBeforeMetadata.hx:26)
        // 3. Updated by the decorator (TestDecorators.hx)
        assertEquals(1, without.annotations.length);
    }

}
