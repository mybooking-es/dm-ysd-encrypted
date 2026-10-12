# 0.2.0
- Added the GCM format: AES-256-GCM with a random 12-byte nonce per value and a 16-byte
  authentication tag, stored as `gcm1:<base64(nonce + ciphertext + tag)>` (strict Base64, one line).
  The `gcm1:` prefix is authenticated (`auth_data`). A tampered or truncated value, or one encrypted
  with another key, raises `OpenSSL::Cipher::CipherError`.
- `decrypt` reads both formats. It looks at the prefix: Base64 never contains `:`, so values without
  `gcm1:` are read as CFB.
- New `Crypto.configure(:write_format => :cfb | :gcm)` option. It defaults to `:cfb`, which writes
  exactly what 0.1.x wrote. This lets 0.2.0 be deployed everywhere before anything is written in
  GCM. Any other value raises `ArgumentError`. Read it with `Crypto.write_format`.
- `:aes_iv` is only needed by the CFB format, for both reading and writing. A GCM-only setup can
  leave it out. The error raised when it is missing now says so.
- `encrypt_cfb`/`decrypt_cfb` (the previous code) and `encrypt_gcm`/`decrypt_gcm` are available
  directly, as is `gcm?(value)`.
- Added specs for `Crypto` without DataMapper (`spec/lib/crypto_spec.rb`): both formats, reading
  each from the other, tampering and the default format.
- Upgrading: no change is needed. Existing CFB values keep being read and written as before until
  `write_format: :gcm` is set. Every process that reads the data must be on 0.2.0 before any
  process writes GCM, because 0.1.x can't read `gcm1:` values.

# 0.1.3
- Previous release: AES-256-CFB with a fixed IV (`:aes_iv`), AES key and IV encrypted with RSA.
