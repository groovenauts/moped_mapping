# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/support/yaml_with_erb'
require 'active_support/core_ext/hash/indifferent_access'

describe MopedMapping do

  let(:config) do
    YAML.load_file(File.expand_path("../../moped.config.yml", __FILE__))["test"].with_indifferent_access
  end

  describe "2d" do

    before do
      MopedMapping.disable
      @session = Moped::Session.new(config[:sessions][:default][:hosts])
      @database_name = config[:sessions][:default][:database]
      @session.use(@database_name)
      @session.tap do |s|
        # コレクションの削除
        s.collection_names.each{|col| s[col].drop }
        # テスト用のデータの追加
        s["points@1"].tap do |c|
          c.insert(num: 1, loc: [ 0,  0])
          c.insert(num: 2, loc: [10, 10])
          c.insert(num: 3, loc: [20, 10])
          c.insert(num: 4, loc: [10, 30])
          c.indexes.create({loc: "2d"})
        end
        s["points@2"].tap do |c|
          c.insert(num: 1, loc: [ 0,  0])
          c.insert(num: 2, loc: [10, 10])
          c.insert(num: 3, loc: [15,  5])
          c.insert(num: 4, loc: [10, 20])
          c.indexes.create({loc: "2d"})
        end
        s["points@3"].tap do |c|
          c.insert(num: 1, loc: [ 0,  0])
          c.insert(num: 2, loc: [10, 10])
          c.insert(num: 3, loc: [ 6,  7])
          c.insert(num: 4, loc: [10,  5])
          c.indexes.create({loc: "2d"})
        end
      end
    end

    describe "geoNear" do
      it do
        MopedMapping.collection_map(@database_name,{"points" => "points@1" })
        MopedMapping.enable
        # {
        #   "ns"=>"moped_mapping_test.points@1", "near"=>"1100000010010011010011111010100010010011010011111010",
        #   "results"=>[
        #     {"dis"=>3.605551275463989 , "obj"=>{"_id"=>"51ebfa5a73b7f70994b28e99", "num"=>2, "loc"=>[10, 10] } },
        #     {"dis"=>7.280109889280518 , "obj"=>{"_id"=>"51ebfa5a73b7f70994b28e9a", "num"=>3, "loc"=>[20, 10] } },
        #     {"dis"=>15.264337522473747, "obj"=>{"_id"=>"51ebfa5a73b7f70994b28e98", "num"=>1, "loc"=>[ 0,  0] } },
        #     {"dis"=>22.20360331117452 , "obj"=>{"_id"=>"51ebfa5a73b7f70994b28e9b", "num"=>4, "loc"=>[10, 30] } }
        #   ],
        #   "stats"=>{"time"=>2, "btreelocs"=>0, "nscanned"=>4, "objectsLoaded"=>4, "avgDistance"=>12.088400499598194, "maxDistance"=>22.203616792998975},
        #   "ok"=>1.0
        # }
        target = [14, 8]
        r = @session.command("geoNear" => "points", "near" => target)
        r["ok"].should == 1
        r["results"].map{|d| d["obj"]["num"]}.should == [2,3,1,4]
        MopedMapping.collection_map(@database_name,{"points" => "points@2" }) do
          r = @session.command("geoNear" => "points", "near" => target)
          r["ok"].should == 1
          r["results"].map{|d| d["obj"]["num"]}.should == [3,2,4,1]
        end
        r = @session.command("geoNear" => "points", "near" => target)
        r["ok"].should == 1
        r["results"].map{|d| d["obj"]["num"]}.should == [2,3,1,4]
      end
    end
  end

end
