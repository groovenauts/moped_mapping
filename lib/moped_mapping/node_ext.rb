# -*- coding: utf-8 -*-
require 'moped_mapping'

module MopedMapping
  module NodeExt
    def self.included(klass)
      klass.module_eval do
        alias_method :query_without_mapping, :query
        alias_method :query, :query_with_mapping
        alias_method :get_more_without_mapping, :get_more
        alias_method :get_more, :get_more_with_mapping
      end
    end

    def query_with_mapping(database, collection, selector, options = {}, &block)
      collection = MopedMapping.mapped_name(database, collection)
      return query_without_mapping(database, collection, selector, options, &block)
    end

    def get_more_with_mapping(database, collection, selector, options = {}, &block)
      collection = MopedMapping.mapped_name(database, collection)
      return get_more_without_mapping(database, collection, selector, options, &block)
    end
  end
end
