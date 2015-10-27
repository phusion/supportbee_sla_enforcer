require 'time'
require_relative 'utils'

class Enforcer
  include Utils

  def initialize(config, grouped_tickets)
    @config = config
    @grouped_tickets = grouped_tickets
    @http = make_http
  end

  def enforce
    analyze
    enforce_analysis_results
  end

private
  def analyze
    @warn_tickets = []
    @overdue_tickets = []
    @config['matchers'].each do |matcher|
      puts "Analyzing with matcher: #{matcher['name']}"
      analyze_with_matcher(matcher)
      puts
    end
  end

  def analyze_with_matcher(matcher)
    if user_id = matcher['conditions']['user_id']
      tickets = @grouped_tickets[:users][user_id]
    else
      group_id = matcher['conditions']['group_id']
      tickets = @grouped_tickets[:groups][group_id]
    end
    analyze_tickets(matcher, tickets || [])
  end

  def analyze_tickets(matcher, tickets)
    matched = false
    tickets.each do |ticket|
      matched = analyze_ticket(matcher, ticket) || matched
    end
    if !matched
      puts "     No matching tickets found"
    end
  end

  def analyze_ticket(matcher, ticket)
    if !ticket_matches_basic_conditions?(matcher, ticket)
      return false
    end

    if ticket_is_overdue?(matcher, ticket)
      if ticket_has_overdue_label?(matcher, ticket)
        puts "     Ticket #{ticket['id']} is overdue, but already has overdue label: #{ticket['subject']}"
      else
        puts "     Ticket #{ticket['id']} is overdue: #{ticket['subject']}"
        @overdue_tickets << [matcher, ticket]
      end
      true
    elsif ticket_deserves_warning?(matcher, ticket)
      if ticket_has_warning_label?(matcher, ticket)
        puts "     Ticket #{ticket['id']} deserves warning, but already has warning label: #{ticket['subject']}"
      else
        puts "     Ticket #{ticket['id']} deserves warning: #{ticket['subject']}"
        @warn_tickets << [matcher, ticket]
      end
      true
    else
      false
    end
  end

  def ticket_matches_basic_conditions?(matcher, ticket)
    if !ticket['unanswered']
      return false
    end

    conditions = matcher['conditions']

    if labels = conditions['has_label']
      labels.each do |label|
        if !ticket_has_label?(ticket, label)
          return false
        end
      end
    end

    if labels = conditions['has_no_label']
      labels.each do |label|
        if ticket_has_label?(ticket, label)
          return false
        end
      end
    end

    true
  end

  def ticket_is_overdue?(matcher, ticket)
    conditions = matcher['conditions']
    overdue_threshold = conditions['overdue_threshold']
    Time.parse(ticket['last_activity_at']) < overdue_threshold
  end

  def ticket_deserves_warning?(matcher, ticket)
    conditions = matcher['conditions']
    overdue_threshold = conditions['warn_threshold']
    if overdue_threshold
      Time.parse(ticket['last_activity_at']) < overdue_threshold
    end
  end

  def ticket_has_label?(ticket, label)
    ticket['labels'].each do |l|
      if l['name'] == label
        return true
      end
    end
    false
  end

  def ticket_has_overdue_label?(matcher, ticket)
    ticket_has_label?(ticket, matcher['enforce']['overdue_label'])
  end

  def ticket_has_warning_label?(matcher, ticket)
    ticket_has_label?(ticket, matcher['enforce']['warning_label'])
  end

  def enforce_analysis_results
    if @warn_tickets.empty? && @overdue_tickets.empty?
      puts 'No action required'
    else
      puts 'Modifying tickets'
      @warn_tickets.each do |matcher, ticket|
        enforce_analysis_result_on_ticket(matcher, ticket,
          'warn_label', 'warning label')
      end
      @overdue_tickets.each do |matcher, ticket|
        enforce_analysis_result_on_ticket(matcher, ticket,
          'overdue_label', 'overdue label')
      end
    end
  end

  def enforce_analysis_result_on_ticket(matcher, ticket, label_key, label_name)
    if @config['dry_run']
      puts "     Dry running, not adding #{label_name} on ticket #{ticket['id']}: " \
        "#{ticket['subject']}"
    else
      escaped_label_name = URI.escape(matcher['enforce'][label_key])
      uri = make_uri(@config, "/tickets/#{ticket['id']}/labels/#{escaped_label_name}")
      puts " --> Adding label on ticket #{ticket['id']}: #{ticket['subject']}"
      puts "     POST #{uri}"

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      response = @http.request(uri, request)
      if response.code == '201'
        puts "     Response: 201"
      else
        STDERR.puts "    Response: #{response.code}\n     Body:\n#{response.body}"
      end
    end
  end
end
