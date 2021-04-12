# frozen_string_literal: true

require "active_support"

module Logidze
  module Accumulate
    extend ActiveSupport::Concern

    included do
      around_save :logidze_accumulate_logs
    end

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
