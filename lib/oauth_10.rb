require 'oauth'
module SNS
  class Oauth10 < SNS::Base

    DEFAULT_OPTIONS={
        :request_token_path => '/oauth/request_token',
        :access_token_path => '/oauth/access_token',
        :authorize_path => '/oauth/authorize',
        #        :oauth_version=>"1.0a"
    }

    attr_accessor :access_token
    attr_accessor :request_token

    def to_site(site)
      site[:access_token_key] = access_token.token
      site[:access_token_secret] = access_token.secret
    end

    def from_site(site)
      self.access_token = ::OAuth::AccessToken.new(consumer, site[:access_token_key], site[:access_token_secret])
    end

    def parse_store_key(params)
      "bind_#{self.class.key}_#{params[:oauth_token]}"
    end

    def load(data)
      if data[:request_token_key] && data[:request_token_secret]
        @request_token = ::OAuth::RequestToken.new(consumer, data[:request_token_key], data[:request_token_secret])
      end
      if data[:access_token_key] && data[:access_token_secret]
        self.access_token = ::OAuth::AccessToken.new(consumer, data[:access_token_key], data[:access_token_secret])
      end
    end

    def dump
      data = {:request_token_key => request_token.token, :request_token_secret => request_token.secret, }
      if access_token
        data.merge!(:access_token_key => access_token.token, :access_token_secret => access_token.secret)
      end
      data
    end

    def http_handler
      lambda do |method, path, params|
        resp = access_token.request(method,path,params)
        [resp.code, resp.body]
      end
    end

    def authorize_url(store_key, &block)
      #store_key is dropped
      callback_url = block.call({})
      if @request_token.nil?
        @request_token = gen_request_token(:oauth_callback => URI.encode(callback_url))
      end
      url = @request_token.authorize_url(:oauth_callback => URI.encode(callback_url))
      store_key = url.scan(/oauth_token=([0-9a-z]+)/i).flatten.first
      ["bind_#{self.class.key}_#{store_key}", url]
    end

    def authorize(params)
      token = @request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
      #self.access_token = ::OAuth::AccessToken.new(consumer, token.token, token.secret)
      self.access_token = token
      [token.token, token.secret]
    end

    def consumer
      @consumer ||= ::OAuth::Consumer.new(key_configs[:key], key_configs[:secret], DEFAULT_OPTIONS.merge(consumer_configs))
    end

  end
end