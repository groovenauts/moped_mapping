# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/support/yaml_with_erb'
require 'active_support/core_ext/hash/indifferent_access'

describe MopedMapping do

  let(:config) do
    YAML.load_file(File.expand_path("../moped.config.yml", __FILE__))["test"].with_indifferent_access
  end

  before do
    @session = Moped::Sessoin.new(config[:sessions][:default])
    @database = @session.database
    @database.tap do |d|
      # コレクションの削除
      d.collection_names.each{|col| d[col].drop }
      # テスト用のデータの追加
      d["items"].tap do |c|
        c.insert(name: "foo", price: 100)
      end
      d["items_1"].tap do |c|
        c.insert(name: "foo", price: 100)
        c.insert(name: "bar", price: 200)
        c.insert(name: "baz", price: 400)
      end
      d["items_2"].tap do |c|
        c.insert(name: "foo", price:  80)
        c.insert(name: "bar", price: 180)
        c.insert(name: "baz", price: 350)
        c.insert(name: "qux", price: 150)
      end
      d["items_3"].tap do |c|
        c.insert(name: "bar", price: 180)
        c.insert(name: "baz", price: 350)
        c.insert(name: "qux", price: 150)
      end
    end
  end

  describe :enable do
    it "with block" do
      MopedMapping.collection_map(@database.name,{"items" => "items_1" })
      col = @database["items"]
      col.find.sort(price: -1).one["name"].should == "foo"
      col.count.should == 1
      MopedMapping.enable do
        col.find.sort(price: -1).one["name"].should == "baz"
        col.count.should == 3
      end
      col.find.sort(price: -1).one["name"].should == "foo"
      col.count.should == 1
    end

    it "without block" do
      MopedMapping.collection_map(@database.name,{"items" => "items_1" })
      col = @database["items"]
      col.find.sort(price: -1).one["name"].should == "foo"
      col.count.should == 1
      MopedMapping.enable
      col.find.sort(price: -1).one["name"].should == "baz"
      col.count.should == 3
      MopedMapping.disable
      col.find.sort(price: -1).one["name"].should == "foo"
      col.count.should == 1
    end
  end


  describe :collection_map do
    it "actually usage" do
      MopedMapping.collection_map(@database.name,{"items" => "items_2" })
      MopedMapping.enable
      col = @database["items"]
      col.find.sort(price: -1).one["name"].should == "qux"
      col.count.should == 4
      MopedMapping.collection_map(@database.name,{"items" => "items_3" }) do
        col.find.sort(price: -1).one["name"].should == "qux"
        col.count.should == 3
      end
    end
  end

end
