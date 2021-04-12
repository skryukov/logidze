# frozen_string_literal: true

require "acceptance_helper"

describe "version accumulation", :db do
  include_context "cleanup migrations"

  before(:all) do
    Dir.chdir("#{File.dirname(__FILE__)}/../dummy") do
      successfully "rails generate logidze:model post"
      successfully "rake db:migrate"

      # Close active connections to handle db variables
      ActiveRecord::Base.connection_pool.disconnect!
    end
  end

  let(:user) do
    AccumulatedPost.create!(title: "Accumulate me", rating: 10)
  end

  it "merges versions by default" do
    user.update!(rating: 100)

    expect(user.reload.log_version).to eq 1
    expect(user.log_size).to eq 1
    expect(user.log_data.versions.last.changes).to include("title" => "Accumulate me", "rating" => 100)
  end

  it "freezes versions on demand" do
    user.freeze_logidze_version!

    user.update!(rating: 100)

    expect(user.reload.log_version).to eq 2
    expect(user.log_size).to eq 2
    expect(user.log_data.versions.last.changes).to_not include("title" => "Accumulate me")
    expect(user.log_data.versions.last.changes).to include("rating" => 100)
  end
end
