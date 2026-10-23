#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("network: {0}")]
    Http(#[from] reqwest::Error),
    #[error("api error {code}: {msg}")]
    Api { code: i64, msg: String },
    #[error("decode: {0}")]
    Decode(String),
    #[error("{0}")]
    Other(String),
}

impl From<serde_json::Error> for Error {
    fn from(e: serde_json::Error) -> Self {
        Error::Decode(e.to_string())
    }
}

pub type Result<T> = std::result::Result<T, Error>;
