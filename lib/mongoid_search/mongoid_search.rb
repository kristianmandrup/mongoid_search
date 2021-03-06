require "mongoid_search/stemmers"

module Mongoid::Search
  def self.included(base)    
    @classes ||= []
    @classes << base
    base.extend ClassMethods

    base.class_eval do
      cattr_accessor *Mongoid::Search.search_macros
    end
  end

  def self.classes
    @classes
  end

  def self.search_macros
    [:match, :allow_empty_search, :relevant_search, :stem_keywords, :ignore_list, :stemmer_class, :search_fields]
  end

  module ClassMethods #:nodoc:
    # Set a field or a number of fields as sources for search
    def search_in(*args)
      options = args.last.is_a?(Hash) && Mongoid::Search.search_macros.include?(args.last.keys.first) ? args.pop : {}
      self.match              = [:any, :all].include?(options[:match]) ? options[:match] : :any
      self.allow_empty_search = [true, false].include?(options[:allow_empty_search]) ? options[:allow_empty_search] : false
      self.relevant_search    = [true, false].include?(options[:relevant_search]) ? options[:relevant_search] : false
      self.stemmer_class      = options[:stemmer_class]
      self.stem_keywords      = !!stemmer_class || options[:stem_keywords]
      self.stemmer_class    ||= MongoidSearch::Stemmers.available

      if stem_keywords && stemmer_class.nil?
        raise "No stemmer found. Please, install either fast-stemmer or ruby-stemmer."
      end

      self.ignore_list        = YAML.load(File.open(options[:ignore_list]))["ignorelist"] if options[:ignore_list].present?
      self.search_fields      = (self.search_fields || []).concat args

      field :_keywords, :type => Array

      # mongoid 3.0 
      # index(name: 1, options: { name: "index_name" })

      index :_keywords => 1, :options => {:background => true}

      before_save :set_keywords 
    end

    def search(query, options={})
      if relevant_search
        search_relevant(query, options)
      else
        search_without_relevance(query, options)
      end
    end

    # Mongoid 2.0.0 introduces Criteria.seach so we need to provide
    # alternate method
    alias csearch search

    def search_without_relevance(query, options={})
      return criteria.all if query.blank? && allow_empty_search
      criteria.send("#{(options[:match]||self.match).to_s}_in", :_keywords => MongoidSearch::Util.normalize_keywords(query, keyword_stemmer(options), ignore_list).map { |q| /#{q}/ })
    end

    def keyword_stemmer(options={})
      stemmer_class.new(:language => options[:language]) if stem_keywords
    end

    def search_relevant(query, options={})
      return criteria.all if query.blank? && allow_empty_search

      keywords = MongoidSearch::Util.normalize_keywords(query, keyword_stemmer(options), ignore_list)

      map = <<-EOS
        function() {
          var entries = 0
          for(i in keywords)
            for(j in this._keywords) {
              if(this._keywords[j] == keywords[i])
                entries++
            }
          if(entries > 0)
            emit(this._id, entries)
        }
      EOS
      reduce = <<-EOS
        function(key, values) {
          return(values[0])
        }
      EOS

      #raise [self.class, self.inspect].inspect

      kw_conditions = keywords.map do |kw|
        {:_keywords => kw}
      end

      criteria = (criteria || self).any_of(*kw_conditions)

      query = criteria.selector

      options.delete(:limit)
      options.delete(:skip)
      options.merge! :scope => {:keywords => keywords}, :query => query

      # res = collection.map_reduce(map, reduce, options)
      # res.find.sort(['value', -1]) # Cursor
      collection.map_reduce(map, reduce, options)
    end

    # Goes through all documents in the class that includes Mongoid::Search
    # and indexes the keywords.
    def index_keywords!
      all.each { |d| d.index_keywords! ? MongoidSearch::Log.green(".") : MongoidSearch::Log.red("F") }
    end
  end

  # Indexes the document keywords
  def index_keywords!
    update_attribute(:_keywords, set_keywords)
  end

  def keyword_language
    super if defined?(super)
  end

  def keyword_stemmer
    self.class.stemmer_class.new(:language => keyword_language) if stem_keywords
  end

  private
  def set_keywords
    self._keywords = self.search_fields.map do |field|
      MongoidSearch::Util.keywords(self, field, keyword_stemmer, ignore_list)
    end.flatten.reject{|k| k.nil? || k.empty?}.uniq.sort
  end
end
