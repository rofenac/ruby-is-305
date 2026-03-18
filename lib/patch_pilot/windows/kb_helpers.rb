# frozen_string_literal: true

module PatchPilot
  module Windows
    # Shared KB number normalization helper included by UpdateQuery and UpdateExecutor.
    module KbHelpers
      private

      def normalize_kb(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?

        kb = raw.strip.split(',').first
        kb.start_with?('KB') ? kb : "KB#{kb}"
      end
    end
  end
end
