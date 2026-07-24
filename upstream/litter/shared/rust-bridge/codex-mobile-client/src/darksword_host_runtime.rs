//! Local bridge from Litter's shell tool to the root-owned DarkSword daemon.

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::time::Duration;

const SOCKET_PATH: &str = "/var/jb/var/run/darksword-rootd.sock";
const REQUEST_MAGIC: &[u8; 4] = b"DSR1";
const RESPONSE_MAGIC: &[u8; 4] = b"DSO1";
const MAX_OUTPUT_BYTES: usize = 1_048_576;

pub fn is_available() -> bool {
    Path::new(SOCKET_PATH).exists()
}

fn write_u32(stream: &mut UnixStream, value: u32) -> std::io::Result<()> {
    stream.write_all(&value.to_le_bytes())
}

fn read_u32(stream: &mut UnixStream) -> std::io::Result<u32> {
    let mut bytes = [0u8; 4];
    stream.read_exact(&mut bytes)?;
    Ok(u32::from_le_bytes(bytes))
}

fn read_i32(stream: &mut UnixStream) -> std::io::Result<i32> {
    let mut bytes = [0u8; 4];
    stream.read_exact(&mut bytes)?;
    Ok(i32::from_le_bytes(bytes))
}

pub fn run_streaming<F>(
    command: &str,
    cwd: Option<&str>,
    timeout_ms: Option<u64>,
    on_output: &mut F,
) -> (i32, Vec<u8>)
where
    F: FnMut(&[u8]),
{
    let timeout = timeout_ms.unwrap_or(60_000).clamp(1_000, 300_000);
    let cwd = cwd.unwrap_or("/var/mobile");
    let cwd_bytes = cwd.as_bytes();
    let command_bytes = command.as_bytes();

    if cwd_bytes.len() > u32::MAX as usize || command_bytes.len() > u32::MAX as usize {
        return (-10, b"DarkSword host request is too large\n".to_vec());
    }

    let mut stream = match UnixStream::connect(SOCKET_PATH) {
        Ok(stream) => stream,
        Err(error) => {
            return (
                -7,
                format!("DarkSword root daemon unavailable: {error}\n").into_bytes(),
            );
        }
    };

    let io_timeout = Duration::from_millis(timeout.saturating_add(5_000));
    let _ = stream.set_read_timeout(Some(io_timeout));
    let _ = stream.set_write_timeout(Some(Duration::from_secs(5)));

    let request_result = (|| -> std::io::Result<()> {
        stream.write_all(REQUEST_MAGIC)?;
        write_u32(&mut stream, timeout as u32)?;
        write_u32(&mut stream, cwd_bytes.len() as u32)?;
        write_u32(&mut stream, command_bytes.len() as u32)?;
        stream.write_all(cwd_bytes)?;
        stream.write_all(command_bytes)?;
        stream.flush()?;
        Ok(())
    })();

    if let Err(error) = request_result {
        return (-7, format!("DarkSword request failed: {error}\n").into_bytes());
    }

    let mut magic = [0u8; 4];
    if let Err(error) = stream.read_exact(&mut magic) {
        return (-7, format!("DarkSword response failed: {error}\n").into_bytes());
    }
    if &magic != RESPONSE_MAGIC {
        return (-7, b"DarkSword daemon returned an invalid response\n".to_vec());
    }

    let exit_code = match read_i32(&mut stream) {
        Ok(value) => value,
        Err(error) => return (-7, format!("DarkSword exit status failed: {error}\n").into_bytes()),
    };
    let output_length = match read_u32(&mut stream) {
        Ok(value) => value as usize,
        Err(error) => return (-7, format!("DarkSword output header failed: {error}\n").into_bytes()),
    };

    if output_length > MAX_OUTPUT_BYTES {
        return (-7, b"DarkSword daemon output exceeded the 1 MiB limit\n".to_vec());
    }

    let mut output = vec![0u8; output_length];
    if let Err(error) = stream.read_exact(&mut output) {
        return (-7, format!("DarkSword output read failed: {error}\n").into_bytes());
    }

    if !output.is_empty() {
        on_output(&output);
    }
    (exit_code, output)
}
