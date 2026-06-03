module Catalog
  class Versions
    def self.latest(records)
      records.max_by { |record| sort_key(record.version, record.id) }
    end

    def self.sort_key(version, id = nil)
      [ Gem::Version.new(version.to_s.split("+", 2).first.presence || "0.0.0"), id.to_i ]
    rescue ArgumentError
      [ Gem::Version.new("0.0.0"), id.to_i ]
    end
  end
end
