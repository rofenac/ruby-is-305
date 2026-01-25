# frozen_string_literal: true

module PatchPilot
  # Resolves credential configurations by expanding environment variable placeholders.
  # Supports ${VAR_NAME} syntax in credential values.
  class CredentialResolver
    ENV_VAR_PATTERN = /\$\{([^}]+)\}/

    # Resolve all environment variable placeholders in a credentials hash
    #
    # @param credentials [Hash] credential configuration with potential ${VAR} placeholders
    # @return [Hash] new hash with environment variables expanded
    # @raise [Error] if a referenced environment variable is not set
    def self.resolve(credentials)
      new.resolve(credentials)
    end

    # Resolve all environment variable placeholders in a credentials hash
    #
    # @param credentials [Hash] credential configuration with potential ${VAR} placeholders
    # @return [Hash] new hash with environment variables expanded
    # @raise [Error] if a referenced environment variable is not set
    def resolve(credentials)
      deep_resolve(credentials)
    end

    private

    def deep_resolve(obj)
      case obj
      when Hash
        obj.transform_values { |v| deep_resolve(v) }
      when Array
        obj.map { |v| deep_resolve(v) }
      when String
        expand_env_vars(obj)
      else
        obj
      end
    end

    def expand_env_vars(str)
      str.gsub(ENV_VAR_PATTERN) do
        var_name = ::Regexp.last_match(1)
        value = ENV.fetch(var_name, nil)
        raise Error, "Environment variable not set: #{var_name}" if value.nil?

        value
      end
    end
  end
end
