#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'uri'
require 'time'
require 'business_time'
require 'active_support/all'
require 'net/http/persistent'

class Enforcer
  ROOT = File.absolute_path(File.dirname(__FILE__))

  def initialize(argv)
    @argv = argv.dup
    @config = YAML.load_file(config_file_path)
    @http = make_http
  end

  def start
    @config['groups'].each do |group|
      puts "Processing group: #{group['id']} (#{group['name']})"
      process_group(group)
      puts
    end
  end

private
  def config_file_path
    @argv[0] || "#{ROOT}/config.yml"
  end

  def make_http
    http = Net::HTTP::Persistent.new
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http
  end

  def make_uri(path)
    url = "https://#{@config['company']}.supportbee.com#{path}"
    if path.include?("?")
      url << "&auth_token=#{@config['auth_token']}"
    else
      url << "?auth_token=#{@config['auth_token']}"
    end
    URI.parse(url)
  end

  def get_http_json(path)
    uri = make_uri(path)
    puts " --> GET #{uri}"
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    response = @http.request(uri, request)
    if response.code == '200'
      puts "     Response: 200"
      JSON.parse(response.body)
    else
      STDERR.puts "    Response: #{response.code}\n     Body:\n#{response.body}"
    end
  end

  def process_group(group)
    group_id = group['id']
    threshold = calculate_response_time_threshold!(group)
    done = false
    page = 1
    queue = []

    while !done
      response = get_http_json("/tickets?per_page=100&page=#{page}&assigned_group=#{group_id}&until=#{threshold.iso8601}")

      if response['tickets'].empty?
        puts "     No tickets"
      else
        puts " --> Analyzing #{response['tickets'].size} ticket(s)"
        response['tickets'].each do |ticket|
          analyze_ticket(group, ticket, queue, threshold)
        end
      end

      if page >= response["total_pages"]
        done = true
      else
        page += 1
      end
    end

    queue.each do |ticket|
      process_ticket(group, ticket)
    end
  end

  def analyze_ticket(group, ticket, queue, threshold)
    if Time.parse(ticket['last_activity_at']) < threshold
      if has_overdue_label?(group, ticket)
        puts "     Ticket #{ticket['id']} violates SLA, but already has overdue label: #{ticket['subject']}"
      else
        puts "     Ticket #{ticket['id']} violates SLA: #{ticket['subject']}"
        queue << ticket
      end
    end
  end

  def process_ticket(group, ticket)
    if @config['dry_run']
      puts "     Dry running, not putting overdue label on ticket #{ticket['id']}: #{ticket['subject']}"
    else
      escaped_label_name = URI.escape(group['overdue_label_name'])
      uri = make_uri("/tickets/#{ticket['id']}/labels/#{escaped_label_name}")
      puts " --> Adding overdue label on ticket #{ticket['id']}: #{ticket['subject']}"
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

  def has_overdue_label?(group, ticket)
    ticket['labels'].each do |label|
      if label['name'] == group['overdue_label_name']
        return true
      end
    end
    false
  end

  def calculate_response_time_threshold!(group)
    if value = group['response_time_in_business_days']
      value.to_i.business_days.ago
    else
      abort "    Group #{group['id']} does not define a response time"
    end
  end
end

Enforcer.new(ARGV).start
