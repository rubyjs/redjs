# RedJS

https://github.com/cowboyd/redjs

Shared specs for a Ruby interface to JavaScript.


Useful for different JavaScript interpreters wanting to present a unified 
interface to Ruby.

Currently used by :

* The Ruby Rhino: http://github.com/cowboyd/therubyrhino
* The Ruby Racer: http://github.com/cowboyd/therubyracer

## Usage

You'll need [RSpec](http://rspec.info/) to use the specs RedJS provides.

add this your *spec_helper.rb* :

```ruby
require 'redjs'
module RedJS
  Context = MyJS::Context # e.g. V8::Context or Rhino::Context
end
```

add *spec/redjs_spec.rb* similar to this :

```ruby
require File.expand_path('../spec_helper', File.dirname(__FILE__))

require 'redjs/load_specs'

describe MyJS::Context do
  
  it_behaves_like 'RedJS::Context'
  
end
```

## API Requirements

### RedJS::Context

* should be instantiable using `new` without arguments or with a hash of options
* desired options passed to `Context.new` :
  * `:with` emulates JavaScript's with statement (provides a shorthand for writing 
    recurring accesses to the passed objects)
* if a block is provided should yield the context instance
* contexts provide an `eval` method for evaluating JavaScript code
* context instances implement [] for exposing Ruby instances to JavaScript

```ruby
MyJS::Context.new do |context|
  context["math"] = MyMath.new
  context.eval("math.plus(20, 22)") #=> 42
end
```

### RedJS::Error

* common error class for propagating errors that occur in JS into the Ruby side
