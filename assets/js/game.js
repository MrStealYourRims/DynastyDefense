const app = document.getElementById('gameApp');
const csrf = app?.dataset.csrf || '';

function formatDuration(seconds) {
    const s = Number(seconds || 0);
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    const rem = s % 60;
    if (m < 60) return `${m}m ${rem}s`;
    const h = Math.floor(m / 60);
    const mm = m % 60;
    return `${h}h ${mm}m`;
}

function formatCosts(costs) {
    return `F:${costs.food} W:${costs.wood} S:${costs.stone} G:${costs.gold}`;
}

async function api(url, method = 'GET', data = null) {
    const options = { method, headers: {} };
    if (data) {
        options.headers['Content-Type'] = 'application/json';
        options.body = JSON.stringify({ ...data, csrf_token: csrf });
    }
    const res = await fetch(url, options);
    return res.json();
}

function renderStatus(payload) {
    ['food', 'wood', 'stone', 'gold'].forEach((res) => {
        document.getElementById(`res-${res}`).textContent = payload.city[res];
    });

    const civInfo = document.getElementById('civilizationInfo');
    if (civInfo && payload.civilization) {
        const bonusText = Object.entries(payload.civilization.bonuses || {}).map(([k,v]) => `${k}: +${v}`).join(', ');
        civInfo.innerHTML = `<small><b>Civilization:</b> ${payload.civilization.name || 'Unassigned'}<br><b>Bonuses:</b> ${bonusText || 'None'}</small>`;
    }

    const buildings = document.getElementById('buildings');
    buildings.innerHTML = '<h3>Buildings (leveled)</h3>' + payload.buildings.map((b) => {
        const next = b.next_upgrade;
        const disabled = !next.can_upgrade ? 'disabled' : '';
        return `
        <div class="data-row"><span>${b.display_name} Lv.${b.level}/${b.max_level}</span><button ${disabled} data-build="${b.id}">Upgrade</button></div>
        <div class="queue-item"><span>Next Lv.${next.target_level} • ${formatCosts(next.costs)} • ${formatDuration(next.duration_seconds)}</span></div>
        <div class="queue-item"><span>Req: Town Hall ${b.required_town_hall_level} ${next.can_upgrade ? '✓' : '✗'}</span></div>`;
    }).join('');

    const research = document.getElementById('research');
    research.innerHTML = '<h3>Research Tree</h3>' + payload.research.map((r) => {
        const next = r.next_research;
        const disabled = !next.can_research ? 'disabled' : '';
        return `
        <div class="data-row"><span>[${r.branch_key}] ${r.display_name} Lv.${r.level}/${r.max_level}</span><button ${disabled} data-research="${r.id}">Research</button></div>
        <div class="queue-item"><span>Next Lv.${next.target_level} • ${formatCosts(next.costs)} • ${formatDuration(next.duration_seconds)}</span></div>
        <div class="queue-item"><span>Prerequisite ${next.prereq_met ? '✓' : '✗'}</span></div>`;
    }).join('');

    const units = document.getElementById('units');
    units.innerHTML = '<h3>Army (Tiers 1-5)</h3>' + payload.units.map((u) => {
        const req = u.training_preview.requirements;
        const reqText = [];
        if (req.required_building_key) reqText.push(`${req.required_building_key} Lv.${req.required_building_level} ${req.building_met ? '✓' : '✗'}`);
        if (req.required_tech_id) reqText.push(`Research #${req.required_tech_id} ${req.tech_met ? '✓' : '✗'}`);
        const canTrain = req.tech_met && req.building_met;
        return `
        <div class="data-row"><span>T${u.tier} ${u.display_name}</span><span>${u.quantity || 0}</span></div>
        <div class="queue-item"><span>Train(1): ${formatCosts(u.training_preview.costs)} • ${formatDuration(u.training_preview.duration_seconds)}</span></div>
        <div class="queue-item"><span>Req: ${reqText.join(' | ') || 'None'}</span></div>
        <div class="data-row"><input type="number" min="1" value="1" id="train-${u.key_name}"><button ${canTrain ? '' : 'disabled'} data-train="${u.id}" data-key="${u.key_name}">Train</button></div>`;
    }).join('');

    const builders = document.getElementById('builders');
    if (builders) {
        builders.innerHTML = '<h3>Builders</h3>' + (payload.builders || []).map((b) =>
            `<div class="queue-item">Builder ${b.slot_index}: ${b.is_unlocked == 1 ? b.status : `locked (${b.unlock_cost_gems} gems)`}</div>`
        ).join('');
    }
    const buildings = document.getElementById('buildings');
    buildings.innerHTML = '<h3>Buildings (leveled)</h3>' + payload.buildings.map((b) => `
      <div class="data-row">
        <span>${b.display_name} Lv.${b.level}/${b.max_level} (TH ${b.required_town_hall_level}+)</span>
        <button data-build="${b.id}">Upgrade</button>
      </div>`).join('');

    const research = document.getElementById('research');
    research.innerHTML = '<h3>Research Tree</h3>' + payload.research.map((r) => `
      <div class="data-row">
        <span>[${r.branch_key}] ${r.display_name} Lv.${r.level}/${r.max_level}</span>
        <button data-research="${r.id}">Research</button>
      </div>`).join('');

    const units = document.getElementById('units');
    units.innerHTML = '<h3>Army (Tiers 1-5)</h3>' + payload.units.map((u) => `
      <div class="data-row">
        <span>T${u.tier} ${u.display_name}</span>
        <span>${u.quantity || 0}</span>
      </div>
      <div class="data-row"><input type="number" min="1" value="1" id="train-${u.key_name}"><button data-train="${u.id}" data-key="${u.key_name}">Train</button></div>`).join('');

    const commanderSelect = document.getElementById('commanderSelect');
    if (commanderSelect) {
        const options = ['<option value="0">None</option>'];
        payload.commanders.forEach((c) => {
            if (c.status === 'available') {
                options.push(`<option value="${c.id}">${c.display_name} Lv.${c.level} (${c.rarity}) +${c.attack_buff_pct}%ATK +${c.speed_buff_pct}%SPD</option>`);
                options.push(`<option value="${c.id}">${c.display_name} Lv.${c.level} (${c.rarity}) +${c.attack_buff_pct}% ATK</option>`);
            }
        });
        commanderSelect.innerHTML = options.join('');
    }
}

function renderMap(payload) {
    const map = document.getElementById('mapGrid');
    map.innerHTML = '';
    const byCoord = {};
    payload.tiles.forEach(t => { byCoord[`${t.x_coord},${t.y_coord}`] = t; });
    for (let y = payload.bounds.y1; y <= payload.bounds.y2; y++) {
        for (let x = payload.bounds.x1; x <= payload.bounds.x2; x++) {
            const tile = byCoord[`${x},${y}`] || { x_coord:x, y_coord:y, tile_type:'empty' };
            const el = document.createElement('button');
            el.className = `tile ${tile.tile_type}`;
            el.textContent = tile.tile_type === 'player_city' ? 'C' : tile.tile_type === 'npc_camp' ? 'N' : tile.tile_type === 'resource_node' ? 'R' : '';
            el.onclick = () => {
                document.getElementById('tileInfo').textContent = `(${tile.x_coord}, ${tile.y_coord}) ${tile.tile_type} ${tile.empire_name || ''}`;
            };
            map.appendChild(el);
        }
    }
}

function renderChat(payload) {
    const box = document.getElementById('chatMessages');
    box.innerHTML = payload.messages.map(m => `<div>[${m.created_at}] <b>${m.username}</b>: ${m.body}</div>`).join('');
    box.scrollTop = box.scrollHeight;
}

async function refreshAll() {
    const [status, map, chat, alliance] = await Promise.all([
        api('api/status.php'), api('api/map.php'), api('api/chat.php'), api('api/alliance.php')
    ]);
    if (!status.error) renderStatus(status);
    if (!map.error) renderMap(map);
    if (!chat.error) renderChat(chat);
    if (!alliance.error) {
        const panel = document.getElementById('alliancePanel');
        if (alliance.alliance) {
            panel.innerHTML = `<h3>Alliance</h3><p>${alliance.alliance.tag} - ${alliance.alliance.name}</p>`;
        } else {
            panel.innerHTML = `<h3>Alliance</h3>
              <input id="allianceName" placeholder="Name"><input id="allianceTag" placeholder="TAG">
              <button id="createAllianceBtn">Create</button>
              <input id="joinTag" placeholder="Join by TAG"><button id="joinAllianceBtn">Join</button>`;
        }
    }
}

document.addEventListener('click', async (e) => {
    const b = e.target.closest('[data-build]');
    if (b) {
        const res = await api('api/build.php', 'POST', { building_id: Number(b.dataset.build) });
        if (res.error) alert(res.error);
        await api('api/build.php', 'POST', { building_id: Number(b.dataset.build) });
        refreshAll();
    }
    const r = e.target.closest('[data-research]');
    if (r) {
        const res = await api('api/research.php', 'POST', { research_id: Number(r.dataset.research) });
        if (res.error) alert(res.error);
        await api('api/research.php', 'POST', { research_id: Number(r.dataset.research) });
        refreshAll();
    }
    const t = e.target.closest('[data-train]');
    if (t) {
        const qty = Number(document.getElementById(`train-${t.dataset.key}`).value || 1);
        const res = await api('api/train.php', 'POST', { unit_id: Number(t.dataset.train), quantity: qty });
        if (res.error) alert(res.error);
        await api('api/train.php', 'POST', { unit_id: Number(t.dataset.train), quantity: qty });
        refreshAll();
    }

    if (e.target.id === 'createAllianceBtn') {
        await api('api/alliance.php', 'POST', {
            action: 'create',
            name: document.getElementById('allianceName').value,
            tag: document.getElementById('allianceTag').value,
        });
        refreshAll();
    }
    if (e.target.id === 'joinAllianceBtn') {
        await api('api/alliance.php', 'POST', { action: 'join', tag: document.getElementById('joinTag').value });
        refreshAll();
    }
});

document.getElementById('sendArmyForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = new FormData(e.target);
    const payload = Object.fromEntries(form.entries());
    Object.keys(payload).forEach(k => payload[k] = isNaN(payload[k]) ? payload[k] : Number(payload[k]));
    const res = await api('api/move.php', 'POST', payload);
    alert(res.error || `Army dispatched. ETA: ${res.arrives_at}`);
    refreshAll();
});

document.getElementById('chatForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = e.target.message.value;
    e.target.message.value = '';
    await api('api/chat.php', 'POST', { body: text, channel: 'global' });
    refreshAll();
});

refreshAll();
setInterval(refreshAll, 15000);
