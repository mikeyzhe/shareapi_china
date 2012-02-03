module SNS
  class TencentWeibo < SNS::Oauth10
    def self.key
      'tencent_weibo'
    end

    #腾讯的nonce值必须32位随机字符串啊！
    def consumer_configs
      config = self.class.config_hash[:consumer_configs]
      config[:nonce] = Base64.encode64(OpenSSL::Random.random_bytes(32)).gsub(/\W/, '')[0, 32]
      config
    end

    consumer_configs :site => "http://open.t.qq.com",
                     :request_token_path => "/cgi-bin/request_token",
                     :access_token_path => "/cgi-bin/access_token",
                     :authorize_path => "/cgi-bin/authorize",
                     :http_method => :get,
                     :scheme => :query_string,
                     #:nonce => nonce,
                     :realm => self_url

    key_configs :key => "input_yours_here",
                :secret => "input_yours_here"

    def gen_request_token(hash={})
      @request_token = consumer.get_request_token(:oauth_callback => hash[:oauth_callback])
      @request_token
    end


    def fetch_info(site)
      status, body = request(:get, consumer_configs[:site]+"/api/user/info", {:format =>'json'})

      if (status=='200')
        body_data=JSON.parse(body)
        if body_data['ret'] == 0
          json_data=body_data['data']
          site[:remote_uid] = json_data['name']
          site[:remote_name] = json_data['name']
          site[:user_name] = json_data['nick']
          site[:email] = json_data['email']
          unless json_data['head'].blank?
            site[:avatar_url] = json_data['head']+"/50"
          end
          site[:location] = json_data['location']
          site[:response_body] = body
          site[:response_code] = status
          true
        else
          false
        end
      else
        false
      end
    end


    def publish(pub, text, hash)
      options = {:format => 'json', :content => text, :clientip => hash[:client_ip]}
      status, body =request(:post, "/api/t/add", options)
      json = JSON.parse(body)
      pub[:http_body] = body
      pub[:http_code] = status

      if status == '200' && json['ret'] == 0
        pub[:pubed] = true
        pub[:remote_id] = json['id']
        [::ErrorCode::OK, '']
      else
        handle_error(status, body, json)
      end
    end


    def publish_image(pub, text, hash)
      options = {:format => 'json', :content => text, :clientip => hash[:client_ip], :pic => File.open(hash[:image_path], "rb")}
      # upload need full path
      upload_full_url = consumer_configs[:site]+"/api/t/add_pic"
      status, body = log_request(:post, upload_full_url, options) do |method, path, params|
        resp = upload(path, params.stringify_keys, {:pic_field => :pic})
        [resp.code, resp.body]
      end

      json = JSON.parse(body)
      pub[:http_body] = body
      pub[:http_code] = status

      if status == '200' && json['ret'] == 0
        pub[:pubed] = true
        pub[:remote_id] = json['id']
        [::ErrorCode::OK, '']
      else
        handle_error(status, body, json)
      end

    end

    def sub_handle_error(status_code, body, json)
      if [1, 2, 4].include?(json['ret'])
        [::ErrorCode::SNS_SITE_ERROR, json['msg']]
      elsif json['ret'] == 3
        if [1, 3, 4].include?(json['errcode'])
          [::ErrorCode::BIND_ERROR, json['msg']]
        else
          [::ErrorCode::SNS_SITE_ERROR, json['msg']]
        end
      else
        super(status_code, body, json)
      end
    end

  end
end