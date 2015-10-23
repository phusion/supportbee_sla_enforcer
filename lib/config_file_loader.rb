require 'yaml'
require 'business_time'
require 'active_support/all'

class ConfigFileLoader
  class KeyError < StandardError
  end

  class KeyTypeMismatch < KeyError
  end

  class KeyNotFound < KeyError
  end

  def initialize(path)
    @path = path
  end

  def load
    config = YAML.load_file(@path)

    require_key(config, 'auth_token', String)
    require_key(config, 'company', String)
    require_key(config, 'matchers', nil, Array)

    validate_and_fix_up_matchers(config)

    config
  end

private
  def require_key(hash, key, key_path = nil, type = nil)
    key_path ||= key
    if hash.key?(key)
      if type && !hash[key].is_a?(type)
        raise KeyTypeMismatch, "Configuration option #{key_path} " \
          "is a #{hash[key].class}, but it should be a #{type}"
      end
    else
      raise KeyNotFound, "Configuration option required: #{key_path}"
    end
  end

  def validate_and_fix_up_matchers(config)
    config['matchers'].each_with_index do |matcher, i|
      validate_matcher(matcher, i)
      fix_up_matcher(matcher)
    end
  end

  def validate_matcher(matcher, i)
  if !matcher.is_a?(Hash)
      raise KeyTypeMismatch, "All matchers in the configuration " \
        "are expected to be dictionaries, but matcher #{i} is a " \
        "#{matcher.class}"
    end

    require_key(matcher, 'name', "matchers[#{i}].name", String)
    require_key(matcher, 'conditions', "matchers[#{i}].conditions", Hash)
    require_key(matcher, 'enforce', "matchers[#{i}].enforce", Hash)

    conditions = matcher['conditions']
    if !conditions['group_id'] && !conditions['user_id']
      raise KeyNotFound, "Configuration option matchers[#{i}].conditions " \
        "must have a group_id or user_id property"
    end

    enforce = matcher['enforce']
    require_key(enforce, 'overdue_time',
      "matchers[#{i}].enforce.overdue_time")
  end

  def fix_up_matcher(matcher)
    conditions = matcher['conditions']
    enforce = matcher['enforce']

    conditions['warn_threshold'] = parse_time_description(
      enforce['warn_time'])
    conditions['overdue_threshold'] = parse_time_description(
      enforce['overdue_time'])

    if conditions['has_label'].is_a?(String)
      conditions['has_label'] = [conditions['has_label']]
    end
    if conditions['has_no_label'].is_a?(String)
      conditions['has_no_label'] = [conditions['has_no_label']]
    end

    enforce['warn_label'] ||= 'respond now'
    enforce['overdue_label'] ||= 'overdue'
  end

  def parse_time_description(desc)
    desc = desc.to_s
    if desc =~ /^(\d+) business days?$/
      $1.to_i.business_days.ago
    elsif desc =~ /^(\d+) days?$/
      $1.to_i.days.ago
    else
      raise KeyError, "Cannot parse time description: #{desc.inspect}"
    end
  end
end
