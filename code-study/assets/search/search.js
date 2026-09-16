/* Local full-text navigation only. No fetch, HTML renderer, network or telemetry. */
(() => {
  'use strict';
  const data = window.CODE_STUDY_DATA;
  const $ = s => document.querySelector(s);
  const input = $('#query'), kind = $('#kind'), box = $('#results'), status = $('#status');
  const more = $('#more'), empty = $('#empty');
  if (!data || !Array.isArray(data.entries)) { status.textContent = '索引缺失或格式错误，请重新生成 assets/search-index.js。'; return; }
  const norm = s => String(s).normalize('NFKC').toLowerCase();
  const safePath = p => typeof p === 'string' && p.length > 0 && !p.startsWith('/') && !p.includes('\\') && !p.includes(':') && !p.split('/').includes('..');
  const entries = data.entries.filter(e => safePath(e.path) && typeof e.text === 'string').map(e => ({...e, hay: norm(e.title + '\n' + e.path + '\n' + e.text)}));
  $('#baseline').textContent = '冻结基线：' + data.baseline;
  let matched = [], shown = 0, tokens = [], timer;
  function mark(text) {
    const fragment = document.createDocumentFragment();
    if (!tokens.length) { fragment.append(document.createTextNode(text)); return fragment; }
    const escaped = tokens.map(t => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    const re = new RegExp(escaped.join('|'), 'gi'); let pos = 0, m;
    while ((m = re.exec(text))) {
      fragment.append(document.createTextNode(text.slice(pos, m.index)));
      const hit = document.createElement('mark'); hit.textContent = m[0]; fragment.append(hit);
      pos = m.index + m[0].length;
    }
    fragment.append(document.createTextNode(text.slice(pos))); return fragment;
  }
  function excerpt(e) {
    const text = e.text.replace(/!\[[^\]]*\]\([^)]*\)/g, '').replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/^#{1,6}\s+/gm, '').replace(/`/g, '').replace(/\n{3,}/g, '\n\n');
    const positions = tokens.map(t => norm(text).indexOf(t)).filter(n => n >= 0);
    const at = positions.length ? Math.min(...positions) : 0, start = Math.max(0, at - 70);
    const end = Math.min(text.length, start + 300);
    return (start ? '…' : '') + text.slice(start, end) + (end < text.length ? '…' : '');
  }
  function localPath(path) {
    const url = new URL(path, document.baseURI);
    return url.protocol === 'file:' ? decodeURIComponent(url.pathname).replace(/^\/([A-Za-z]:)/, '$1') : url.href;
  }
  async function copy(text, button, label) {
    let ok = false;
    try { if (navigator.clipboard) { await navigator.clipboard.writeText(text); ok = true; } } catch (_) {}
    if (!ok) {
      const area = document.createElement('textarea'); area.value = text; area.style.position = 'fixed'; area.style.left = '-9999px'; document.body.append(area); area.select();
      try { ok = document.execCommand('copy'); } catch (_) {} area.remove();
    }
    button.textContent = ok ? '已复制' : '复制失败，请手动选择路径';
    setTimeout(() => { button.textContent = label; }, 2000);
  }
  function next() {
    const end = Math.min(shown + 40, matched.length);
    for (let i = shown; i < end; i++) {
      const e = matched[i], card = document.createElement('article'); card.className = 'result';
      const badge = document.createElement('span'); badge.className = 'badge'; badge.textContent = e.kind;
      const heading = document.createElement('h2'), link = document.createElement('a'); link.href = encodeURI(e.path); link.append(mark(e.title)); heading.append(link);
      const p = document.createElement('p'); p.className = 'excerpt'; p.append(mark(excerpt(e)));
      const path = document.createElement('code'); path.className = 'path'; path.textContent = e.path;
      const full = document.createElement('code'); full.className = 'full-path'; full.textContent = localPath(e.path);
      const actions = document.createElement('div'); actions.className = 'actions';
      const open = document.createElement('a'); open.href = encodeURI(e.path); open.textContent = e.kind === '源码' ? '打开冻结源码' : '打开 .md'; actions.append(open);
      for (const [text, label] of [[e.path, '复制相对路径'], [localPath(e.path), '复制完整路径']]) {
        const button = document.createElement('button'); button.type = 'button'; button.textContent = label; button.addEventListener('click', () => copy(text, button, label)); actions.append(button);
      }
      card.append(badge, heading, p, path, full, actions); box.append(card);
    }
    shown = end; more.hidden = shown >= matched.length; more.textContent = `继续显示（${shown} / ${matched.length}）`;
  }
  function run(save = true) {
    tokens = [...new Set(norm(input.value.trim()).split(/\s+/).filter(Boolean))];
    matched = entries.filter(e => (!kind.value || e.kind === kind.value) && tokens.every(t => e.hay.includes(t)));
    const score = e => tokens.reduce((s, t) => s + (norm(e.title).includes(t) ? 100 : 0) + (norm(e.path).includes(t) ? 40 : 0), e.kind === '阶段' ? 2 : 0);
    matched.sort((a, b) => score(b) - score(a) || a.path.localeCompare(b.path, 'zh-CN'));
    shown = 0; box.replaceChildren(); empty.hidden = matched.length !== 0;
    status.textContent = `${matched.length} 条结果 · 全文索引 ${entries.length} 个文件 · 多关键词同时命中`;
    next();
    if (save) { const p = new URLSearchParams(); if (input.value.trim()) p.set('q', input.value.trim()); if (kind.value) p.set('kind', kind.value); try { history.replaceState(null, '', '#' + p.toString()); } catch (_) {} }
  }
  function restore() { const p = new URLSearchParams(location.hash.slice(1)); input.value = p.get('q') || ''; kind.value = p.get('kind') || ''; run(false); }
  input.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => run(), 100); });
  $('#search-form').addEventListener('submit', e => { e.preventDefault(); clearTimeout(timer); run(); });
  kind.addEventListener('change', () => run()); more.addEventListener('click', next);
  $('#reset').addEventListener('click', () => { clearTimeout(timer); input.value = ''; kind.value = ''; run(); input.focus(); });
  window.addEventListener('hashchange', restore); restore();
})();
