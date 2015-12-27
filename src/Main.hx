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
package;

import haxe.unit.TestRunner;
import hxdecorate.Decorator;
import test.ConversionTestSuite;
import test.DecorateBeforeTestSuite;
import test.NonExistentMetadataTestSuite;

@:build(hxdecorate.Decorator.build({
    'DecoratorOne' : 'test.decorators.TestDecorators#decoratorOne',
    'DecoratorTwo' : 'test.decorators.TestDecorators#decoratorTwo',
    'BDecoratorOne' : 'test.decorators.TestDecoratorsBuildMetadata#decoratorOne',
    'BDecoratorTwo' : 'test.decorators.TestDecoratorsBuildMetadata#decoratorTwo'
}, [
    "test.classes.ToDecorate",
    "test.classes.ToDecorateBuildMetadata",
    "test.classes.ToDecorateWithBeforeMetadata",
    "test.classes.ToDecorateWithoutBeforeMetadata",
    "test.classes.NonExistentMetadata"
]))
class Main {

    static function main() {
        var runner : TestRunner = new TestRunner();
        runner.add(new ConversionTestSuite());
        runner.add(new DecorateBeforeTestSuite());
        runner.add(new NonExistentMetadataTestSuite());

        runner.run();
    }

}
