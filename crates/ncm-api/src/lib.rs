//! 网易云音乐协议层：加密、会话与接口。不依赖任何 UI。

mod client;
pub mod crypto;
mod endpoints;
mod error;
pub mod models;

pub use client::{Client, Crypto, Session};
pub use endpoints::qr_login_url;
pub use error::{Error, Result};
pub use models::*;
