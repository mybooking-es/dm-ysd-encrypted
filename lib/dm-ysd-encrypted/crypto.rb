require 'openssl'
require 'base64'

#
# It encrypt and decrypt a value using AES-256-CFB algoritm
#
# The AES key is encrypted using a public RSA KEY
#
module Crypto

  def encrypt(value)

    cipher= OpenSSL::Cipher.new('AES-256-CFB')
    cipher.encrypt
    cipher.key= cipher_password
    cipher.iv= cipher.iv_len < cipher_iv.size ? cipher_iv[0..cipher.iv_len-1] : cipher_iv
    Base64.encode64(cipher.update(value) + cipher.final)

  end

  def decrypt(value)

    decipher= OpenSSL::Cipher.new('AES-256-CFB')
    decipher.decrypt
    decipher.key= cipher_password
    decipher.iv= decipher.iv_len < cipher_iv.size ? cipher_iv[0..decipher.iv_len-1] : cipher_iv
    decipher.update(Base64.decode64(value)) + decipher.final

  end

  def cipher_password
    
    @cipher_password ||= load_cipher_password
  
  end
   
  def load_cipher_password

    unless Crypto.aes_key
      raise 'Crypto has not been configured. Do Crypto.configure'
    end

    rsa_key.private_decrypt Crypto.aes_key

  end

  def cipher_iv

    @cipher_iv ||= load_cipher_iv
  
  end

  def load_cipher_iv
  
    unless Crypto.aes_iv
      raise 'Crypto has not been configured. Do Crypto.configure'
    end

    rsa_key.private_decrypt Crypto.aes_iv

  end

  def rsa_key
  
    @rsa_key ||= load_rsa_key

  end

  def load_rsa_key
    
    unless Crypto.rsa_key
      raise 'Crypto has not been configured. Do Crypto.configure'
    end
        
    OpenSSL::PKey::RSA.new Crypto.rsa_key

  end

  def self.configure(opts={})
    
    @_rsa_key = opts[:rsa_key]
    @_aes_key = opts[:aes_key]
    @_aes_iv = opts[:aes_iv] 

  end

  def self.rsa_key
    @_rsa_key
  end

  def self.aes_key
    @_aes_key
  end

  def self.aes_iv
    @_aes_iv
  end

end

