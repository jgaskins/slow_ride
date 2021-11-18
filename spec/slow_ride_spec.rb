# frozen_string_literal: true

require "securerandom"

RSpec.describe SlowRide do
  describe "minimum_checks" do
    let(:tripped) { [] } # Needs to be a mutable value
    let(:feature) do
      SlowRide::Redis.new("spec-#{SecureRandom.uuid}", failure_threshold: 0.1, minimum_checks: 10, max_duration: 10) do |fails, checks|
        tripped << true
      end
    end

    it "trips when it meets the minimum checks and has passed the failure threshold" do
      9.times { feature.check {} } # 9 successful checks
      feature.check { raise "hell" } rescue nil

      expect(tripped).to eq [true]
      feature.check {}
    end

    it "does not trip if the check to meet the minimum is not a failure" do
      8.times { feature.check {} } # Runs successfully 8x

      feature.check { raise "hell" } rescue nil
      expect(tripped).to be_empty # 9th time should not trip yet because we haven't reached the minimum

      feature.check {}
      expect(tripped).to be_empty # 10th time should not trip yet because it didn't fail
    end
  end
end
