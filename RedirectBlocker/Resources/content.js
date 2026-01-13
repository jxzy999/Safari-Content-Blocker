// content.js

const mainWorldScript = `
(function() {
    console.log("🛡️ [防跳转] 超级拦截脚本已注入");

    // ==========================================
    // 策略 1: 针对性废除常见跳转函数 (Sanjiangge 等站专用)
    // ==========================================
    // 这些网站通常定义一个叫 uaredirect 的函数来跳转
    // 我们直接抢先定义它，并让它变成空函数，这样网站的脚本就失效了
    Object.defineProperty(window, 'uaredirect', {
        value: function(murl) {
            console.log("✅ 成功拦截 uaredirect 函数调用，目标:", murl);
            return; // 什么都不做
        },
        writable: false, // 禁止网站覆盖我们的函数
        configurable: false
    });

    // ==========================================
    // 策略 2: 拦截 location.replace 和 assign
    // ==========================================
    const originalReplace = window.location.replace;
    const originalAssign = window.location.assign;

    window.location.replace = function(url) {
        console.log("🛑 拦截 location.replace:", url);
        // 只有用户确认才放行
        if(confirm("网页试图跳转到：" + url + "\\n\\n是否允许？")) {
            originalReplace.call(window.location, url);
        }
    };
    
    window.location.assign = function(url) {
        console.log("🛑 拦截 location.assign:", url);
        if(confirm("网页试图跳转到：" + url + "\\n\\n是否允许？")) {
            originalAssign.call(window.location, url);
        }
    };

    // ==========================================
    // 策略 3: beforeunload (终极防线)
    // ==========================================
    // 这是唯一能拦截 window.location.href = "..." 的办法
    // 机制：如果浏览器要离开当前页，必须经过这一关
    
    // 标记是否是用户点击行为
    let isUserClick = false;
    
    window.addEventListener('click', function() {
        isUserClick = true;
        // 1秒后重置，防止一次点击永久放行
        setTimeout(() => { isUserClick = false; }, 1000);
    }, true);

    window.addEventListener('beforeunload', function(e) {
        // 如果是用户刚才点击了链接，放行
        if (isUserClick) return;

        // 否则，视为脚本自动跳转，强制弹窗拦截
        // 注意：现代浏览器为了防止滥用，不一定显示自定义文本，但会显示默认提示
        e.preventDefault();
        e.returnValue = '检测到自动跳转行为，已拦截。';
        return '检测到自动跳转行为，已拦截。';
    });
    
    console.log("🛡️ 防御体系已建立");
})();
`;

// ==========================================
// 策略 4: 清理 Meta Refresh (针对 HTML 标签跳转)
// ==========================================
// 这种跳转不走 JS，必须移除 DOM 节点
function removeMetaRefresh() {
    const metas = document.querySelectorAll('meta[http-equiv="refresh"]');
    metas.forEach(meta => {
        console.log("🗑️ 移除 Meta Refresh 标签:", meta.content);
        meta.remove();
    });
}

// 立即执行一次
removeMetaRefresh();

// 监听 DOM 变化，防止后续动态添加
const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
            if (node.tagName === 'META' && node.getAttribute('http-equiv')?.toLowerCase() === 'refresh') {
                console.log("🗑️ 拦截到动态插入的 Meta Refresh");
                node.remove();
            }
        });
    });
});
observer.observe(document.documentElement, { childList: true, subtree: true });


// ==========================================
// 注入主世界脚本
// ==========================================
const script = document.createElement('script');
script.textContent = mainWorldScript;
const parent = document.head || document.documentElement;
parent.insertBefore(script, parent.firstChild);
script.remove();
