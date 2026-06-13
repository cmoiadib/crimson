require "spec_helper"

RSpec.describe Crimson::RetryHandler do
  describe ".retryable?" do
    it "returns true for rate limit errors" do
      error = StandardError.new("Rate limit exceeded")
      expect(described_class.retryable?(error)).to be true
    end

    it "returns true for 429 errors" do
      error = StandardError.new("429 Too Many Requests")
      expect(described_class.retryable?(error)).to be true
    end

    it "returns true for timeout errors" do
      error = StandardError.new("Request timed out")
      expect(described_class.retryable?(error)).to be true
    end

    it "returns true for connection errors" do
      error = StandardError.new("Connection refused")
      expect(described_class.retryable?(error)).to be true
    end

    it "returns true for server errors" do
      error = StandardError.new("500 Internal server error")
      expect(described_class.retryable?(error)).to be true
    end

    it "returns true for overloaded errors" do
      error = StandardError.new("API is overloaded")
      expect(described_class.retryable?(error)).to be true
    end

    it "returns false for non-retryable errors" do
      error = StandardError.new("Invalid API key")
      expect(described_class.retryable?(error)).to be false
    end

    it "returns false for generic errors" do
      error = StandardError.new("Something went wrong")
      expect(described_class.retryable?(error)).to be false
    end
  end

  describe ".compute_delay" do
    it "uses exponential backoff" do
      error = StandardError.new("timeout")
      delay = described_class.compute_delay(error, 1, 1.0, 30.0)
      expect(delay).to be >= 1.0
      expect(delay).to be <= 1.5  # base + random(0..0.5)
    end

    it "increases delay on second attempt" do
      error = StandardError.new("timeout")
      delay = described_class.compute_delay(error, 2, 1.0, 30.0)
      expect(delay).to be >= 2.0
      expect(delay).to be <= 2.5
    end

    it "caps delay at max_delay" do
      error = StandardError.new("timeout")
      delay = described_class.compute_delay(error, 10, 1.0, 5.0)
      expect(delay).to be <= 5.5
    end

    it "uses Retry-After header if present" do
      error_class = Class.new(StandardError) do
        attr_reader :response
        def initialize(msg, response: nil)
          super(msg)
          @response = response
        end
      end
      error = error_class.new("429", response: { headers: { "Retry-After" => "5" } })
      delay = described_class.compute_delay(error, 1, 1.0, 30.0)
      expect(delay).to eq(5.0)
    end
  end

  describe ".with_retry" do
    it "returns the result on success" do
      result = described_class.with_retry { "success" }
      expect(result).to eq("success")
    end

    it "retries on retryable error" do
      attempts = 0
      result = described_class.with_retry(max_retries: 3, base_delay: 0.01) do
        attempts += 1
        raise StandardError.new("timeout") if attempts < 2
        "success"
      end
      expect(result).to eq("success")
      expect(attempts).to eq(2)
    end

    it "raises after max retries" do
      attempts = 0
      expect {
        described_class.with_retry(max_retries: 2, base_delay: 0.01) do
          attempts += 1
          raise StandardError.new("timeout")
        end
      }.to raise_error(StandardError)
      expect(attempts).to eq(3)  # initial + 2 retries
    end

    it "does not retry non-retryable errors" do
      attempts = 0
      expect {
        described_class.with_retry(max_retries: 3, base_delay: 0.01) do
          attempts += 1
          raise StandardError.new("Invalid API key")
        end
      }.to raise_error(StandardError)
      expect(attempts).to eq(1)
    end
  end
end
