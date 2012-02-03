module SNS
  class Facebook < SNS::Oauth20

    def self.key
      'facebook'
    end

    consumer_configs :site => 'https://graph.facebook.com',
                     :scope => 'publish_stream,offline_access',
                     :realm => self_url

    key_configs :app_id => "input_yours_here",
                :app_key => "input_yours_here",
                :app_secret => "input_yours_here"


    def fetch_info(site)
      query_fields=%w|id name gender link username location picture |
      status, body = request(:get,"/me?fields=#{query_fields.join(",")}",{})
      if (status == '200')
        json_data=JSON.parse(body)
        site[:remote_uid] = json_data['id']
        site[:remote_name] = json_data['username']
        site[:user_name] = json_data['name']
        site[:avatar_url] = json_data['picture']
        site[:location] = json_data['location']
        site[:person_url] = json_data['link']
        site[:gender] = json_data['gender']
        site[:response_body] = body
        site[:response_code] = status
        true
      else
        false
      end

    end

    def publish(pub, text, hash)

      status, body  = request(:post,"/me/feed", :message => text,
                 :picture => hash[:image_url]+"?#{rand(1000)}",
                 :link => hash[:url],
                 :name => I18n.t(:app_name),
                 :description => I18n.t(:app_short_desc))


      json = JSON.parse(body)
      pub[:response_body] = body
      pub[:response_code] = status

      if pub.response_code =='200'
        pub[:pubed] = true
        pub[:remote_id] = json['id']
        [::ErrorCode::OK, '']
      else
        handle_error(status, body, json)
      end
    end

    def sub_handle_error(status_code, body, json)
      if json['error']
        if json['type'] =='OAuthException'
          return [::ErrorCode::BIND_ERROR, json['message']]
        else
          return [::ErrorCode::SERVER_UNKNOWN, 'unknown']
        end
      else
        [::ErrorCode::SERVER_UNKNOWN, "unknown"]
      end
    end
  end
end