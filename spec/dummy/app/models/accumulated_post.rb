# frozen_string_literal: true

class AccumulatedPost < ActiveRecord::Base
  has_logidze accumulate_logs: true

  self.table_name = "posts"

  belongs_to :user
  has_many :comments

  class WithDefaultScope < self
    default_scope { joins(:user) }
  end
end
