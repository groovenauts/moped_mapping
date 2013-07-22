require "moped_mapping/version"

require 'moped'

module MopedMapping
  extend self

  attr_reader :enabled

  def enable(&block) ; set_enabled(true , &block); end
  def disable(&block); set_enabled(false, &block); end

  def set_enabled(value)
    if block_given?
      bak, @enabled = @enabled, value
      begin
        yield
      ensure
        @enabled = bak
      end
    else
      @enabled = value
    end
  end
  private :set_enabled


  def db_collection_map
    @db_collection_map ||= {}
  end

  def mapped_name(database, collection)
    return collection unless MopedMapping.enabled
    mapping = db_collection_map[database]
    return collection unless mapping
    return mapping[collection] || collection
  end

  def mapped_full_name(database, collection)
    return collection unless MopedMapping.enabled
    db, col = collection.split(/\./, 2)
    return collection unless col
    mapping = db_collection_map[db]
    return collection unless mapping
    mapped = mapping[col]
    mapped ? "#{db}.#{mapped}" : collection
  end

  def collection_map(db_name, mapping)
    if block_given?
      bak, db_collection_map[db_name] = db_collection_map[db_name], mapping
      begin
        yield
      ensure
        db_collection_map[db_name] = bak
      end
    else
      db_collection_map[db_name] = mapping
    end
  end

end


require "moped_mapping/session_context_ext"
require "moped_mapping/indexes_ext"
require "moped_mapping/node_ext"

Moped::Session::Context.send(:include, MopedMapping::SessionContextExt)
Moped::Indexes.send(:include, MopedMapping::IndexesExt)
Moped::Node.send(:include, MopedMapping::NodeExt)
