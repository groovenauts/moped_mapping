# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/support/yaml_with_erb'
require 'active_support/core_ext/hash/indifferent_access'

describe MopedMapping do

  let(:config) do
    YAML.load_file(File.expand_path("../moped.config.yml", __FILE__))["test"].with_indifferent_access
  end

  before do
    MopedMapping.disable
    @session = Moped::Session.new(config[:sessions][:default][:hosts])
    @database_name = config[:sessions][:default][:database]
    @session.use(@database_name)
    @session.tap do |s|
      # コレクションの削除
      s.collection_names.each{|col| s[col].drop }
      # テスト用のデータの追加
      s["items"].tap do |c|
        c.insert(name: "foo", price: 100)
      end
      s["items@1"].tap do |c|
        200.times do |i|
          c.insert(name: "item1-#{'%04d' % [i]}", price: (100 * rand).ceil)
        end
      end
    end
  end


  describe :find_with_cursor do
    it do
      MopedMapping.enable
      col = @session["items"]
      MopedMapping.collection_map(@database_name, {"items" => "items@1" }) do
        col.find().to_a.should have(200).items
      end
    end
  end

end
