use std::fmt;

/// Why a Corobs call refused its arguments. The variants mirror the exceptions the C# reference
/// throws, so a port's caller can tell the same failures apart.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CorobsError {
    /// A number outside the range the operation accepts (C# `ArgumentOutOfRangeException`).
    ArgumentOutOfRange(String),
    /// An argument that is invalid as a whole (C# `ArgumentException`).
    Argument(String),
    /// An operation this object does not support (C# `InvalidOperationException`).
    InvalidOperation(String),
}

impl fmt::Display for CorobsError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CorobsError::ArgumentOutOfRange(m) => write!(f, "argument out of range: {m}"),
            CorobsError::Argument(m) => write!(f, "invalid argument: {m}"),
            CorobsError::InvalidOperation(m) => write!(f, "invalid operation: {m}"),
        }
    }
}

impl std::error::Error for CorobsError {}

/// The result of a Corobs call that can refuse its arguments.
pub type Result<T> = std::result::Result<T, CorobsError>;

pub(crate) fn out_of_range<T>(message: impl Into<String>) -> Result<T> {
    Err(CorobsError::ArgumentOutOfRange(message.into()))
}

pub(crate) fn argument<T>(message: impl Into<String>) -> Result<T> {
    Err(CorobsError::Argument(message.into()))
}
