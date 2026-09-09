use super::{normalize_document, normalize_table};

#[test]
fn synthetic_invoice_preserves_empty_cells_currency_and_suffix() {
    let source = include_str!("../tests/fixtures/ocr-tables/invoice.raw.md");
    let result = normalize_document(source).unwrap();
    assert!(result.contains("| Discount |  |  | -$6.50 |"));
    assert!(result.contains("| Total |  |  | $120.00 |"));
    assert!(result.ends_with("<Payment due: 2026-09-30. Thank you."));
    assert!(!result.contains("<table"));
}

#[test]
fn actual_finance_reconstructs_only_the_omitted_row_start_and_retains_spans() {
    let source = include_str!("../tests/fixtures/ocr-tables/finance.raw.md");
    let result = normalize_document(source).unwrap();
    assert_eq!(result.matches("<tr>").count(), 5);
    assert_eq!(result.matches("colspan=\"2\"").count(), 2);
    assert_eq!(result.matches("rowspan=\"2\"").count(), 1);
    assert_eq!(result.matches("<th ").count(), 7);
    assert_eq!(result.matches("<td ").count(), 15);
    assert!(result.contains("Totals are synthetic."));
}

#[test]
fn actual_schedule_preserves_row_spans_and_entities() {
    let source = include_str!("../tests/fixtures/ocr-tables/schedule.raw.md");
    let result = normalize_document(source).unwrap();
    assert_eq!(result.matches("rowspan=\"2\"").count(), 2);
    assert!(result.contains("Q&amp;A"));
    assert_eq!(result.matches("<td ").count(), 14);
    assert!(result.contains("Bring a laptop."));
}

#[test]
fn mixed_row_headers_and_inline_content_stay_native_html() {
    let source = "<table><tr><th>Key</th><th>Value</th></tr><tr><th scope='row'>Command</th><td><code>--foo=a|b</code><br>A&amp;B <strong>safe</strong></td></tr></table>";
    let result = normalize_table(source).unwrap();
    assert!(result.contains("<code>--foo=a|b</code><br/>A&amp;B <strong>safe</strong>"));
    assert_eq!(result.matches("<th ").count(), 3);
    assert_eq!(result.matches("<td ").count(), 1);
}

#[test]
fn attributes_do_not_confuse_tag_boundaries_or_content() {
    let source = "<TABLE class='a > b'><TR><TH>A<TH>B<TR><TD>&#x41;&nbsp;&copy;<TD>x|y</TABLE>";
    assert_eq!(
        normalize_table(source).unwrap(),
        "| A | B |\n| --- | --- |\n| A © | x\\|y |"
    );
}

#[test]
fn literals_in_code_fences_inline_code_and_indented_code_are_preserved() {
    let source = "# Guide\n\n```html\n<table><tr><td>code</td></tr></table>\n```\n\n`<table>`\n\n    <table>\n";
    assert_eq!(normalize_document(source).unwrap(), source.trim());
    let mixed = format!("{source}\n<table><tr><th>A</th></tr><tr><td>B</td></tr></table>");
    let result = normalize_document(&mixed).unwrap();
    assert!(result.contains("<td>code</td>"));
    assert!(result.ends_with("| A |\n| --- |\n| B |"));
}

#[test]
fn reject_dangerous_truncated_nested_or_invalid_span_geometry() {
    for table in [
        "<table><tr><td>A</td></tr>",
        "<table><tr><td><script>alert(1)</script></td></tr></table>",
        "<table><tr><td style='display:none'>hidden</td></tr></table>",
        "<table><tr><td><table><tr><td>nested</td></tr></table></td></tr></table>",
        "<table><tr><td rowspan='99'>A</td></tr></table>",
        "<table><tr><td rowspan='2'>A</td></tr></table>",
        "<table><tr><td>A</td><td>B</td></tr><tr><td>C</td></tr></table>",
        "<table><tr><td rowspan='1' rowspan='2'>A</td></tr></table>",
        "<table><tr><td><b>A</td></tr></table>",
    ] {
        assert!(normalize_document(table).is_none(), "{table}");
    }
}

#[test]
fn exact_names_never_parse_thead_as_th_or_track_as_tr() {
    assert!(normalize_table("<table><track><td>x</td></track></table>").is_none());
    let result = normalize_table("<table><thead><tr><th>A</th><th>B</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>").unwrap();
    assert_eq!(result.lines().count(), 3);
}

#[test]
fn captions_and_multiple_tables_keep_document_order_without_deduplication() {
    let source = include_str!("../tests/fixtures/ocr-tables/keyvalue.raw.md");
    let result = normalize_document(source).unwrap();
    assert_eq!(result.matches("| Property | Value |").count(), 3);
    assert_eq!(result.matches("Synthetic test host.").count(), 1);
    let result = normalize_document("Before<table><caption>Caption</caption><tr><th>A</th></tr><tr><td>B</td></tr></table>After").unwrap();
    assert_eq!(
        result,
        "Before\n\nCaption\n\n| A |\n| --- |\n| B |\n\nAfter"
    );
}

#[test]
fn ambiguous_gfm_extra_pipe_is_rejected_not_silently_reassigned() {
    let source = include_str!("../tests/fixtures/ocr-tables/api.raw.md");
    assert!(normalize_document(source).is_none());
    let valid = source.replace("ready | pending", "ready \\| pending");
    assert_eq!(
        normalize_document(&valid).unwrap(),
        valid.trim().replace("<br>", "\u{2028}")
    );
    assert!(normalize_document("| A | B |\n| --- | --- |\n| x | `a|b` |").is_some());
}

#[test]
fn bilingual_gfm_preserves_every_character() {
    let source = include_str!("../tests/fixtures/ocr-tables/bilingual.raw.md");
    assert_eq!(normalize_document(source).unwrap(), source.trim());
}

#[test]
fn generate_synthetic_projection_evidence_when_explicitly_requested() {
    let Ok(directory) = std::env::var("MARLA_OCR_EVAL_DIR") else {
        return;
    };
    for name in [
        "invoice",
        "api",
        "comparison",
        "bilingual",
        "keyvalue",
        "finance",
        "schedule",
    ] {
        let source = std::fs::read_to_string(format!("{directory}/{name}.raw.md")).unwrap();
        let result = normalize_document(&source);
        if let Some(markdown) = result {
            std::fs::write(format!("{directory}/{name}.normalized.md"), markdown).unwrap();
        }
    }
}

#[test]
fn prose_formatting_and_table_cell_breaks_are_normalized_outside_code_only() {
    let source = "<b>After</b> and <em>note</em> with `<b>literal</b>`";
    assert_eq!(
        normalize_document(source).unwrap(),
        "**After** and *note* with `<b>literal</b>`"
    );
}

#[test]
fn checked_in_native_projection_fixtures_match_the_current_normalizer() {
    for (raw, canonical) in [
        (
            include_str!("../tests/fixtures/ocr-tables/finance.raw.md"),
            include_str!("../tests/fixtures/ocr-tables/finance.canonical.md"),
        ),
        (
            include_str!("../tests/fixtures/ocr-tables/schedule.raw.md"),
            include_str!("../tests/fixtures/ocr-tables/schedule.canonical.md"),
        ),
        (
            include_str!("../tests/fixtures/ocr-tables/invoice.raw.md"),
            include_str!("../tests/fixtures/ocr-tables/invoice.canonical.md"),
        ),
        (
            include_str!("../tests/fixtures/ocr-tables/comparison.raw.md"),
            include_str!("../tests/fixtures/ocr-tables/comparison.canonical.md"),
        ),
        (
            include_str!("../tests/fixtures/ocr-tables/keyvalue.raw.md"),
            include_str!("../tests/fixtures/ocr-tables/keyvalue.canonical.md"),
        ),
        (
            include_str!("../tests/fixtures/ocr-tables/bilingual.raw.md"),
            include_str!("../tests/fixtures/ocr-tables/bilingual.canonical.md"),
        ),
    ] {
        assert_eq!(normalize_document(raw).unwrap(), canonical);
    }
}
