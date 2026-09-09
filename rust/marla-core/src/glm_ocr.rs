use crate::{CancellationSignal, MarlaTranslationEventCallback};
use reqwest::header::{AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::sync::Arc;
use std::time::Duration;

const GLM_OCR_URL: &str = "https://open.bigmodel.cn/api/paas/v4/layout_parsing";
const OLLAMA_GLM_OCR_URL: &str = "http://127.0.0.1:11434/api/generate";

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct OCRRequest {
    pub(crate) schema_version: u32,
    #[serde(rename = "requestID")]
    pub(crate) request_id: String,
    pub(crate) image_base64: String,
    pub(crate) mime_type: String,
    pub(crate) api_key: String,
    #[serde(default = "default_provider")]
    pub(crate) provider: String,
    #[serde(default)]
    pub(crate) timeouts: OCRTimeouts,
}

fn default_provider() -> String {
    "glmOCR".to_owned()
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct OCRTimeouts {
    #[serde(default = "default_connect_timeout")]
    connect_seconds: u64,
    #[serde(default = "default_overall_timeout")]
    overall_seconds: u64,
}

impl Default for OCRTimeouts {
    fn default() -> Self {
        Self {
            connect_seconds: default_connect_timeout(),
            overall_seconds: default_overall_timeout(),
        }
    }
}

fn default_connect_timeout() -> u64 {
    10
}

fn default_overall_timeout() -> u64 {
    60
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct OCREvent<'a> {
    schema_version: u32,
    #[serde(rename = "requestID")]
    request_id: &'a str,
    #[serde(rename = "type")]
    event_type: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<&'a OCRResult>,
    #[serde(skip_serializing_if = "Option::is_none")]
    code: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    message: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    retryable: Option<bool>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct OCRResult {
    provider: &'static str,
    document: OCRDocument,
    content: TranslationContent,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct OCRDocument {
    blocks: Vec<ContentBlock>,
    detected_language: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ContentBlock {
    id: String,
    kind: &'static str,
    source_text: String,
    bounds: Option<NormalizedRect>,
    reading_order: usize,
    confidence: Option<f64>,
}

#[derive(Clone, Copy, Debug, Serialize)]
struct NormalizedRect {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct TranslationContent {
    format: &'static str,
    text: String,
}

#[derive(Clone, Copy)]
struct PageDimensions {
    width: f64,
    height: f64,
}

pub(crate) async fn run(
    request: OCRRequest,
    cancellation: Arc<CancellationSignal>,
    callback: MarlaTranslationEventCallback,
    context_value: usize,
) {
    let is_ollama = request.provider == "ollamaGLMOCR";
    let endpoint = if is_ollama {
        OLLAMA_GLM_OCR_URL
    } else {
        GLM_OCR_URL
    };
    run_at_url(
        request,
        cancellation,
        callback,
        context_value,
        endpoint,
        is_ollama,
    )
    .await;
}

async fn run_at_url(
    request: OCRRequest,
    cancellation: Arc<CancellationSignal>,
    callback: MarlaTranslationEventCallback,
    context_value: usize,
    endpoint_url: &str,
    is_ollama: bool,
) {
    let context = || context_value as *mut std::ffi::c_void;
    let request_id = request.request_id.clone();
    if request.schema_version != 1
        || request_id.is_empty()
        || request.image_base64.is_empty()
        || (!is_ollama && request.api_key.trim().is_empty())
        || !matches!(request.mime_type.as_str(), "image/png" | "image/jpeg")
    {
        emit_failed(
            callback,
            context(),
            &request_id,
            "invalid_configuration",
            if is_ollama {
                "本机 Ollama GLM-OCR 请求配置无效。"
            } else {
                "GLM-OCR 请求配置无效。"
            },
            false,
        );
        return;
    }

    emit(
        callback,
        context(),
        OCREvent {
            schema_version: 1,
            request_id: &request_id,
            event_type: "started",
            result: None,
            code: None,
            message: None,
            retryable: None,
        },
    );

    let client = match reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(request.timeouts.connect_seconds.max(1)))
        .build()
    {
        Ok(client) => client,
        Err(_) => {
            emit_failed(
                callback,
                context(),
                &request_id,
                "internal",
                "无法创建 GLM-OCR 网络客户端。",
                true,
            );
            return;
        }
    };
    let body = if is_ollama {
        json!({
            "model": "glm-ocr",
            "prompt": "Read all visible text in reading order. Return only GitHub-Flavored Markdown. Use pipe tables for every table. Use headings, lists, and fenced code blocks when visible. Do not add commentary or HTML tags.",
            "images": [request.image_base64],
            "stream": false,
            "options": {"temperature": 0}
        })
    } else {
        json!({
            "model": "glm-ocr",
            "file": format!("data:{};base64,{}", request.mime_type, request.image_base64),
            "return_crop_images": false,
            "need_layout_visualization": false,
            "request_id": request_id,
        })
    };
    let mut builder = client
        .post(endpoint_url)
        .header(CONTENT_TYPE, "application/json")
        .json(&body);
    if !is_ollama {
        builder = builder.header(AUTHORIZATION, request.api_key.trim());
    }
    let response = tokio::select! {
        _ = cancellation.wait() => {
            emit_cancelled(callback, context(), &request_id);
            return;
        }
        result = tokio::time::timeout(
            Duration::from_secs(request.timeouts.overall_seconds.max(1)),
            builder.send()
        ) => match result {
            Ok(Ok(response)) => response,
            Ok(Err(_)) => {
                emit_failed(
                    callback,
                    context(),
                    &request_id,
                    "network",
                    if is_ollama { "无法连接本机 Ollama GLM-OCR。" } else { "无法连接 GLM-OCR。" },
                    true,
                );
                return;
            }
            Err(_) => {
                emit_failed(
                    callback,
                    context(),
                    &request_id,
                    "timeout",
                    if is_ollama { "本机 Ollama GLM-OCR 识别超时。" } else { "GLM-OCR 结构识别超时。" },
                    true,
                );
                return;
            }
        }
    };

    if cancellation.is_cancelled() {
        emit_cancelled(callback, context(), &request_id);
        return;
    }
    let status = response.status();
    if !is_ollama
        && (status == reqwest::StatusCode::UNAUTHORIZED || status == reqwest::StatusCode::FORBIDDEN)
    {
        emit_failed(
            callback,
            context(),
            &request_id,
            "unauthorized",
            "GLM-OCR API Key 未授权。",
            true,
        );
        return;
    }
    if !is_ollama && status == reqwest::StatusCode::TOO_MANY_REQUESTS {
        emit_failed(
            callback,
            context(),
            &request_id,
            "rate_limited",
            "GLM-OCR 暂时限流。",
            true,
        );
        return;
    }
    if !status.is_success() {
        emit_failed(
            callback,
            context(),
            &request_id,
            "provider",
            if is_ollama {
                "本机 Ollama GLM-OCR 返回了错误。"
            } else {
                "GLM-OCR 返回了错误。"
            },
            true,
        );
        return;
    }

    let decoded = tokio::select! {
        _ = cancellation.wait() => {
            emit_cancelled(callback, context(), &request_id);
            return;
        }
        result = tokio::time::timeout(
            Duration::from_secs(request.timeouts.overall_seconds.max(1)),
            response.json::<Value>()
        ) => match result {
            Ok(Ok(value)) => value,
            Ok(Err(_)) => {
                emit_failed(
                    callback,
                    context(),
                    &request_id,
                    "invalid_response",
                    if is_ollama { "本机 Ollama GLM-OCR 响应格式无效。" } else { "GLM-OCR 响应格式无效。" },
                    true,
                );
                return;
            }
            Err(_) => {
                emit_failed(
                    callback,
                    context(),
                    &request_id,
                    "timeout",
                    if is_ollama { "读取本机 Ollama GLM-OCR 响应超时。" } else { "读取 GLM-OCR 响应超时。" },
                    true,
                );
                return;
            }
        }
    };
    let Some(result) = normalize_response(&decoded, is_ollama) else {
        emit_failed(
            callback,
            context(),
            &request_id,
            "invalid_response",
            if is_ollama {
                "本机 Ollama GLM-OCR 没有返回可安全解析的文字或表格。"
            } else {
                "GLM-OCR 没有返回可安全使用的结构化文字。"
            },
            true,
        );
        return;
    };
    emit(
        callback,
        context(),
        OCREvent {
            schema_version: 1,
            request_id: &request_id,
            event_type: "completed",
            result: Some(&result),
            code: None,
            message: None,
            retryable: None,
        },
    );
}

fn normalize_response(value: &Value, is_ollama: bool) -> Option<OCRResult> {
    if is_ollama {
        let text = find_key(value, "response")?.as_str()?.trim();
        if text.is_empty() {
            return None;
        }
        let normalized_text = crate::ocr_table::normalize_document(text)?;
        return Some(OCRResult {
            provider: "ollamaGLMOCR",
            document: OCRDocument {
                blocks: vec![ContentBlock {
                    id: "page-0001-block-0000".to_owned(),
                    kind: "paragraph",
                    source_text: normalized_text.clone(),
                    bounds: None,
                    reading_order: 0,
                    confidence: None,
                }],
                detected_language: None,
            },
            content: TranslationContent {
                format: "semanticMarkdown",
                text: normalized_text,
            },
        });
    }
    let layout = find_key(value, "layout_details")?;
    let mut blocks = Vec::new();
    collect_blocks(layout, None, &mut blocks);
    blocks.sort_by_key(|block| block.reading_order);
    for (index, block) in blocks.iter_mut().enumerate() {
        block.reading_order = index;
        block.id = format!("page-0001-block-{index:04}");
    }
    let markdown = reconstruct_markdown(&blocks);
    if markdown.trim().is_empty() {
        return None;
    }
    Some(OCRResult {
        provider: "glmOCR",
        document: OCRDocument {
            blocks,
            detected_language: None,
        },
        content: TranslationContent {
            format: "semanticMarkdown",
            text: markdown,
        },
    })
}

fn find_key<'a>(value: &'a Value, key: &str) -> Option<&'a Value> {
    match value {
        Value::Object(object) => object
            .get(key)
            .or_else(|| object.values().find_map(|child| find_key(child, key))),
        Value::Array(array) => array.iter().find_map(|child| find_key(child, key)),
        _ => None,
    }
}

fn collect_blocks(
    value: &Value,
    inherited_dimensions: Option<PageDimensions>,
    blocks: &mut Vec<ContentBlock>,
) {
    match value {
        Value::Array(array) => {
            for child in array {
                collect_blocks(child, inherited_dimensions, blocks);
            }
        }
        Value::Object(object) => {
            let dimensions = dimensions(object).or(inherited_dimensions);
            if let Some(source_text) = block_text(object) {
                let trimmed = source_text.trim();
                if !trimmed.is_empty() {
                    let label = string_field(object, &["label", "type", "category", "block_type"])
                        .unwrap_or("paragraph");
                    let reading_order = number_field(object, &["index", "reading_order", "order"])
                        .map(|value| value.max(0.0) as usize)
                        .unwrap_or(blocks.len());
                    blocks.push(ContentBlock {
                        id: String::new(),
                        kind: block_kind(label),
                        source_text: trimmed.to_owned(),
                        bounds: normalized_bounds(object, dimensions),
                        reading_order,
                        confidence: number_field(object, &["confidence", "score"])
                            .filter(|value| (0.0..=1.0).contains(value)),
                    });
                    return;
                }
            }
            for child in object.values() {
                collect_blocks(child, dimensions, blocks);
            }
        }
        _ => {}
    }
}

fn dimensions(object: &serde_json::Map<String, Value>) -> Option<PageDimensions> {
    let width = number_field(object, &["width", "page_width", "image_width"])?;
    let height = number_field(object, &["height", "page_height", "image_height"])?;
    (width > 0.0 && height > 0.0).then_some(PageDimensions { width, height })
}

fn block_text(object: &serde_json::Map<String, Value>) -> Option<String> {
    for key in ["content", "text", "markdown"] {
        if let Some(Value::String(value)) = object.get(key) {
            return Some(value.clone());
        }
    }
    None
}

fn string_field<'a>(object: &'a serde_json::Map<String, Value>, keys: &[&str]) -> Option<&'a str> {
    keys.iter().find_map(|key| object.get(*key)?.as_str())
}

fn number_field(object: &serde_json::Map<String, Value>, keys: &[&str]) -> Option<f64> {
    keys.iter().find_map(|key| object.get(*key)?.as_f64())
}

fn normalized_bounds(
    object: &serde_json::Map<String, Value>,
    dimensions: Option<PageDimensions>,
) -> Option<NormalizedRect> {
    let bbox = object
        .get("bbox_2d")
        .or_else(|| object.get("bbox"))?
        .as_array()?;
    if bbox.len() != 4 {
        return None;
    }
    let x1 = bbox[0].as_f64()?;
    let y1 = bbox[1].as_f64()?;
    let x2 = bbox[2].as_f64()?;
    let y2 = bbox[3].as_f64()?;
    let coordinates_are_normalized = [x1, y1, x2, y2]
        .iter()
        .all(|value| (0.0..=1.0).contains(value));
    let (x1, y1, x2, y2) = if coordinates_are_normalized {
        (x1, y1, x2, y2)
    } else {
        let dimensions = dimensions?;
        (
            x1 / dimensions.width,
            y1 / dimensions.height,
            x2 / dimensions.width,
            y2 / dimensions.height,
        )
    };
    if ![x1, y1, x2, y2].iter().all(|value| value.is_finite())
        || x1 < 0.0
        || y1 < 0.0
        || x2 > 1.0
        || y2 > 1.0
        || x2 <= x1
        || y2 <= y1
    {
        return None;
    }
    Some(NormalizedRect {
        x: x1,
        y: y1,
        width: x2 - x1,
        height: y2 - y1,
    })
}

fn block_kind(label: &str) -> &'static str {
    let label = label.to_ascii_lowercase();
    if label.contains("title") && !label.contains("caption") {
        if label.contains("doc") {
            "title"
        } else {
            "heading"
        }
    } else if label.contains("table") && label.contains("caption") {
        "caption"
    } else if label.contains("table") {
        "table"
    } else if label.contains("formula") || label.contains("equation") {
        "formula"
    } else if label.contains("code") || label.contains("algorithm") {
        "code"
    } else if label.contains("list") {
        "listItem"
    } else if label.contains("caption") {
        "caption"
    } else if label.contains("text") || label.contains("paragraph") {
        "paragraph"
    } else {
        "other"
    }
}

fn reconstruct_markdown(blocks: &[ContentBlock]) -> String {
    blocks
        .iter()
        .filter_map(|block| {
            let text = block.source_text.trim();
            if text.is_empty() {
                return None;
            }
            Some(match block.kind {
                "title" => format!("# {}", collapse_inline_whitespace(text)),
                "heading" => format!("## {}", collapse_inline_whitespace(text)),
                "listItem" => format!("- {}", collapse_inline_whitespace(text)),
                "code" => format!("```\n{text}\n```"),
                "formula" => format!("$$\n{text}\n$$"),
                "table" => html_table_to_gfm(text).unwrap_or_else(|| text.to_owned()),
                _ => text.to_owned(),
            })
        })
        .collect::<Vec<_>>()
        .join("\n\n")
}

fn collapse_inline_whitespace(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn html_table_to_gfm(html: &str) -> Option<String> {
    let normalized = crate::ocr_table::normalize_table(html)?;
    // Cloud layout's table consumers still require a rectangular GFM projection.
    (!normalized.contains("<table>")).then_some(normalized)
}

fn emit(
    callback: MarlaTranslationEventCallback,
    context: *mut std::ffi::c_void,
    event: OCREvent<'_>,
) {
    let Ok(payload) = serde_json::to_vec(&event) else {
        return;
    };
    // SAFETY: Payload remains valid for this synchronous callback; the Swift bridge copies it.
    unsafe { callback(payload.as_ptr(), payload.len(), context) };
}

fn emit_failed(
    callback: MarlaTranslationEventCallback,
    context: *mut std::ffi::c_void,
    request_id: &str,
    code: &str,
    message: &str,
    retryable: bool,
) {
    emit(
        callback,
        context,
        OCREvent {
            schema_version: 1,
            request_id,
            event_type: "failed",
            result: None,
            code: Some(code),
            message: Some(message),
            retryable: Some(retryable),
        },
    );
}

fn emit_cancelled(
    callback: MarlaTranslationEventCallback,
    context: *mut std::ffi::c_void,
    request_id: &str,
) {
    emit(
        callback,
        context,
        OCREvent {
            schema_version: 1,
            request_id,
            event_type: "cancelled",
            result: None,
            code: None,
            message: None,
            retryable: None,
        },
    );
}

#[cfg(test)]
mod tests {
    use super::{OCRRequest, OCRTimeouts, html_table_to_gfm, normalize_response, run_at_url};
    use crate::CancellationSignal;
    use serde_json::{Value, json};
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::sync::{Arc, Mutex};
    use std::thread;

    #[test]
    fn normalizes_pixel_and_normalized_boxes_into_semantic_markdown() {
        let response = json!({
            "data": {
                "layout_details": [{
                    "width": 1000,
                    "height": 500,
                    "blocks": [
                        {"index": 1, "label": "text", "content": "Body", "bbox_2d": [100, 100, 900, 200]},
                        {"index": 0, "label": "doc_title", "content": "Title", "bbox_2d": [0.1, 0.05, 0.9, 0.15]}
                    ]
                }]
            }
        });
        let result = normalize_response(&response, false).expect("normalized response");
        assert_eq!(result.document.blocks[0].kind, "title");
        assert_eq!(result.document.blocks[1].bounds.expect("bounds").width, 0.8);
        assert_eq!(result.content.text, "# Title\n\nBody");
    }

    #[test]
    fn rejects_out_of_range_or_reversed_layout_boxes() {
        let response = json!({
            "data": {
                "layout_details": [{
                    "width": 1000,
                    "height": 500,
                    "blocks": [
                        {"index": 0, "label": "text", "content": "Outside", "bbox_2d": [900, 20, 1100, 80]},
                        {"index": 1, "label": "text", "content": "Reversed", "bbox_2d": [0.8, 0.2, 0.4, 0.3]}
                    ]
                }]
            }
        });
        let result = normalize_response(&response, false).expect("normalized response");
        assert!(
            result
                .document
                .blocks
                .iter()
                .all(|block| block.bounds.is_none())
        );
        assert_eq!(result.content.text, "Outside\n\nReversed");
    }

    #[test]
    fn converts_safe_literal_html_table_to_gfm() {
        let table =
            "<table><tr><th>Name</th><th>Value</th></tr><tr><td>A</td><td>x|y</td></tr></table>";
        assert_eq!(
            html_table_to_gfm(table).as_deref(),
            Some("| Name | Value |\n| --- | --- |\n| A | x\\|y |")
        );
    }

    #[test]
    fn rejects_a_response_without_canonical_layout_text() {
        assert!(normalize_response(&json!({"md_results": "# untrusted"}), false).is_none());
    }

    #[test]
    fn normalizes_ollama_html_table_inside_surrounding_text() {
        let result = normalize_response(
            &json!({
                "response": "Intro\n<table class=\"table table-bordered\"><thead><tr><th>Path</th><th>Boundary</th></tr></thead><tbody><tr><td>Vision OCR</td><td>Local</td></tr></tbody></table>\nOutro"
            }),
            true,
        )
        .expect("normalized Ollama response");
        assert_eq!(
            result.content.text,
            "Intro\n\n| Path | Boundary |\n| --- | --- |\n| Vision OCR | Local |\n\n\nOutro"
        );
        assert_eq!(result.document.blocks[0].source_text, result.content.text);
    }

    #[test]
    fn normalizes_ollama_response_without_inventing_layout_bounds() {
        let result = normalize_response(
            &json!({"model": "glm-ocr", "response": "# Hello\n\n| A | B |"}),
            true,
        )
        .expect("normalized Ollama response");
        assert_eq!(result.provider, "ollamaGLMOCR");
        assert_eq!(result.content.format, "semanticMarkdown");
        assert_eq!(result.document.blocks.len(), 1);
        assert!(result.document.blocks[0].bounds.is_none());
        assert_eq!(result.content.text, "# Hello\n\n| A | B |");
    }

    #[tokio::test]
    async fn sends_the_fixed_glm_contract_with_raw_authorization_and_normalizes_response() {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind mock server");
        let address = listener.local_addr().expect("mock server address");
        let captured = Arc::new(Mutex::new(String::new()));
        let captured_for_server = Arc::clone(&captured);
        let server = thread::spawn(move || {
            let (mut stream, _) = listener.accept().expect("accept request");
            let mut bytes = Vec::new();
            let mut buffer = [0_u8; 4096];
            loop {
                let count = stream.read(&mut buffer).expect("read request");
                if count == 0 {
                    break;
                }
                bytes.extend_from_slice(&buffer[..count]);
                let request = String::from_utf8_lossy(&bytes);
                if let Some(header_end) = request.find("\r\n\r\n") {
                    let content_length = request[..header_end]
                        .lines()
                        .find_map(|line| {
                            line.to_ascii_lowercase()
                                .strip_prefix("content-length: ")?
                                .parse::<usize>()
                                .ok()
                        })
                        .unwrap_or(0);
                    if bytes.len() >= header_end + 4 + content_length {
                        break;
                    }
                }
            }
            *captured_for_server.lock().expect("capture request") =
                String::from_utf8(bytes).expect("utf8 request");
            let body = json!({
                "data": {"layout_details": [{
                    "width": 100,
                    "height": 100,
                    "blocks": [{"label": "doc_title", "content": "Hello", "bbox_2d": [0, 0, 100, 20]}]
                }]}
            })
            .to_string();
            write!(
                stream,
                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                body.len(),
                body
            )
            .expect("write response");
        });

        let events = Box::new(Mutex::new(Vec::<Value>::new()));
        let context = Box::into_raw(events);
        run_at_url(
            OCRRequest {
                schema_version: 1,
                request_id: "request-33".to_owned(),
                image_base64: "aW1hZ2U=".to_owned(),
                mime_type: "image/png".to_owned(),
                api_key: "raw-secret".to_owned(),
                provider: "glmOCR".to_owned(),
                timeouts: OCRTimeouts::default(),
            },
            Arc::new(CancellationSignal::default()),
            collect_event,
            context as usize,
            &format!("http://{address}/layout_parsing"),
            false,
        )
        .await;
        server.join().expect("server completed");

        let request = captured.lock().expect("captured request");
        assert!(
            request.contains("authorization: raw-secret")
                || request.contains("Authorization: raw-secret")
        );
        assert!(!request.contains("Bearer raw-secret"));
        assert!(request.contains("\"model\":\"glm-ocr\""));
        assert!(request.contains("\"file\":\"data:image/png;base64,aW1hZ2U=\""));
        assert!(request.contains("\"request_id\":\"request-33\""));

        // SAFETY: The callback context was allocated above and is reclaimed exactly once here.
        let events = unsafe { Box::from_raw(context) };
        let events = events.lock().expect("events");
        assert_eq!(
            events.last().and_then(|event| event["type"].as_str()),
            Some("completed")
        );
        assert_eq!(
            events
                .last()
                .and_then(|event| event["result"]["content"]["format"].as_str()),
            Some("semanticMarkdown")
        );
    }

    unsafe extern "C" fn collect_event(
        bytes: *const u8,
        length: usize,
        context: *mut std::ffi::c_void,
    ) {
        if bytes.is_null() || context.is_null() {
            return;
        }
        // SAFETY: The production emitter keeps bytes valid for this callback and the test context
        // points to the live mutex allocated above.
        let payload = unsafe { std::slice::from_raw_parts(bytes, length) };
        let Ok(value) = serde_json::from_slice::<Value>(payload) else {
            return;
        };
        let events = unsafe { &*(context as *const Mutex<Vec<Value>>) };
        events.lock().expect("collect event").push(value);
    }
}
