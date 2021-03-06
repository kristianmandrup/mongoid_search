# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name = "mongoid_search2"
  s.version = "0.3.0.rc.1"
  s.authors = ["Mauricio Zaffari"]
  s.email =["mauricio@papodenerd.net"]
  s.homepage = "http://www.papodenerd.net/mongoid-search-full-text-search-for-your-mongoid-models/"
  s.summary = "Search implementation for Mongoid ORM"
  s.description = "Simple full text search implementation."

  s.required_rubygems_version = ">= 1.3.6"
  
  s.add_development_dependency("fast-stemmer", ["~> 1.0.0"])
  s.add_development_dependency("ruby-stemmer", [">= 0.8.3"])

  s.require_path = "lib"
  s.files = IO.read('Manifest.txt').split("\n")
end
