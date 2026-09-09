"""Opt-in local OCR evaluation; saves ONLY this script's synthetic fixture outputs."""
import base64
import collections
import hashlib
import http.client
import json
from pathlib import Path
import re
import sys
import time
from html.parser import HTMLParser


class Structure(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tags = collections.Counter()
        self.spans = []
        self.cells = []
        self.active = None

    def handle_starttag(self, tag, attrs):
        self.tags[tag] += 1
        a = dict(attrs)
        for key in ('rowspan', 'colspan'):
            if key in a:
                self.spans.append([tag, key, a[key]])
        if tag in ('td', 'th'):
            self.active = []
        if tag == 'br' and self.active is not None:
            self.active.append(' ')

    def handle_data(self, text):
        if self.active is not None:
            self.active.append(text)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.active is not None:
            self.cells.append(' '.join(''.join(self.active).split()))
            self.active = None


def main():
    root = Path(sys.argv[1])
    fixtures = json.loads((root / 'fixtures.json').read_text())
    source = Path('rust/marla-core/src/glm_ocr.rs').read_text()
    prompt = re.search(r'"prompt": "([^"]+)"', source)[1]
    (root / 'prompt.txt').write_text(prompt)
    results = []
    for fixture in fixtures:
        image = (root / (fixture['id'] + '.png')).read_bytes()
        payload = json.dumps(dict(model='glm-ocr', prompt=prompt,
                                  images=[base64.b64encode(image).decode()],
                                  stream=False, options=dict(temperature=0))).encode()
        conn = http.client.HTTPConnection('127.0.0.1', 11434, timeout=120)
        start = time.monotonic()
        record = dict(id=fixture['id'], image_sha256=hashlib.sha256(image).hexdigest(),
                      expected_cells=len(fixture['cells']))
        print('Sending ' + fixture['id'], flush=True)
        try:
            conn.request('POST', '/api/generate', body=payload, headers={'Content-Type': 'application/json'})
            response = conn.getresponse()
            body = response.read()
            record.update(http_status=response.status, seconds=round(time.monotonic() - start, 3))
            decoded = json.loads(body)
            text = decoded.get('response', '')
            # Synthetic content only. No user captures or settings enter this harness.
            (root / (fixture['id'] + '.response.json')).write_text(json.dumps(decoded, ensure_ascii=False, indent=2))
            (root / (fixture['id'] + '.raw.md')).write_text(text)
            parsed = Structure()
            parsed.feed(text)
            record.update(done=decoded.get('done'), done_reason=decoded.get('done_reason'),
                          chars=len(text), tags=dict(parsed.tags), spans=parsed.spans,
                          actual_html_cells=len(parsed.cells),
                          cell_texts=parsed.cells,
                          gfm_lines=sum(bool(re.match(r'^\s*\|', l)) for l in text.splitlines()),
                          title_present=fixture['title'] in text, footer_present=fixture['footer'] in text)
            for key in ['total_duration', 'load_duration', 'eval_count', 'eval_duration']:
                if key in decoded:
                    record[key] = decoded[key]
            print(json.dumps(record, ensure_ascii=False), flush=True)
        except Exception as error:
            record.update(seconds=round(time.monotonic() - start, 3), error=type(error).__name__)
            print(json.dumps(record), flush=True)
        finally:
            conn.close()
        results.append(record)
        (root / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
