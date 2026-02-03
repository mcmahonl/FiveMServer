let state = {
    mode: null,
    team: 1,
    role: 'runner',
    selectedCar: 1,
};

const carNames = ['Insurgent', 'Kuruma', 'Zentorno'];
const fullCarNames = ['HVY Insurgent', 'Karin Kuruma (Armored)', 'Pegassi Zentorno'];

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.type) {
        case 'showLobby': showLobby(data); break;
        case 'hideLobby': hideLobby(); break;
        case 'updateLobby': updateLobby(data); break;
        case 'updateTimer': updateTimer(data.time, data.label); break;
        case 'showRaceCountdown': showRaceCountdown(data.number, data.text); break;
        case 'hideRaceCountdown': hideRaceCountdown(); break;
        case 'showRaceHud': showRaceHud(); break;
        case 'hideRaceHud': hideRaceHud(); break;
        case 'updateRaceHud': updateRaceHud(data); break;
        case 'showEditor': showEditor(data); break;
        case 'hideEditor': hideEditor(); break;
        case 'updateEditor': updateEditor(data); break;
        case 'updateOnlinePlayers': updateOnlinePlayers(data.players); break;
        case 'updatePot': updatePot(data.pot, data.wager, data.teamSize || 1); break;
        case 'showResults': showResults(data.data); break;
        case 'hideResults': hideResults(); break;
    }
});

function showLobby(data) {
    state.mode = 'lobby';
    state.team = data.team;
    state.role = data.role;
    state.selectedCar = 1;
    document.getElementById('lobby').classList.remove('hidden');
    updateRole();
    updateCarSelection();
}

function hideLobby() {
    state.mode = null;
    document.getElementById('lobby').classList.add('hidden');
}

function updateLobby(data) {
    document.getElementById('green-count').textContent = data.players.green.length;
    document.getElementById('purple-count').textContent = data.players.purple.length;
    updatePlayerList('green-players', data.players.green);
    updatePlayerList('purple-players', data.players.purple);
}

function updatePlayerList(elementId, players) {
    const container = document.getElementById(elementId);
    container.innerHTML = '';
    players.forEach(p => {
        const div = document.createElement('div');
        div.className = 'player' + (p.ready ? ' player-ready' : '');
        const roleClass = p.role === 'runner' ? 'role-runner' : 'role-blocker';
        div.innerHTML = '<span>' + p.name + '</span><span class="player-role ' + roleClass + '">' + p.role.toUpperCase() + '</span>';
        container.appendChild(div);
    });
}

function updateRole() {
    const roleEl = document.getElementById('role');
    roleEl.textContent = state.role.toUpperCase();
    roleEl.className = 'role ' + (state.role === 'runner' ? 'role-runner-text' : 'role-blocker-text');
    updateCarSelection();
}

function updateCarSelection() {
    const container = document.getElementById('car-options');
    container.innerHTML = '';
    if (state.role === 'runner') {
        const div = document.createElement('div');
        div.className = 'car-option selected';
        div.textContent = 'Voodoo';
        container.appendChild(div);
        document.getElementById('car-name').textContent = 'Declasse Voodoo';
    } else {
        carNames.forEach((name, idx) => {
            const div = document.createElement('div');
            div.className = 'car-option' + (state.selectedCar === idx + 1 ? ' selected' : '');
            div.textContent = name;
            div.onclick = () => selectCar(idx + 1);
            container.appendChild(div);
        });
        document.getElementById('car-name').textContent = fullCarNames[state.selectedCar - 1];
    }
}

function selectCar(index) {
    if (state.role === 'runner') return;
    state.selectedCar = index;
    updateCarSelection();
    fetch('https://offense-defense/selectCar', { method: 'POST', body: JSON.stringify({ car: index }) });
}

function updateTimer(time, label) {
    document.getElementById('timer').textContent = time !== null ? time : '--';
    document.getElementById('timer-label').textContent = label || 'WAITING FOR PLAYERS';
}

function showRaceCountdown(number, text) {
    state.mode = 'countdown';
    const el = document.getElementById('race-countdown');
    const numEl = document.getElementById('countdown-number');
    const textEl = document.getElementById('countdown-text');
    el.classList.remove('hidden');
    numEl.textContent = number;
    numEl.className = 'race-countdown-number' + (number === 'GO' ? ' go' : '');
    textEl.textContent = text || '';
    numEl.style.animation = 'none';
    void numEl.offsetHeight;
    numEl.style.animation = 'pulse 1s ease-in-out';
}

function hideRaceCountdown() {
    state.mode = null;
    document.getElementById('race-countdown').classList.add('hidden');
}

function showEditor(data) {
    state.mode = 'editor';
    document.getElementById('editor').classList.remove('hidden');
    updateEditor(data);
}

function hideEditor() {
    state.mode = null;
    document.getElementById('editor').classList.add('hidden');
}

function updateEditor(data) {
    document.getElementById('editor-map').textContent = data.mapName || 'untitled';
    document.getElementById('editor-cp-count').textContent = data.checkpoints || 0;
    document.getElementById('editor-lobby').textContent = data.hasLobby ? 'YES' : 'NO';
    document.getElementById('editor-grid').textContent = data.hasGrid ? 'YES' : 'NO';
}

function updateOnlinePlayers(players) {
    const container = document.getElementById('online-players');
    if (!container) return;
    container.innerHTML = '';
    players.forEach(p => {
        const div = document.createElement('div');
        div.className = 'online-player';
        const rankHtml = p.rank > 0 ? '<span class="online-rank">#' + p.rank + '</span>' : '';
        const pointsHtml = p.points !== undefined ? '<span class="online-points">' + p.points.toLocaleString() + 'pts</span>' : '';
        div.innerHTML = rankHtml + '<span class="online-name">' + p.name + '</span>' + pointsHtml + '<span class="online-role ' + p.role + '">' + p.role.toUpperCase() + '</span>';
        container.appendChild(div);
    });
}

function updatePot(pot, wager, teamSize) {
    const potAmount = document.getElementById('pot-amount');
    const yourWager = document.getElementById('your-wager');
    const yourWinnings = document.getElementById('your-winnings');

    if (potAmount) potAmount.textContent = pot.toLocaleString();
    if (yourWager) yourWager.textContent = 'Your wager: ' + wager.toLocaleString();

    if (yourWinnings && teamSize > 0) {
        const winShare = Math.floor(pot / teamSize);
        const netGain = winShare - wager;
        yourWinnings.textContent = 'If you win: +' + netGain.toLocaleString();
    }
}

function showResults(data) {
    state.mode = 'results';
    const el = document.getElementById('results');
    const title = document.getElementById('results-title');
    const change = document.getElementById('results-change');
    const total = document.getElementById('results-total');

    // Set title
    if (data.won) {
        title.textContent = 'TEAM ' + data.teamName.toUpperCase() + ' WINS!';
        title.className = 'results-title win';
    } else {
        title.textContent = 'YOU LOSE';
        title.className = 'results-title lose';
    }

    // Set change with +/- sign
    const changeVal = data.change;
    if (changeVal >= 0) {
        change.textContent = '+' + changeVal.toLocaleString();
        change.className = 'results-change positive';
    } else {
        change.textContent = changeVal.toLocaleString();
        change.className = 'results-change negative';
    }

    // Set new total
    total.textContent = data.newTotal.toLocaleString() + ' POINTS';

    el.classList.remove('hidden');

    // Auto-hide after 7 seconds
    setTimeout(() => hideResults(), 7000);
}

function hideResults() {
    state.mode = null;
    document.getElementById('results').classList.add('hidden');
    // Reset pot display
    const potDisplay = document.getElementById('pot-display');
    if (potDisplay) potDisplay.classList.add('hidden');
}

function showRaceHud() {
    document.getElementById('race-hud').classList.remove('hidden');
}

function hideRaceHud() {
    document.getElementById('race-hud').classList.add('hidden');
}

function updateRaceHud(data) {
    // Update checkpoint progress
    const cpProgress = document.getElementById('cp-progress');
    const cpDistance = document.getElementById('cp-distance');
    if (cpProgress) cpProgress.textContent = data.checkpoint + ' / ' + data.totalCheckpoints;
    if (cpDistance) cpDistance.textContent = data.distance + 'm';

    // Update positions
    const pos1 = document.getElementById('pos-1st');
    const pos2 = document.getElementById('pos-2nd');
    if (pos1 && pos2 && data.positions) {
        const first = data.positions[0];
        const second = data.positions[1];
        if (first) {
            pos1.innerHTML = '1ST <span class="team-name ' + first.team.toLowerCase() + '">' + first.team.toUpperCase() + '</span>';
        }
        if (second) {
            pos2.innerHTML = '2ND <span class="team-name ' + second.team.toLowerCase() + '">' + second.team.toUpperCase() + '</span>';
        }
    }
}

document.addEventListener('keydown', (e) => {
    if (state.mode === 'lobby') {
        if ((e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') && state.role === 'blocker') {
            state.selectedCar = Math.max(1, state.selectedCar - 1);
            updateCarSelection();
            fetch('https://offense-defense/selectCar', { method: 'POST', body: JSON.stringify({ car: state.selectedCar }) });
        }
        if ((e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') && state.role === 'blocker') {
            state.selectedCar = Math.min(3, state.selectedCar + 1);
            updateCarSelection();
            fetch('https://offense-defense/selectCar', { method: 'POST', body: JSON.stringify({ car: state.selectedCar }) });
        }
        if (e.key === 'Enter') fetch('https://offense-defense/ready', { method: 'POST' });
        if (e.key === 'Escape') fetch('https://offense-defense/leave', { method: 'POST' });
        if (e.key === 'g' || e.key === 'G') fetch('https://offense-defense/switchTeam', { method: 'POST', body: JSON.stringify({ team: 1 }) });
        if (e.key === 'p' || e.key === 'P') fetch('https://offense-defense/switchTeam', { method: 'POST', body: JSON.stringify({ team: 2 }) });
        if (e.key === 'r' || e.key === 'R') fetch('https://offense-defense/switchRole', { method: 'POST', body: JSON.stringify({ role: 'runner' }) });
        if (e.key === 'b' || e.key === 'B') fetch('https://offense-defense/switchRole', { method: 'POST', body: JSON.stringify({ role: 'blocker' }) });
    }
    if (state.mode === 'editor' && e.key === 'Escape') {
        fetch('https://offense-defense/editorExit', { method: 'POST' });
    }
});
