require 'openssl'
require 'base64'

#
# It encrypts and decrypts a value using AES-256.
#
# The AES key (and, for the legacy format, the IV) is encrypted using a RSA key.
#
# Two formats:
#
# - GCM (from 0.2.0): AES-256-GCM with a random nonce per value, stored with the value, and an
#   authentication tag (a tampered value fails to decrypt):
#
#     gcm1:<base64(nonce (12 bytes) + ciphertext + tag (16 bytes))>
#
# - CFB (legacy): AES-256-CFB with the same IV (Crypto.aes_iv) for every value:
#
#     <base64(ciphertext)>
#
# decrypt reads both (it looks at the prefix: Base64 never contains ':'). encrypt writes the format
# given by Crypto.configure(:write_format => :cfb | :gcm), :cfb by default, so a new version of
# the gem can be deployed everywhere before anything is written in GCM.
#
module Crypto

  GCM_PREFIX = 'gcm1:'.freeze
  GCM_NONCE_SIZE = 12
  GCM_TAG_SIZE = 16
  WRITE_FORMATS = [:cfb, :gcm].freeze

  def encrypt(value)
    Crypto.write_format == :gcm ? encrypt_gcm(value) : encrypt_cfb(value)
  end

  def decrypt(value)
    gcm?(value) ? decrypt_gcm(value) : decrypt_cfb(value)
  end

  def gcm?(value)
    value.start_with?(GCM_PREFIX)
  end

  def encrypt_gcm(value)

    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.encrypt
    cipher.key = cipher_password
    nonce = cipher.random_iv
    # The prefix is authenticated: the format of a value can't be changed without notice.
    cipher.auth_data = GCM_PREFIX
    encrypted = cipher.update(value) + cipher.final
    GCM_PREFIX + Base64.strict_encode64(nonce + encrypted + cipher.auth_tag)

  end

  #
  # @raise [OpenSSL::Cipher::CipherError] if the value has been tampered with (or the key is not
  #   the one it was encrypted with)
  #
  def decrypt_gcm(value)

    raw = Base64.strict_decode64(value[GCM_PREFIX.size..-1])
    raise OpenSSL::Cipher::CipherError, 'GCM value too short' if raw.bytesize < GCM_NONCE_SIZE + GCM_TAG_SIZE

    decipher = OpenSSL::Cipher.new('aes-256-gcm')
    decipher.decrypt
    decipher.key = cipher_password
    decipher.iv = raw.byteslice(0, GCM_NONCE_SIZE)
    decipher.auth_tag = raw.byteslice(raw.bytesize - GCM_TAG_SIZE, GCM_TAG_SIZE)
    decipher.auth_data = GCM_PREFIX
    decipher.update(raw.byteslice(GCM_NONCE_SIZE, raw.bytesize - GCM_NONCE_SIZE - GCM_TAG_SIZE)) + decipher.final

  end

  def encrypt_cfb(value)

    cipher= OpenSSL::Cipher.new('AES-256-CFB')
    cipher.encrypt
    cipher.key= cipher_password
    cipher.iv= cipher.iv_len < cipher_iv.size ? cipher_iv[0..cipher.iv_len-1] : cipher_iv
    Base64.encode64(cipher.update(value) + cipher.final)

  end

  def decrypt_cfb(value)

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

  # Only the CFB format uses it: once every value is in GCM, :aes_iv is no longer needed.
  def load_cipher_iv

    unless Crypto.aes_iv
      raise 'Crypto has not been configured with :aes_iv (needed by the CFB format). Do Crypto.configure'
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

    write_format = (opts[:write_format] || :cfb).to_sym
    unless WRITE_FORMATS.include?(write_format)
      raise ArgumentError, "write_format must be one of #{WRITE_FORMATS.inspect}"
    end

    @_rsa_key = opts[:rsa_key]
    @_aes_key = opts[:aes_key]
    @_aes_iv = opts[:aes_iv]
    @_write_format = write_format

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

  def self.write_format
    @_write_format || :cfb
  end

end
