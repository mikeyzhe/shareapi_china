module SNS
  class SinaWeibo < SNS::Oauth10
    def self.key
      'sina_weibo'
    end

    consumer_configs :site => 'http://api.t.sina.com.cn',
                     :callback => "input_yours_here",
                     :realm => self_url

    key_configs :key => "input_yours_here",
                :secret => "input_yours_here"


    def gen_request_token(hash ={})
      consumer.get_request_token(:callback => consumer_configs[:callback])
    end

    def fetch_info(site)
      status, body = request(:get, "/account/verify_credentials.json", {})

      if (status=='200')
        json_data=JSON.parse(body)
        site[:remote_uid] = json_data['id']
        site[:remote_name] = json_data['name']
        site[:user_name] = json_data['screen_name']
        site[:avatar_url] = json_data['profile_image_url']
        site[:location] = json_data['location']
        site[:description] = json_data['description']
        site[:response_body] = body
        site[:response_code] = status
        true
      else
        false
      end
    end


    def publish(pub, text, hash)
      options = {:status => text, :pic => File.open(hash[:image_path], "rb")}
      # upload need full path
      upload_full_url = consumer_configs[:site]+"/statuses/upload.json"
      status, body = log_request(:post, upload_full_url, options) do |method, path, params|
        resp = upload(path, params,{:pic_field => :pic})
        [resp.code, resp.body]
      end

      json = JSON.parse(body)
      pub[:http_body] = body
      pub[:http_code] = status

      if status == '200'
        pub[:pubed] = true
        pub[:remote_id] = json['id']
        [::ErrorCode::OK, '']
      else
        handle_error(status, body, json)
      end

    end

    def sub_handle_error(status_code, body, json)
      code, desc=json['error'].split(":", 2)
      my_code=::ErrorCode::CODE_MAP[self.class.key][code] || ::ErrorCode::SNS_SITE_ERROR
      [my_code, desc]
    end

  end
end