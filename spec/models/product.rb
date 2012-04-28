class Product
  include Mongoid::Document
  include Mongoid::Search
  field :brand
  field :name
  field :attrs, :type => Array

  has_many :tags
  belongs_to   :category

  embeds_many     :subproducts

  search_in :brand, :name, :outlet, :attrs, :tags => :name, :category => :name, :subproducts => [:brand, :name]
end
