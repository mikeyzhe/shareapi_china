#hack for facebook proxy because oauth2.0 use faraday as http lib
if ENV['SNS_PROXY']
  module Faraday
    class Adapter
      class NetHttp < Faraday::Adapter
        alias_method :__old_net_http_class, :net_http_class

        def net_http_class(env)
          if ENV['SNS_PROXY']
            Net::HTTP::Proxy("202.152.183.120", 65333, nil, nil)
          else
            __old_net_http_class(env)
          end
        end
      end
    end
  end
end