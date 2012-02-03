module SNS
  class Douban < SNS::Oauth10
    def self.key
      'douban'
    end

    consumer_configs :signature_method => "HMAC-SHA1",
                     :site => "http://www.douban.com",
                     :scheme => :header,
                     :request_token_path => '/service/auth/request_token',
                     :access_token_path => '/service/auth/access_token',
                     :authorize_path => '/service/auth/authorize',
                     :realm => self_url

    key_configs :key => "input_yours_here",
                :secret => "input_yours_here"

    API_SITE='http://api.douban.com'

    def gen_request_token(hash ={})
      consumer.get_request_token(:oauth_callback => hash[:oauth_callback])
    end

    def fetch_info(site)
      status, body = request(:get, API_SITE+"/people/%40me", {:alt => 'json'})

      if (status=='200')
        json_data=JSON.parse(body)
        site[:remote_uid] = json_data['db:uid']['$t'] rescue ''
        site[:remote_name] = json_data['title']['$t'] rescue ''
        site[:user_name] = json_data['title']['$t'] rescue ''
        site[:location] = json_data['db:location']['$t'] rescue ''
        site[:avatar_url] = json_data['link'].find { |x| x['@rel']=='icon' }['@href'] rescue ''
        site[:person_url] = json_data['link'].find { |x| x['@rel']=='alternate' }['@href'] rescue ''
        site[:description] = json_data['content']['$t'].strip rescue ''
        site[:response_body] = body
        site[:response_code] = status
        true
      else
        false
      end
    end


    def publish(pub, text, hash)
      url="#{API_SITE}/miniblog/saying"
      content = <<-XML
<?xml version='1.0' encoding='UTF-8'?>
<entry xmlns:ns0="http://www.w3.org/2005/Atom" xmlns:db="http://www.douban.com/xmlns/">
<alt>json</alt>
<content>#{text}</content>
</entry>
      XML
      status, body = log_request(:post, url, content) do |method, url, content|
        resp = access_token.post(url, content, {"Content-Type" => "application/atom+xml", "alt" =>'json'})
        [resp.code, resp.body]
      end

      json = JSON.parse(body)
      pub[:http_body] = body
      pub[:http_code] = status

      if ['200', '201'].include?(status)
        pub[:pubed] = true
        pub[:remote_id] = json['id']
        [::ErrorCode::OK, '']
      else
        handle_error(status, body, json)
      end

    end

    def sub_handle_error(status_code, body, json)
      if status_code == '401'
        [::ErrorCode::BIND_ERROR, '未授权']
      elsif  status_code == '403'
        [::ErrorCode::BIND_ERROR, '被禁止访问']
      else
        super(status_code, body, json)
      end
    end
  end
end