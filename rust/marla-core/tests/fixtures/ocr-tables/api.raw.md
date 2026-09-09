# API reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| limit | integer | 100 | Range: 1 < limit < 500 |
| filter | string | A&B | Values: ready | pending |
| path | string | /v1/items | Keep ${ITEM_ID} unchanged |
| enabled | boolean | false | Line one<br>Line two |

Example: `curl --fail /v1/items?limit=25`