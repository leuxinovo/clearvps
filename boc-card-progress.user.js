
// ==UserScript==
// @name         中国银行网申制卡进度查询
// @namespace    https://open.boc.cn/
// @version      2.0.0
// @description  中国银行网申卡号及制卡进度查询，手机适配版
// @match        https://open.boc.cn/bankcard/cardReserve/index.html*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    if (window.__BOC_CARD_PROGRESS__) return;
    window.__BOC_CARD_PROGRESS__ = true;

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

    const STEPS = ['已申请', '制卡中', '待领卡', '已领卡'];

    let cardNo = '';
    let statusCode = '';
    let showCard = false;
    let minimized = false;
    let lastData = '';

    const css = `
    #boc-panel, #boc-panel *,
    #boc-toggle, #boc-toggle * {
        box-sizing: border-box !important;
    }

    #boc-panel {
        position: fixed !important;
        z-index: 2147483646 !important;
        left: 50% !important;
        bottom: calc(20px + env(safe-area-inset-bottom)) !important;
        transform: translateX(-50%) !important;
        width: min(680px, calc(100vw - 28px)) !important;
        background: #fff !important;
        color: #222 !important;
        border: 1px solid #eee !important;
        border-radius: 25px !important;
        box-shadow: 0 10px 45px rgba(0,0,0,.16) !important;
        padding: 25px 24px 22px !important;
        font-family: -apple-system, BlinkMacSystemFont,
        "PingFang SC", "Microsoft YaHei", sans-serif !important;
        text-align: left !important;
        line-height: 1.5 !important;
        max-height: 75dvh !important;
        overflow-y: auto !important;
        -webkit-overflow-scrolling: touch !important;
    }

    #boc-panel .boc-header {
        display: flex !important;
        align-items: center !important;
        justify-content: space-between !important;
        margin-bottom: 25px !important;
    }

    #boc-panel .boc-title {
        font-size: 23px !important;
        font-weight: 750 !important;
        color: #222 !important;
    }

    #boc-panel .boc-close {
        border: 0 !important;
        background: transparent !important;
        color: #999 !important;
        font-size: 30px !important;
        padding: 0 0 0 12px !important;
        cursor: pointer !important;
    }

    #boc-panel .boc-label {
        color: #999 !important;
        font-size: 15px !important;
        margin-bottom: 3px !important;
    }

    #boc-panel .boc-number {
        color: #222 !important;
        font-size: clamp(21px, 5vw, 31px) !important;
        font-weight: 750 !important;
        overflow-wrap: anywhere !important;
        margin-bottom: 21px !important;
    }

    #boc-panel .boc-status {
        color: #222 !important;
        font-size: clamp(18px, 4.5vw, 24px) !important;
        font-weight: 750 !important;
        margin-bottom: 3px !important;
        line-height: 1.5 !important;
    }

    #boc-panel .boc-code {
        font-size: 15px !important;
        color: #999 !important;
        margin-bottom: 22px !important;
    }

    #boc-panel .boc-steps {
        display: flex !important;
        justify-content: space-between !important;
        align-items: flex-start !important;
        margin: 8px 0 24px !important;
        gap: 3px !important;
    }

    #boc-panel .boc-step {
        flex: 1 !important;
        text-align: center !important;
        font-size: 12px !important;
        color: #bbb !important;
        position: relative !important;
    }

    #boc-panel .boc-dot {
        width: 17px !important;
        height: 17px !important;
        border-radius: 50% !important;
        border: 2px solid #ccc !important;
        margin: 0 auto 7px !important;
        background: #fff !important;
    }

    #boc-panel .boc-step.done .boc-dot {
        background: #b60020 !important;
        border-color: #b60020 !important;
    }

    #boc-panel .boc-step.active {
        color: #b60020 !important;
        font-weight: bold !important;
    }

    #boc-panel .boc-step.active .boc-dot {
        border: 5px solid #b60020 !important;
    }

    #boc-panel .boc-buttons {
        display: flex !important;
        flex-direction: column !important;
        gap: 10px !important;
    }

    #boc-panel .boc-btn {
        width: 100% !important;
        min-height: 53px !important;
        border: none !important;
        border-radius: 13px !important;
        font-size: 16px !important;
        font-weight: 600 !important;
        cursor: pointer !important;
        -webkit-appearance: none !important;
        touch-action: manipulation !important;
    }

    #boc-panel .boc-copy {
        background: #b60020 !important;
        color: white !important;
    }

    #boc-panel .boc-secondary {
        background: #f3f3f3 !important;
        color: #444 !important;
    }

    #boc-panel .boc-tip {
        color: #999 !important;
        font-size: 12px !important;
        margin-top: 13px !important;
        text-align: center !important;
    }

    #boc-toggle {
        position: fixed !important;
        z-index: 2147483646 !important;
        right: 16px !important;
        bottom: calc(20px + env(safe-area-inset-bottom)) !important;
        background: #b60020 !important;
        color: #fff !important;
        border: 0 !important;
        border-radius: 30px !important;
        padding: 13px 19px !important;
        font-size: 14px !important;
        box-shadow: 0 4px 16px #0003 !important;
        cursor: pointer !important;
        touch-action: manipulation !important;
    }

    @media (max-width: 600px) {
        #boc-panel {
            width: calc(100vw - 28px) !important;
            padding: 22px 20px 20px !important;
            bottom: calc(15px + env(safe-area-inset-bottom)) !important;
            border-radius: 23px !important;
            max-height: 72dvh !important;
        }

        #boc-panel .boc-title {
            font-size: 21px !important;
        }

        #boc-panel .boc-label {
            font-size: 14px !important;
        }

        #boc-panel .boc-btn {
            min-height: 55px !important;
        }
    }
    `;

    function getRecord() {
        const el = document.getElementsByClassName(
            'progress-result-wrap'
        )[0];

        if (!el) return null;

        let vue = el.__vue__;

        for (let i = 0; vue && i < 5; i++) {
            if (vue.recordInfo) return vue.recordInfo;
            vue = vue.$parent;
        }

        return null;
    }

    function maskNumber(number) {
        if (!number) return '--';
        const s = String(number);
        if (s.length < 9) return '****';
        return s.slice(0, 8) + '**** **** ' + s.slice(-4);
    }

    function getStep(code) {
        if (code === '00') return 0;
        if (code === '01') return 1;
        if (code === '03' || code === '04') return 2;
        if (code === '06') return 3;
        return -1;
    }

    function renderSteps(code) {
        const active = getStep(code);

        return STEPS.map((name, index) => {
            let cls = '';
            if (active >= 0 && index < active) cls = 'done';
            if (index === active) cls = 'active';

            return `
                <div class="boc-step ${cls}">
                    <div class="boc-dot"></div>
                    <div>${name}</div>
                </div>
            `;
        }).join('');
    }

    function render() {
        const panel = document.getElementById('boc-panel');
        if (!panel) return;

        const number = showCard ? cardNo : maskNumber(cardNo);
        const status = STATUS[statusCode] || '暂无制卡进度';

        panel.querySelector('#boc-number').textContent = number;
        panel.querySelector('#boc-status').textContent = status;
        panel.querySelector('#boc-code').textContent =
            '状态码：' + (statusCode || '--');

        const steps = panel.querySelector('#boc-steps');

        if (getStep(statusCode) >= 0) {
            steps.innerHTML = renderSteps(statusCode);
            steps.style.display = 'flex';
        } else {
            steps.style.display = 'none';
        }

        panel.querySelector('#boc-show').textContent =
            showCard ? '隐藏卡号' : '显示卡号';
    }

    function query() {
        const record = getRecord();
        if (!record) return;

        const newCard = String(record.cardNo || '');
        const newStatus = String(
            record.mkcrdProgreSts ?? ''
        ).trim().padStart(2, '0');

        if (!newCard && !newStatus) return;

        const key = newCard + '|' + newStatus;
        if (key === lastData) return;

        lastData = key;
        cardNo = newCard;
        statusCode = newStatus;

        render();

        const tip = document.getElementById('boc-tip');
        if (tip) {
            tip.textContent = '数据来自当前中国银行网申查询页面';
        }
    }

    function createPanel() {
        if (document.getElementById('boc-panel')) return;

        const style = document.createElement('style');
        style.textContent = css;
        document.head.appendChild(style);

        const panel = document.createElement('div');
        panel.id = 'boc-panel';

        panel.innerHTML = `
            <div class="boc-header">
                <div class="boc-title">💳 制卡信息</div>
                <button class="boc-close" id="boc-close"
                    aria-label="关闭">×</button>
            </div>

            <div class="boc-label">预选卡号</div>
            <div class="boc-number" id="boc-number">等待查询...</div>

            <div class="boc-label">制卡进度</div>
            <div class="boc-status" id="boc-status">等待查询...</div>
            <div class="boc-code" id="boc-code">状态码：--</div>

            <div class="boc-steps" id="boc-steps">
                ${renderSteps('00')}
            </div>

            <div class="boc-buttons">
                <button class="boc-btn boc-copy" id="boc-copy">
                    复制卡号
                </button>
                <button class="boc-btn boc-secondary" id="boc-show">
                    显示卡号
                </button>
                <button class="boc-btn boc-secondary" id="boc-refresh">
                    刷新查询
                </button>
            </div>

            <div class="boc-tip" id="boc-tip">
                请先完成验证码验证
            </div>
        `;

        document.body.appendChild(panel);

        const toggle = document.createElement('button');
        toggle.id = 'boc-toggle';
        toggle.textContent = '💳 制卡信息';
        toggle.style.display = 'none';
        document.body.appendChild(toggle);

        document.getElementById('boc-close').onclick = () => {
            panel.style.display = 'none';
            toggle.style.display = 'block';
        };

        toggle.onclick = () => {
            panel.style.display = 'block';
            toggle.style.display = 'none';
            query();
        };

        document.getElementById('boc-refresh').onclick = query;

        document.getElementById('boc-show').onclick = () => {
            showCard = !showCard;
            render();
        };

        document.getElementById('boc-copy').onclick = async () => {
            if (!cardNo) {
                alert('暂未获取到卡号');
                return;
            }

            try {
                if (navigator.clipboard &&
                    window.isSecureContext) {
                    await navigator.clipboard.writeText(cardNo);
                } else {
                    const input = document.createElement('textarea');
                    input.value = cardNo;
                    input.style.position = 'fixed';
                    input.style.opacity = '0';
                    document.body.appendChild(input);
                    input.select();
                    const ok = document.execCommand('copy');
                    input.remove();
                    if (!ok) throw new Error('copy failed');
                }

                const btn = document.getElementById('boc-copy');
                btn.textContent = '复制成功 ✓';
                setTimeout(() => {
                    btn.textContent = '复制卡号';
                }, 1500);
            } catch (e) {
                alert('复制失败，请尝试手动复制');
            }
        };

        render();
    }

    function init() {
        createPanel();
        query();

        // 低频检测，不监听 DOM 变化，避免循环触发
        const timer = setInterval(() => {
            if (!document.getElementById('boc-panel')) {
                clearInterval(timer);
                return;
            }
            query();
        }, 1500);

        // 页面离开时停止检测
        window.addEventListener('pagehide', () => {
            clearInterval(timer);
        }, { once: true });
    }

    init();

})();
