
// ==UserScript==
// @name         中国银行网申制卡进度查询
// @namespace    https://open.boc.cn/
// @version      1.0.0
// @description  自动查询中国银行网申卡号及制卡进度
// @author       ChatGPT
// @match        https://open.boc.cn/bankcard/cardReserve/index.html*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    const STATUS = {
        '00': '待制卡',
        '01': '制卡中',
        '03': '制卡完毕，已寄出到网点',
        '04': '待领卡',
        '06': '已领卡',
        '02': '流程异常',
        '05': '流程异常',
        '07': '流程异常'
    };

    const STYLE = `
        #boc-query-panel {
            position: fixed;
            right: 20px;
            bottom: 25px;
            width: 300px;
            z-index: 999999;
            background: #fff;
            border-radius: 12px;
            box-shadow: 0 5px 25px rgba(0,0,0,.2);
            font-family: -apple-system, BlinkMacSystemFont, "Microsoft YaHei", sans-serif;
            color: #333;
            overflow: hidden;
            border: 1px solid #eee;
        }
        #boc-query-panel * { box-sizing: border-box; }
        #boc-query-panel .header {
            background: #b82025;
            color: #fff;
            padding: 14px 16px;
            font-size: 15px;
            font-weight: bold;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        #boc-query-panel .close {
            cursor: pointer;
            font-size: 20px;
            line-height: 18px;
        }
        #boc-query-panel .content { padding: 16px; }
        #boc-query-panel .item { margin-bottom: 15px; }
        #boc-query-panel .label {
            color: #888;
            font-size: 12px;
            margin-bottom: 7px;
        }
        #boc-query-panel .value {
            font-size: 15px;
            font-weight: bold;
            word-break: break-all;
        }
        #boc-query-panel .status {
            color: #b82025;
            font-size: 17px;
        }
        #boc-query-panel .buttons {
            display: flex;
            gap: 8px;
            margin-top: 15px;
        }
        #boc-query-panel button {
            flex: 1;
            border: none;
            border-radius: 6px;
            padding: 10px 5px;
            cursor: pointer;
            font-size: 13px;
        }
        #boc-query-panel .refresh {
            background: #b82025;
            color: white;
        }
        #boc-query-panel .copy {
            background: #f1f1f1;
            color: #333;
        }
        #boc-query-panel .message {
            font-size: 12px;
            color: #888;
            margin-top: 12px;
            line-height: 1.6;
        }
        #boc-query-toggle {
            position: fixed;
            right: 20px;
            bottom: 25px;
            z-index: 999998;
            background: #b82025;
            color: white;
            border: none;
            border-radius: 25px;
            padding: 13px 18px;
            cursor: pointer;
            box-shadow: 0 3px 12px #0003;
            font-size: 14px;
        }
    `;

    let cardNo = '';
    let showCard = false;

    function getRecordInfo() {
        const el = document.getElementsByClassName(
            'progress-result-wrap'
        )[0];

        if (!el || !el.__vue__) return null;

        const vue = el.__vue__;
        const record = vue.$parent?.recordInfo;

        return record || null;
    }

    function maskCard(value) {
        if (!value) return '--';
        const str = String(value);
        if (str.length <= 8) return '****';
        return str.slice(0, 4) +
            ' **** **** ' +
            str.slice(-4);
    }

    function createPanel() {
        if (document.getElementById('boc-query-panel')) return;

        const style = document.createElement('style');
        style.textContent = STYLE;
        document.head.appendChild(style);

        const panel = document.createElement('div');
        panel.id = 'boc-query-panel';

        panel.innerHTML = `
            <div class="header">
                <span>中国银行 · 制卡进度查询</span>
                <span class="close" id="boc-close">×</span>
            </div>
            <div class="content">
                <div class="item">
                    <div class="label">申领卡号</div>
                    <div class="value" id="boc-card">等待查询...</div>
                </div>
                <div class="item">
                    <div class="label">制卡进度</div>
                    <div class="value status" id="boc-status">等待查询...</div>
                </div>
                <div class="item">
                    <div class="label">状态代码</div>
                    <div class="value" id="boc-code">--</div>
                </div>
                <div class="buttons">
                    <button class="refresh" id="boc-refresh">刷新查询</button>
                    <button class="copy" id="boc-copy">复制卡号</button>
                    <button class="copy" id="boc-show">显示卡号</button>
                </div>
                <div class="message" id="boc-message">
                    请先完成验证码验证并进入进度查询页面。
                </div>
            </div>
        `;

        document.body.appendChild(panel);

        const toggle = document.createElement('button');
        toggle.id = 'boc-query-toggle';
        toggle.textContent = '银行卡进度';
        toggle.style.display = 'none';
        document.body.appendChild(toggle);

        document.getElementById('boc-close').onclick = () => {
            panel.style.display = 'none';
            toggle.style.display = 'block';
        };

        toggle.onclick = () => {
            panel.style.display = 'block';
            toggle.style.display = 'none';
        };

        document.getElementById('boc-refresh').onclick = query;
        document.getElementById('boc-show').onclick = () => {
            showCard = !showCard;
            document.getElementById('boc-show').textContent =
                showCard ? '隐藏卡号' : '显示卡号';
            renderCard();
        };

        document.getElementById('boc-copy').onclick = async () => {
            if (!cardNo) {
                alert('暂未获取到卡号');
                return;
            }

            try {
                await navigator.clipboard.writeText(cardNo);
                alert('卡号已复制');
            } catch (e) {
                alert('复制失败，请检查浏览器剪贴板权限');
            }
        };

        query();
    }

    function renderCard() {
        const el = document.getElementById('boc-card');
        if (!el) return;

        el.textContent = showCard ? (cardNo || '--') : maskCard(cardNo);
    }

    function query() {
        const record = getRecordInfo();

        const cardEl = document.getElementById('boc-card');
        const statusEl = document.getElementById('boc-status');
        const codeEl = document.getElementById('boc-code');
        const messageEl = document.getElementById('boc-message');

        if (!record) {
            cardEl.textContent = '暂未获取到数据';
            statusEl.textContent = '--';
            codeEl.textContent = '--';
            messageEl.textContent =
                '请先输入验证码进入查询页面，然后点击刷新查询。';
            return;
        }

        cardNo = record.cardNo || '';

        const code = String(record.mkcrdProgreSts ?? '')
            .trim()
            .padStart(2, '0');

        const status = STATUS[code] || (
            code ? '未知状态' : '暂无制卡进度'
        );

        renderCard();

        statusEl.textContent = status;
        codeEl.textContent = code || '--';

        messageEl.textContent = cardNo
            ? '查询成功 · 数据来自当前网申查询页面'
            : '已读取进度信息，但暂未获取到卡号。';
    }

    function init() {
        createPanel();

        // 兼容验证码验证后异步加载查询结果
        const observer = new MutationObserver(() => {
            const record = getRecordInfo();
            if (record) query();
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    init();

})();
