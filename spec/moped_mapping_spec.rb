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
      s["items@1"].tap do |c|
        c.insert(name: "foo", price: 100)
        c.insert(name: "bar", price: 200)
        c.insert(name: "baz", price: 400)
      end
      s["items@2"].tap do |c|
        c.insert(name: "foo", price:  80)
        c.insert(name: "bar", price: 180)
        c.insert(name: "baz", price: 350)
        c.insert(name: "qux", price: 150)
      end
      s["items@3"].tap do |c|
        c.insert(name: "bar", price: 180)
        c.insert(name: "baz", price: 350)
        c.insert(name: "qux", price: 400)
      end
    end
  end

  describe :enable do
    it "with block" do
      MopedMapping.collection_map(@database_name,{"items" => "items@1" })
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
      MopedMapping.collection_map(@database_name,{"items" => "items@1" })
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
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable
      col = @session["items"]
      col.find.sort(price: -1).one["name"].should == "baz"
      col.find.count.should == 4
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find.sort(price: -1).one["name"].should == "qux"
        col.find.count.should == 3
      end
    end
  end

  describe :create do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items@4" })
      MopedMapping.enable
      @session.collection_names.should =~ %w[items items@1 items@2 items@3]
      @session.command("create" => "items")
      @session.collection_names.should =~ %w[items items@1 items@2 items@3 items@4]
      MopedMapping.collection_map(@database_name,{"items" => "items@5" }) do
        @session.command("create" => "items")
        @session.collection_names.should =~ %w[items items@1 items@2 items@3 items@4 items@5]
      end
    end
  end

  describe :drop do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable
      @session.collection_names.should =~ %w[items items@1 items@2 items@3]
      col = @session["items"]
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.drop
        @session.collection_names.should =~ %w[items items@1 items@2]
      end
      col.drop
      @session.collection_names.should =~ %w[items items@1]
    end
  end


  describe :renameCollection do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2", "products" => "products@2" })
      MopedMapping.enable
      @session.collection_names.should =~ %w[items items@1 items@2 items@3]
      # renameCollection では単なるコレクション名ではなく、 <ネームスペース名>.<コレクション名> を指定する必要があります
      @session.with(database: :admin).command("renameCollection" => "#{@database_name}.items", "to" => "#{@database_name}.products")
      @session.collection_names.should =~ %w[items items@1 products@2 items@3]
      MopedMapping.collection_map(@database_name,{"items" => "items@3", "products" => "products@3" }) do
        @session.with(database: :admin).command("renameCollection" => "#{@database_name}.items", "to" => "#{@database_name}.products")
        @session.collection_names.should =~ %w[items items@1 products@2 products@3]
      end
      @session.collection_names.should =~ %w[items items@1 products@2 products@3]
    end
  end

  describe :cloneCollectionAsCapped  do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2", "products" => "products@2" })
      MopedMapping.enable
      @session.collection_names.should =~ %w[items items@1 items@2 items@3]
      @session.command("cloneCollectionAsCapped" => "items", "toCollection" => "products", "size" => 1024 * 1024)
      @session.collection_names.should =~ %w[items items@1 items@2 items@3 products@2]
      MopedMapping.collection_map(@database_name,{"items" => "items@3", "products" => "products@3" }) do
        @session.command("cloneCollectionAsCapped" => "items", "toCollection" => "products", "size" => 1024 * 1024)
        @session.collection_names.should =~ %w[items items@1 items@2 items@3 products@2 products@3]
      end
      @session.collection_names.should =~ %w[items items@1 items@2 items@3 products@2 products@3]
    end
  end


  describe :distinct do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable
      col = @session["items"]
      col.find.distinct(:name).should =~ %w[foo bar baz qux]
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find.distinct(:name).should =~ %w[bar baz qux]
      end
      col.find.distinct(:name).should =~ %w[foo bar baz qux]
    end
  end

  describe :findAndModify do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable
      col = @session["items"]
      col.find(name: "bar").modify({"$set" => {price: 190}})
      col.find(name: "bar").one["price"].should == 190
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(name: "bar").modify({"$set" => {price: 200}})
        col.find(name: "bar").one["price"].should == 200
      end
      col.find(name: "bar").one["price"].should == 190
    end
  end




  describe :create_index do
    it "actual usage" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable
      col = @session["items"]
      col.indexes.create({name: 1}, {name: "items_2_name"})
      col.indexes[{"name" => 1}]["name"].should == "items_2_name"

      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.indexes.create({"name" => 1}, {name: "items_3_name"})
        col.indexes[{"name" => 1}]["name"].should == "items_3_name"
      end

      %w[items items@2].each do |col_name|
        col.indexes[{"name" => 1}]["name"].should == "items_2_name"
      end
    end
  end

end
