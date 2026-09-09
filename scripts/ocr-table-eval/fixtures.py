"""Synthetic use cases; W3C irregular-header examples inform span topology only."""
import json
import sys


def grid(id, title, widths, matrix, footer, dark=False, row_headers=False):
    cells = [dict(row=r, col=c, text=t, rowspan=1, colspan=1,
                  header=r == 0 or (row_headers and c == 0))
             for r, row in enumerate(matrix) for c, t in enumerate(row)]
    return dict(id=id, title=title, widths=widths, rows=len(matrix),
                cells=cells, footer=footer, dark=dark)


fixtures = [
    grid('invoice', 'Invoice INV-2048', [340, 110, 220, 220], [
        ['Item', 'Qty', 'Unit price', 'Amount'],
        ['USB-C cable', '3', '$12.50', '$37.50'],
        ['Keyboard', '1', '$89.00', '$89.00'],
        ['Discount', '', '', '-$6.50'],
        ['Total', '', '', '$120.00'],
    ], 'Payment due: 2026-09-30. Thank you.'),
    grid('api', 'API reference', [235, 210, 250, 345], [
        ['Parameter', 'Type', 'Default', 'Description'],
        ['limit', 'integer', '100', 'Range: 1 < limit < 500'],
        ['filter', 'string', 'A&B', 'Values: ready | pending'],
        ['path', 'string', '/v1/items', 'Keep ${ITEM_ID} unchanged'],
        ['enabled', 'boolean', 'false', 'Line one\nLine two'],
    ], 'Example: curl --fail /v1/items?limit=25', dark=True, row_headers=True),
    grid('comparison', 'Plan comparison', [300, 250, 250, 250], [
        ['Feature', 'Starter', 'Team', 'Enterprise'],
        ['Users', '1', '10', 'Unlimited'],
        ['Export CSV', 'Yes', 'Yes', 'Yes'],
        ['Audit log', 'No', '30 days', '365 days'],
        ['Support', 'Email', 'Chat\nEmail', 'Dedicated'],
    ], 'Prices exclude tax. Trial: 14 days.', row_headers=True),
    grid('bilingual', '库存 / Inventory', [320, 220, 220, 260], [
        ['商品 / Item', '仓库 / Depot', '数量 / Qty', '备注 / Notes'],
        ['连接线 / Cable', '上海', '12', '待发货 / Pending'],
        ['键盘 / Keyboard', 'Berlin', '0', '缺货 / Out of stock'],
        ['支架 / Stand', 'Tokyo', '7', '检查 A&B 型号'],
    ], '更新时间 / Updated: 2026-09-08 10:00', dark=True),
    grid('keyvalue', 'Server properties', [330, 650], [
        ['Property', 'Value'], ['Hostname', 'demo.local'], ['IPv6', '2001:db8::10'],
        ['Command', 'iperf3 -s --port 5201'], ['Note', ''],
    ], 'Synthetic test host. No live credentials.', row_headers=True),
]
finance = grid('finance', 'Quarterly revenue (USD)', [260, 210, 210, 210, 210], [
    ['Region', '2025', '', '2026', ''], ['', 'Q1', 'Q2', 'Q1', 'Q2'],
    ['North', '120', '140', '150', '170'], ['South', '80', '90', '95', '110'],
    ['Total', '200', '230', '245', '280'],
], 'Totals are synthetic. Values in thousands.')
finance['cells'] = [c for c in finance['cells'] if (c['row'], c['col']) not in [(0, 2), (0, 4), (1, 0)]]
for c in finance['cells']:
    if c['row'] == 0:
        if c['col'] == 0:
            c['rowspan'] = 2
        else:
            c['colspan'] = 2
    if c['row'] == 1:
        c['header'] = True
fixtures.append(finance)
schedule = grid('schedule', 'Training schedule', [230, 230, 400, 230], [
    ['Day', 'Time', 'Session', 'Room'], ['Monday', '09:00', 'Introduction', 'A1'],
    ['', '10:00', 'Hands-on lab', 'B2'], ['Tuesday', '09:00', 'Review', 'A1'],
    ['', '10:00', 'Q&A', 'B2'],
], 'Bring a laptop. All times are local.', row_headers=True)
schedule['cells'] = [c for c in schedule['cells'] if (c['row'], c['col']) not in [(2, 0), (4, 0)]]
for c in schedule['cells']:
    if c['col'] == 0 and c['row'] in [1, 3]:
        c['rowspan'] = 2
fixtures.append(schedule)
with open(sys.argv[1], 'w') as output:
    json.dump(fixtures, output, ensure_ascii=False, indent=2)
