module Integrations
  class RepositorySync
    class UnsupportedProvider < StandardError; end

    def self.call(integration_account)
      case integration_account.provider
      when "github"
        GithubRepositorySync.call(integration_account)
      when "gitlab"
        GitlabRepositorySync.call(integration_account)
      else
        raise UnsupportedProvider, "#{integration_account.provider} does not support repository sync"
      end
    end
  end
end
