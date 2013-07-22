# -*- coding: utf-8 -*-
require 'spec_helper'

require 'tengine/support/yaml_with_erb'
require 'active_support/core_ext/hash/indifferent_access'

describe MopedMapping do

  let(:config) do
    YAML.load_file(File.expand_path("../../moped.config.yml", __FILE__))["test"].with_indifferent_access
  end

  describe "thread safe" do
    before do
      MopedMapping.disable
      @session = Moped::Session.new(config[:sessions][:default][:hosts])
      @database_name = config[:sessions][:default][:database]
      @session.use(@database_name)
      @session.tap do |s|
        # コレクションの削除
        s.collection_names.each{|col| s[col].drop }
        # テスト用のデータの追加
        s["test_logs@1"].tap do |c|
          c.insert(num: 1)
          c.insert(num: 2)
          c.insert(num: 3)
          c.insert(num: 4)
        end
        s["test_logs@2"].tap do |c|
          c.insert(num: 1)
        end
      end
    end

    it "query@1 and insert@2 parallel" do
      MopedMapping.enable
      database_name = config[:sessions][:default][:database]
      run_insert = true
      query_thread = Thread.new do
        MopedMapping.collection_map(@database_name,{"test_logs" => "test_logs@1" }) do
          session1 = Moped::Session.new(config[:sessions][:default][:hosts])
          session1.use(database_name)
          1000.times do
            Thread.pass
            begin
              col = session1["test_logs"]
              r = col.find.count
              r.should == 4
            rescue
              run_insert = false
              raise
            end
          end
        end
      end

      insert_thread = Thread.new do
        MopedMapping.collection_map(@database_name,{"test_logs" => "test_logs@2" }) do
          session2 = Moped::Session.new(config[:sessions][:default][:hosts])
          session2.use(database_name)
          1000.times do |idx|
            Thread.pass
            break unless run_insert
            col = session2["test_logs"]
            col.insert(num: idx + 2)
          end
        end
      end
      query_thread.join
      insert_thread.join
    end


    it "query@1 and insert@2 parallel with default collection_map defined in main thread" do
      MopedMapping.collection_map(@database_name,{"test_logs" => "test_logs@1" })
      MopedMapping.enable
      database_name = config[:sessions][:default][:database]
      run_insert = true
      query_thread = Thread.new do
        session1 = Moped::Session.new(config[:sessions][:default][:hosts])
        session1.use(database_name)
        1000.times do
          Thread.pass
          begin
            col = session1["test_logs"]
            r = col.find.count
            r.should == 4
          rescue
            run_insert = false
            raise
          end
        end
      end

      insert_thread = Thread.new do
        MopedMapping.collection_map(@database_name,{"test_logs" => "test_logs@2" }) do
          session2 = Moped::Session.new(config[:sessions][:default][:hosts])
          session2.use(database_name)
          1000.times do |idx|
            Thread.pass
            break unless run_insert
            col = session2["test_logs"]
            col.insert(num: idx + 2)
          end
        end
      end
      query_thread.join
      insert_thread.join
    end
  end

end
