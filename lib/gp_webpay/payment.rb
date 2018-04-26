module GpWebpay
  class Payment

    DIGEST_ALLOWED_ATTRIBUTES = %w(OPERATION ORDERNUMBER MERORDERNUM MD PRCODE
                                   SRCODE RESULTTEXT USERPARAM1 ADDINFO)

    DEFAULT_VALUES = {
      deposit_flag: 1
    }

    def initialize(atributes = {})
      atributes.each do |key, value|
        instance_variable_set(:"@#{key}", value) if self.respond_to?(key)
      end
      DEFAULT_VALUES.each do |key, value|
        instance_variable_set(:"@#{key}", value) if !self.public_send(key)
      end
    end

    attr_reader :order_number, :amount_in_cents, :currency, :deposit_flag,
                :merchant_description, :description, :paymethod,
                :disable_paymethod, :paymethods, :email, :reference_number,
                :cart_info

    attr_accessor :redirect_url

    def merchant_number
      config.merchant_number
    end

    def operation
      'CREATE_ORDER'
    end

    def pay_url(options = {})
      self.redirect_url = options[:redirect_url]
      attributes_with_digest = payment_attributes_with_digest
      attributes_with_digest['LANG'] = options[:lang] if options.has_key?(:lang)
      "#{config.pay_url}?#{URI.encode_www_form(attributes_with_digest)}"
    end

    def success?(params)
      verified_response?(params) &&
        params['PRCODE'] == '0' && params['SRCODE'] == '0'
    end

    private

    def config
      GpWebpay.config
    end

    def digest
      sign = merchant_key.sign(OpenSSL::Digest::SHA1.new, digest_text)
      Base64.encode64(sign).gsub("\n", '')
    end

    def digest_text
      payment_attributes.values.join('|')
    end

    def digest_verification(params)
      (DIGEST_ALLOWED_ATTRIBUTES & params.keys).
        map { |key| params[key] }.join('|')
    end

    def digest1_verification(params)
      digest_verification(params) + "|#{config.merchant_number}"
    end

    def payment_attributes
      @payment_attributes ||= PaymentAttributes.new(self).to_h
    end

    def payment_attributes_with_digest
      payment_attributes.merge('DIGEST' => digest)
    end

    def verified_response?(params)
      verify_digest(params['DIGEST'], digest_verification(params)) &&
        verify_digest(params['DIGEST1'], digest1_verification(params))
    end

    def verify_digest(signature, data)
      gpe_key.verify(OpenSSL::Digest::SHA1.new, Base64.decode64(signature), data)
    end

    def merchant_key
      @merchant_key ||= begin
        pem = config.merchant_pem
        OpenSSL::PKey::RSA.new(pem, config.merchant_password)
      end
    end

    def gpe_key
      @gpe_key ||= begin
        pem = config.gpe_pem
        OpenSSL::X509::Certificate.new(pem).public_key
      end
    end
  end
end
