
module DataMapper
  class Property 
    class TextEncrypted < Text  
      extend ::Crypto

      def load(value)
        return unless value
        self.class.decrypt(value)
      end

      def dump(value)
        return unless value
        self.class.encrypt(value)
      end

      def typecast(value)
        return value if value.is_a?(String)
        return value.to_s if value.respond_to? :to_s
        value
      end


    end
  end
end

