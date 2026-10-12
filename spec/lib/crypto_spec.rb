require 'openssl'
require 'base64'
require_relative '../../lib/dm-ysd-encrypted/crypto'

# Crypto alone (no DataMapper): both formats, reading both, and a tampered GCM value.
describe Crypto do

  RSA_KEY = OpenSSL::PKey::RSA.generate(2048)
  AES_KEY = OpenSSL::Random.random_bytes(32)
  AES_IV = OpenSSL::Random.random_bytes(16)

  # Crypto memoizes the AES key and the IV in the object that extends it: a fresh one per example.
  def crypto_object
    Object.new.extend(Crypto)
  end

  def configure(**options)
    Crypto.configure({ rsa_key: RSA_KEY.to_pem,
                       aes_key: RSA_KEY.public_encrypt(AES_KEY),
                       aes_iv: RSA_KEY.public_encrypt(AES_IV) }.merge(options))
  end

  # The legacy format, computed without the gem.
  def legacy_cfb(value)
    cipher = OpenSSL::Cipher.new('AES-256-CFB')
    cipher.encrypt
    cipher.key = AES_KEY
    cipher.iv = AES_IV
    Base64.encode64(cipher.update(value) + cipher.final)
  end

  let(:message) { 'secret: ñandú 123 €' }

  describe 'write_format' do

    it 'is :cfb by default (the same output as before 0.2.0)' do
      configure
      expect(Crypto.write_format).to eq(:cfb)
      expect(crypto_object.encrypt(message)).to eq(legacy_cfb(message))
    end

    it 'can be :gcm' do
      configure(write_format: :gcm)
      expect(crypto_object.encrypt(message)).to start_with(Crypto::GCM_PREFIX)
    end

    it 'rejects any other value' do
      expect { configure(write_format: :ecb) }.to raise_error(ArgumentError)
    end

  end

  describe 'GCM' do

    before { configure(write_format: :gcm) }

    it 'round-trips' do
      crypto = crypto_object
      expect(crypto.decrypt(crypto.encrypt(message)).force_encoding('UTF-8')).to eq(message)
    end

    it 'round-trips an empty value' do
      crypto = crypto_object
      expect(crypto.decrypt(crypto.encrypt(''))).to eq('')
    end

    it 'uses a new nonce for every value: the same text gives different ciphertexts' do
      crypto = crypto_object
      expect(crypto.encrypt(message)).not_to eq(crypto.encrypt(message))
    end

    it 'is a single line of strict Base64 after the prefix' do
      encrypted = crypto_object.encrypt('x' * 500)
      expect(encrypted).not_to include("\n")
      expect { Base64.strict_decode64(encrypted.delete_prefix(Crypto::GCM_PREFIX)) }.not_to raise_error
    end

    it 'does not need :aes_iv' do
      configure(write_format: :gcm, aes_iv: nil)
      crypto = crypto_object
      expect(crypto.decrypt(crypto.encrypt(message)).force_encoding('UTF-8')).to eq(message)
    end

    it 'fails with a tampered value' do
      crypto = crypto_object
      raw = Base64.strict_decode64(crypto.encrypt(message).delete_prefix(Crypto::GCM_PREFIX))
      raw.setbyte(Crypto::GCM_NONCE_SIZE, raw.getbyte(Crypto::GCM_NONCE_SIZE) ^ 1)
      tampered = Crypto::GCM_PREFIX + Base64.strict_encode64(raw)
      expect { crypto.decrypt(tampered) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'fails with another key' do
      encrypted = crypto_object.encrypt(message)
      other_rsa = OpenSSL::PKey::RSA.generate(2048)
      Crypto.configure(rsa_key: other_rsa.to_pem, aes_key: other_rsa.public_encrypt(OpenSSL::Random.random_bytes(32)),
                       write_format: :gcm)
      expect { crypto_object.decrypt(encrypted) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'fails with a truncated value' do
      expect { crypto_object.decrypt("#{Crypto::GCM_PREFIX}#{Base64.strict_encode64('short')}") }
        .to raise_error(OpenSSL::Cipher::CipherError)
    end

  end

  describe 'reading both formats' do

    it 'reads a legacy CFB value while writing GCM' do
      configure(write_format: :gcm)
      crypto = crypto_object
      expect(crypto.decrypt(legacy_cfb(message)).force_encoding('UTF-8')).to eq(message)
    end

    it 'reads a GCM value while writing CFB (a node that has not switched yet)' do
      configure(write_format: :gcm)
      encrypted = crypto_object.encrypt(message)
      configure(write_format: :cfb)
      expect(crypto_object.decrypt(encrypted).force_encoding('UTF-8')).to eq(message)
    end

    it 'tells the formats apart by the prefix' do
      configure(write_format: :gcm)
      crypto = crypto_object
      expect(crypto.gcm?(crypto.encrypt(message))).to be(true)
      expect(crypto.gcm?(legacy_cfb(message))).to be(false)
    end

  end

end
