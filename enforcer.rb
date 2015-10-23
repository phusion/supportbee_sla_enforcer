#!/usr/bin/env ruby
require_relative 'lib/config_file_loader'
require_relative 'lib/tickets_fetcher'
require_relative 'lib/enforcer'

class EnforcerApp
  ROOT = File.absolute_path(File.dirname(__FILE__))

  def initialize(argv)
    @argv = argv.dup
  end

  def start
    load_config
    fetch_relevant_tickets
    enforce
  end

private
  def config_file_path
    @argv[0] || "#{ROOT}/config.yml"
  end

  def load_config
    begin
      @config = ConfigFileLoader.new(config_file_path).load
    rescue ConfigFileLoader::KeyError => e
      abort(e.message)
    end
  end

  def fetch_relevant_tickets
    puts "Fetching relevant tickets"
    @grouped_tickets = TicketsFetcher.new(@config).fetch
    puts
  end

  def enforce
    Enforcer.new(@config, @grouped_tickets).enforce
  end
end

EnforcerApp.new(ARGV).start
