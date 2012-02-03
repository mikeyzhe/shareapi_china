module SNS
  class Twitter < SNS::Oauth10

    def self.key
      'twitter'
    end

    DEV_KEY={:key => 'input_yours_here', :secret =>'input_yours_here', :dev => true}
    PRODUCT_KEY={:key => 'input_yours_here', :secret =>'input_yours_here', :dev =>false}


    if ENV['SNS_PROXY']
      CALLBACK_URL = "input_yours_here"
      key_configs DEV_KEY
    else
      CALLBACK_URL = "input_yours_here"
      key_configs PRODUCT_KEY
    end

    consumer_configs :proxy => ENV['SNS_PROXY'],
                     :site => 'https://api.twitter.com',
                     :callback => CALLBACK_URL,
                     :realm => self_url

    def gen_request_token(hash={})
      @request_token = consumer.get_request_token(:oauth_callback => CALLBACK_URL)
      @request_token
    end

    def hide_authorize_url(store_key, &block)
      if @request_token.nil?
        @request_token = gen_request_token
      end
      url = @request_token.authorize_url(:oauth_callback => CALLBACK_URL)
      store_key = url.scan(/oauth_token=([0-9a-z]+)/i).flatten.first
      ["bind_#{self.class.key}_#{store_key}", url]
    end

    def authorize(params)
      token = @request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
      #self.access_token = ::OAuth::AccessToken.new(consumer, token.token, token.secret)
      self.access_token = token
      [token.token, token.secret]
    end

    def fetch_info(site)
      status, body =request(:get, "/account/verify_credentials.json", {})

      if (status =='200')
        json_data=JSON.parse(body)
        site[:remote_uid] = json_data['id_str']
        site[:remote_name] = json_data['screen_name']
        site[:user_name] = json_data['name']
        site[:avatar_url] = json_data['profile_image_url']
        site[:location] = json_data['location']
        site[:description] = json_data['description']
        site[:response_body] = body
        site[:response_code] = status
      else
        false
      end
    end


    def publish(pub, text, hash)
      options ={:status => text}
      status, body = request(:post, "/statuses/update.json", options)
      json = JSON.parse(body)
      pub[:http_body] = body
      pub[:http_code] = status

      if status == '200'
        pub[:pubed] = true
        pub[:remote_id]= json['id_str']
        [::ErrorCode::OK, '']
      else
        handle_error(status, body, json)
      end

    end

  end
end