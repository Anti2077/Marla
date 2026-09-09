//! Bounded OCR table dialect, not a browser or a general HTML5 implementation.
//! Explicitly repairs omitted row starts/cell end tags; never guesses span geometry.
use std::collections::BTreeMap;

const MAX_ROWS: usize = 128;
const MAX_COLS: usize = 32;
const MAX_BYTES: usize = 256 * 1024;

#[derive(Debug)]
struct Tag {
    name: String,
    closing: bool,
    attrs: BTreeMap<String, String>,
}

#[derive(Default, Debug)]
struct Cell {
    header: bool,
    rowspan: usize,
    colspan: usize,
    html: String,
    text: String,
    rich: bool,
}

#[derive(Default)]
struct Table {
    rows: Vec<Vec<Cell>>,
    row: Option<Vec<Cell>>,
    cell: Option<Cell>,
    inline: Vec<String>,
    caption: String,
    in_caption: bool,
    started: bool,
    ended: bool,
}

fn xml(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn decode(text: &str) -> String {
    let mut out = String::new();
    let mut rest = text;
    while let Some(start) = rest.find('&') {
        out.push_str(&rest[..start]);
        rest = &rest[start..];
        let Some(end) = rest.find(';').filter(|n| *n <= 16) else {
            out.push('&');
            rest = &rest[1..];
            continue;
        };
        let key = &rest[1..end];
        let value = match key {
            "amp" => Some('&'),
            "lt" => Some('<'),
            "gt" => Some('>'),
            "quot" => Some('"'),
            "apos" | "#39" => Some('\''),
            "nbsp" => Some('\u{a0}'),
            "copy" => Some('©'),
            "reg" => Some('®'),
            "euro" => Some('€'),
            "pound" => Some('£'),
            "yen" => Some('¥'),
            "ndash" => Some('–'),
            "mdash" => Some('—'),
            "hellip" => Some('…'),
            _ => key
                .strip_prefix("#x")
                .or_else(|| key.strip_prefix("#X"))
                .and_then(|s| u32::from_str_radix(s, 16).ok())
                .and_then(char::from_u32)
                .or_else(|| {
                    key.strip_prefix('#')
                        .and_then(|s| s.parse().ok())
                        .and_then(char::from_u32)
                }),
        };
        if let Some(value) = value {
            out.push(value);
        } else {
            out.push_str(&rest[..=end]);
        }
        rest = &rest[end + 1..];
    }
    out.push_str(rest);
    out
}

// Quoted '>' is not the end of a tag; tag/attribute names require exact boundaries.
fn tag_at(source: &str) -> Option<(Tag, usize)> {
    let mut quote = None;
    let mut end = None;
    for (i, ch) in source.char_indices().skip(1) {
        if let Some(q) = quote {
            if ch == q {
                quote = None;
            }
        } else if ch == '\'' || ch == '"' {
            quote = Some(ch);
        } else if ch == '>' {
            end = Some(i);
            break;
        }
    }
    let end = end?;
    let mut inner = source[1..end].trim();
    let closing = inner.starts_with('/');
    inner = inner.trim_start_matches('/').trim_end_matches('/').trim();
    let n = inner.find(char::is_whitespace).unwrap_or(inner.len());
    let name = inner[..n].to_ascii_lowercase();
    if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric()) {
        return None;
    }
    let mut rest = inner[n..].trim();
    let mut attrs = BTreeMap::new();
    while !rest.is_empty() {
        let n = rest
            .find(|c: char| c == '=' || c.is_whitespace())
            .unwrap_or(rest.len());
        if n == 0 {
            return None;
        }
        let key = rest[..n].to_ascii_lowercase();
        rest = rest[n..].trim_start();
        let mut value = String::new();
        if let Some(tail) = rest.strip_prefix('=') {
            rest = tail.trim_start();
            if let Some(q) = rest.chars().next().filter(|c| *c == '"' || *c == '\'') {
                let end = rest[1..].find(q)? + 1;
                value = decode(&rest[1..end]);
                rest = &rest[end + 1..];
            } else {
                let end = rest.find(char::is_whitespace).unwrap_or(rest.len());
                value = decode(&rest[..end]);
                rest = &rest[end..];
            }
        }
        if attrs.insert(key, value).is_some() {
            return None;
        }
        rest = rest.trim_start();
    }
    Some((
        Tag {
            name,
            closing,
            attrs,
        },
        end + 1,
    ))
}

impl Table {
    fn finish_cell(&mut self) -> Option<()> {
        if !self.inline.is_empty() {
            return None;
        }
        if let Some(cell) = self.cell.take() {
            self.row.as_mut()?.push(cell);
        }
        Some(())
    }
    fn finish_row(&mut self) -> Option<()> {
        self.finish_cell()?;
        if let Some(row) = self.row.take() {
            if row.is_empty() || self.rows.len() >= MAX_ROWS {
                return None;
            }
            self.rows.push(row);
        }
        Some(())
    }
    fn text(&mut self, raw: &str) -> Option<()> {
        let value = decode(raw);
        if self.in_caption {
            self.caption.push_str(&value);
            return Some(());
        }
        if let Some(cell) = &mut self.cell {
            cell.html.push_str(&xml(&value));
            cell.text.push_str(&value);
            Some(())
        } else if value.trim().is_empty() {
            Some(())
        } else {
            None
        }
    }
    fn tag(&mut self, tag: Tag) -> Option<()> {
        let name = tag.name.as_str();
        if self.ended {
            return None;
        }
        // Styling/handlers/hidden nodes cannot silently change the visible text contract.
        if tag.attrs.keys().any(|a| {
            !matches!(
                a.as_str(),
                "class" | "border" | "scope" | "id" | "headers" | "rowspan" | "colspan"
            )
        }) {
            return None;
        }
        match (name, tag.closing) {
            ("table", false) if !self.started => {
                self.started = true;
            }
            ("table", true) if self.started => {
                self.finish_row()?;
                self.ended = true;
            }
            _ if !self.started => return None,
            ("caption", false) if self.cell.is_none() => self.in_caption = true,
            ("caption", true) if self.in_caption => self.in_caption = false,
            ("thead" | "tbody" | "tfoot", _) => {
                self.finish_row()?;
            }
            ("tr", false) => {
                self.finish_row()?;
                self.row = Some(Vec::new());
            }
            ("tr", true) => {
                self.finish_row()?;
            }
            ("td" | "th", false) => {
                self.finish_cell()?;
                if self.row.is_none() {
                    self.row = Some(Vec::new());
                }
                let span = |key: &str| -> Option<usize> {
                    let n = tag
                        .attrs
                        .get(key)
                        .map(|s| s.parse::<usize>())
                        .transpose()
                        .ok()?
                        .unwrap_or(1);
                    (n > 0 && n <= MAX_COLS).then_some(n)
                };
                self.cell = Some(Cell {
                    header: name == "th",
                    rowspan: span("rowspan")?,
                    colspan: span("colspan")?,
                    ..Cell::default()
                });
            }
            ("td" | "th", true) if self.cell.is_some() => {
                self.finish_cell()?;
            }
            ("br", false) => {
                let cell = self.cell.as_mut()?;
                cell.rich = true;
                cell.html.push_str("<br/>");
                cell.text.push('\n');
            }
            ("strong" | "b" | "em" | "i" | "code" | "span" | "s", closing) => {
                let cell = self.cell.as_mut()?;
                cell.rich = true;
                if closing {
                    if self.inline.pop().as_deref() != Some(name) {
                        return None;
                    }
                    cell.html.push_str(&format!("</{name}>"));
                } else {
                    if self.inline.len() >= 16 {
                        return None;
                    }
                    self.inline.push(name.to_owned());
                    cell.html.push_str(&format!("<{name}>"));
                }
            }
            _ => return None,
        }
        Some(())
    }
    fn render(self) -> Option<String> {
        if !self.ended || self.in_caption || self.rows.is_empty() {
            return None;
        }
        let mut occupied = vec![vec![false; MAX_COLS]; self.rows.len()];
        let mut width = 0;
        let mut use_html = false;
        for (r, row) in self.rows.iter().enumerate() {
            let mut col = 0;
            for cell in row {
                while col < MAX_COLS && occupied[r][col] {
                    col += 1;
                }
                if col + cell.colspan > MAX_COLS || r + cell.rowspan > self.rows.len() {
                    return None;
                }
                for band in occupied.iter_mut().skip(r).take(cell.rowspan) {
                    for slot in band.iter_mut().skip(col).take(cell.colspan) {
                        if *slot {
                            return None;
                        }
                        *slot = true;
                    }
                }
                col += cell.colspan;
                width = width.max(col);
                use_html |=
                    cell.rowspan != 1 || cell.colspan != 1 || cell.rich || cell.header != (r == 0);
            }
        }
        if width == 0 || occupied.iter().any(|row| row[..width].iter().any(|x| !x)) {
            return None;
        }
        let mut result = if use_html {
            let mut out = String::from("<table><tbody>");
            for row in &self.rows {
                out.push_str("<tr>");
                for cell in row {
                    let tag = if cell.header { "th" } else { "td" };
                    out.push_str(&format!(
                        "<{tag} rowspan=\"{}\" colspan=\"{}\">{}</{tag}>",
                        cell.rowspan, cell.colspan, cell.html
                    ));
                }
                out.push_str("</tr>");
            }
            out.push_str("</tbody></table>");
            out
        } else {
            let mut lines = Vec::new();
            for (r, row) in self.rows.iter().enumerate() {
                let cells = row
                    .iter()
                    .map(|c| markdown_text(&c.text))
                    .collect::<Vec<_>>();
                lines.push(format!("| {} |", cells.join(" | ")));
                if r == 0 {
                    lines.push(format!("| {} |", vec!["---"; width].join(" | ")));
                }
            }
            lines.join("\n")
        };
        if !self.caption.trim().is_empty() {
            result = format!("{}\n\n{result}", markdown_text(&self.caption));
        }
        Some(result)
    }
}

fn markdown_text(text: &str) -> String {
    let text = text.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut out = String::new();
    for c in text.chars() {
        if matches!(c, '\\' | '`' | '*' | '_' | '[' | ']' | '<' | '>' | '|') {
            out.push('\\');
        }
        out.push(c);
    }
    out
}

pub(crate) fn normalize_table(source: &str) -> Option<String> {
    if source.len() > MAX_BYTES {
        return None;
    }
    let mut table = Table::default();
    let mut rest = source;
    while let Some(start) = rest.find('<') {
        table.text(&rest[..start])?;
        rest = &rest[start..];
        if !rest[1..].starts_with(|c: char| c.is_ascii_alphabetic() || c == '/') {
            table.text("<")?;
            rest = &rest[1..];
            continue;
        }
        let (tag, length) = tag_at(rest)?;
        table.tag(tag)?;
        rest = &rest[length..];
    }
    table.text(rest)?;
    table.render()
}

// Only structural tables outside literal fenced/inline code are interpreted.
// Everything between tables is retained; blank boundaries prevent table/paragraph joining.
pub(crate) fn normalize_document(source: &str) -> Option<String> {
    if source.len() > MAX_BYTES {
        return None;
    }
    validate_gfm(source)?;
    let mut out = String::new();
    let mut at = 0;
    let mut fence: Option<(u8, usize)> = None;
    let mut inline_ticks = 0;
    let mut prose_tags: Vec<String> = Vec::new();
    while at < source.len() {
        let rest = &source[at..];
        let line_start = at == 0 || source.as_bytes()[at - 1] == b'\n';
        if line_start {
            inline_ticks = 0;
            if rest.starts_with("    ") && fence.is_none() {
                let line = rest.split('\n').next()?;
                out.push_str(line);
                at += line.len();
                continue;
            }
            let line = rest.split('\n').next()?;
            let trimmed = line.trim_start_matches(' ');
            if line.len() - trimmed.len() <= 3 {
                let marker = trimmed.as_bytes().first().copied().unwrap_or(0);
                if marker == b'`' || marker == b'~' {
                    let count = trimmed.bytes().take_while(|b| *b == marker).count();
                    if count >= 3 {
                        if let Some((old, length)) = fence {
                            if old == marker
                                && count >= length
                                && trimmed[count..].trim().is_empty()
                            {
                                fence = None;
                            }
                        } else {
                            fence = Some((marker, count));
                        }
                        out.push_str(line);
                        at += line.len();
                        continue;
                    }
                }
            }
        }
        if fence.is_none() && rest.starts_with('\\') {
            let length = rest.chars().take(2).map(char::len_utf8).sum::<usize>();
            out.push_str(&rest[..length]);
            at += length;
            continue;
        }
        if fence.is_none() && rest.starts_with('`') {
            let count = rest.bytes().take_while(|b| *b == b'`').count();
            if inline_ticks == count {
                inline_ticks = 0;
            } else if inline_ticks == 0 {
                inline_ticks = count;
            }
            out.push_str(&rest[..count]);
            at += count;
            continue;
        }
        if fence.is_none() && inline_ticks == 0 && rest.starts_with('<') {
            if let Some((tag, tag_length)) = tag_at(rest) {
                if matches!(tag.name.as_str(), "b" | "strong" | "i" | "em") && tag.attrs.is_empty()
                {
                    let marker = if matches!(tag.name.as_str(), "b" | "strong") {
                        "**"
                    } else {
                        "*"
                    };
                    if tag.closing && prose_tags.last() == Some(&tag.name) {
                        prose_tags.pop();
                        out.push_str(marker);
                        at += tag_length;
                        continue;
                    } else if !tag.closing
                        && rest
                            .to_ascii_lowercase()
                            .contains(&format!("</{}>", tag.name))
                    {
                        prose_tags.push(tag.name);
                        out.push_str(marker);
                        at += tag_length;
                        continue;
                    }
                }
                if tag.name == "br" && !tag.closing && tag.attrs.is_empty() {
                    // Preserve a cell-internal line break without splitting a GFM row.
                    out.push('\u{2028}');
                    at += tag_length;
                    continue;
                }
                if tag.name == "table" {
                    if tag.closing {
                        return None;
                    }
                    let mut cursor = 0;
                    let end = loop {
                        let offset = rest[cursor..].find('<')? + cursor;
                        if let Some((part, length)) = tag_at(&rest[offset..]) {
                            if part.name == "table" && part.closing {
                                break offset + length;
                            }
                            cursor = offset + length;
                        } else {
                            cursor = offset + 1;
                        }
                    };
                    let normalized = normalize_table(&rest[..end])?;
                    if !out.is_empty() {
                        if !out.ends_with('\n') {
                            out.push('\n');
                        }
                        if !out.ends_with("\n\n") {
                            out.push('\n');
                        }
                    }
                    out.push_str(&normalized);
                    out.push_str("\n\n");
                    at += end;
                    continue;
                }
            } else if rest.to_ascii_lowercase().starts_with("<table") {
                return None;
            }
        }
        let c = rest.chars().next()?;
        out.push(c);
        at += c.len_utf8();
    }
    Some(out.trim().to_owned())
}

// A delimiter gives a reliable column count. Excess pipes have ambiguous ownership;
// reject instead of guessing which neighboring cells to concatenate.
fn validate_gfm(source: &str) -> Option<()> {
    let mut width = None;
    let mut previous = None;
    let mut fence: Option<(char, usize)> = None;
    for line in source.lines() {
        let trimmed = line.trim();
        if let Some(marker) = trimmed.chars().next().filter(|c| *c == '`' || *c == '~') {
            let count = trimmed.chars().take_while(|c| *c == marker).count();
            if count >= 3 {
                if let Some((old, length)) = fence {
                    if marker == old && count >= length && trimmed[count..].trim().is_empty() {
                        fence = None;
                    }
                } else {
                    fence = Some((marker, count));
                }
                width = None;
                previous = None;
                continue;
            }
        }
        if fence.is_some() || line.starts_with("    ") {
            continue;
        }
        if !trimmed.starts_with('|') {
            width = None;
            previous = None;
            continue;
        }
        let cells = gfm_cells(trimmed);
        if cells.iter().all(|c| {
            let value = c.trim().trim_matches(':');
            value.len() >= 3 && value.bytes().all(|b| b == b'-')
        }) {
            if previous != Some(cells.len()) {
                return None;
            }
            width = Some(cells.len());
        } else if width.is_some_and(|w| w != cells.len()) {
            return None;
        }
        previous = Some(cells.len());
    }
    Some(())
}

fn gfm_cells(line: &str) -> Vec<String> {
    let mut cells = Vec::new();
    let mut text = String::new();
    let mut chars = line.chars().peekable();
    let mut code = 0;
    while let Some(c) = chars.next() {
        if c == '\\' {
            text.push(c);
            if let Some(next) = chars.next() {
                text.push(next);
            }
        } else if c == '`' {
            let mut n = 1;
            while chars.peek() == Some(&'`') {
                chars.next();
                n += 1;
            }
            if code == n {
                code = 0;
            } else if code == 0 {
                code = n;
            }
            text.push_str(&"`".repeat(n));
        } else if c == '|' && code == 0 {
            cells.push(std::mem::take(&mut text));
        } else {
            text.push(c);
        }
    }
    cells.push(text);
    if cells.first().is_some_and(|s| s.trim().is_empty()) {
        cells.remove(0);
    }
    if cells.last().is_some_and(|s| s.trim().is_empty()) {
        cells.pop();
    }
    cells
}

#[cfg(test)]
#[path = "ocr_table_tests.rs"]
mod tests;
