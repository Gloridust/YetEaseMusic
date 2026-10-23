//! 网易云各加密通道的请求体编码。
//!
//! 参照 api-enhanced `util/crypto.js`（MIT）用 Rust 重写，常量与算法保持一致。

use aes::Aes128;
use aes::cipher::{BlockModeDecrypt, BlockModeEncrypt, KeyInit, KeyIvInit, block_padding::Pkcs7};
use base64::Engine;
use base64::engine::general_purpose::STANDARD as B64;
use md5::{Digest, Md5};
use num_bigint::BigUint;

const IV: &[u8; 16] = b"0102030405060708";
const PRESET_KEY: &[u8; 16] = b"0CoJUm6Qyw8W8jud";
const LINUXAPI_KEY: &[u8; 16] = b"rFgB&h#%2?^eDg:Q";
const EAPI_KEY: &[u8; 16] = b"e82ckenh8dichen8";
const BASE62: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const RSA_MODULUS: &str = "e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7";
const RSA_EXPONENT: u32 = 0x10001;

type CbcEnc = cbc::Encryptor<Aes128>;
type EcbEnc = ecb::Encryptor<Aes128>;
type EcbDec = ecb::Decryptor<Aes128>;

fn aes_cbc(data: &[u8], key: &[u8; 16]) -> Vec<u8> {
    CbcEnc::new(key.into(), IV.into()).encrypt_padded_vec::<Pkcs7>(data)
}

fn aes_ecb(data: &[u8], key: &[u8; 16]) -> Vec<u8> {
    EcbEnc::new(key.into()).encrypt_padded_vec::<Pkcs7>(data)
}

fn aes_ecb_decrypt(data: &[u8], key: &[u8; 16]) -> Option<Vec<u8>> {
    EcbDec::new(key.into()).decrypt_padded_vec::<Pkcs7>(data).ok()
}

/// 无填充 RSA：把字节串当作大端整数做 m^e mod n，结果补零到 256 个十六进制字符。
fn rsa_no_padding(data: &[u8]) -> String {
    let n = BigUint::parse_bytes(RSA_MODULUS.as_bytes(), 16).expect("valid modulus");
    let m = BigUint::from_bytes_be(data);
    let c = m.modpow(&BigUint::from(RSA_EXPONENT), &n);
    format!("{:0>256}", c.to_str_radix(16))
}

fn random_secret_key() -> [u8; 16] {
    let mut key = [0u8; 16];
    for b in &mut key {
        *b = BASE62[rand::random_range(0..BASE62.len())];
    }
    key
}

/// weapi：两次 AES-CBC + RSA 包装随机密钥。返回表单字段 `params` / `encSecKey`。
pub fn weapi(text: &str) -> [(&'static str, String); 2] {
    weapi_with_key(text, random_secret_key())
}

fn weapi_with_key(text: &str, secret: [u8; 16]) -> [(&'static str, String); 2] {
    let first = B64.encode(aes_cbc(text.as_bytes(), PRESET_KEY));
    let params = B64.encode(aes_cbc(first.as_bytes(), &secret));
    let mut reversed = secret;
    reversed.reverse();
    [("params", params), ("encSecKey", rsa_no_padding(&reversed))]
}

/// linuxapi：AES-ECB，十六进制大写。返回表单字段 `eparams`。
pub fn linuxapi(text: &str) -> [(&'static str, String); 1] {
    [("eparams", hex::encode_upper(aes_ecb(text.as_bytes(), LINUXAPI_KEY)))]
}

/// eapi：`url` 是 `/api/...` 形式的路径。返回表单字段 `params`。
pub fn eapi(url: &str, text: &str) -> [(&'static str, String); 1] {
    let digest = hex::encode(Md5::digest(format!("nobody{url}use{text}md5forencrypt")));
    let data = format!("{url}-36cd479b6b5-{text}-36cd479b6b5-{digest}");
    [("params", hex::encode_upper(aes_ecb(data.as_bytes(), EAPI_KEY)))]
}

/// 解密 eapi 加密的响应体（请求带 `e_r=true` 时服务端会加密返回）。
pub fn eapi_decrypt_response(body: &[u8]) -> Option<Vec<u8>> {
    aes_ecb_decrypt(body, EAPI_KEY)
}

/// 解出 eapi 请求体，便于调试抓包。返回 (url, json 文本)。
pub fn eapi_decrypt_request(params_hex: &str) -> Option<(String, String)> {
    let raw = aes_ecb_decrypt(&hex::decode(params_hex).ok()?, EAPI_KEY)?;
    let text = String::from_utf8(raw).ok()?;
    let mut parts = text.splitn(3, "-36cd479b6b5-");
    Some((parts.next()?.to_owned(), parts.next()?.to_owned()))
}

/// 匿名注册用的设备 ID 编码（`cloudmusic_dll_encode_id`）。
pub fn encode_device_id(device_id: &str) -> String {
    const XOR_KEY: &[u8] = b"3go8&$8*3*3h0k(2)2";
    let xored: Vec<u8> = device_id
        .bytes()
        .enumerate()
        .map(|(i, b)| b ^ XOR_KEY[i % XOR_KEY.len()])
        .collect();
    let digest = B64.encode(Md5::digest(&xored));
    B64.encode(format!("{device_id} {digest}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    type CbcDec = cbc::Decryptor<Aes128>;

    #[test]
    fn eapi_round_trip() {
        let [(_, params)] = eapi("/api/song/lyric", r#"{"id":1}"#);
        let (url, text) = eapi_decrypt_request(&params).unwrap();
        assert_eq!(url, "/api/song/lyric");
        assert_eq!(text, r#"{"id":1}"#);
    }

    #[test]
    fn eapi_known_vector() {
        // 用 md5sum + `openssl enc -aes-128-ecb` 独立算出
        let [(_, params)] = eapi("/api/song/lyric", r#"{"id":1}"#);
        assert_eq!(
            params,
            "9B1595479B79266065903BA79E9883029338432CD7D98D1A3626E997A2C531219B13F34AFEC3DA8E\
             69251F8EB21D1A1159D38E428357226CDD469CCFDC2CC954D27CF6A4C22E1023A03E8FAF9F5182C7\
             BC2BCB0C4A7E53B249894EBF962CD6E6"
        );
    }

    #[test]
    fn weapi_inner_layers_decrypt() {
        let secret = *b"abcdefghijklmnop";
        let [(_, params), (_, enc_sec_key)] = weapi_with_key(r#"{"a":1}"#, secret);
        assert_eq!(enc_sec_key.len(), 256);
        let outer = B64.decode(params).unwrap();
        let first = CbcDec::new((&secret).into(), IV.into())
            .decrypt_padded_vec::<Pkcs7>(&outer)
            .unwrap();
        let inner = B64.decode(first).unwrap();
        let text = CbcDec::new(PRESET_KEY.into(), IV.into())
            .decrypt_padded_vec::<Pkcs7>(&inner)
            .unwrap();
        assert_eq!(text, br#"{"a":1}"#);
    }

    #[test]
    fn rsa_known_vector() {
        // 用 Python 的 pow(m, 65537, n) 独立算出
        let got = rsa_no_padding(b"aaaaaaaaaaaaaaaa");
        assert_eq!(&got[..32], "d473b9eca232f1b4090dd606b0df86de");
        assert_eq!(&got[224..], "1153d9d85e1ea3d78fa8d9210d581cee");
    }
}
