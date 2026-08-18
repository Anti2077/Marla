use std::env;
use std::fs;
use std::io::{self, Read, Write};
use std::net::TcpListener;
use std::thread;
use std::time::Duration;

fn main() {
    let mut arguments = env::args().skip(1);
    let sample_count = arguments
        .next()
        .and_then(|value| value.parse::<usize>().ok())
        .expect("usage: performance_sse_server <sample-count> <url-file>");
    let url_file = arguments
        .next()
        .expect("usage: performance_sse_server <sample-count> <url-file>");
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind local performance server");
    let address = listener
        .local_addr()
        .expect("read local performance address");
    fs::write(&url_file, format!("http://{address}/v1")).expect("write local server URL");

    for _ in 0..sample_count {
        let (mut stream, _) = listener.accept().expect("accept local performance request");
        stream
            .set_read_timeout(Some(Duration::from_secs(2)))
            .expect("set request read timeout");
        read_request(&mut stream);
        stream
            .write_all(
                b"HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n",
            )
            .expect("write response headers");
        write_chunk(
            &mut stream,
            "data: {\"choices\":[{\"delta\":{\"content\":\"local delta\"}}]}\n\n",
        )
        .expect("write local delta");
        stream.flush().expect("flush local delta");
        thread::sleep(Duration::from_millis(120));
        // The performance fixture exits as soon as the first delta becomes
        // visible. A closed client at this point is therefore expected, and
        // must not stop the server before later samples can connect.
        if write_chunk(&mut stream, "data: [DONE]\n\n").is_ok() {
            let _ = stream.write_all(b"0\r\n\r\n");
            let _ = stream.flush();
        }
    }
}

fn read_request(stream: &mut impl Read) {
    let mut request = Vec::new();
    let mut buffer = [0_u8; 4096];
    loop {
        match stream.read(&mut buffer) {
            Ok(0) | Err(_) => break,
            Ok(count) => {
                request.extend_from_slice(&buffer[..count]);
                let Some(header_end) = request.windows(4).position(|bytes| bytes == b"\r\n\r\n")
                else {
                    continue;
                };
                let headers = String::from_utf8_lossy(&request[..header_end + 4]);
                let content_length = headers
                    .lines()
                    .find_map(|line| {
                        line.to_ascii_lowercase()
                            .strip_prefix("content-length:")
                            .and_then(|value| value.trim().parse::<usize>().ok())
                    })
                    .unwrap_or_default();
                if request.len() >= header_end + 4 + content_length {
                    break;
                }
            }
        }
    }
}

fn write_chunk(stream: &mut impl Write, value: &str) -> io::Result<()> {
    write!(stream, "{:X}\r\n{value}\r\n", value.len())
}
