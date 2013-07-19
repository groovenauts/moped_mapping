require 'moped_mapping'

module MopedMapping
  module SessionContextExt
    def self.included(klass)
      klass.module_eval do
        %w[query command].each do |m|
          alias_method :"#{m}_without_mapping", m.to_sym
          alias_method m.to_sym, :"#{m}_with_mapping"
        end
      end
    end

    def query_with_mapping(database, collection, selector, options = {}, &block)
      collection = MopedMapping.mapped_name(database, collection)
      return query_without_mapping(database, collection, selector, options, &block)
    end

    COMMAND_NAMES = %w[drop count].map(&:to_sym).freeze

    def command_with_mapping(database, command, &block)
      COMMAND_NAMES.each do |name|
        next unless command.key?(name)
        command[name] = MopedMapping.mapped_name(database, command[name])
      end
      return command_without_mapping(database, command, &block)
    end

  end
end
