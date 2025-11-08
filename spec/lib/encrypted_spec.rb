require 'spec_helper'
require 'openssl'
require 'digest/sha2'
require 'base64'

describe DataMapper::Property::Encrypted do

  before :all do

    class Item
      include DataMapper::Resource
     
      property :id, Serial
      property :text, Encrypted

    end

    @property = ::Item.properties[:text]
    @message = '123457890'

    # Create RSA keys
     
    rsa_keys = OpenSSL::PKey::RSA.generate(2048)
    aes_key  = Digest::SHA2.new(256).digest('secret')
    aes_iv   = rand.to_s
    
    Crypto.configure(:rsa_key => rsa_keys.to_pem, 
      :aes_key => rsa_keys.public_encrypt(aes_key), 
      :aes_iv => rsa_keys.public_encrypt(aes_iv))

    aes = OpenSSL::Cipher.new('AES-256-CFB')
    aes.encrypt
    aes.key = aes_key
    aes.iv = aes_iv
    @encrypted_message = Base64.encode64(aes.update(@message) + aes.final)

    decipher = OpenSSL::Cipher.new('AES-256-CFB')
    decipher.decrypt
    decipher.key = aes_key
    decipher.iv = aes_iv
    @decrypted_message = decipher.update(Base64.decode64(@encrypted_message)) + decipher.final

  end

  describe "#dump" do
  
    subject{ @property.dump(@message) }
    it { should == @encrypted_message }

  end


  describe "#load" do

    subject{ @property.load(@encrypted_message) } 
    it { should == @message }

  end


end
