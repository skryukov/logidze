# frozen_string_literal: true

require "active_support"

module Logidze
  # Logidze can accumulate all changes without incrementing version number unless `#freeze_logidze_version!` is called.
  # One can use this feature to control version creation explicitly.
  #
  # @example
  #   class Post < ActiveRecord::Base
  #     has_logidze accumulate_logs: true
  #   end
  #
  #   post = Post.create!(title: "bar")
  #   post.reload.log_size #=> 1
  #
  #   post.update!(title: "baz")
  #   post.reload.log_size #=> 1
  #
  #   post.freeze_logidze_version!
  #
  #   post.update!(title: "foobar")
  #   post.reload.log_size #=> 2
  #
  #   post.update!(title: "foobarbaz")
  #   post.reload.log_size #=> 2
  module Accumulate
    extend ActiveSupport::Concern

    included do
      around_save :logidze_accumulate_logs
    end

    # Freezes current log version so that the next model update
    # will lead to creating a new version.
    def freeze_logidze_version!
      self.class
        .where(self.class.primary_key => id)
        .update_all("log_data = jsonb_set(log_data,'{h,-1}',log_data#>'{h,-1}' #- '{m,_acc}')")

      reload_log_data
    end

    def logidze_accumulate_logs(&block)
      Logidze.with_accumulation(transactional: false, &block)
    end
  end
end
