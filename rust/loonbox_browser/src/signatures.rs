//! Package signature verification.
//!
//! Single verification gate for ALL Nest package types:
//! feathers, extensions, filter lists, browser scripts.
//! SHA-256 hash comparison against expected hex digest.

use sha2::{Sha256, Digest};

/// Verify a package file's SHA-256 hash matches the expected hex string.
///
/// Returns `true` if the hash matches, `false` otherwise.
pub fn verify_package(path: &str, expected_sha256_hex: &str) -> anyhow::Result<bool> {
    let bytes = std::fs::read(path)
        .map_err(|e| anyhow::anyhow!("Failed to read package at '{}': {}", path, e))?;
    let hash = Sha256::digest(&bytes);
    let actual_hex = hex::encode(hash);
    Ok(actual_hex.eq_ignore_ascii_case(expected_sha256_hex))
}
