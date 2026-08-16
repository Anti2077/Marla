# Pre-release Check

Complete the following checks before **3:00 PM on Friday**, and keep every command and placeholder unchanged.

## Basic Flow

1. Launch `Marla_dev.app`.
2. Open Settings and confirm that the API Profile is named **Staging**.
3. Translate content containing *emphasis*, a link, and code.

> If the status is not `ready`, stop the release and record `{{STATUS}}`.

### Acceptance Items

- [ ] Heading and list hierarchy is correct
- [ ] Link destinations are unchanged
- [ ] Inline code `MARLA_API_KEY` is not translated
- [ ] The copied result remains complete Markdown

| Item | Expected | Actual |
| --- | --- | --- |
| Build number | `${BUILD_ID}` | `{{BUILD_ID}}` |
| Minimum system | macOS 14 | `{{MIN_OS}}` |
| Status | ready | `{{STATUS}}` |

See the [release documentation](https://example.com/docs?lang=en&section=release) for details.

```sh
export MARLA_API_KEY="${MARLA_API_KEY}"
launchctl kickstart -k gui/501/com.example.marla
```

Finish with one conclusion: **ready to release** or **rollback required**.
