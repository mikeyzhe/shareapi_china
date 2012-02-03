require 'oauth2'
module SNS
  class Oauth20 < SNS::Base

    attr_accessor :access_token
    attr_accessor :request_client
    attr_accessor :callback_url

    def parse_store_key(params)
      params[:back_key]
    end

    def to_site(site)
      site[:access_token_key] = access_token.token
    end

    def from_site(site)
      self.access_token = ::OAuth2::AccessToken.new(request_client, site[:access_token_key], site[:refresh_token], site[:expires_in], {})
    end

    def request_client
      @request_client ||= gen_request_client
    end

    def gen_request_client
      ::OAuth2::Client.new(
          key_configs[:app_key],
          key_configs[:app_secret],
          :site => consumer_configs[:site],
          :raise_errors => false,
          :parse_json => false
      )
    end

    def access_token=(val)
      @access_token = val
    end

    def dump
      data={:callback_url =>callback_url}
      if access_token
        data.merge!(:access_token => access_token.token,
                    :refresh_token => access_token.refresh_token,
                    :expires_in => access_token.expires_in,
                    :expires_at => access_token.expires_at,
                    :other_params => access_token.params)
      end
      data
    end

    def load(data)
      if data[:callback_url]
        self.callback_url = data[:callback_url]
      end
      if data[:access_token]
        self.access_token = ::OAuth2::AccessToken.new(request_client, data[:access_token], data[:refresh_token], data[:expires_in], data[:other_params])
      end
    end

    def http_handler
      lambda do |method, path, params|
        resp = access_token.request(method, path, params).response
        [resp.status.to_s, resp.body]
      end
    end


    def authorize_url(store_key, &block)

      if ENV['SNS_PROXY']
        self.callback_url = block.call(:back_key => store_key, :host => "work.catleft.com")
      else
        self.callback_url = block.call(:back_key => store_key)
      end
      url = request_client.web_server.authorize_url(:display => "touch", :redirect_uri => callback_url, :scope => consumer_configs[:scope])
      [store_key, url]
    end

    def authorize(params)
      token=request_client.web_server.get_access_token(params[:code], :redirect_uri => callback_url)
      self.access_token = token
      [token.token, nil]
    end

  end
end