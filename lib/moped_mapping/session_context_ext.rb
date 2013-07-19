# -*- coding: utf-8 -*-
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

    # MongoDBのコマンド一覧
    # http://docs.mongodb.org/manual/reference/command/

    # MongoDBのコマンドのうち、コレクションを対象としたコマンド名
    collection_command_names = [
      # #aggregation-commands
      :count, :aggregate, :distinct, # group # mapReduce
      # #geospatial-commands
      :geoNear, :geoSearch, :geoWalk,
      # #query-and-write-operation-commands
      :findAndModify, # text
      # #replication-commands
      # #sharding-commands
      :shardCollection,
      # #instance-administration-commands
      :drop, :create, :cloneCollection, :cloneCollectionAsCapped, :convertToCapped,
      :dropIndexes, :compact, :collMod, :reIndex,

      # #instance-administration-commands but require collection_name with database_name
      # renameCollection

      # #diagnostic-commands
      :collStats, :validate, :serverStatus,
    ].freeze

    # 文字列とSymbolの両方
    COLLECTION_COMMAND_NAMES = (collection_command_names + collection_command_names.map(&:to_s).map(&:freeze)).freeze

    full_name_command_names = [
      :renameCollection, :to
    ].freeze

    FULL_NAME_COMMAND_NAMES = (full_name_command_names + full_name_command_names.map(&:to_s).map(&:freeze)).freeze

    def command_with_mapping(database, command, &block)
      done = false
      COLLECTION_COMMAND_NAMES.each do |name|
        next unless command.key?(name)
        command[name] = MopedMapping.mapped_name(database, command[name])
        done = true
        break
      end

      unless done
        FULL_NAME_COMMAND_NAMES.each do |name|
          next unless command.key?(name)
          command[name] = MopedMapping.mapped_full_name(database, command[name])
        end
      end
      return command_without_mapping(database, command, &block)
    end

  end
end
