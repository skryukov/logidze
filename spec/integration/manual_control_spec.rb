# frozen_string_literal: true

require "spec_helper"
require "acceptance_helper"

describe "manual control", :db do
  include_context "cleanup migrations"

  before(:all) do
    Dir.chdir("#{File.dirname(__FILE__)}/../dummy") do
      successfully "rails generate logidze:model user --only-trigger --manual-control"
      successfully "rake db:migrate"

      # Close active connections to handle db variables
      ActiveRecord::Base.connection_pool.disconnect!
    end
  end

  let(:user) { User.create! }

  describe "#update!" do
    it "does not updates log_data" do
      expect(user.reload.log_data).to be_nil

      user.update!(time: Time.current)

      expect(user.reload.log_data).to be_nil
    end
  end

  describe "#append_logidze_version!" do
    it "updates log_data every time" do
      expect(user.reload.log_data).to be_nil

      user.append_logidze_version!

      expect(user.reload.log_size).to eq(1)

      user.append_logidze_version!

      expect(user.reload.log_size).to eq(2)

      user.append_logidze_version!

      expect(user.reload.log_size).to eq(3)
    end
  end
end
