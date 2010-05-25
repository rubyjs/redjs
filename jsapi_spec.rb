
require "#{File.dirname(__FILE__)}/../redjs_helper.rb"

describe "Ruby Javascript API" do

  describe "Basic Evaluation" do
    it "can evaluate some javascript" do
      Context.eval("5 + 3")
    end
  
    it "can pass back null to ruby" do
      Context.eval("null").should be_nil      
    end
  
    it "can pass back undefined to ruby" do
      Context.eval("this.undefined").should be_nil
    end
  
    it "can pass the empty string back to ruby" do
      Context.eval("''").should == ""
    end
  
    it "can pass doubles back to ruby" do
      Context.eval("2.5").should == 2.5
    end
  
    it "can pass fixed numbers back to ruby" do
      Context.eval("1").should == 1
    end
  
    it "can pass boolean values back to ruby" do
      Context.eval("true").should be(true)
      Context.eval("false").should be(false)
    end  
  
    it "treats nil and the empty string as the same thing when it comes to eval" do
      Context.eval(nil).should == Context.eval('')
    end
  
    it "can pass back strings to ruby" do
      Context.open do |cxt|
        cxt['foo'] = "Hello World"
        cxt.eval("foo").should == "Hello World"
      end
    end

    it "can pass back very long strings to ruby" do
      lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis faucibus, diam vel pellentesque aliquet, nisl sapien molestie eros, vitae vehicula libero massa vel neque. Phasellus tempor pharetra ipsum vel venenatis. Quisque vitae nisl vitae quam mattis pellentesque et in sapien. Sed at lectus quis eros pharetra feugiat non ac neque. Vivamus lacus eros, feugiat at volutpat at, viverra id nisl. Vivamus ac dolor eleifend libero venenatis pharetra ut iaculis arcu. Donec neque nibh, vehicula non porta a, consectetur eu erat. Sed eleifend, metus vel euismod placerat, lectus lectus sollicitudin nisl, ac elementum sem quam nec dolor. In hac habitasse platea dictumst. Proin vitae suscipit orci. Suspendisse a ipsum vel lorem tempus scelerisque et vitae neque. Proin sodales, tellus sit amet consequat cursus, odio massa ultricies enim, eu fermentum velit lectus in lacus. Quisque eu porttitor diam. Nunc felis purus, facilisis non tristique ac, pulvinar nec nulla. Duis dolor risus, egestas nec tristique ac, ullamcorper cras amet."
      Context.open do |cxt|
        cxt.eval("'#{lorem}'").should == lorem
      end
    end
  
    it "can pass objects back to ruby" do
      Context.open do |cxt|      
        cxt.eval("({foo: 'bar', baz: 'bang', '5': 5, embedded: {badda: 'bing'}})").tap do |object|
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
    end
  
    it "unwraps ruby objects returned by embedded ruby code to maintain referential integrity" do
      Object.new.tap do |o|
        Context.open do |cxt|
          cxt['get'] = lambda {o}
          cxt.eval('get()').should be(o)
        end
      end
    end

    it "converts arrays to javascript" do
      Context.new do |cxt|
        cxt['a'] = [1,2,4]
        cxt.eval('var sum = 0;for (var i = 0; i < a.length; i++) {sum += a[i]}; sum').should == 7
      end
    end

    it "converts ruby hashes to javascript objects" do
      Context.new do |cxt|
        cxt['h'] = {:foo => 'bar', :baz => 'bang', :bar => {'hello' => 'world'}}
        cxt['h']['foo'].should == 'bar'
        cxt['h']['baz'].should == 'bang'
        cxt['h']['bar']['hello'].should == 'world'
      end
    end
  end

  describe "Calling Ruby Code From Within Javascript" do

    before(:each) do
      @class = Class.new
      @instance = @class.new
    end

    it "can embed a closure into a context and call it" do
      Context.open do |cxt|
        cxt["say"] = lambda {|word, times| word * times}
        cxt.eval("say('Hello',2)").should == "HelloHello"
      end
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
      class_eval do
        def ruby_time
          Time.new
        end
      end
      evaljs('o.ruby_time instanceof Date').should == true
      evaljs('o.ruby_time.valueOf()').should == Time.new.to_i
      evaljs('new Date()').should be_kind_of(Time)
    end

    it "can embed a ruby object into a context and call its methods" do
      class_eval do
        def say_hello(to)
          "Hello #{to}!"
        end
      end
      evaljs('o.say_hello("Gracie")').should == "Hello Gracie!"
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
      Context.open do |cxt|
        cxt['timesfive'] = five.method(:times)
        cxt.eval('timesfive(3)').should == 15
      end          
    end
    
    it "reports ruby methods that do not exist as undefined" do
      Context.open(:with => Object.new) do |cxt|
        cxt.eval('this.foobar').should be_nil 
      end
    end
  
    it "can call public locally defined ruby methods" do
      class_eval do
        def voo(str)
          "voo#{str}"
        end
      end
      evaljs("o.voo('doo')").should == "voodoo"
    end
  
    it "translates ruby naming conventions into javascript naming conventions, but you can still access them by their original names" do
      class_eval do
        def my_special_method(to)
          "hello #{to}"
        end
      end
      evaljs("o.mySpecialMethod('Frank')").should == "hello Frank"
      evaljs("o.my_special_method('Jack')").should == "hello Jack"
    end
  
    it "hides methods not defined directly on this instance's class" do
      class_eval do
        def bar
        end
      end
      evaljs("o.to_s").should be_nil
    end
  
    it "translated camel case properties are enumerated by default, but perl case are not" do
      class_eval do
        def foo_bar
        end
      
        def baz_bang        
        end      
      end
      require 'set'
      evaljs(<<-EOJS).to_set.should == Set.new(["fooBar","bazBang"])
      var names = [];
      for (var p in o) {
        names.push(p);
      }
      names;
      EOJS
    end
  
    it "will see a method that appears after the wrapper was first created" do
      Context.open do |cxt|
        cxt['o'] = @instance
        class_eval do
          def whiz(str)
            "whiz#{str}!"
          end
        end
        cxt.eval("o.whiz('bang')").should == "whizbang!"
      end
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
      Context.open do |cxt|
        cxt['puts'] = lambda {|o| puts o.inspect}
        cxt['o'] = @instance
        cxt.eval(str)
      end
    end
  
    def class_eval(&body)
      @class.class_eval &body
    end
  
  end

  describe "Calling JavaScript Code From Within Ruby" do
    it "allows you to capture a reference to a javascript function and call it" do
      Context.open do |cxt|
        f = cxt.eval('(function add(lhs, rhs) {return lhs + rhs})')
        f.call(nil, 1,2).should == 3
      end
    end
    
    it "can be done outside an open context" do
      Context.open do |cxt|
        @f = cxt.eval('(function add(lhs, rhs) {return lhs + rhs})')
      end
      @f.call(nil, 1,1).should == 2
    end

    it "unwraps objects that are backed by javascript objects to pass their native equivalents" do |cxt|
      Context.open do |cxt|
        cxt.eval('obj = {foo: "bar"}')
        f = cxt.eval('(function() {return this == obj})')
        f.call(cxt['obj']).should be(true)
      end
    end
  end

  describe "Setting up the Host Environment" do
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

      Context.open(:with => scope) do |cxt|
        cxt.eval("plus(1,2)").should == 3
        cxt.eval("minus(10, 20)").should == -10
        cxt.eval("this").should be(scope)
      end    
    end
  
    it "can directly embed ruby values into javascript" do
      Context.open do |cxt|
        cxt["bar"] = 9
        cxt['foo'] = "bar"
        cxt['num'] = 3.14
        cxt['trU'] = true
        cxt['falls'] = false
        cxt.eval("bar + 10").should be(19)
        cxt.eval('foo').should == "bar"
        cxt.eval('num').should == 3.14
        cxt.eval('trU').should be(true)
        cxt.eval('falls').should be(false)      
      end
    end
    
    it "extends object to allow for the arbitrary execution of javascript with any object as the scope" do
      Class.new.class_eval do
      
        def initialize
          @lhs = 5
        end
      
        def timesfive(rhs)
          @lhs * rhs     
        end
      
        new.eval_js("timesfive(6)").should == 30
      end
    end
  
    it "can limit the number of instructions that are executed in the context" do
      pending "haven't figured out how to constrain resources in V8"
      lambda {
        Context.open do |cxt|
          cxt.instruction_limit = 100 * 1000
          timeout(1) do
            cxt.eval('while (true);')
          end
        end
      }.should raise_error(RunawayScriptError)
    end    
  end

  describe "loading javascript source into the interpreter" do

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
      Context.open do |cxt|
        cxt.eval(source, "StringIO").should == 5
        cxt['foo'].should == "bar"
      end
    end

    it "can load a file into the runtime" do
      mock(:JavascriptSourceFile).tap do |file|
        File.should_receive(:open).with("path/to/mysource.js").and_yield(file)
        Context.open do |cxt|
          cxt.should_receive(:evaluate).with(file, "path/to/mysource.js", 1)
          cxt.load("path/to/mysource.js")
        end
      end

    end
  end

  describe "A Javascript Object Reflected Into Ruby" do
  
    before(:each) do
      @o = Context.open do |cxt|
        @cxt = cxt      
        cxt.eval("o = new Object(); o")
      end
    end
  
    def evaljs(js)
      @cxt.open do
        @cxt.eval(js)
      end
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
      Context.open do |cxt|
        cxt.eval(<<EOJS)['bar'].should == "baz"
function Foo() {}
Foo.prototype.bar = 'baz'
new Foo()
EOJS
      end
    end

    it "is enumenable" do
      @cxt.open do
        evaljs("o.foo = 'bar'; o.bang = 'baz'; o[5] = 'flip'")
        {}.tap do |h|
          @o.each do |k,v|
            h[k] = v
          end
          h.should == {"foo" => 'bar', "bang" => 'baz', 5 => 'flip'}
        end
      end
    end  
end

  describe "Exception Handling" do
    it "raises javascript exceptions as ruby exceptions" do
      lambda {
        Context.new.eval('foo')
      }.should raise_error(JavascriptError)
    end

    it "can handle syntax errors" do
    	lambda {
    		Context.eval('does not compiles')
    	}.should raise_error
    end
    
    it "should track message state" do
      begin        
        Context.open do |cxt|
          cxt.eval("var foo = 'bar';\nsyntax error!", "foo.js")
        end
      rescue JavascriptError => e
        e.line_number.should == 2
        e.source_name.should == "foo.js"
      end
    end
  end
end