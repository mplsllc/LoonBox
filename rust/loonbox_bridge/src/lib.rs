//! LoonBox Bridge — flutter_rust_bridge FFI layer.
//!
//! This crate exposes the public API surface that Dart calls via FFI.
//! flutter_rust_bridge generates Dart bindings from the functions in api.rs.

mod frb_generated;
pub mod api;
