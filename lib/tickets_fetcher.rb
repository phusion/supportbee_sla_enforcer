require 'time'
require_relative 'utils'

class TicketsFetcher
  include Utils

  def initialize(config)
    @config = config
    @http = make_http
  end

  def fetch
    thresholds = calculate_time_thresholds_by_entity
    fetch_tickets(thresholds)
  end

private
  def calculate_time_thresholds_by_entity
    result = {}
    @config['matchers'].each do |matcher|
      key = entity_key(matcher)
      threshold = matcher['conditions']['threshold']

      if result[key].nil? || threshold > result[key]
        result[key] = threshold
      end
    end
    result
  end

  def entity_key(matcher)
    conditions = matcher['conditions']
    if user_id = conditions['user_id']
      [:user, user_id]
    else
      [:group, conditions['group_id']]
    end
  end

  def fetch_tickets(thresholds)
    result = { users: {}, groups: {} }
    thresholds.each_pair do |key, threshold|
      entity_type, entity_id = key
      tickets = fetch_tickets_for(entity_type, entity_id, threshold)
      if entity_type == :user
        result[:users][entity_id] ||= []
        result[:users][entity_id].concat(tickets)
      else
        result[:groups][entity_id] ||= []
        result[:groups][entity_id].concat(tickets)
      end
    end
    result
  end

  def fetch_tickets_for(entity_type, entity_id, threshold)
    done = false
    page = 1
    result = []

    while !done
      path = "/tickets?per_page=100&page=#{page}&" \
        "assigned_#{entity_type}=#{entity_id}&" \
        "until=#{threshold.iso8601}"
      response = get_http_json(@config, @http, path)

      puts "     #{response['tickets'].size} tickets fetched"
      result.concat(response['tickets'])

      if page >= response['total_pages']
        done = true
      else
        page += 1
      end
    end

    result
  end
end
