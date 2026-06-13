require "spec_helper"

RSpec.describe Crimson::CostTracker do
  subject(:tracker) { described_class.new }

  describe "#total_cost" do
    it "starts at zero" do
      expect(tracker.total_cost).to eq(0.0)
    end

    it "accumulates cost across track calls" do
      tracker.track("gpt-4o", { prompt_tokens: 1_000_000, completion_tokens: 500_000 })
      tracker.track("gpt-4o", { prompt_tokens: 500_000, completion_tokens: 250_000 })

      expect(tracker.total_cost).to be_within(0.001).of(11.25)
    end
  end

  describe "#track" do
    it "calculates cost for known model" do
      result = tracker.track("gpt-4o", { prompt_tokens: 1000, completion_tokens: 500 })
      # gpt-4o: $2.50/M input, $10.00/M output
      expected_input = (2.50 / 1_000_000.0) * 1000
      expected_output = (10.00 / 1_000_000.0) * 500
      expect(result[:total]).to be_within(0.0001).of(expected_input + expected_output)
    end

    it "returns zero for unknown model" do
      result = tracker.track("unknown-model", { prompt_tokens: 1000, completion_tokens: 500 })
      expect(result[:total]).to eq(0)
    end

    it "returns zero for nil usage" do
      result = tracker.track("gpt-4o", nil)
      expect(result[:total]).to eq(0)
    end

    it "accepts string keys in usage" do
      result = tracker.track("gpt-4o", { "prompt_tokens" => 1000, "completion_tokens" => 500 })
      expect(result[:total]).to be > 0
    end

    it "accepts symbol keys in usage" do
      result = tracker.track("gpt-4o", { prompt: 1000, completion: 500 })
      expect(result[:total]).to be > 0
    end

    it "stores breakdown" do
      tracker.track("gpt-4o", { prompt_tokens: 1000, completion_tokens: 500 })
      expect(tracker.breakdown.length).to eq(1)
      expect(tracker.breakdown.first[:input]).to be > 0
    end
  end

  describe "#reset" do
    it "resets total cost and breakdown" do
      tracker.track("gpt-4o", { prompt_tokens: 1000, completion_tokens: 500 })
      tracker.reset

      expect(tracker.total_cost).to eq(0.0)
      expect(tracker.breakdown).to be_empty
    end
  end
end
