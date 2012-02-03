module SNS
  module Upload

    #NOTICE：
    #各个微博字段名可能不统一
    def upload(url, options, field_info)
      @pic_field =field_info[:pic_field]
      url = URI.parse(url)
      http = Net::HTTP.new(url.host, url.port)

      req = Net::HTTP::Post.new(url.request_uri)
      req = sign_without_pic_field(req, self.access_token, options)
      req = set_multipart_field(req, options)
      #req["Content-Length"] = req.body.bytesize
      http.request(req)
    end

    #图片不参与签名
    def sign_without_pic_field(req, access_token, options)
      req.set_form_data(params_without_pic_field(options))
      self.consumer.sign!(req, access_token)
      req
    end

    #mutipart编码：http://www.ietf.org/rfc/rfc1867.txt
    def set_multipart_field(req, params)
      multipart_post = Multipart::MultipartPost.new
      multipart_post.set_form_data(req, params)
    end

    def params_without_pic_field(options)
      options.except(@pic_field)
    end

  end

  module Multipart

    class Param
      attr_accessor :k, :v

      def initialize(k, v)
        @k = k
        @v = v
      end

      def to_multipart
        #return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"\r\n\r\n#{v}\r\n"
        # Don't escape mine...
        return "Content-Disposition: form-data; name=\"#{k}\"\r\n\r\n#{v}\r\n"
      end
    end

    class FileParam
      attr_accessor :k, :filename, :content

      def initialize(k, filename, content)
        @k = k
        @filename = filename
        @content = content
      end

      def to_multipart
        #return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"; filename=\"#{filename}\"\r\n" + "Content-Transfer-Encoding: binary\r\n" + "Content-Type: #{MIME::Types.type_for(@filename)}\r\n\r\n" + content + "\r\n "
        # Don't escape mine
        debug_str="Content-Disposition: form-data; name=\"#{k}\"; filename=\"#{File.basename(@filename)}\"\r\n" + "Content-Transfer-Encoding: binary\r\n" + "Content-Type: #{MIME::Types.type_for(@filename)}\r\n\r\n" + content + "\r\n"
        #puts debug_str
        debug_str
      end
    end
    class MultipartPost

      BOUNDARY = 'tarsiers-rule0000'
      #BOUNDARY = '---------------------------7d33a816d302b6'
      ContentType = "multipart/form-data; boundary=" + BOUNDARY

      def set_form_data(req, params)
        body, content_type = prepare_query(params)
        req["Content-Type"] = content_type
        req.body = body
        req["Content-Length"] = body.bytesize
        req
      end

      def prepare_query(params)
        fp = []
        params.each { |k, v|
          if v.respond_to?(:read)
            fp.push(FileParam.new(k, v.path, v.read))
            v.close
          else
            fp.push(Param.new(k, v))
          end
        }
        body = fp.collect { |p| "--" + BOUNDARY + "\r\n" + p.to_multipart }.join("") + "--" + BOUNDARY + "--rn"
        return body, ContentType
      end

    end
  end
end