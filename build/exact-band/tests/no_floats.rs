//! The float-free property is **checked, not asserted**.
//!
//! This mirrors the discipline in `quilt-verilog/tools/tower/verify.py`, which
//! greps its own generated C for floating-point types rather than trusting that
//! none crept in. A claim of "no floating point" that nothing enforces decays
//! the first time someone reaches for `sqrt`.

use std::fs;
use std::path::Path;

fn rust_sources(dir: &Path, out: &mut Vec<(String, String)>) {
    for entry in fs::read_dir(dir).expect("src/ must be readable") {
        let path = entry.expect("dir entry").path();
        if path.is_dir() {
            rust_sources(&path, out);
        } else if path.extension().and_then(|e| e.to_str()) == Some("rs") {
            let text = fs::read_to_string(&path).expect("source must be readable");
            out.push((path.display().to_string(), text));
        }
    }
}

/// No `f32`, `f64`, or `sqrt` may appear in this crate's own source — outside of
/// prose, where they are discussed precisely because they are excluded.
#[test]
fn crate_source_contains_no_floating_point() {
    let mut sources = Vec::new();
    rust_sources(Path::new("src"), &mut sources);
    assert!(!sources.is_empty(), "found no sources to scan - test is vacuous");

    let mut offences = Vec::new();
    for (path, text) in &sources {
        for (n, line) in text.lines().enumerate() {
            let code = line.trim_start();
            // Doc comments and ordinary comments are prose, not code.
            if code.starts_with("//") || code.starts_with("*") { continue; }
            // `.sqrt(` catches the float method; a bare `sqrt(` would also
            // match this crate's own exact `isqrt(`, which is the point of it.
            for needle in ["f32", "f64", ".sqrt(", "as f32", "as f64", "libm"] {
                if code.contains(needle) {
                    offences.push(format!("{path}:{}: `{needle}` in `{}`", n + 1, code.trim()));
                }
            }
        }
    }
    assert!(offences.is_empty(),
        "floating point reached the source:\n  {}", offences.join("\n  "));
    eprintln!("floats   : none in {} source files", sources.len());
}

/// The crate must stay `no_std` and free of `unsafe`.
#[test]
fn crate_is_no_std_and_forbids_unsafe() {
    let lib = fs::read_to_string("src/lib.rs").expect("lib.rs");
    assert!(lib.contains("#![no_std]"), "must remain no_std");
    assert!(lib.contains("#![forbid(unsafe_code)]"), "must forbid unsafe");
}
