// jkcoxson

extern crate bindgen;

use std::{
    env,
    fs::{canonicalize, read_to_string},
    path::PathBuf,
    process::Command,
};

fn main() {
    // Tell cargo to invalidate the built crate whenever build files change
    println!("cargo:rerun-if-changed=wrapper.h");
    println!("cargo:rerun-if-changed=build.rs");

    ////////////////////////////
    //   BINDGEN GENERATION   //
    ////////////////////////////

    if cfg!(feature = "pls-generate") {
        // Get gnutls path per OS
        let gnutls_path = match env::consts::OS {
            "linux" => "/usr/include",
            "macos" => "/opt/homebrew/include",
            "windows" => {
                panic!("Generating bindings on Windows is broken, pls remove the pls-generate feature.");
            }
            _ => panic!("Unsupported OS"),
        };

        let bindings = bindgen::Builder::default()
            // The input header we would like to generate
            .header("wrapper.h")
            // Include in clang build
            .clang_arg(format!("-I{}", gnutls_path))
            // Tell cargo to invalidate the built crate whenever any of the
            // included header files changed.
            .parse_callbacks(Box::new(bindgen::CargoCallbacks))
            // Finish the builder and generate the bindings.
            .generate()
            // Unwrap the Result and panic on failure.
            .expect("Unable to generate bindings");

        // Write the bindings to the $OUT_DIR/bindings.rs file.
        let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
        bindings
            .write_to_file(out_path.join("bindings.rs"))
            .expect("Couldn't write bindings!");
    }

    if cfg!(feature = "vendored") {
        // Change current directory to OUT_DIR
        let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
        env::set_current_dir(out_path).unwrap();
        // Clone and bootstrap the vendored library.
        repo_setup("https://github.com/libimobiledevice/libplist.git");

        // Build libplist for the Cargo target. The upstream build script lets
        // autotools guess the host from `clang`; iOS cross-builds need it set.
        let mut config = autotools::Config::new("libplist");
        config.without("cython", None);
        configure_for_target(&mut config);
        config.cflag("-std=gnu17");
        let dst = config.build();

        println!(
            "cargo:rustc-link-search=native={}",
            dst.join("lib").display()
        );

        println!("cargo:rustc-link-lib=static=plist-2.0");
    } else {
        // Check if folder ./override exists
        let override_path = PathBuf::from("./override").join(env::var("TARGET").unwrap());
        if override_path.exists() {
            println!(
                "cargo:rustc-link-search={}",
                canonicalize(&override_path).unwrap().display()
            );
        }

        println!("cargo:rustc-link-search=/usr/local/lib");
        println!("cargo:rustc-link-search=/usr/lib");
        println!("cargo:rustc-link-search=/opt/homebrew/lib");
        println!("cargo:rustc-link-search=/usr/local/opt/libimobiledevice/lib");
        println!("cargo:rustc-link-search=/usr/local/opt/libusbmuxd/lib");
        println!("cargo:rustc-link-search=/usr/local/opt/libimobiledevice-glue/lib");
    }
}

fn configure_for_target(config: &mut autotools::Config) {
    let target = env::var("TARGET").unwrap_or_default();
    let Some(host) = autotools_host_for_target(&target) else {
        return;
    };

    env::set_var("PKG_CONFIG_ALLOW_CROSS", "1");
    config.config_option("host", Some(host));
    config.env("ac_cv_c_undeclared_builtin_options", "-fno-builtin");

    if let Some(cpp) = cargo_target_env("CPP", &target) {
        config.env("CPP", cpp);
    } else if let Some(cc) = cargo_target_env("CC", &target) {
        config.env("CPP", format!("{cc} -E"));
    }

    if let Some(cxxcpp) = cargo_target_env("CXXCPP", &target) {
        config.env("CXXCPP", cxxcpp);
    } else if let Some(cxx) = cargo_target_env("CXX", &target) {
        config.env("CXXCPP", format!("{cxx} -E"));
    }

    if let Some(ar) = cargo_target_env("AR", &target) {
        config.env("AR", ar);
    }
    if let Some(ranlib) = cargo_target_env("RANLIB", &target) {
        config.env("RANLIB", ranlib);
    }
}

fn cargo_target_env(name: &str, target: &str) -> Option<String> {
    let target = target.replace('-', "_");
    env::var(format!("{name}_{target}"))
        .ok()
        .or_else(|| env::var(name).ok())
}

fn autotools_host_for_target(target: &str) -> Option<&'static str> {
    match target {
        "aarch64-apple-ios" | "aarch64-apple-ios-sim" => Some("aarch64-apple-darwin"),
        "x86_64-apple-ios" => Some("x86_64-apple-darwin"),
        _ => None,
    }
}

fn repo_setup(url: &str) {
    let repo_name = url.split('/').last().unwrap().replace(".git", "");

    let status = Command::new("git")
        .args(["clone", "--depth=1", url])
        .status()
        .expect("failed to launch git clone for vendored libplist");
    assert!(status.success(), "failed to clone vendored libplist");

    env::set_current_dir(&repo_name).unwrap();

    // libplist's repository contains Autoconf/Automake input files. A fresh
    // clone must be bootstrapped before the autotools crate invokes configure.
    // The old implementation discarded autogen.sh's exit status, leaving a
    // placeholder configure script containing AM_INIT_AUTOMAKE on macOS CI.
    let mut bootstrap = Command::new("./autogen.sh");
    bootstrap.env("NOCONFIGURE", "1");
    if env::consts::OS == "macos" {
        bootstrap.env("LIBTOOLIZE", "glibtoolize");
    }
    let status = bootstrap
        .status()
        .expect("failed to launch libplist autogen.sh");
    assert!(status.success(), "libplist autogen.sh failed");

    let configure = PathBuf::from("configure");
    let configure_text = read_to_string(&configure)
        .expect("libplist bootstrap did not produce a readable configure script");
    assert!(
        !configure_text.contains("AM_INIT_AUTOMAKE("),
        "libplist configure script still contains unexpanded Automake macros"
    );

    env::set_current_dir("..").unwrap();
}
