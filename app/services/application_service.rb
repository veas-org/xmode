class ApplicationService
  Result = Data.define(:success?, :error, :payload) do
    def method_missing(name, *args)
      return payload[name] if payload.is_a?(Hash) && payload.key?(name)

      super
    end

    def respond_to_missing?(name, include_private = false)
      payload.is_a?(Hash) && payload.key?(name) || super
    end
  end

  def self.success(payload = {})
    Result.new(true, nil, payload)
  end

  def self.failure(error, payload = {})
    Result.new(false, error, payload)
  end
end
