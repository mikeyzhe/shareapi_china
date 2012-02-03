require 'mime/types'
module SNS

  class Base

    include Upload

    def self.inner_config
      @@config
    end

    def self.config_hash
      @@config ||= Hash.new() { |h, k| h[k]={} }
      @@config[self.name]
    end


    def self.consumer_configs(val)
      config_hash[:consumer_configs] ||= {}
      config_hash[:consumer_configs].merge!(val)
    end

    def self.key_configs(val)
      config_hash[:key_configs] =val
    end

    def self.self_url
      "http://catleft.com"
    end


    def consumer_configs
      self.class.config_hash[:consumer_configs]
    end

    def site
      consumer_configs[:site]
    end

    def key_configs
      self.class.config_hash[:key_configs]
    end

    def authorize(params)

    end

    def options
      {}
    end

    def handle_error(status_code, body, json)
      Stat.gateway.warn("publish raw_error %s[%s] "%[status_code, body])
      if ['403', '401'].include?(status_code)
        [::ErrorCode::BIND_ERROR, "no permission"]
      else
        sub_handle_error(status_code, body, json)
      end
    end

    def sub_handle_error(status_code, body, json)
      [::ErrorCode::SERVER_UNKNOWN, "unknown"]
    end

    def http_handler
      raise 'no handler on base'
    end

    def log_request(method, path, params, &block)
      key = self.class.key
      Stat.sns.info("request %s %s [%s] [%s]"%[key, method, path, params.inspect])
      time_set=Time.now.to_f*1000
      begin
        status_code, body = block.call(method, path, params)
        time_cost = (Time.now.to_f*1000 - time_set)
        Stat.sns.info("response succ cost[%.2f] %s %s [%s] [%s] => %s[%s]"%[time_cost, key, method, path, params.inspect, status_code, body])
        [status_code, body]
      rescue Exception => exception
        time_cost = (Time.now.to_f*1000 - time_set)
        Stat.sns.error("response failed cost[%.2f] %s %s [%s] [%s] => %s "%[time_cost, key, method, path, params.inspect, exception.to_log])
        raise exception
      end
    end

    def request(method, path, params)
      log_request(method, path, params) do |a, b, c|
        http_handler.call(a, b, c.stringify_keys)
      end
    end

  end
end