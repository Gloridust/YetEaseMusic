//! 请求层：cookie 会话 + 按加密通道组装请求。
//!
//! 行为对照 api-enhanced `util/request.js`。

use std::collections::BTreeMap;
use std::sync::{Arc, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};

use crate::crypto;
use crate::error::{Error, Result};

const DOMAIN: &str = "https://music.163.com";
const API_DOMAIN: &str = "https://interface.music.163.com";
const EAPI_DOMAIN: &str = "https://interfacepc.music.163.com";

const UA_WEAPI: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0";
const UA_LINUXAPI: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36";
const UA_API_IPHONE: &str = "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)";

/// 这些业务码在 api-enhanced 里也按成功处理（主要是扫码登录的中间状态）。
const OK_CODES: &[i64] = &[200, 201, 302, 400, 502, 800, 801, 802, 803];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Crypto {
    Weapi,
    Eapi,
    Linuxapi,
    /// 明文 `/api`
    Api,
}

/// 可持久化的会话：cookie + 固定的设备指纹。登录后把它整个存盘即可。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Session {
    pub cookies: BTreeMap<String, String>,
    /// 设置后以 `X-Real-IP` / `X-Forwarded-For` 发送（出口在海外时用国内 IP 绕开版权地区限制）。
    #[serde(default)]
    pub real_ip: Option<String>,
}

impl Session {
    pub fn is_logged_in(&self) -> bool {
        self.cookies.get("MUSIC_U").is_some_and(|v| !v.is_empty())
    }

    /// 补齐客户端指纹类 cookie。只在缺失时生成，生成后随会话一起持久化，
    /// 避免每次请求都像一台新设备。
    fn ensure_fingerprint(&mut self) {
        let c = &mut self.cookies;
        let nuid = c
            .entry("_ntes_nuid".into())
            .or_insert_with(|| random_hex(32))
            .clone();
        c.entry("_ntes_nnid".into())
            .or_insert_with(|| format!("{nuid},{}", now_ms()));
        c.entry("WNMCID".into()).or_insert_with(|| {
            let s: String = (0..6)
                .map(|_| (b'a' + rand::random_range(0..26u8)) as char)
                .collect();
            format!("{s}.{}.01.0", now_ms())
        });
        c.entry("WEVNSM".into()).or_insert_with(|| "1.0.0".into());
        c.entry("deviceId".into()).or_insert_with(|| {
            (0..52)
                .map(|_| b"0123456789ABCDEF"[rand::random_range(0..16)] as char)
                .collect()
        });
        c.entry("NMTID".into())
            .or_insert_with(|| format!("00O{}", random_hex(19)));
        c.entry("os".into()).or_insert_with(|| "pc".into());
        c.entry("osver".into())
            .or_insert_with(|| "Microsoft-Windows-10-Professional-build-19045-64bit".into());
        c.entry("appver".into())
            .or_insert_with(|| "3.1.17.204416".into());
        c.entry("channel".into())
            .or_insert_with(|| "netease".into());
    }

    fn header_cookie(&self) -> String {
        let mut c = self.cookies.clone();
        c.insert("__remember_me".into(), "true".into());
        c.insert("ntes_kaola_ad".into(), "1".into());
        if !self.is_logged_in() {
            c.remove("MUSIC_U");
        }
        join_cookie(c.iter())
    }

    fn get(&self, k: &str) -> &str {
        self.cookies.get(k).map(String::as_str).unwrap_or("")
    }

    /// eapi 请求里 `header` 字段 / Cookie 头的内容。
    fn eapi_header(&self) -> Map<String, Value> {
        let mut h = Map::new();
        for k in ["osver", "deviceId", "os", "appver"] {
            h.insert(k.into(), self.get(k).into());
        }
        h.insert("versioncode".into(), "140".into());
        h.insert("mobilename".into(), "".into());
        h.insert("buildver".into(), (now_ms() / 1000).to_string().into());
        h.insert("resolution".into(), "1920x1080".into());
        h.insert("__csrf".into(), self.get("__csrf").into());
        h.insert("channel".into(), self.get("channel").into());
        h.insert(
            "requestId".into(),
            format!("{}_{:04}", now_ms(), rand::random_range(0..1000)).into(),
        );
        if self.is_logged_in() {
            h.insert("MUSIC_U".into(), self.get("MUSIC_U").into());
        } else if !self.get("MUSIC_A").is_empty() {
            h.insert("MUSIC_A".into(), self.get("MUSIC_A").into());
        }
        if !self.get("NMTID").is_empty() {
            h.insert("NMTID".into(), self.get("NMTID").into());
        }
        h
    }

    fn apply_set_cookie(&mut self, raw: &str) {
        let Some(first) = raw.split(';').next() else {
            return;
        };
        let Some((k, v)) = first.split_once('=') else {
            return;
        };
        let (k, v) = (k.trim(), v.trim());
        let expired = raw.split(';').any(|attr| {
            let attr = attr.trim().to_ascii_lowercase();
            attr == "max-age=0" || attr.starts_with("max-age=-")
        });
        if expired || v.is_empty() {
            self.cookies.remove(k);
        } else {
            self.cookies.insert(k.to_owned(), v.to_owned());
        }
    }
}

#[derive(Clone)]
pub struct Client {
    http: reqwest::Client,
    session: Arc<RwLock<Session>>,
}

impl Client {
    pub fn new(session: Session) -> Result<Self> {
        // reqwest 用 rustls-no-provider，这里装上 ring（交叉编译到安卓比 aws-lc 省事）
        let _ = rustls::crypto::ring::default_provider().install_default();
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(20))
            .build()?;
        let mut session = session;
        session.ensure_fingerprint();
        Ok(Self {
            http,
            session: Arc::new(RwLock::new(session)),
        })
    }

    /// 当前会话快照，用于存盘。
    pub fn session(&self) -> Session {
        self.session.read().unwrap().clone()
    }

    pub fn is_logged_in(&self) -> bool {
        self.session.read().unwrap().is_logged_in()
    }

    pub fn set_real_ip(&self, ip: Option<String>) {
        self.session.write().unwrap().real_ip = ip;
    }

    /// 清除登录态（保留设备指纹）。
    pub fn clear_login(&self) {
        let mut s = self.session.write().unwrap();
        for k in ["MUSIC_U", "__csrf", "MUSIC_R_U", "MUSIC_SNS"] {
            s.cookies.remove(k);
        }
    }

    /// 底层请求。`uri` 形如 `/api/xxx`。返回业务 JSON。
    pub async fn request(&self, uri: &str, data: Value, crypto: Crypto) -> Result<Value> {
        let mut data = match data {
            Value::Object(m) => m,
            Value::Null => Map::new(),
            other => {
                return Err(Error::Other(format!(
                    "request data must be an object: {other}"
                )));
            }
        };
        let (url, form, cookie, ua, referer) = {
            let s = self.session.read().unwrap();
            match crypto {
                Crypto::Weapi => {
                    data.insert("csrf_token".into(), s.get("__csrf").into());
                    let text = Value::Object(data).to_string();
                    let form = crypto::weapi(&text)
                        .map(|(k, v)| (k.to_owned(), v))
                        .to_vec();
                    (
                        format!("{DOMAIN}/weapi/{}", &uri[5..]),
                        form,
                        s.header_cookie(),
                        UA_WEAPI,
                        Some(DOMAIN),
                    )
                }
                Crypto::Linuxapi => {
                    let text = json!({
                        "method": "POST",
                        "url": format!("{DOMAIN}{uri}"),
                        "params": Value::Object(data),
                    })
                    .to_string();
                    let form = crypto::linuxapi(&text)
                        .map(|(k, v)| (k.to_owned(), v))
                        .to_vec();
                    (
                        format!("{DOMAIN}/api/linux/forward"),
                        form,
                        s.header_cookie(),
                        UA_LINUXAPI,
                        None,
                    )
                }
                Crypto::Eapi => {
                    let header = s.eapi_header();
                    let cookie =
                        join_cookie(header.iter().map(|(k, v)| (k, v.as_str().unwrap_or(""))));
                    data.insert("header".into(), Value::Object(header));
                    data.entry("e_r").or_insert(false.into());
                    let text = Value::Object(data).to_string();
                    let form = crypto::eapi(uri, &text)
                        .map(|(k, v)| (k.to_owned(), v))
                        .to_vec();
                    (
                        format!("{EAPI_DOMAIN}/eapi/{}", &uri[5..]),
                        form,
                        cookie,
                        UA_API_IPHONE,
                        None,
                    )
                }
                Crypto::Api => {
                    let header = s.eapi_header();
                    let cookie =
                        join_cookie(header.iter().map(|(k, v)| (k, v.as_str().unwrap_or(""))));
                    let form = data
                        .into_iter()
                        .map(|(k, v)| {
                            let v = match v {
                                Value::String(s) => s,
                                other => other.to_string(),
                            };
                            (k, v)
                        })
                        .collect();
                    (
                        format!("{API_DOMAIN}{uri}"),
                        form,
                        cookie,
                        UA_API_IPHONE,
                        None,
                    )
                }
            }
        };

        let mut req = self
            .http
            .post(&url)
            .header("User-Agent", ua)
            .header("Cookie", cookie)
            .form(&form);
        if let Some(r) = referer {
            req = req.header("Referer", r);
        }
        if let Some(ip) = self.session.read().unwrap().real_ip.clone() {
            req = req.header("X-Real-IP", &ip).header("X-Forwarded-For", &ip);
        }
        tracing::debug!(%uri, ?crypto, "request");
        // 连接失败、超时这类网络抖动自动重试（最多 2 次，退避 300ms / 900ms）
        let mut attempt = 0;
        let resp = loop {
            let r = req
                .try_clone()
                .expect("form body is cloneable")
                .send()
                .await;
            match r {
                Err(e) if attempt < 2 && (e.is_connect() || e.is_timeout() || e.is_request()) => {
                    attempt += 1;
                    tracing::warn!(%uri, attempt, "request failed, retrying: {e}");
                    tokio::time::sleep(std::time::Duration::from_millis(
                        300 * 3u64.pow(attempt - 1),
                    ))
                    .await;
                }
                r => break r?,
            }
        };
        {
            let mut s = self.session.write().unwrap();
            for v in resp.headers().get_all(reqwest::header::SET_COOKIE) {
                if let Ok(v) = v.to_str() {
                    s.apply_set_cookie(v);
                }
            }
        }
        let status = resp.status();
        let bytes = resp.bytes().await?;
        let body: Value = serde_json::from_slice(&bytes).or_else(|_| {
            // 部分接口在 e_r=true 时返回 eapi 加密体
            crypto::eapi_decrypt_response(&bytes)
                .and_then(|b| serde_json::from_slice(&b).ok())
                .ok_or_else(|| {
                    Error::Decode(format!(
                        "HTTP {status}, {} bytes non-JSON body",
                        bytes.len()
                    ))
                })
        })?;
        let code = body
            .get("code")
            .and_then(|c| c.as_i64().or_else(|| c.as_str()?.parse().ok()))
            .unwrap_or(status.as_u16() as i64);
        if OK_CODES.contains(&code) {
            Ok(body)
        } else {
            let msg = ["message", "msg", "blockText"]
                .iter()
                .find_map(|k| body.get(*k)?.as_str().map(str::to_owned))
                .unwrap_or_default();
            Err(Error::Api { code, msg })
        }
    }
}

fn join_cookie<'a, K, V>(it: impl Iterator<Item = (K, V)>) -> String
where
    K: AsRef<str> + 'a,
    V: AsRef<str> + 'a,
{
    it.map(|(k, v)| format!("{}={}", enc(k.as_ref()), enc(v.as_ref())))
        .collect::<Vec<_>>()
        .join("; ")
}

/// 与 JS `encodeURIComponent` 一致的编码。
fn enc(s: &str) -> String {
    const KEEP: &[u8] = b"-_.!~*'()";
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || KEEP.contains(&b) {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
    out
}

fn random_hex(n_bytes: usize) -> String {
    let mut buf = vec![0u8; n_bytes];
    rand::fill(&mut buf[..]);
    hex::encode(buf)
}

pub(crate) fn now_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_cookie_parsing() {
        let mut s = Session::default();
        s.apply_set_cookie("MUSIC_U=abc; Max-Age=1296000; Expires=x; Path=/; HTTPOnly");
        assert_eq!(s.get("MUSIC_U"), "abc");
        s.apply_set_cookie("MUSIC_U=; Max-Age=0; Path=/");
        assert!(!s.is_logged_in());
    }

    #[test]
    fn encode_uri_component() {
        assert_eq!(enc("a b/c=d"), "a%20b%2Fc%3Dd");
        assert_eq!(enc("中"), "%E4%B8%AD");
    }
}
