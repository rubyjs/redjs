# -*- encoding: utf-8 -*-

shared_examples_for "RedJS::Context", :shared => true do

  describe "Basic Evaluation", :compat => '0.1.0' do

    before do
      @cxt = RedJS::Context.new
    end

    it "can evaluate some javascript" do
      @cxt.eval("5 + 3").should == 8
    end

    it "can pass back null to ruby" do
      @cxt.eval("null").should be_nil
    end

    it "can pass back undefined to ruby" do
      @cxt.eval("this.undefined").should be_nil
    end

    it "can pass the empty string back to ruby" do
      @cxt.eval("''").should == ""
    end

    it "can pass doubles back to ruby" do
      @cxt.eval("2.5").should == 2.5
    end

    it "can pass fixed numbers back to ruby" do
      @cxt.eval("1").should == 1
    end

    it "can pass boolean values back to ruby" do
      @cxt.eval("true").should be(true)
      @cxt.eval("false").should be(false)
    end

    it "treats nil and the empty string as the same thing when it comes to eval" do
      @cxt.eval(nil).should == @cxt.eval('')
    end

    it "can pass back strings to ruby" do
      @cxt['foo'] = "Hello World"
      @cxt.eval("foo").should == "Hello World"
    end

    it "can pass back very long strings to ruby" do
      lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis faucibus, diam vel pellentesque aliquet, nisl sapien molestie eros, vitae vehicula libero massa vel neque. Phasellus tempor pharetra ipsum vel venenatis. Quisque vitae nisl vitae quam mattis pellentesque et in sapien. Sed at lectus quis eros pharetra feugiat non ac neque. Vivamus lacus eros, feugiat at volutpat at, viverra id nisl. Vivamus ac dolor eleifend libero venenatis pharetra ut iaculis arcu. Donec neque nibh, vehicula non porta a, consectetur eu erat. Sed eleifend, metus vel euismod placerat, lectus lectus sollicitudin nisl, ac elementum sem quam nec dolor. In hac habitasse platea dictumst. Proin vitae suscipit orci. Suspendisse a ipsum vel lorem tempus scelerisque et vitae neque. Proin sodales, tellus sit amet consequat cursus, odio massa ultricies enim, eu fermentum velit lectus in lacus. Quisque eu porttitor diam. Nunc felis purus, facilisis non tristique ac, pulvinar nec nulla. Duis dolor risus, egestas nec tristique ac, ullamcorper cras amet."
      @cxt.eval("'#{lorem}'").should == lorem
    end

    it "correctly handles translating strings that have non-standard characters" do
      @cxt['utf8'] = "Σὲ γνωρίζω ἀπὸ τὴν κόψη"
      @cxt['utf8'].should == "Σὲ γνωρίζω ἀπὸ τὴν κόψη"
      @cxt.eval('var nativeUtf8 = "Σὲ γνωρίζω ἀπὸ τὴν κόψη"')
      @cxt['nativeUtf8'].should == "Σὲ γνωρίζω ἀπὸ τὴν κόψη"
    end

    it "translates JavaScript dates properly into ruby Time objects" do
      now = Time.now
      @cxt.eval('new Date()').tap do |time|
        time.should be_kind_of(Time)
        time.year.should == now.year
        time.day.should == now.day
        time.month.should == now.month
        time.min.should == now.min
        time.sec.should == now.sec
      end
    end

    it "can pass objects back to ruby" do
      @cxt.eval("({foo: 'bar', baz: 'bang', '5': 5, embedded: {badda: 'bing'}})").tap do |object|
        object.should_not be_nil
        object['foo'].should == 'bar'
        object['baz'].should == 'bang'
        object['5'].should == 5
        object['embedded'].tap do |embedded|
          embedded.should_not be_nil
          embedded['badda'].should == 'bing'
        end
      end
    end

    it "can pass int properties to ruby", :compat => '0.2.1'  do
      @cxt.eval("({ 4: '4', 5: 5, '6': true })").tap do |object|
        object[ 4 ].should == '4'
        object['4'].should == '4'
        object[ 5 ].should == 5
        object['5'].should == 5
        object['6'].should == true
      end
    end

    it "unwraps ruby objects returned by embedded ruby code to maintain referential integrity" do
      Object.new.tap do |o|
        @cxt['get'] = lambda {o}
        @cxt.eval('get()').should be(o)
      end
    end

    it "always returns the same ruby object for a single javascript object" do
      obj = @cxt.eval('obj = {}')
      obj.should be(@cxt['obj'])
      @cxt.eval('obj').should be(@cxt['obj'])
      @cxt['obj'].should be(@cxt['obj'])
    end

    it "converts arrays to javascript" do
      @cxt['a'] = [1,2,4]
      @cxt.eval('var sum = 0;for (var i = 0; i < a.length; i++) {sum += a[i]}; sum').should == 7
      @cxt.eval('[1,2,3]').tap do |a|
        a.length.should == 3
        a.to_a.should == [1,2,3]
      end
    end

    it "can iterate over arrays" do
      @cxt['a'] = @cxt.eval('[{num: 1},{num:2},{num:3},{num: 4}]')
      a = @cxt['a']
      a.inject(0) do |sum, item|
        sum + item['num']
      end.should == 10

    end

    it "converts ruby hashes to javascript objects" do
      @cxt['h'] = {:foo => 'bar', :baz => 'bang', :bar => {'hello' => 'world'}}
      @cxt['h']['foo'].should == 'bar'
      @cxt['h']['baz'].should == 'bang'
      @cxt['h']['bar']['hello'].should == 'world'
    end
  end

  describe "Calling Ruby Code From Within Javascript", :compat => '0.1.0' do

    before(:each) do
      @class = Class.new
      @instance = @class.new
      @cxt = RedJS::Context.new
      @cxt['o'] = @instance
    end

    it "can embed a closure into a context and call it" do
      @cxt["say"] = lambda { |*args| args[-2] * args[-1] }
      @cxt.eval("say('Hello', 2)").should == "HelloHello"
    end

    it "recognizes the same closure embedded into the same context as the same function object" do
      @cxt['say'] = @cxt['declare'] = lambda { |*args| args }
      @cxt.eval('say == declare').should be(true)
      @cxt.eval('say === declare').should be(true)
    end

    it "translates ruby Array to Javascript Array" do
      class_eval do
        def ruby_array
          []
        end
      end
      evaljs('o.ruby_array instanceof Array').should == true
    end

    it "translates ruby Time to Javascript Date" do
      now = Time.now
      class_eval do
        def ruby_time
          @now
        end
      end
      @instance.instance_variable_set(:@now, now)
      evaljs('o.ruby_time instanceof Date').should == true
      evaljs('o.ruby_time.getFullYear()').should == now.year
      evaljs('o.ruby_time.getMonth() + 1').should == now.month
      evaljs('o.ruby_time.getDate()').should == now.day
      evaljs('o.ruby_time.getMinutes()').should == now.min
      evaljs('o.ruby_time.getSeconds()').should == now.sec
    end

    it "translates ruby true to Javascript true" do
      class_eval do
        def bool
          true
        end
      end
      evaljs('o.bool === true').should == true
    end

    it "translates ruby false to Javascript false" do
      class_eval do
        def bool
          false
        end
      end
      evaljs('o.bool === false').should == true
    end

    it "can embed a ruby object into a context and call its methods" do
      class_eval do
        def say_hello(to)
          "Hello #{to}!"
        end
      end
      evaljs('o.say_hello("Gracie")').should == "Hello Gracie!"
    end

    it "recognizes object method as the same function" do
      @class.class_eval do
        def foo(*args); args; end
      end
      @cxt['obj'] = @class.new
      @cxt.eval('obj.foo === obj.foo').should be(true)
    end

    it "recognizes functions on objects of the same class being equal", :compat => '0.2.0' do
      @class.class_eval do
        def foo(*args); args; end
        self
      end
      @cxt['one'] = @class.new
      @cxt['two'] = @class.new
      @cxt.eval('one.foo == two.foo').should be(true)
    end

    it "recognizes functions on objects of the same class being the same", :compat => '0.2.1' do
      @class.class_eval do
        def foo(*args); args; end
        self
      end
      @cxt['one'] = @class.new
      @cxt['two'] = @class.new
      @cxt.eval('one.foo === two.foo').should be(true)
      #TODO: nice to have, but a bit tricky.
      # @cxt.eval('one.foo === one.constructor.prototype.foo').should be(true)
    end

    it "fails without the correct context passed to an object function", :compat => '0.2.0' do
      @class.class_eval do
        def foo(*args); args; end
      end
      @cxt['obj'] = @class.new
      @cxt.eval('var foo = obj.foo;')
      lambda { @cxt.eval('foo()') }.should raise_error
    end

    it "can call a bound ruby method" do
      five = class_eval do
        def initialize(lhs)
          @lhs = lhs
        end
        def times(rhs)
          @lhs * rhs
        end
        new(5)
      end

      @cxt['timesfive'] = five.method(:times)
      @cxt.eval('timesfive(3)').should == 15
    end

    it "reports object's type being object", :compat => '0.1.1' do
      @cxt.eval('typeof( o )').should == 'object'
    end

    it "reports object method type as function", :compat => '0.1.1' do
      @class.class_eval do
        def foo(*args); args; end
      end
      @cxt.eval('typeof o.foo ').should == 'function'
    end

    it "reports wrapped class as of type function", :compat => '0.1.1' do
      @cxt['RObject'] = Object
      @cxt.eval('typeof(RObject)').should == 'function'
    end

    it "truncates lambda arguments passed in to match the arity of the function", :compat => '0.4.2' do
      @cxt['testing'] = lambda { |arg| arg }
      lambda {
        @cxt.eval('testing(1,2,3)')
      }.should_not raise_error

      @cxt['testing'] = lambda { }
      lambda {
        @cxt.eval('testing(1,2,3)')
      }.should_not raise_error
    end

    it "truncates method arguments passed in to match the arity of the function", :compat => '0.4.3' do
      @instance.instance_eval do
        def foo(arg); arg; end
        def bar(*args); args; end
      end

      lambda {
        @cxt.eval('o.foo(1,2,3)').should == 1
      }.should_not raise_error
      lambda {
        @cxt.eval('o.bar(1,2,3)').to_a.should == [ 1, 2, 3 ]
      }.should_not raise_error
    end

    it "fills in missing arguments with nils to match the arity of the function", :compat => '0.4.3' do
      @instance.instance_eval do
        def foo(a1, a2, a3); [a1, a2, a3]; end
      end
      
      lambda {
        @cxt.eval('o.foo(1)').to_a.should == [ 1, nil, nil ]
        @cxt.eval('o.foo()').to_a.should == [ nil, nil, nil ]
      }.should_not raise_error
    end

    describe "Default Ruby Object Access" do

      it "can call public locally defined ruby methods" do
        class_eval do
          def voo(str)
            "voo#{str}"
          end
        end
        evaljs("o.voo('doo')").should == "voodoo"
      end

      it "reports ruby methods that do not exist as undefined" do
        RedJS::Context.new(:with => Object.new) do |cxt|
          cxt.eval('this.foobar').should be nil
        end
      end

      it "can access methods defined in an object's superclass" do
        o = Class.new.class_eval do
          attr_accessor :foo
          def foo
            @foo ||= "FOO"
          end
          Class.new(self)
        end.new
        RedJS::Context.new(:with => o) do |cxt|
          cxt.eval('this.foo').should == 'FOO'
          cxt.eval('this.foo = "bar!"')
          cxt.eval('this.foo').should == "bar!"
        end
      end

      it "allows a ruby object to intercept property access with []" do
        Class.new.class_eval do
          def [](val)
            "FOO"
          end
          RedJS::Context.new(:with => new) do |cxt|
            cxt.eval('this.foo').should == "FOO"
            cxt.eval('this.bar').should == "FOO"
          end
        end
      end

      it "allows a ruby object to intercept property setting with []=" do
        Class.new.class_eval do
          def initialize
            @properties = {}
          end
          def [](name)
            @properties[name]
          end
          def []=(name, value)
            @properties[name] = value
          end

          RedJS::Context.new(:with => new) do |cxt|
            cxt.eval('this.foo = "bar"').should == "bar"
            cxt.eval('this.foo').should == "bar"
          end
        end
      end

      it "allows a ruby object which intercepts property access to take a pass on intercepting the property", :compat => '0.4.0' do
        klass = Class.new do
          def initialize
            @attrs = {}
          end
          def [](name)
            name =~ /foo/ ? @attrs[name] : yield
          end
          def []=(name, value)
            name =~ /foo/ ? @attrs[name] = "#{value}-diddly" : yield
          end
        end

        RedJS::Context.new do |cxt|
          cxt['foo'] = klass.new
          cxt.eval('typeof foo.bar').should == 'undefined'
          cxt.eval('foo.bar = "baz"')
          cxt.eval('foo.bar').should == 'baz'
          cxt.eval('foo.foobar').should == nil
          cxt.eval('foo.foobar = "baz"')
          cxt.eval('foo.foobar').should == "baz-diddly"
        end
      end

      it "allows a ruby object to take a pass on intercepting an indexed property", :compat => '0.4.0' do
        klass = Class.new do
          def initialize
            @arr = []
          end
          def [](i)
            i >= 5 ? @arr[i] : yield
          end
          def []=(i, value)
            i >= 5 ? @arr[i] = "#{value}-diddly" : yield
          end
        end

        RedJS::Context.new do |cxt|
          cxt['obj'] = klass.new
          cxt.eval('typeof obj[1]').should == 'undefined'
          cxt.eval('obj[1] = "foo"')
          cxt.eval('obj[1]').should == "foo"
          cxt.eval('obj[5] = "foo"').should == "foo"
          cxt.eval('obj[5]').should == "foo-diddly"
        end
      end

      it "does not make the [] and []= methods visible or enumerable by default", :compat => '0.4.1' do
        klass = Class.new do
          def [](name); name; end
          def []=(name, value); name && value; end
        end

        RedJS::Context.new do |cxt|
          cxt['o'] = klass.new
          cxt.eval('o["[]"]').should == nil
          cxt.eval('o["[]="]').should == nil
          cxt.eval('a = new Array(); for (var i in o) a.push(i);')
          cxt['a'].length.should == 0
        end
      end

      it "doesn't kill the whole process if a dynamic interceptor or setter throws an exception" do
        klass = Class.new do
          def [](name)
            raise "BOOM #{name}!"
          end
          def []=(name, value)
            raise "Bam #{name} = #{value} !"
          end
        end

        RedJS::Context.new do |cxt|
          cxt['foo'] = klass.new
          lambda {
            cxt.eval('foo.bar')
          }.should raise_error
          lambda {
            cxt.eval('foo.bar = "baz"')
          }.should raise_error
        end
      end

      it "doesn't kill the whole process if reader or accessor throws an exception" do
        klass = Class.new do
          def foo
            raise "NO GET 4 U!"
          end
          def foo=(val)
            raise "NO SET 4 U!"
          end
        end

        cxt = RedJS::Context.new(:with => klass.new)
        lambda {
          cxt.eval(this.foo)
        }.should raise_error
        lambda {
          cxt.eval("this.foo = 'bar'")
        }.should raise_error
      end

      it "allows access to methods defined on an objects included/extended modules (class)" do
        modul = Module.new do
          attr_accessor :foo
          def foo
            @foo ||= "FOO"
          end
        end
        klass = Class.new do
          include modul
        end

        RedJS::Context.new(:with => klass.new) do |cxt|
          cxt.eval('this.foo').should == "FOO"
          cxt.eval('this.foo = "bar!"')
          cxt.eval('this.foo').should == "bar!"
        end
      end

      it "allows access to methods defined on an objects included/extended modules (instance)" do
        modul = Module.new do
          attr_accessor :foo
          def foo
            @foo ||= "FOO"
          end
          self
        end

        obj = Object.new; obj.extend(modul)
        RedJS::Context.new(:with => obj) do |cxt|
          cxt.eval('this.foo').should == "FOO"
          cxt.eval('this.foo = "bar!"')
          cxt.eval('this.foo').should == "bar!"
        end
      end

      it "allows access to public singleton methods" do
        obj = Object.new
        class << obj; attr_accessor :foo; end
        def obj.foo; @foo ||= "FOO"; end

        RedJS::Context.new(:with => obj) do |cxt|
          cxt.eval("this.foo").should == "FOO"
          cxt.eval('this.foo = "bar!"')
          cxt.eval('this.foo').should == "bar!"
        end
      end

      it "does not allow access to methods defined on Object and above", :compat => '0.5.0' do
        klass = Class.new do
          def foo; "FOO"; end
        end

        RedJS::Context.new(:with => klass.new) do |cxt|
          for method in Object.public_instance_methods
            cxt.eval("this['#{method}']").should be nil
          end
        end
      end

      it "hides methods derived from Object, Kernel, etc...", :compat => '0.5.0' do
        evaljs("o.to_s").should be nil # Object
        evaljs("o.puts").should be nil # Kernel
      end

      it "does not allow to call a ruby constructor, unless that constructor has been directly embedded", :compat => '0.5.0' do
        klass = Class.new
        @cxt['obj'] = klass.new
        lambda {
          @cxt.eval('new (obj.constructor)()')
        }.should raise_js_error
      end

      describe "with an integer index" do

        it "allows accessing indexed properties via the []() method" do
          class_eval do
            def [](i)
              "foo" * i
            end
          end
          evaljs("o[3]").should == "foofoofoo"
        end

        it "allows setting indexed properties via the []=() method" do
          class_eval do
            def [](i)
              @storage ||= []
              @storage[i]
            end
            def []=(i, val)
              @storage ||= []
              @storage[i] = val
            end
          end
          evaljs("o[3] = 'three'").should == 'three'
          evaljs("o[3]").should == 'three'
        end

        it "doesn't kill the whole process if indexed interceptors throw exceptions" do
          class_eval do
            def [](idx)
              raise "No Indexed [#{idx}] For You!"
            end
            def []=(idx, value)
              raise "No Indexed [#{idx}] = #{value} For You!"
            end
          end
          lambda {
            evaljs("o[1] = 'boo'")
          }.should raise_error
          lambda {
            evaljs("o[1]")
          }.should raise_error
        end

        #TODO: I'm not sure this is warranted
        #it "will enumerate indexed properties if a length property is provided"
      end

    end

    it "will see a method that appears after the wrapper was first created" do
      @cxt['o'] = @instance
      class_eval do
        def whiz(str)
          "whiz#{str}!"
        end
      end
      @cxt.eval("o.whiz('bang')").should == "whizbang!"
    end

    it "treats ruby methods that have an arity of 0 as javascript properties by default" do
      class_eval do
        def property
          "flan!"
        end
      end
      evaljs('o.property').should == 'flan!'
    end

    it "will call ruby accesssor function when setting a property from javascript" do
      class_eval do
        def dollars
          @dollars
        end

        def dollars=(amount)
          @dollars = amount
        end
      end
      evaljs('o.dollars = 50')
      @instance.dollars.should == 50
    end

    it "will accept expando properties by default for properties on ruby object that are not implemented in ruby" do
      evaljs('o.five = 5; o.five').should == 5
    end

    it "it silently fails to replace properties which are defined on ruby objects but which are read-only" do
      class_eval do
        def bar
          "baz"
        end
      end
      evaljs('o.bar = "bing"; o.bar').should == "baz"
    end

    def evaljs(str)
      @cxt.eval(str)
    end

    def class_eval(&body)
      @class.class_eval &body
    end

  end

  describe "Calling JavaScript Code From Within Ruby", :compat => '0.1.0' do

    before(:each) do
      @cxt = RedJS::Context.new
    end

    it "allows you to capture a reference to a javascript function and call it" do
      f = @cxt.eval('(function add(lhs, rhs) {return lhs + rhs})')
      f.call(1,2).should == 3
    end

    it "can path the 'this' object into a function as context with methodcall()" do
      obj = @cxt.eval('({num: 5})')
      times = @cxt.eval('(function times(num) {return this.num * num})')
      times.methodcall(obj, 5).should == 25
    end

    it "unwraps objects that are backed by javascript objects to pass their native equivalents" do
      @cxt.eval('obj = {foo: "bar"}')
      f = @cxt.eval('(function() {return this == obj})')
      f.methodcall(@cxt['obj']).should be(true)
    end

    it "can invoke a javacript constructor and return the new object reflected into ruby" do
      wrapper = @cxt.eval('(function Wrapper(value) {this.value = value})')
      wrapper.new(5)['value'].should == 5
    end

    it "can call a javascript method directly from a ruby object" do
      obj = @cxt.eval('Object').new
      obj.should respond_to(:toString)
      obj.toString().should == '[object Object]'
    end

    it "can access properties defined on a javascript object through ruby" do
      obj = @cxt.eval('({ str: "bar", num: 5 })')
      obj.str.should == "bar"
      obj.num.should == 5
    end

    it "can set properties on the javascript object via ruby setter methods" do
      obj = @cxt.eval('({ str: "bar", num: 5 })')
      obj.str = "baz"
      obj.str.should == "baz"
      obj.double = proc {|i| i * 2}
      obj.double.call(2).should == 4
      obj.array = 1,2,3
      obj.array.to_a.should == [1,2,3]
      obj.array = [1,2,3]
      obj.array.to_a.should == [1,2,3]
    end

    it "is an error to try and pass parameters to a property" do
      obj = @cxt.eval('({num: 1})')
      lambda {
        obj.num(5)
      }.should raise_error(ArgumentError)
    end
  end

  describe "Setting up the Host Environment", :compat => '0.1.0' do

    before(:each) do
      @cxt = RedJS::Context.new
    end

    it "can eval javascript with a given ruby object as the scope." do
      scope = Class.new.class_eval do
        def plus(lhs, rhs)
          lhs + rhs
        end

        def minus(lhs, rhs)
          lhs - rhs
        end

        new
      end

      RedJS::Context.new(:with => scope) do |cxt|
        cxt.eval("plus(1,2)", "test").should == 3
        cxt.eval("minus(10, 20)", "test").should == -10
        cxt.eval("this").should be(scope)
      end
    end

    it "can directly embed ruby values into javascript" do
      @cxt["bar"] = 9
      @cxt['foo'] = "bar"
      @cxt['num'] = 3.14
      @cxt['trU'] = true
      @cxt['falls'] = false
      @cxt.eval("bar + 10").should == 19
      @cxt.eval('foo').should == "bar"
      @cxt.eval('num').should == 3.14
      @cxt.eval('trU').should be(true)
      @cxt.eval('falls').should be(false)
    end

    it "has the global object available as a javascript value" do
      @cxt['foo'] = 'bar'
      @cxt.scope.should_not be(nil)
      @cxt.scope.should respond_to :'[]'
      @cxt.scope['foo'].should == 'bar'
    end

    it "will treat class objects as constructors by default" do
      @cxt[:MyClass] = Class.new do
        attr_reader :one, :two
        def initialize(one, two)
          @one, @two = one, two
        end
      end
      @cxt.eval('new MyClass(1,2).one').should == 1
      @cxt.eval('new MyClass(1,2).two').should == 2
    end

    it "exposes class properties as javascript properties on the corresponding constructor" do
      @cxt[:MyClass] = Class.new do
        def self.foo(*args)
          args.inspect
        end
      end
      @cxt.eval('MyClass.foo').should_not be nil
      @cxt.eval('MyClass.foo()').should == "[]"
    end

    it "unwraps reflected ruby constructor objects into their underlying ruby classes" do
      @cxt['RubyObject'] = Object
      @cxt['RubyObject'].should be(Object)
    end

    it "honors the instanceof operator for ruby instances when compared to their reflected constructors" do
      @cxt['RubyObject'] = Object
      @cxt['rb_object'] = Object.new
      @cxt.eval('rb_object instanceof RubyObject').should be(true)
      @cxt.eval('new RubyObject() instanceof RubyObject').should be(true)
      @cxt.eval('new RubyObject() instanceof Array').should be(false)
      @cxt.eval('new RubyObject() instanceof Object').should be(true)
    end

    it "reports constructor function as being an instance of Function", :compat => '0.1.1' do
      @cxt['RubyObject'] = Object
      @cxt.eval('RubyObject instanceof Function').should be(true)
    end

    it "respects ruby's inheritance chain with the instanceof operator", :compat => '0.1.1' do
      @cxt['Class1'] = klass1 = Class.new(Object)
      @cxt['Class2'] = klass2 = Class.new(klass1)
      @cxt['obj1'] = klass1.new
      @cxt['obj2'] = klass2.new

      @cxt.eval('obj1 instanceof Class1').should == true
      @cxt.eval('obj1 instanceof Class2').should == false
      @cxt.eval('obj2 instanceof Class2').should == true
      @cxt.eval('obj2 instanceof Class1').should == true
    end

    it "unwraps instances created by a native constructor when passing them back to ruby" do
      @cxt['RubyClass'] = Class.new do
        def definitely_a_product_of_this_one_off_class?
          true
        end
      end
      @cxt.eval('new RubyClass()').should be_definitely_a_product_of_this_one_off_class
    end
  end

  describe "Loading javascript source into the interpreter", :compat => '0.1.0' do

    it "can take an IO object in the eval method instead of a string" do
      source = StringIO.new(<<-EOJS)
  /*
  * we want to have a fairly verbose function so that we can be assured tha
  * we overflow the buffer size so that we see that the reader is chunking
  * it's payload in at least several fragments.
  *
  * That's why we're wasting space here
  */
  function five() {
    return 5
  }
  foo = 'bar'
  five();
      EOJS
      RedJS::Context.new do |cxt|
        cxt.eval(source, "StringIO").should == 5
        cxt['foo'].should == "bar"
      end
    end

    it "can load a file into the runtime" do
      filename = Pathname(__FILE__).dirname.join("fixtures/loadme.js").to_s
      RedJS::Context.new.load(filename).should == "I am Legend"
    end
  end

  describe "A Javascript Object Reflected Into Ruby", :compat => '0.1.0' do

    before(:each) do
      @cxt = RedJS::Context.new
      @o = @cxt.eval("o = new Object(); o")
    end

    def evaljs(js)
      @cxt.eval(js)
    end

    it "can have its properties manipulated via ruby style [] hash access" do
      @o["foo"] = 'bar'
      evaljs('o.foo').should == "bar"
      evaljs('o.blue = "blam"')
      @o["blue"].should == "blam"
    end

    it "doesn't matter if you use a symbol or a string to set a value" do
      @o[:foo] = "bar"
      @o['foo'].should == "bar"
      @o['baz'] = "bang"
      @o[:baz].should == "bang"
    end

    it "returns nil when the value is null, null, or not defined" do
      @o[:foo].should be_nil
    end

    it "traverses the prototype chain when hash accessing properties from the ruby object" do
      RedJS::Context.new do |cxt|
        cxt.eval(<<EOJS)['bar'].should == "baz"
function Foo() {}
Foo.prototype.bar = 'baz'
new Foo()
EOJS
      end
    end

    it "is enumenable" do
      evaljs("o.foo = 'bar'; o.bang = 'baz'; o[5] = 'flip'")
      {}.tap do |h|
        @o.each do |k,v|
          h[k] = v
        end
        h.should == {"foo" => 'bar', "bang" => 'baz', 5 => 'flip'}
      end
    end
  end

  describe "Exception Handling", :compat => '0.1.0' do

    it "raises javascript exceptions as ruby exceptions" do
      lambda {
        RedJS::Context.new.eval('foo')
      }.should raise_js_error
    end

    it "can handle syntax errors" do
      lambda {
        RedJS::Context.eval('does not compiles')
      }.should raise_error
    end

    it "will allow exceptions to pass through multiple languages boundaries (i.e. js -> rb -> js -> rb)" do
      RedJS::Context.new do |cxt|
        cxt['one'] = lambda do
          cxt.eval('two()', 'one.js')
        end
        cxt['two'] = lambda do
          cxt.eval('three()', 'two.js')
        end
        cxt['three'] = lambda do
          cxt.eval('throw "BOOM!"', "three.js")
        end
        lambda {
          cxt['one'].call(cxt.scope)
        }.should raise_error {|e|
          #TODO: assert something about the contents of the stack?
          #--cowboyd 05/25/2010
        }
      end
    end

    it "translates ruby exceptions into javascript exceptions if they are thrown from code called it javascript", :compat => '0.3.0' do
      RedJS::Context.new do |cxt|
        cxt['boom'] = lambda { raise "BOOM!" }
        cxt.eval('( function() { try { boom() } catch (e) { return e.message } } )()').should == 'BOOM!'
      end
    end

    it "allows javascript to catch ScriptError", :compat => '0.4.4' do
      RedJS::Context.new do |cxt|
        cxt['boom'] = lambda { raise ScriptError, "BOOM!" }
        cxt.eval('( function() { try { boom() } catch (e) { return e.message } } )()').should == 'BOOM!'
      end
    end

    it "will not let JavaScript catch other errors such as a SystemExit and fatal", :compat => '0.4.4' do
      RedJS::Context.new do |cxt|
        cxt['boom'] = lambda { raise Exception, "ByE!" }
        expect {cxt.eval('( function() { try { boom() } catch (e) { return e.message } } )()')}.should raise_error Exception
      end
    end

    it "propagates javascript thrown values into the ruby side", :compat => '0.4.5' do
      RedJS::Context.new do |cxt|
        begin
          cxt.eval('throw 42')
        rescue => e
          e.should respond_to(:value)
          e.value.should == 42
        else
          fail "not raised !"
        end
        begin
          cxt.eval("throw { foo: 'bar' }")
        rescue => e
          e.should respond_to(:value)
          e.value.should respond_to(:'[]')
          e.value['foo'].should == 'bar'
        else
          fail "not raised !"
        end
      end
    end

    it "propagates a javascript thrown error from a function", :compat => '0.4.6' do
      context = RedJS::Context.new
      context.eval 'function bar() { throw new Error("bar"); }'
      begin
        context['bar'].call
      rescue Exception => e
        e.should be_a defined?(RedJS::Error) ? RedJS::Error : StandardError
      else
        fail "function bar() not raised !"
      end
    end

    it "propagates a javascript thrown error from a constructor", :compat => '0.4.6' do
      context = RedJS::Context.new
      context.eval 'Foo = function() { throw new Error("Foo"); };'
      begin
        context['Foo'].new
      rescue Exception => e
        e.should be_a defined?(RedJS::Error) ? RedJS::Error : StandardError
      else
        fail "not raised !"
      end
    end

  end

  describe "A Ruby class reflected into JavaScript", :compat => '0.6.0' do

    it "will extend instances of the class when properties are added to the corresponding JavaScript constructor's prototype" do
      klass = Class.new
      RedJS::Context.new do |cxt|
        cxt['RubyObject'] = klass
        cxt.eval('RubyObject.prototype.foo = function() {return "bar"}')
        cxt['o'] = klass.new
        cxt.eval('o.foo()').should == "bar"
      end
    end

    it "will extend instances of subclasses when properties are added to the corresponding JavaScript constructor's prototype" do
      superclass = Class.new
      subclass = Class.new(superclass)
      RedJS::Context.new do |cxt|
        cxt['SuperClass'] = superclass
        cxt['SubClass'] = subclass
        cxt['o'] = subclass.new
        cxt.eval('SuperClass.prototype.foo = function() {return "bar"}')
        cxt.eval('o.foo()').should == "bar"
      end
    end

  end

  private

  before :all do # check setup
    unless defined?(RedJS::Context)
      raise "missing RedJS::Context - please expose your context e.g. `RedJS.const_set :Context, V8::Context`"
    end
    unless defined?(RedJS::Error)
      warn "RedJS::Error not exposed, specs will only check that a generic error is raised, " +
           "if you have a JSError please set it e.g. `RedJS.const_set :Error, Rhino::JSError`"
    end
  end

  def raise_js_error
    defined?(RedJS::Error) ? raise_error(RedJS::Error) : raise_error
  end

end