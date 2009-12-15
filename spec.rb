

describe "Basic Evaluation" do
  it "can evaluate some javascript" do
    Context.open do |cxt|
      cxt.eval("5 + 3").should == 8
    end
  end
  
  it "treats nil and the empty string as the same thing when it comes to eval" do
    Context.open do |cxt|
      cxt.eval(nil).should == cxt.eval('')
    end
  end
  
  it "can embed primitive ruby object into javascript" do
    Context.open do |cxt|
      cxt['foo'] = "Hello World"
      cxt.eval("foo").should == "Hello World"
    end
  end


  it "won't let you do some operations unless the context is open" do
    Context.new.tap do |closed|
      lambda {closed.eval('1')}.should raise_error(ContextError)    
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
  
  it "can embed a ruby object into a context and call its methods" do
    class_eval do
      def say_hello(to)
        "Hello #{to}!"
      end
    end
    evaljs('o.say_hello("Gracie")').should == "Hello Gracie!"
  end
  
  it "can call public locally defined ruby methods" do
    class_eval do
      def voo
        "doo"
      end
    end
    evaljs("o.voo").should_not be_nil
    evaljs("o.voo()").should == "doo"
  end
  
  it "translates ruby naming conventions into javascript naming conventions, but you can still access them by their original names" do
    class_eval do
      def my_special_method
        "hello"
      end
    end
    evaljs("o.mySpecialMethod").should_not be_nil
    evaljs("o.mySpecialMethod()").should == "hello"
    evaljs("o.my_special_method").should_not be_nil
    evaljs("o.my_special_method()").should == "hello"
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
    pending "why the hell isn't the return value of getIds() being respected?!?"
    evaljs(<<-EOJS).should == ["fooBar,bazBang"]
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
        def bar
          "baz!"
        end
      end
      cxt.eval("o.bar").should_not be_nil
      cxt.eval("o.bar()").should == "baz!"
    end
  end
  
  
  
  it "treats ruby methods that have an arity of 0 as javascript properties by default"
  
  it "will call ruby accesssor function when setting a property from javascript"  
  
  
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
    lambda {
      Context.open do |cxt|
        cxt.instruction_limit = 100 * 1000
        timeout(1) do
          cxt.eval('while (true);')
        end
      end
    }.should raise_error(Rhino::RunawayScriptError)
  end
    
  it "has a private constructor" do
    lambda {
      Context.new(nil)
    }.should raise_error
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
    evaljs("o.foo = 'bar'; o.bang = 'baz'; o[5] = 'flip'")
    @o.inject({}) {|i,p| k,v = p; i.tap {i[k] = v}}.should == {"foo" => 'bar', "bang" => 'baz', 5 => 'flip'}    
  end
  
end
