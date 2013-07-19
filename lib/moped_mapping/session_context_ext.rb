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
      :drop, :create, # :convertToCapped,
      :dropIndexes, :compact, :collMod, :reIndex,

      # #diagnostic-commands
      :collStats, :validate, :serverStatus,
    ].freeze

    COLLECTION_COMMAND_NAMES = (collection_command_names + collection_command_names.map(&:to_s).map(&:freeze)).freeze

    command_args_array = [
      # [:cloneCollection, :from], # このfromはホスト名を指定するので、対象外
      [:cloneCollectionAsCapped, :toCollection],
    ].map(&:freeze).freeze

    COMMAND_ARGS_ARRAY = (
      command_args_array +
      command_args_array.map{|args| args.map(&:to_s).map(&:freeze).freeze }
    ).freeze

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
        COMMAND_ARGS_ARRAY.each do |args|
          next unless command.key?(args.first)
          args.each do |arg|
            command[arg] = MopedMapping.mapped_name(database, command[arg])
          end
          done = true
          break
        end
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
