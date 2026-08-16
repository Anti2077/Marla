# 릴리스 전 확인

**금요일 오후 3시**까지 다음 확인을 완료하고 모든 명령어와 자리표시자를 그대로 유지하세요.

## 기본 절차

1. `Marla_dev.app`을 실행합니다.
2. 설정을 열고 API Profile 이름이 **Staging**인지 확인합니다.
3. *강조 텍스트*, 링크, 코드가 포함된 내용을 번역합니다.

> 상태가 `ready`가 아니면 릴리스를 중단하고 `{{STATUS}}`를 기록하세요.

### 승인 항목

- [ ] 제목과 목록 계층이 올바르다
- [ ] 링크 대상이 변경되지 않았다
- [ ] 인라인 코드 `MARLA_API_KEY`가 번역되지 않았다
- [ ] 복사한 결과가 완전한 Markdown으로 유지된다

| 항목 | 예상값 | 실제값 |
| --- | --- | --- |
| 빌드 번호 | `${BUILD_ID}` | `{{BUILD_ID}}` |
| 최소 시스템 | macOS 14 | `{{MIN_OS}}` |
| 상태 | ready | `{{STATUS}}` |

자세한 내용은 [릴리스 문서](https://example.com/docs?lang=ko&section=release)를 확인하세요.

```sh
export MARLA_API_KEY="${MARLA_API_KEY}"
launchctl kickstart -k gui/501/com.example.marla
```

마지막으로 **릴리스 가능** 또는 **롤백 필요** 중 하나로 결론을 작성하세요.
