use super::tests::{
    run_ffi_in_place_request, run_ffi_request_with_model, spawn_http_server, valid_request,
};
use super::{
    EndpointProtocol, InPlaceSourceBlock, StreamContentMode, qwen_in_place_source,
    translation_stream_content_mode,
};
use std::time::Duration;

fn stream_frame(content: &str, finished: bool) -> String {
    let event = serde_json::json!({
        "choices": [{
            "delta": {"content": content},
            "finish_reason": if finished { Some("stop") } else { None }
        }]
    });
    format!("data: {event}\n\n")
}

#[test]
fn stream_mode_respects_bounded_model_families_and_explicit_protocols() {
    let mut endpoint = valid_request().endpoint;
    for model in [
        "qwen-mt-flash",
        "qwen-mt-lite",
        " QWEN-MT-FLASH ",
        "qwen-mt-flash-2025-09-15",
        "qwen-mt-lite-2025-09-15",
    ] {
        endpoint.model = model.to_string();
        assert_eq!(
            translation_stream_content_mode(&endpoint),
            StreamContentMode::Delta
        );
    }
    for model in [
        "qwen-mt-turbo",
        "qwen-mt-plus",
        "qwen-mt-plus-2025-09-15",
        "qwen-mt-flashlight",
        "qwen-mt-literature",
        "qwen-mt-unknown",
    ] {
        endpoint.model = model.to_string();
        assert_eq!(
            translation_stream_content_mode(&endpoint),
            StreamContentMode::Cumulative
        );
    }
    for protocol in [
        EndpointProtocol::OpenAIResponses,
        EndpointProtocol::AnthropicMessages,
        EndpointProtocol::GoogleGemini,
    ] {
        endpoint.provider_protocol = protocol;
        endpoint.model = "qwen-mt-plus".to_string();
        assert_eq!(
            translation_stream_content_mode(&endpoint),
            StreamContentMode::Delta
        );
    }
    endpoint.provider_protocol = EndpointProtocol::OpenAICompatible;
    endpoint.model = "qwen-flash".to_string();
    assert_eq!(
        translation_stream_content_mode(&endpoint),
        StreamContentMode::Delta
    );
}

#[test]
fn flash_and_lite_preserve_incremental_repeated_and_unicode_chunks() {
    // Repeating the first chunk is valid delta content, even though it also
    // resembles a duplicate cumulative snapshot. No text-based guessing.
    let chunks = ["", "What", "What", " is ", "你好", "\n", "**done**"];
    for model in ["qwen-mt-flash", "qwen-mt-lite"] {
        for use_done_marker in [false, true] {
            let mut body = chunks
                .iter()
                .map(|chunk| stream_frame(chunk, false))
                .collect::<String>();
            if use_done_marker {
                body.push_str("data: [DONE]\n\n");
            } else {
                body.push_str(&stream_frame("", true));
            }
            let (base_url, captured) = spawn_http_server("200 OK", &body);
            let events = run_ffi_request_with_model(&base_url, 3, model);
            let request = captured.recv_timeout(Duration::from_secs(2)).unwrap();
            let payload: serde_json::Value =
                serde_json::from_str(request.split_once("\r\n\r\n").unwrap().1).unwrap();
            assert_eq!(payload["messages"].as_array().unwrap().len(), 1);
            assert_eq!(payload["messages"][0]["role"], "user");
            assert_eq!(payload["translation_options"]["source_lang"], "English");
            assert_eq!(payload["translation_options"]["target_lang"], "Chinese");
            assert!(payload.get("incremental_output").is_none());
            assert!(payload.get("enable_thinking").is_none());
            let deltas = events
                .iter()
                .filter(|event| event["type"] == "delta")
                .map(|event| event["text"].as_str().unwrap())
                .collect::<Vec<_>>();
            assert_eq!(deltas, chunks[1..], "model: {model}, events: {events:?}");
            assert_eq!(events.last().unwrap()["type"], "completed");
            assert_eq!(events.last().unwrap()["text"], chunks.concat());
        }
    }
}

#[test]
fn flash_in_place_validates_incremental_boundaries_without_partial_deltas() {
    let blocks = vec![InPlaceSourceBlock {
        id: "paragraph-1".to_string(),
        kind: "paragraph".to_string(),
        source_text: "Open https://example.com with API_TOKEN".to_string(),
    }];
    let translated = qwen_in_place_source(&blocks, "00000000-0000-0000-0000-000000000020").replace(
        "Open https://example.com with API_TOKEN",
        "使用 API_TOKEN 打开 https://example.com",
    );
    // Split the exact boundary and Chinese text across events, as real tokens do.
    let mut body = translated
        .chars()
        .map(|character| stream_frame(&character.to_string(), false))
        .collect::<String>();
    body.push_str(&stream_frame("", true));
    let (base_url, _captured) = spawn_http_server("200 OK", &body);
    let events = run_ffi_in_place_request(&base_url, 3, "qwen-mt-flash", &blocks);
    assert_eq!(
        events
            .iter()
            .map(|event| event["type"].as_str().unwrap())
            .collect::<Vec<_>>(),
        vec!["started", "completed"],
        "events: {events:?}"
    );
    let canonical: serde_json::Value =
        serde_json::from_str(events.last().unwrap()["text"].as_str().unwrap()).unwrap();
    assert_eq!(
        canonical,
        serde_json::json!({"blocks": [{
            "id": "paragraph-1", "text": "使用 API_TOKEN 打开 https://example.com"
        }]})
    );
}

#[test]
fn turbo_and_plus_preserve_cumulative_snapshots_and_empty_stop() {
    let body = ["", "玛", "玛拉", "玛", "玛拉"]
        .iter()
        .map(|chunk| stream_frame(chunk, false))
        .chain(std::iter::once(stream_frame("", true)))
        .collect::<String>();
    for model in ["qwen-mt-turbo", "qwen-mt-plus"] {
        let (base_url, _captured) = spawn_http_server("200 OK", &body);
        let events = run_ffi_request_with_model(&base_url, 3, model);
        assert_eq!(events.last().unwrap()["type"], "completed");
        assert_eq!(
            events
                .iter()
                .filter_map(|event| event["text"].as_str())
                .collect::<Vec<_>>(),
            vec!["玛", "拉", "玛拉"]
        );
    }
}

#[test]
fn discontinuous_legacy_cumulative_stream_still_fails() {
    let body = stream_frame("玛", false) + &stream_frame("不同", true);
    for model in ["qwen-mt-turbo", "qwen-mt-plus"] {
        let (base_url, _captured) = spawn_http_server("200 OK", &body);
        let events = run_ffi_request_with_model(&base_url, 3, model);
        assert_eq!(events[1]["text"], "玛");
        assert_eq!(events.last().unwrap()["type"], "failed");
        assert_eq!(events.last().unwrap()["code"], "invalid_response");
    }
}

#[test]
fn flash_in_place_still_rejects_invalid_boundaries_and_protected_payloads() {
    let blocks = vec![InPlaceSourceBlock {
        id: "paragraph-1".to_string(),
        kind: "paragraph".to_string(),
        source_text: "Open https://example.com with API_TOKEN".to_string(),
    }];
    let payload = qwen_in_place_source(&blocks, "00000000-0000-0000-0000-000000000020");
    for invalid in [
        payload.replace("_BEGIN", "_BROKEN"),
        payload.replace("https://example.com", "https://changed.example"),
    ] {
        let body = invalid
            .chars()
            .map(|character| stream_frame(&character.to_string(), false))
            .chain(std::iter::once(stream_frame("", true)))
            .collect::<String>();
        let (base_url, _captured) = spawn_http_server("200 OK", &body);
        let events = run_ffi_in_place_request(&base_url, 3, "qwen-mt-flash", &blocks);
        assert_eq!(
            events
                .iter()
                .map(|event| event["type"].as_str().unwrap())
                .collect::<Vec<_>>(),
            vec!["started", "failed"]
        );
        assert_eq!(events.last().unwrap()["code"], "invalid_response");
    }
}
