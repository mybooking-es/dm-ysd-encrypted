dm-encrypted
======
A [DataMapper](http://github.com/datamapper/data_mapper)
[type](http://github.com/datamapper/dm-more/tree/master/dm-types) that supports
encrypted columns.

It's a fork of qhoxie/dm-encrypted project, hosted on Github. 

It works on DM 1.2 and allows the encryption of long strings.

It uses AES to crypt the cipher the data. The AES 256 bits key and the AES initialization vector
are both encrypted using a RSA key.


Installation
------------
    gem install dm-ysd-encrypted 

Usage
-----
Configure the Crypto (see "Generating the keys" below for real keys):
    
    rsa_key = OpenSSL::PKey::RSA.generate(2048) 

    Crypto.configure({:rsa_key => my_rsa_key,
      :aes_key => rsa_key.public_encrypt(Digest::SHA2.new(256).digest('password')),
      :aes_iv => rsa_key.public_encrypt(rand.to_s)}

In your models, you simply specify the column type as Encrypted (String) or TextEncrypted (Text):

    class Account
      include DataMapper::Resource

      property :id,         Serial
      property :username,   String
      property :password,   Encrypted
    end

Saving and loading those fields will transparently work with plaintext:

    >> Account.create :username => "me", :password => "secret"
    >> Account.first.password
    => "secret"

However it is ciphertext in the database:

    >> select password from accounts;
    => qxZjz37mt2PU...tcHPf5Un3RGAyxaT==

Comments/Suggestions/Requests
----------------------------
Email me: yurak.sisa.dream@gmail.com

Copyright
---------
Copyright (c) 2009 Quin Hoxie. See LICENSE for details.

Formats (0.2.0)
---------------
Two formats; `decrypt` reads both, telling them apart by the prefix (Base64 never contains `:`):

* **GCM**: AES-256-GCM with a random nonce per value and an authentication tag. A tampered value
  raises `OpenSSL::Cipher::CipherError`. It does not use `:aes_iv`.

      gcm1:<base64(nonce (12 bytes) + ciphertext + tag (16 bytes))>

* **CFB** (legacy, up to 0.1.3): AES-256-CFB with the same IV (`:aes_iv`) for every value.

`encrypt` writes the format given by `:write_format`, `:cfb` by default:

    Crypto.configure(:rsa_key => ..., :aes_key => ..., :aes_iv => ..., :write_format => :gcm)

Migrating: deploy 0.2.0 everywhere (it keeps writing CFB, and reads both), then switch to
`:write_format => :gcm` and re-encrypt the existing values. A node with 0.1.3 can't read GCM values.
`:aes_iv` is needed while any CFB value is left.

Generating the keys
-------------------
A key set has three parts for CFB and two for GCM:

| Part     | What it is                                                 | CFB | GCM |
|----------|------------------------------------------------------------|-----|-----|
| `rsa`    | RSA private key (PEM)                                      | yes | yes |
| `aeskey` | the AES-256 key: 32 random bytes, encrypted with the RSA key | yes | yes |
| `aesiv`  | the AES IV: 16 random bytes, encrypted with the RSA key    | yes | no  |

GCM has no IV to generate: it takes a new random nonce for every value and stores it with the
value. CFB has nowhere to store a per-value IV, so it uses one fixed IV per key set.

### Two layers in `aeskey` and `aesiv`

    32 random bytes ──RSA encrypt──▶ 512 bytes ──Base64──▶ 684 characters   (aeskey, RSA 4096)
    (the real AES key)               (ciphertext)          (text for an env file or a credential)

When it starts, the gem goes the other way: `Base64.decode64` gives the 512 bytes, then
`rsa_key.private_decrypt` gives the 32-byte AES key. The IV works the same way, with 16 bytes.

* **RSA always outputs exactly the size of its key**, whatever it encrypts: 4096 bits = 512 bytes,
  2048 bits = 256 bytes. The PKCS#1 v1.5 padding (`00 02 <random> 00 <data>`) fills the rest.
  Because that padding is random, encrypting the same key twice gives different outputs.
* **Base64** turns every 3 bytes into 4 characters, so 512 bytes become 684 characters and 256
  bytes become 344.

| File                          | RSA 2048 | RSA 4096 |
|-------------------------------|----------|----------|
| `aeskey` / `aesiv` (Base64, one line) | 344 | 684 |
| `openssl rand -base64 32` (wrong)     | 44  | 44  |

So the size of `aeskey` is set by the RSA key, not by the AES key. A 44-character `aeskey` is
not encrypted. `openssl rand -base64 32` alone is missing the RSA layer: `private_decrypt` fails
with it (bad padding or size), and the AES key would sit in clear text in the file.

### CFB: three parts

    umask 077
    # 1. RSA private key (PEM)
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out keys.rsa
    # 2. AES key: 32 random bytes -> encrypted with the RSA key -> Base64 on one line
    openssl rand 32 | openssl pkeyutl -encrypt -inkey keys.rsa -pkeyopt rsa_padding_mode:pkcs1 | base64 -w0 > keys.aeskey
    # 3. AES IV: 16 random bytes, encrypted the same way
    openssl rand 16 | openssl pkeyutl -encrypt -inkey keys.rsa -pkeyopt rsa_padding_mode:pkcs1 | base64 -w0 > keys.aesiv

    Crypto.configure(:rsa_key => File.read('keys.rsa'),
                     :aes_key => Base64.decode64(File.read('keys.aeskey')),
                     :aes_iv => Base64.decode64(File.read('keys.aesiv')))

### GCM: two parts

    umask 077
    # 1. RSA private key (PEM)
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out keys.rsa
    # 2. AES key: 32 random bytes -> encrypted with the RSA key -> Base64 on one line
    openssl rand 32 | openssl pkeyutl -encrypt -inkey keys.rsa -pkeyopt rsa_padding_mode:pkcs1 | base64 -w0 > keys.aeskey

    Crypto.configure(:rsa_key => File.read('keys.rsa'),
                     :aes_key => Base64.decode64(File.read('keys.aeskey')),
                     :write_format => :gcm)

`Crypto.configure` takes the RSA key as PEM text and the encrypted parts as raw bytes, so the
Base64 files are decoded first.

Notes:

* **Moving from CFB to GCM keeps the IV.** A key set that has written CFB still needs `:aes_iv`
  to read those values, until they have all been re-encrypted, and to read old backups. Only a
  key set that has been GCM-only from the start can do without it. The application using the gem
  may require all three parts anyway.
* The IV is generated once per key set, never per value.
* `umask 077` makes the files readable by their owner only.
* `base64 -w0` is GNU coreutils. On macOS use `base64`, which already writes a single line.
