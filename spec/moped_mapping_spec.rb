# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/support/yaml_with_erb'
require 'active_support/core_ext/hash/indifferent_access'

describe MopedMapping do

  let(:config) do
    YAML.load_file(File.expand_path("../moped.config.yml", __FILE__))["test"].with_indifferent_access
  end

  before do
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
      s["items_1"].tap do |c|
        c.insert(name: "foo", price: 100)
        c.insert(name: "bar", price: 200)
        c.insert(name: "baz", price: 400)
      end
      s["items_2"].tap do |c|
        c.insert(name: "foo", price:  80)
        c.insert(name: "bar", price: 180)
        c.insert(name: "baz", price: 350)
        c.insert(name: "qux", price: 150)
      end
      s["items_3"].tap do |c|
        c.insert(name: "bar", price: 180)
        c.insert(name: "baz", price: 350)
        c.insert(name: "qux", price: 400)
      end
    end
  end

  describe :enable do
    it "with block" do
      MopedMapping.collection_map(@database_name,{"items" => "items_1" })
      col = @session["items"]
      col.find.sort(price: -1).one["name"].should == "foo"
      col.find.count.should == 1
      MopedMapping.enable do
        col.find.sort(price: -1).one["name"].should == "baz"
        col.find.count.should == 3
      end
      col.find.sort(price: -1).one["name"].should == "foo"
      col.find.count.should == 1
    end

    it "without block" do
      MopedMapping.collection_map(@database_name,{"items" => "items_1" })
      col = @session["items"]
      col.find.sort(price: -1).one["name"].should == "foo"
      col.find.count.should == 1
      MopedMapping.enable
      col.find.sort(price: -1).one["name"].should == "baz"
      col.find.count.should == 3
      MopedMapping.disable
      col.find.sort(price: -1).one["name"].should == "foo"
      col.find.count.should == 1
    end
  end


  describe :collection_map do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items_2" })
      MopedMapping.enable
      col = @session["items"]
      col.find.sort(price: -1).one["name"].should == "baz"
      col.find.count.should == 4
      MopedMapping.collection_map(@database_name,{"items" => "items_3" }) do
        col.find.sort(price: -1).one["name"].should == "qux"
        col.find.count.should == 3
      end
    end
  end

end
