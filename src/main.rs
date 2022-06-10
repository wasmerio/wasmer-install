use anyhow::{anyhow, Context, Result};
use http_req::{
    request::Request,
    response::{Response, StatusCode},
    uri::Uri,
};
use std::convert::TryFrom;

use std::path::PathBuf;
use tempfile::TempDir;

#[cfg_attr(debug_assertions, derive(Debug))]
enum InstallationStrategy {
    SplitBinLibConfig {
        data_dir: PathBuf,
        executable_dir: PathBuf,
    },
    SingleInstallPath(PathBuf),
    None,
}

fn wasmer_path(override_existing: bool) -> Result<InstallationStrategy> {
    if override_existing {
        if let Some(install_directory) = std::env::var("WASMER_DIR")
            .ok()
            .map(PathBuf::from)
            .filter(|p| p.exists())
            .or_else(|| {
                dirs::home_dir().map(|mut p| {
                    p.push(".wasmer");
                    p
                })
            })
        {
            return Ok(InstallationStrategy::SingleInstallPath(install_directory));
        }
    }

    if let (Some(data_dir), Some(executable_dir)) = (dirs::data_dir(), dirs::executable_dir()) {
        return Ok(InstallationStrategy::SplitBinLibConfig {
            data_dir,
            executable_dir,
        });
    }

    if let Some(mut home_dir) = dirs::home_dir() {
        home_dir.push(".wasmer");
        return Ok(InstallationStrategy::SingleInstallPath(home_dir));
    }

    Ok(InstallationStrategy::None)
}

fn get_latest_release() -> Result<serde_json::Value> {
    let mut writer = Vec::new();
    let uri = Uri::try_from("https://api.github.com/repos/wasmerio/wasmer/releases").unwrap();

    let response = Request::new(&uri)
        .header("User-Agent", "wasmer.io self update")
        .header("Accept", "application/vnd.github.v3+json")
        .timeout(Some(std::time::Duration::new(30, 0)))
        .send(&mut writer)
        .map_err(anyhow::Error::new)
        .context("Could not lookup wasmer repository on Github.")?;

    assert_eq!(response.status_code(), StatusCode::new(200));

    let v: std::result::Result<serde_json::Value, _> = serde_json::from_reader(&*writer);
    let mut response = v.map_err(anyhow::Error::new)?;
    if let Some(releases) = response.as_array_mut() {
        releases
            .retain(|r| r["tag_name"].is_string() && !r["tag_name"].as_str().unwrap().is_empty());
        releases.sort_by_cached_key(|r| r["tag_name"].as_str().unwrap_or_default().to_string());
        if let Some(latest) = releases.pop() {
            return Ok(latest);
        }
    }

    Err(anyhow!(
        "Could not get Github API response, falling back to downloading latest version."
    ))
}

fn download_release(mut latest: serde_json::Value) -> Result<String> {
    println!("Latest release: {}", latest["name"]);
    if let Some(assets) = latest["assets"].as_array_mut() {
        assets.retain(|a| {
            if let Some(name) = a["name"].as_str() {
                #[cfg(target_arch = "x86_64")]
                {
                    name.contains("x86_64") || name.contains("amd64")
                }
                #[cfg(target_arch = "aarch64")]
                {
                    name.contains("arm64") || name.contains("aarch64")
                }
            } else {
                false
            }
        });
        assets.retain(|a| {
            if let Some(name) = a["name"].as_str() {
                #[cfg(target_os = "macos")]
                {
                    name.contains("darwin") || name.contains("macos")
                }
                #[cfg(target_arch = "windows")]
                {
                    name.contains("windows")
                }
                #[cfg(target_arch = "linux")]
                {
                    name.contains("linux")
                }
            } else {
                false
            }
        });
        assets.retain(|a| {
            if let Some(name) = a["name"].as_str() {
                #[cfg(target_env = "musl")]
                {
                    name.contains("musl")
                }
                #[cfg(not(target_env = "musl"))]
                {
                    !name.contains("musl")
                }
            } else {
                false
            }
        });
        if assets.len() == 1 {
            let browser_download_url = if let Some(url) = assets[0]["browser_download_url"].as_str()
            {
                url.to_string()
            } else {
                return Err(anyhow!(
                    "Could not get download url from Github API response."
                ));
            };
            let filename = browser_download_url
                .split("/")
                .last()
                .unwrap_or("output")
                .to_string();
            let mut file = std::fs::File::create(&filename)?;
            println!("Downloading {} to {}", browser_download_url, &filename);
            let download_thread: std::thread::JoinHandle<Result<Response, anyhow::Error>> =
                std::thread::spawn(move || {
                    let uri = Uri::try_from(browser_download_url.as_str())?;
                    let mut response = Request::new(&uri)
                        .header("User-Agent", "wasmer.io self update")
                        .send(&mut file)
                        .map_err(anyhow::Error::new)
                        .context("Could not lookup wasmer artifact on Github.")?;
                    if response.status_code() == StatusCode::new(302) {
                        let redirect_uri =
                            Uri::try_from(response.headers().get("Location").unwrap().as_str())
                                .unwrap();
                        response = Request::new(&redirect_uri)
                            .header("User-Agent", "wasmer.io self update")
                            .send(&mut file)
                            .map_err(anyhow::Error::new)
                            .context("Could not lookup wasmer artifact on Github.")?;
                    }
                    Ok(response)
                });
            let _sleep_dur = std::time::Duration::from_millis(1);
            let _sleep_ctr = std::time::Duration::from_millis(0);

            println!();

            /*
            while !download_thread.is_finished() {
                sleep_ctr = sleep_ctr.checked_add(sleep_dur).unwrap_or(sleep_ctr);
                match std::fs::metadata(&filename) {
                    Ok(v) => {
                        print!("\r{} bytes", v.len());
                        std::io::stdout().flush();
                    }
                    Err(err) => {
                        println!("Could not read `{}` file metadata: {}", &filename, err);
                    }
                }
                std::thread::sleep(sleep_dur);
            }
            println!();
            */
            let _response = download_thread
                .join()
                .expect("Could not join downloading thread");
            //file.write_all(&writer)?;
            //println!("downloaded {} bytes to {}", writer.len(), filename);
            return Ok(filename);
        }
    }
    Err(anyhow!("Could not get latest release artifact."))
}

fn install_release(tarball: String, strategy: InstallationStrategy) -> Result<()> {
    let files = std::process::Command::new("tar")
        .arg("-tf")
        .arg(&tarball)
        .output()
        .expect("failed to execute process")
        .stdout;
    let files_s = String::from_utf8(files)?;
    std::dbg!(&files_s); //debug
    let files = files_s
        .lines()
        .filter(|p| !p.ends_with('/'))
        .collect::<Vec<&str>>();
    std::dbg!(&files); //debug
    let _output = std::process::Command::new("tar")
        .arg("-xf")
        .arg(&tarball)
        .output()
        .expect("failed to execute process");
    match strategy {
        InstallationStrategy::SplitBinLibConfig {
            data_dir,
            executable_dir,
        } => {
            for file in files {
                if file.starts_with("bin/") && !file["bin/".len()..].is_empty() {
                    let bin_path = executable_dir.join(&file["bin/".len()..]);
                    println!("Copying {} to {}...", &file, &bin_path.display());
                    std::fs::copy(&file, &bin_path)?;
                } else if file.starts_with("lib/") && !file["lib/".len()..].is_empty() {
                    let lib_path = data_dir.join(&file["lib/".len()..]);
                    println!("Copying {} to {}...", &file, &lib_path.display());
                    std::fs::copy(&file, &lib_path)?;
                } else if file.starts_with("include/") && !file["include/".len()..].is_empty() {
                    let lib_path = data_dir.join(&file["include/".len()..]);
                    println!("Copying {} to {}...", &file, &lib_path.display());
                    std::fs::copy(&file, &lib_path)?;
                }
            }
        }
        InstallationStrategy::SingleInstallPath(path) => {
            if !path.exists() {
                println!("Creating directory {}...", path.display());
                std::fs::create_dir_all(&path)?;
            }
            for subdir in ["bin", "lib", "include"] {
                if !path.join(subdir).exists() {
                    println!("Creating directory {}...", path.join(subdir).display());
                    std::fs::create_dir_all(&path.join(subdir))?;
                }
            }
            for file in files {
                if file.starts_with("bin/") && !file["bin/".len()..].is_empty() {
                    let bin_path = path.join(&file);
                    println!("Copying {} to {}...", &file, &bin_path.display());
                    std::fs::copy(&file, &bin_path)?;
                } else if file.starts_with("lib/") && !file["lib/".len()..].is_empty() {
                    let lib_path = path.join(&file);
                    println!("Copying {} to {}...", &file, &lib_path.display());
                    std::fs::copy(&file, &lib_path)?;
                } else if file.starts_with("include/") && !file["include/".len()..].is_empty() {
                    let lib_path = path.join(&file);
                    println!("Copying {} to {}...", &file, &lib_path.display());
                    std::fs::copy(&file, &lib_path)?;
                }
            }
        }
        InstallationStrategy::None => return Err(anyhow!("Don't know where to install.")),
    }
    Ok(())
}

fn main() {
    let args = std::env::args().skip(1).collect::<Vec<String>>();

    let strategy = wasmer_path(false).unwrap();
    if args.is_empty() {
        let latest = get_latest_release().unwrap();
        let cwd = std::env::current_dir().unwrap();
        let tmp_dir = TempDir::new().unwrap();
        println!("tmp_dir is {}", tmp_dir.path().display()); // debug
        std::env::set_current_dir(tmp_dir.path()).unwrap();
        let result =
            download_release(latest).and_then(|tarball| install_release(tarball, strategy));
        std::env::set_current_dir(&cwd).unwrap();
        tmp_dir.close().unwrap();
        result.unwrap();
    } else if args.last().map(String::as_str) == Some("print") {
        let latest = get_latest_release().unwrap();
        println!("{}", latest["name"]);
    } else if ["help", "--help", "-h"].contains(&args[0].as_str()) {
        println!(r#"wasmer-install [--help|-h] [print]"#);
    }
}
