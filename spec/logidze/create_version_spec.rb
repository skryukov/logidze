# frozen_string_literal: true

require "acceptance_helper"

describe "create logidze version", :db do
  include_context "cleanup migrations"

  before(:all) do
    Dir.chdir("#{File.dirname(__FILE__)}/../dummy") do
      successfully "rake db:migrate"
    end
  end

  let(:user) { User.create! }
  let(:now) { Time.local(1989, 7, 10, 18, 23, 33) }

  describe "#create_logidze_version!" do
    let(:user) do
      User.create!(time: now, name: "test", age: 10, active: false, extra: {gender: "X"})
    end

    context "when log_data is null" do
      specify "without arguments" do
        expect(user.log_data).to be_nil

        user.create_logidze_version!

        expect(user.log_data).not_to be_nil
        expect(user.log_data.version).to eq 1
        expect(Time.at(user.log_data.current_version.time / 1000) - now).to be > 1.year
        expect(user.log_data.current_version.changes)
          .to include({
            "name" => "test",
            "age" => 10,
            "active" => false,
            "extra" => '{"gender": "X"}'
          })
      end
    end

    context "when log_data is populated" do
      before(:each) do
        user.create_logidze_snapshot!
        user.update!(time: now, name: "test", age: 10, active: false, extra: {gender: "X"})
      end

      specify "without arguments" do
        expect(user.log_data.version).to eq(1)

        user.create_logidze_version!

        expect(user.log_data.version).to eq 2
        expect(Time.at(user.log_data.current_version.time / 1000) - now).to be > 1.year
        expect(user.log_data.current_version.changes)
          .to include({
            "name" => "test",
            "age" => 10,
            "active" => false,
            "extra" => '{"gender": "X"}'
          })
      end

      specify "timestamp column" do
        expect(user.log_data.version).to eq(1)

        user.create_logidze_version!(timestamp: :time)

        expect(user.log_data.version).to eq 2
        expect(user.log_data.current_version.time).to eq(now.to_i * 1_000)
      end

      specify "columns filtering: only" do
        expect(user.log_data.version).to eq(1)

        user.create_logidze_version!(only: %w[name age])

        expect(user.log_data.version).to eq 2
        expect(user.log_data.current_version.changes).to eq({"name" => "test", "age" => 10})
      end

      specify "columns filtering: except" do
        expect(user.log_data.version).to eq(1)

        user.create_logidze_version!(except: %w[age])

        expect(user.log_data.version).to eq 2
        expect(user.log_data.current_version.changes.keys).to include("name", "active")
        expect(user.log_data.current_version.changes.keys).not_to include("age")
      end

      specify "limit of versions" do
        expect(user.log_data.version).to eq(1)

        user.create_logidze_version!(limit: 1)

        expect(user.log_data.version).to eq 2
        expect(user.log_size).to eq 1
      end

      specify "debounce_time" do
        expect(user.log_data.version).to eq(1)

        user.create_logidze_version!(debounce_time: 42000000)

        expect(user.log_data.version).to eq 1
        expect(user.log_size).to eq 1
        expect(user.log_data.current_version.changes)
          .to include({
            "name" => "test",
            "age" => 10,
            "active" => false,
            "extra" => '{"gender": "X"}'
          })
      end
    end
  end

  describe ".create_logidze_version" do
    before(:each) do
      user.create_logidze_snapshot!
      user.update!(time: now, name: "test", age: 10, active: false, extra: {gender: "X"})
    end

    specify do
      expect(user.log_data.version).to eq 1

      User.where(id: user.id).create_logidze_version(timestamp: :time, only: %w[name age])

      user.reload

      expect(user.log_data.version).to eq 2
      expect(user.log_data.current_version.time).to eq(now.to_i * 1_000)
      expect(user.log_data.current_version.changes).to eq({"name" => "test", "age" => 10})
    end
  end
end
