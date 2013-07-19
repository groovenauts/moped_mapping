# -*- coding: utf-8 -*-
require 'moped_mapping'

module MopedMapping
  module IndexesExt
    def self.included(klass)
      klass.module_eval do
        alias_method :namespace_without_mapping, :namespace
        alias_method :namespace, :namespace_with_mapping
      end
    end

    def namespace_with_mapping
      return @namespace unless MopedMapping.enabled
      col_name = MopedMapping.mapped_name(database.name, collection_name)
      "#{database.name}.#{col_name}"
    end
  end
end
