# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "redjs"

Gem::Specification.new do |s|
  s.name = %q{redjs}
  s.version = RedJS::VERSION
  
  s.authors = ["Charles Lowell"]
  s.summary = %q{JavaScript compatibility specs for Ruby.}
  s.description = %q{An interface compatibility suite for Ruby embeddings of Javascript.}
  s.email = %q{cowboyd@thefrontside.net}
  
  s.homepage = %q{http://github.com/cowboyd/redjs}
  s.require_paths = ["lib"]
  
  s.extra_rdoc_files = ["README.md"]
  
  s.files = `git ls-files`.split("\n")

  s.add_development_dependency "rspec", ">= 2.7"
end