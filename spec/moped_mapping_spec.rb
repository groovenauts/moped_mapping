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
        c.insert(name: "foo", price:  90)
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

    it "update thread local mapping" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable

      expect(MopedMapping.db_collection_map[@database_name]["items"]).to eq "items@2"

      t = Thread.new do
        expect(MopedMapping.db_collection_map[@database_name]["items"]).to eq "items@2"
        MopedMapping.collection_map(@database_name, {"items" => "items@3"})
        expect(MopedMapping.db_collection_map[@database_name]["items"]).to eq "items@3"
        Thread.pass
      end
      t.join

      MopedMapping.update_main_collection_map(@database_name, {"items" => "items@2"})

      t = Thread.new do
        MopedMapping.update_main_collection_map(@database_name, {"items" => "items@2"})
        Thread.pass
      end
      t.join

    end

  end

  describe :update_main_collection_map do
    it "update main mapping" do
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable

      expect(MopedMapping.db_collection_map[@database_name]["items"]).to eq "items@2"

      t = Thread.new do
        expect(MopedMapping.db_collection_map[@database_name]["items"]).to eq "items@2"
        MopedMapping.update_main_collection_map(@database_name, {"items" => "items@3"})
        expect(MopedMapping.db_collection_map[@database_name]["items"]).to eq "items@3"
        Thread.pass
      end
      t.join

      MopedMapping.update_main_collection_map(@database_name, {"items" => "items@3"})

      t = Thread.new do
        MopedMapping.update_main_collection_map(@database_name, {"items" => "items@3"})
        Thread.pass
      end
      t.join

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
      %w[items items@2].each do |col_name|
        col.indexes[{"name" => 1}]["name"].should == "items_2_name"
      end

      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.indexes.create({"name" => 1}, {name: "items_3_name"})
        %w[items items@2].each do |col_name|
          col.indexes[{"name" => 1}]["name"].should == "items_3_name"
        end
      end

      %w[items items@2].each do |col_name|
        col.indexes[{"name" => 1}]["name"].should == "items_2_name"
      end
    end
  end

  describe :drop_index do
    it "actual usage" do
      %w[items items@1 items@2 items@3].each do |col_name|
        col = @session[col_name]
        col.indexes.create({name: 1}, {name: "#{col_name}_name"})
        col.indexes.create({price: 1}, {name: "#{col_name}_price"})
      end

      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.enable
      col = @session["items"]
      col.indexes.drop({"name" => 1})
      %w[items items@2].each do |col_name|
        col.indexes.to_a.map{|idx| idx["name"]}.should =~ ["_id_", "items@2_price"]
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col = @session["items"]
        col.indexes.drop({"price" => 1})
        %w[items items@3].each do |col_name|
          col.indexes.to_a.map{|idx| idx["name"]}.should =~ ["_id_", "items@3_name"]
        end
      end
    end
  end

  describe :insert do
    it do
      MopedMapping.collection_map(@database_name,{"items" => "items@2" })
      MopedMapping.disable do
        @session["items"].find.count.should == 1
        @session["items@2"].find.count.should == 4
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.enable
      col = @session["items"]
      col.find.count.should == 4
      col.insert({name: "quux", price: 500})
      col.find.count.should == 5
      @session["items"].find.count.should == 5
      MopedMapping.disable do
        @session["items"].find.count.should == 1
        @session["items@2"].find.count.should == 5
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        @session["items"].find.count.should == 3
      end
    end
  end


  describe :find_one do
    it do
      MopedMapping.disable do
        @session["items"  ].find(name: "foo").one["price"].should == 100
        @session["items@1"].find(name: "foo").one["price"].should == 90
        @session["items@2"].find(name: "foo").one["price"].should == 80
        @session["items@3"].find(name: "foo").one.should == nil
      end
      MopedMapping.enable
      col = @session["items"]
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(name: "foo").one["price"].should == 90
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(name: "foo").one["price"].should == 80
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(name: "foo").one.should == nil
      end
    end
  end

  def assert_item_prices(col, name_to_prices)
    name_to_prices.each do  |k,v|
      begin
        @session[col].find(name: k).one["price"].should == v
      rescue
        puts "[#{col}] #{k} => #{v}"
        raise
      end
    end
  end

  describe :find_with_cursor do
    it do
      MopedMapping.enable
      col = @session["items"]
      cond = { price: {"$gte" => 100, "$lte" => 350} }
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(cond).sort(price: 1).map{|r| r["name"]}.should == %w[bar]
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(cond).sort(price: 1).map{|r| r["name"]}.should == %w[qux bar baz]
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(cond).sort(price: 1).map{|r| r["name"]}.should == %w[bar baz]
      end
    end
  end


  describe :update do
    it "match just one" do
      MopedMapping.enable
      col = @session["items"]
      change = {"$inc" => {price: 30}}
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(name: "foo").update(change)
      end
      MopedMapping.disable do
        @session["items"  ].find(name: "foo").one["price"].should == 100
        @session["items@1"].find(name: "foo").one["price"].should == 120
        @session["items@2"].find(name: "foo").one["price"].should == 80
        @session["items@3"].find(name: "foo").one.should == nil
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(name: "foo").update(change)
      end
      MopedMapping.disable do
        @session["items"  ].find(name: "foo").one["price"].should == 100
        @session["items@1"].find(name: "foo").one["price"].should == 120
        @session["items@2"].find(name: "foo").one["price"].should == 110
        @session["items@3"].find(name: "foo").one.should == nil
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(name: "foo").update(change)
      end
      MopedMapping.disable do
        @session["items"  ].find(name: "foo").one["price"].should == 100
        @session["items@1"].find(name: "foo").one["price"].should == 120
        @session["items@2"].find(name: "foo").one["price"].should == 110
        @session["items@3"].find(name: "foo").one.should == nil
      end
    end

    it "match some documents and does not use update_all but update" do
      MopedMapping.disable do
        {
          "items@1" => {"foo" =>  90, "bar" => 200, "baz" => 400},
          "items@2" => {"foo" =>  80, "bar" => 180, "baz" => 350, "qux" => 150},
          "items@3" => {              "bar" => 180, "baz" => 350, "qux" => 400},
        }.each do |col, hash|
          hash.each do  |k,v|
            @session[col].find(name: k).one["price"].should == v
          end
        end
      end
      MopedMapping.enable
      col = @session["items"]
      cond = { price: {"$gte" => 100, "$lte" => 350} }
      change = {"$inc" => {price: 30}}
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(cond).update(change)
      end
      MopedMapping.disable do
        {
          "items@1" => {"foo" =>  90, "bar" => 230, "baz" => 400},
          "items@2" => {"foo" =>  80, "bar" => 180, "baz" => 350, "qux" => 150},
          "items@3" => {              "bar" => 180, "baz" => 350, "qux" => 400},
        }.each do |col, hash|
          hash.each do  |k,v|
            @session[col].find(name: k).one["price"].should == v
          end
        end
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(cond).update(change)
      end
      MopedMapping.disable do
        {
          "items@1" => {"foo" =>  90, "bar" => 230, "baz" => 400},
          "items@2" => {"foo" =>  80, "bar" => 210, "baz" => 350, "qux" => 150},
          "items@3" => {              "bar" => 180, "baz" => 350, "qux" => 400},
        }.each do |col, hash|
          hash.each do  |k,v|
            @session[col].find(name: k).one["price"].should == v
          end
        end
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(cond).update(change)
      end
      MopedMapping.disable do
        {
          "items@1" => {"foo" =>  90, "bar" => 230, "baz" => 400},
          "items@2" => {"foo" =>  80, "bar" => 210, "baz" => 350, "qux" => 150},
          "items@3" => {              "bar" => 210, "baz" => 350, "qux" => 400},
        }.each do |col, hash|
          hash.each do  |k,v|
            @session[col].find(name: k).one["price"].should == v
          end
        end
      end
    end

    it "match some documents and use update_all" do
      MopedMapping.disable do
        assert_item_prices "items@1", {"foo" =>  90, "bar" => 200, "baz" => 400}
        assert_item_prices "items@2", {"foo" =>  80, "bar" => 180, "baz" => 350, "qux" => 150}
        assert_item_prices "items@3", {              "bar" => 180, "baz" => 350, "qux" => 400}
      end
      MopedMapping.enable
      col = @session["items"]
      cond = { price: {"$gte" => 100, "$lte" => 350} }
      change = {"$inc" => {price: 30}}
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(cond).update_all(change)
      end
      MopedMapping.disable do
        assert_item_prices "items@1", {"foo" =>  90, "bar" => 230, "baz" => 400}
        assert_item_prices "items@2", {"foo" =>  80, "bar" => 180, "baz" => 350, "qux" => 150}
        assert_item_prices "items@3", {              "bar" => 180, "baz" => 350, "qux" => 400}
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(cond).update_all(change)
      end
      MopedMapping.disable do
        assert_item_prices "items@1", {"foo" =>  90, "bar" => 230, "baz" => 400}
        assert_item_prices "items@2", {"foo" =>  80, "bar" => 210, "baz" => 380, "qux" => 180}
        assert_item_prices "items@3", {              "bar" => 180, "baz" => 350, "qux" => 400}
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(cond).update_all(change)
      end
      MopedMapping.disable do
        assert_item_prices "items@1", {"foo" =>  90, "bar" => 230, "baz" => 400}
        assert_item_prices "items@2", {"foo" =>  80, "bar" => 210, "baz" => 380, "qux" => 180}
        assert_item_prices "items@3", {              "bar" => 210, "baz" => 380, "qux" => 400}
      end
    end

    it "match just one and upsert" do
      MopedMapping.enable
      col = @session["items"]
      change = {name: "foo", price: 60}
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(name: "foo").upsert(change)
      end
      MopedMapping.disable do
        assert_item_prices "items@1", {"foo" =>  60, "bar" => 200, "baz" => 400}
        assert_item_prices "items@2", {"foo" =>  80, "bar" => 180, "baz" => 350, "qux" => 150}
        assert_item_prices "items@3", {              "bar" => 180, "baz" => 350, "qux" => 400}
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(name: "foo").upsert(change)
      end
      MopedMapping.disable do
        assert_item_prices "items@1", {"foo" =>  60, "bar" => 200, "baz" => 400}
        assert_item_prices "items@2", {"foo" =>  60, "bar" => 180, "baz" => 350, "qux" => 150}
        assert_item_prices "items@3", {              "bar" => 180, "baz" => 350, "qux" => 400}
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(name: "foo").upsert(change)
      end
      MopedMapping.disable do
        assert_item_prices "items@1", {"foo" =>  60, "bar" => 200, "baz" => 400}
        assert_item_prices "items@2", {"foo" =>  60, "bar" => 180, "baz" => 350, "qux" => 150}
        assert_item_prices "items@3", {"foo" =>  60, "bar" => 180, "baz" => 350, "qux" => 400}
      end
    end

  end


  describe :remove do
    it "match just one" do
      MopedMapping.enable
      col = @session["items"]
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(name: "foo").remove
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 4
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(name: "foo").remove
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 3
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(name: "foo").remove
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 3
        @session["items@3"].find.count.should == 3
      end
    end

    it "match some documents and does not use remove_all but remove" do
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 3
        @session["items@2"].find.count.should == 4
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.enable
      col = @session["items"]
      cond = { price: {"$gte" => 100, "$lte" => 350} }
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(cond).remove
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 4
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(cond).remove
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 3
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(cond).remove
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 3
        @session["items@3"].find.count.should == 2
      end
    end

    it "match some documents and use remove_all" do
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 3
        @session["items@2"].find.count.should == 4
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.enable
      col = @session["items"]
      cond = { price: {"$gte" => 100, "$lte" => 350} }
      MopedMapping.collection_map(@database_name,{"items" => "items@1" }) do
        col.find(cond).remove_all
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 4
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@2" }) do
        col.find(cond).remove_all
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 1
        @session["items@3"].find.count.should == 3
      end
      MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
        col.find(cond).remove_all
      end
      MopedMapping.disable do
        @session["items"  ].find.count.should == 1
        @session["items@1"].find.count.should == 2
        @session["items@2"].find.count.should == 1
        @session["items@3"].find.count.should == 1
      end
    end

  end

end
