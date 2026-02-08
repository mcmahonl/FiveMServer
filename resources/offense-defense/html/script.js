let resultsTimeout = null;
let browserExpanded = false;
let state = {
    mode: null,
    game: null, // 'od' or 'rb' or 'sumo'
    editorGame: null, // 'od' or 'rb' or 'sumo' (for editor)
    team: 1,
    role: 'runner',
    selectedCar: 1,
};

// Vehicle configs per game
const gameVehicles = {
    od: {
        runner: { short: 'Voodoo', full: 'Declasse Voodoo' },
        blocker: [
            { short: 'Insurgent', full: 'HVY Insurgent' },
            { short: 'Kuruma', full: 'Karin Kuruma (Armored)' },
            { short: 'Zentorno', full: 'Pegassi Zentorno' },
        ]
    },
    rb: {
        runner: { short: 'Panto', full: 'Benefactor Panto' },
        blocker: [
            { short: 'Insurgent', full: 'HVY Insurgent' },
            { short: 'Nightshark', full: 'HVY Nightshark' },
            { short: 'Tezeract', full: 'Pegassi Tezeract' },
        ]
    },
    sumo: {
        vehicles: [
            'Phantom Wedge', 'Ramp Buggy', 'Vapid Monster Truck', 'Half-Track', 'HVY Menacer', 'Chernobog',
            'Overflod Autarch', 'Coil Cyclone', 'Progen GP1', 'Ocelot XA-21', 'Ocelot Penetrator',
            'Overflod Entity XF', 'Overflod Entity XXR', 'Progen T20', 'Grotti Turismo R', 'Grotti Cheetah', 'Pegassi Zentorno',
            'Ubermacht Revolter', 'Pfister Neon', 'Coil Raiden', 'Benefactor Schafter V12', 'Stirling GT',
            'Vapid Dominator', 'Willard Faction Custom', 'Albany Buccaneer Custom', 'Karin Sultan RS',
            'Canis Kamacho', 'Dune FAV', 'BF Bifta', 'BF Injection', 'Karin Rebel', 'Vapid Sandking',
            'Benefactor Panto', 'Weeny Issi', 'Declasse Mamba',
        ]
    }
};

const gameNames = {
    od: 'OFFENSE DEFENSE',
    rb: 'RUNNING BACK',
    sumo: 'SUMO'
};

// Get NUI callback prefix for current game
function getCallback(name) {
    if (state.game === 'rb') return 'rb_' + name;
    if (state.game === 'sumo') return 'sumo_' + name;
    return name; // OD uses original callback names
}

window.addEventListener('message', (event) => {
    const data = event.data;

    switch(data.type) {
        case 'showLobby': showLobby(data); break;
        case 'hideLobby': hideLobby(); break;
        case 'updateLobby': updateLobby(data); break;
        case 'updateTimer': updateTimer(data.time, data.label); break;
        case 'showRaceCountdown': showRaceCountdown(data.number, data.text); break;
        case 'hideRaceCountdown': hideRaceCountdown(); break;
        case 'showFinalCheckpoint': showFinalCheckpoint(); break;
        case 'showRaceHud': showRaceHud(data); break;
        case 'hideRaceHud': hideRaceHud(); break;
        case 'updateRaceHud': updateRaceHud(data); break;
        case 'showEditor': showEditor(data); break;
        case 'hideEditor': hideEditor(); break;
        case 'updateEditor': updateEditor(data); break;
        case 'updateOnlinePlayers': updateOnlinePlayers(data.players); break;
        case 'updatePot': updatePot(data.pot, data.wager, data.teamSize || 1); break;
        case 'showResults': showResults(data.data); break;
        case 'hideResults': hideResults(); break;
        case 'showRespawnProgress': showRespawnProgress(data.progress); break;
        case 'hideRespawnProgress': hideRespawnProgress(); break;
        case 'setPlayersTitle': setPlayersTitle(data.title); break;
        case 'updateMinigames': updateMinigames(data.games); break;
        case 'showBrowser': showBrowser(); break;
        case 'hideBrowser': hideBrowser(); break;
        case 'showCarHud': showCarHud(); break;
        case 'hideCarHud': hideCarHud(); break;
        case 'updateCarHud': updateCarHud(data); break;
        case 'showRoundResult': showRoundResult(data); break;
        case 'hideRoundResult': hideRoundResult(); break;
        case 'updateRoundScore': updateRoundScore(data); break;
        case 'toggleBrowser': toggleBrowser(); break;
    }
});

function showLobby(data) {
    document.getElementById('timer').textContent = '--';
    document.getElementById('timer-label').textContent = 'WAITING FOR PLAYERS';
    state.mode = 'lobby';
    state.game = data.game || 'od';
    state.team = data.team;
    state.role = data.role;
    state.selectedCar = 1;

    // Update lobby title based on game
    const headerEl = document.querySelector('#lobby .header h1');
    const subtitleEl = document.querySelector('#lobby .subtitle');
    if (headerEl) headerEl.textContent = gameNames[state.game] || 'MINIGAME';
    if (subtitleEl) subtitleEl.textContent = 'Green vs Purple';

    // Update controls and role label based on game type
    const controlsEl = document.querySelector('#lobby .controls');
    const roleLabelEl = document.querySelector('#lobby .role-label');
    const roleDisplayEl = document.querySelector('#lobby .role-display');
    if (state.game === 'sumo') {
        // Sumo: no roles, carousel car selection
        if (roleDisplayEl) roleDisplayEl.classList.add('hidden');
        if (controlsEl) controlsEl.innerHTML =
            '<span class="key">G</span><span class="key">P</span> Team ' +
            '<span class="key">A</span><span class="key">D</span> Car ' +
            '<span class="key">ENTER</span> Ready ' +
            '<span class="key">ESC</span> Leave';
    } else if (state.game === 'rb') {
        // RB: no role switching, runner is auto-assigned each round
        if (roleDisplayEl) roleDisplayEl.classList.remove('hidden');
        if (controlsEl) controlsEl.innerHTML =
            '<span class="key">G</span><span class="key">P</span> Team ' +
            '<span class="key">A</span><span class="key">D</span> Car ' +
            '<span class="key">ENTER</span> Ready ' +
            '<span class="key">ESC</span> Leave';
        if (roleLabelEl) roleLabelEl.textContent = 'RUNNER AUTO-ASSIGNED EACH ROUND';
    } else {
        if (roleDisplayEl) roleDisplayEl.classList.remove('hidden');
        if (controlsEl) controlsEl.innerHTML =
            '<span class="key">G</span><span class="key">P</span> Team ' +
            '<span class="key">R</span><span class="key">B</span> Role ' +
            '<span class="key">A</span><span class="key">D</span> Car ' +
            '<span class="key">ENTER</span> Ready ' +
            '<span class="key">ESC</span> Leave';
        if (roleLabelEl) roleLabelEl.textContent = 'YOUR ROLE';
    }

    document.getElementById('lobby').classList.remove('hidden');
    document.getElementById('minigames-browser').classList.add('hidden');
    updateRole();
    updateCarSelection();
}

function hideLobby() {
    state.mode = null;
    state.game = null;
    document.getElementById('lobby').classList.add('hidden');
    restoreBrowser();
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
    const vehicles = gameVehicles[state.game || 'od'];

    if (state.game === 'sumo') {
        // Sumo: carousel-style single car display with arrows
        const carList = vehicles.vehicles;
        const idx = state.selectedCar - 1;
        const carName = carList[idx] || carList[0];
        container.innerHTML =
            '<span class="car-arrow">&laquo;</span>' +
            '<div class="car-option selected sumo-car">' + carName + '</div>' +
            '<span class="car-arrow">&raquo;</span>';
        // Update car label
        const labelEl = document.querySelector('.car-label');
        if (labelEl) labelEl.textContent = 'SELECT VEHICLE (' + state.selectedCar + '/' + carList.length + ')';
    } else if (state.role === 'runner' && state.game !== 'rb') {
        // Only show runner vehicle for OD; RB always shows blocker selection
        const div = document.createElement('div');
        div.className = 'car-option selected';
        div.textContent = vehicles.runner.short;
        container.appendChild(div);
    } else {
        vehicles.blocker.forEach((car, idx) => {
            const div = document.createElement('div');
            div.className = 'car-option' + (state.selectedCar === idx + 1 ? ' selected' : '');
            div.textContent = car.short;
            div.onclick = () => selectCar(idx + 1);
            container.appendChild(div);
        });
    }
}

function selectCar(index) {
    if (state.role === 'runner' && state.game !== 'sumo') return;
    state.selectedCar = index;
    updateCarSelection();
    fetch('https://offense-defense/' + getCallback('selectCar'), { method: 'POST', body: JSON.stringify({ car: index }) });
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
    document.getElementById('minigames-browser').classList.add('hidden');
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

// Editor - dynamic based on game type
function showEditor(data) {
    state.mode = 'editor';
    state.editorGame = data.game || 'od';
    document.getElementById('editor').classList.remove('hidden');
    document.getElementById('minigames-browser').classList.add('hidden');

    const titleEl = document.getElementById('editor-title');
    if (titleEl) {
        if (state.editorGame === 'sumo') titleEl.textContent = 'SUMO MAP EDITOR';
        else if (state.editorGame === 'rb') titleEl.textContent = 'RB MAP EDITOR';
        else titleEl.textContent = 'RACE EDITOR';
    }

    updateEditor(data);
}

function hideEditor() {
    state.mode = null;
    state.editorGame = null;
    document.getElementById('editor').classList.add('hidden');
    restoreBrowser();
}

function updateEditor(data) {
    const infoEl = document.getElementById('editor-info');
    const controlsEl = document.getElementById('editor-controls');
    const titleEl = document.getElementById('editor-title');
    const game = data.game || state.editorGame || 'od';

    if (game === 'sumo') {
        if (titleEl) titleEl.textContent = 'SUMO MAP EDITOR';
        if (infoEl) infoEl.innerHTML =
            '<div>Map: <span>' + (data.mapName || 'untitled') + '</span></div>' +
            '<div>Team 1 Spawn: <span>' + (data.hasTeam1 ? 'YES' : 'NO') + '</span></div>' +
            '<div>Team 2 Spawn: <span>' + (data.hasTeam2 ? 'YES' : 'NO') + '</span></div>' +
            '<div class="editor-note">Arena center auto-calculated from spawns</div>';
        if (controlsEl) controlsEl.innerHTML =
            '<div><span class="key">1</span> Set Team 1 Spawn</div>' +
            '<div><span class="key">2</span> Set Team 2 Spawn</div>' +
            '<div><span class="key">3</span> Set Arena Center</div>' +
            '<div><span class="key">\u2191\u2193</span> Adjust Radius</div>' +
            '<div><span class="key">E</span> Remove Last</div>' +
            '<div><span class="key">Z</span> Save Map</div>' +
            '<div><span class="key">ESC</span> Exit Editor</div>';
    } else if (game === 'rb') {
        if (infoEl) infoEl.innerHTML =
            '<div>Map: <span>' + (data.mapName || 'untitled') + '</span></div>' +
            '<div>Team 1 Spawn: <span>' + (data.hasTeam1 ? 'YES' : 'NO') + '</span></div>' +
            '<div>Team 2 Spawn: <span>' + (data.hasTeam2 ? 'YES' : 'NO') + '</span></div>' +
            '<div class="editor-note">End zones auto-placed behind each spawn</div>';
        if (controlsEl) controlsEl.innerHTML =
            '<div><span class="key">1</span> Set Team 1 Spawn</div>' +
            '<div><span class="key">2</span> Set Team 2 Spawn</div>' +
            '<div><span class="key">E</span> Remove Last</div>' +
            '<div><span class="key">Z</span> Save Map</div>' +
            '<div><span class="key">ESC</span> Exit Editor</div>';
    } else {
        // OD editor
        if (infoEl) infoEl.innerHTML =
            '<div>Map: <span>' + (data.mapName || 'untitled') + '</span></div>' +
            '<div>Checkpoints: <span>' + (data.checkpoints || 0) + '</span></div>' +
            '<div>Lobby set: <span>' + (data.hasLobby ? 'YES' : 'NO') + '</span></div>' +
            '<div>Start grid: <span>' + (data.hasGrid ? 'YES' : 'NO') + '</span></div>';
        if (controlsEl) controlsEl.innerHTML =
            '<div><span class="key">X</span> Add Checkpoint</div>' +
            '<div><span class="key">E</span> Remove Last</div>' +
            '<div><span class="key">H</span> Set Lobby Here</div>' +
            '<div><span class="key">G</span> Set Start Grid</div>' +
            '<div><span class="key">Z</span> Save Map</div>' +
            '<div><span class="key">ESC</span> Exit Editor</div>';
    }
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
    if (resultsTimeout) { clearTimeout(resultsTimeout); resultsTimeout = null; }
    state.mode = 'results';
    const el = document.getElementById('results');
    const title = document.getElementById('results-title');
    const change = document.getElementById('results-change');
    const total = document.getElementById('results-total');

    if (data.won) {
        title.textContent = 'TEAM ' + data.teamName.toUpperCase() + ' WINS!';
        title.className = 'results-title win';
    } else {
        title.textContent = 'YOU LOSE';
        title.className = 'results-title lose';
    }

    const changeVal = data.change;
    if (changeVal >= 0) {
        change.textContent = '+' + changeVal.toLocaleString();
        change.className = 'results-change positive';
    } else {
        change.textContent = changeVal.toLocaleString();
        change.className = 'results-change negative';
    }

    total.textContent = data.newTotal.toLocaleString() + ' POINTS';
    el.classList.remove('hidden');
    resultsTimeout = setTimeout(() => hideResults(), 7000);
}

function hideResults() {
    state.mode = null;
    document.getElementById('results').classList.add('hidden');
    const potDisplay = document.getElementById('pot-display');
    if (potDisplay) potDisplay.classList.add('hidden');
}

function showRaceHud(data) {
    const game = (data && data.game) || state.game || 'od';
    const cpLabel = document.getElementById('cp-label');
    const roundScore = document.getElementById('round-score');

    if (game === 'sumo') {
        if (cpLabel) cpLabel.textContent = 'TIME';
        if (roundScore) roundScore.classList.remove('hidden');
    } else if (game === 'rb') {
        // RB: show round score, distance label
        if (cpLabel) cpLabel.textContent = 'END ZONE';
        if (roundScore) roundScore.classList.remove('hidden');
    } else {
        // OD: checkpoint label, hide score
        if (cpLabel) cpLabel.textContent = 'CHECKPOINT';
        if (roundScore) roundScore.classList.add('hidden');
    }

    document.getElementById('race-hud').classList.remove('hidden');
    document.getElementById('minigames-browser').classList.add('hidden');
}

function hideRaceHud() {
    document.getElementById('race-hud').classList.add('hidden');
    restoreBrowser();
    const roundScore = document.getElementById('round-score');
    if (roundScore) roundScore.classList.add('hidden');
}

function updateRaceHud(data) {
    const game = data.game || state.game || 'od';
    const cpLabel = document.getElementById('cp-label');
    const cpProgress = document.getElementById('cp-progress');
    const cpDistance = document.getElementById('cp-distance');
    const pos1 = document.getElementById('pos-1st');
    const pos2 = document.getElementById('pos-2nd');

    if (game === 'sumo') {
        if (cpLabel) cpLabel.textContent = 'TIME';
        if (cpProgress) cpProgress.textContent = data.timer ? data.timer + 's' : '--';
        if (cpDistance) {
            if (data.eliminated) {
                cpDistance.textContent = 'ELIMINATED';
            } else {
                cpDistance.textContent = 'ALIVE';
            }
        }

        // Show alive counts per team
        if (pos1 && pos2) {
            const g = data.aliveGreen !== undefined ? data.aliveGreen : '?';
            const p = data.alivePurple !== undefined ? data.alivePurple : '?';
            pos1.innerHTML = '<span class="team-name green">GREEN</span> ' + g + ' alive';
            pos2.innerHTML = '<span class="team-name purple">PURPLE</span> ' + p + ' alive';
        }
    } else if (game === 'rb') {
        // RB: show round timer, offense/defense info, distance for runner
        if (cpLabel) cpLabel.textContent = 'TIME';
        if (cpProgress) cpProgress.textContent = data.timer ? data.timer + 's' : '--';
        if (cpDistance) {
            if (data.role === 'runner') {
                cpDistance.textContent = data.distance + 'm to End Zone';
            } else {
                cpDistance.textContent = data.role ? data.role.toUpperCase() : '';
            }
        }

        // Show offense/defense teams
        if (pos1 && pos2 && data.offenseTeam) {
            const offTeam = data.offenseTeam === 1 ? 'GREEN' : 'PURPLE';
            const defTeam = data.offenseTeam === 1 ? 'PURPLE' : 'GREEN';
            pos1.innerHTML = 'OFF <span class="team-name ' + offTeam.toLowerCase() + '">' + offTeam + '</span>';
            pos2.innerHTML = 'DEF <span class="team-name ' + defTeam.toLowerCase() + '">' + defTeam + '</span>';
        }
    } else {
        // OD: show checkpoint progress
        if (cpLabel) cpLabel.textContent = 'CHECKPOINT';
        if (cpProgress) cpProgress.textContent = data.checkpoint + ' / ' + data.totalCheckpoints;
        if (cpDistance) cpDistance.textContent = data.distance + 'm';

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
}

// Round result (between RB rounds)
function showRoundResult(data) {
    const el = document.getElementById('round-result');
    const title = document.getElementById('round-result-title');
    const score = document.getElementById('round-result-score');

    if (data.won) {
        title.textContent = 'TEAM ' + data.teamName.toUpperCase() + ' SCORES!';
        title.className = 'round-result-title win';
    } else {
        title.textContent = 'TEAM ' + data.teamName.toUpperCase() + ' SCORES';
        title.className = 'round-result-title lose';
    }

    score.textContent = (data.greenScore || 0) + ' - ' + (data.purpleScore || 0);

    el.classList.remove('hidden');
}

function hideRoundResult() {
    document.getElementById('round-result').classList.add('hidden');
}

function updateRoundScore(data) {
    const greenEl = document.getElementById('score-green');
    const purpleEl = document.getElementById('score-purple');
    if (greenEl) greenEl.textContent = data.greenScore || 0;
    if (purpleEl) purpleEl.textContent = data.purpleScore || 0;
}

function showRespawnProgress(progress) {
    const el = document.getElementById('respawn-progress');
    const fill = document.getElementById('respawn-fill');
    if (el) el.classList.remove('hidden');
    if (fill) fill.style.width = progress + '%';
}

function hideRespawnProgress() {
    const el = document.getElementById('respawn-progress');
    const fill = document.getElementById('respawn-fill');
    if (el) el.classList.add('hidden');
    if (fill) fill.style.width = '0%';
}

function setPlayersTitle(title) {
    const titleEl = document.querySelector('.online-title');
    if (titleEl) titleEl.textContent = title;
}

// Minigames Browser
function updateMinigames(games) {
    if (!games) return;

    // Update Offense Defense
    const od = games.od;
    if (od) {
        updateGameCard('od', od, 'racing');
    }

    // Update Running Back
    const rb = games.rb;
    if (rb) {
        updateGameCard('rb', rb, ['playing', 'celebration']);
    }

    // Update Sumo
    const sumo = games.sumo;
    if (sumo) {
        updateGameCard('sumo', sumo, ['playing', 'celebration']);
    }
}

function updateGameCard(prefix, data, activePhase) {
    const statusEl = document.getElementById(prefix + '-status');
    const capacityEl = document.getElementById(prefix + '-capacity');
    const progressEl = document.getElementById(prefix + '-progress');
    const checkpointEl = document.getElementById(prefix + '-checkpoint');
    const playersEl = document.getElementById(prefix + '-players');
    const joinEl = document.getElementById(prefix + '-join');
    const labelEl = progressEl ? progressEl.querySelector('.progress-label') : null;

    if (!statusEl) return;

    statusEl.textContent = data.status.toUpperCase();
    statusEl.className = 'game-status ' + data.status;

    if (capacityEl) capacityEl.textContent = data.playerCount + '/' + data.maxPlayers;

    if (progressEl && checkpointEl) {
        const isActive = Array.isArray(activePhase) ? activePhase.includes(data.status) : data.status === activePhase;
        if (isActive && (data.checkpoint || data.scores)) {
            progressEl.classList.remove('hidden');
            if (data.scores) {
                if (labelEl) labelEl.textContent = 'SCORE';
                checkpointEl.textContent = data.scores;
            } else {
                if (labelEl) labelEl.textContent = 'CHECKPOINT';
                checkpointEl.textContent = data.checkpoint;
            }
        } else {
            progressEl.classList.add('hidden');
        }
    }

    if (playersEl) {
        playersEl.innerHTML = '';
        if (data.players && data.players.length > 0) {
            data.players.forEach(p => {
                const span = document.createElement('span');
                span.className = 'game-player ' + (p.team || '');
                span.textContent = p.name;
                playersEl.appendChild(span);
            });
        }
    }

    if (joinEl) {
        const joinKey = prefix === 'od' ? 'J' : prefix === 'rb' ? 'K' : 'L';
        if (data.status === 'idle' || data.status === 'lobby') {
            joinEl.classList.remove('disabled');
            joinEl.innerHTML = '<span class="key">' + joinKey + '</span> JOIN';
        } else {
            joinEl.classList.add('disabled');
            joinEl.innerHTML = 'IN PROGRESS';
        }
    }
}

function restoreBrowser() {
    const el = document.getElementById('minigames-browser');
    el.classList.remove('hidden');
    if (browserExpanded) {
        el.classList.remove('browser-collapsed');
    } else {
        el.classList.add('browser-collapsed');
    }
}

function showBrowser() {
    restoreBrowser();
}

function hideBrowser() {
    document.getElementById('minigames-browser').classList.add('hidden');
}

function toggleBrowser() {
    const el = document.getElementById('minigames-browser');
    if (el.classList.contains('hidden')) return; // don't toggle if hidden by lobby/race
    browserExpanded = !browserExpanded;
    if (browserExpanded) {
        el.classList.remove('browser-collapsed');
    } else {
        el.classList.add('browser-collapsed');
    }
}

function joinGame(game) {
    fetch('https://offense-defense/joinGame', { method: 'POST', body: JSON.stringify({ game: game }) });
}

document.addEventListener('keydown', (e) => {
    if (state.mode === 'lobby') {
        const canChangeCar = state.game === 'sumo' || state.role === 'blocker';
        const maxCar = state.game === 'sumo' ? gameVehicles.sumo.vehicles.length : 3;
        if ((e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') && canChangeCar) {
            state.selectedCar = Math.max(1, state.selectedCar - 1);
            updateCarSelection();
            fetch('https://offense-defense/' + getCallback('selectCar'), { method: 'POST', body: JSON.stringify({ car: state.selectedCar }) });
        }
        if ((e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') && canChangeCar) {
            state.selectedCar = Math.min(maxCar, state.selectedCar + 1);
            updateCarSelection();
            fetch('https://offense-defense/' + getCallback('selectCar'), { method: 'POST', body: JSON.stringify({ car: state.selectedCar }) });
        }
        if (e.key === 'Enter') fetch('https://offense-defense/' + getCallback('ready'), { method: 'POST' });
        if (e.key === 'Escape') fetch('https://offense-defense/' + getCallback('leave'), { method: 'POST' });
        if (e.key === 'g' || e.key === 'G') fetch('https://offense-defense/' + getCallback('switchTeam'), { method: 'POST', body: JSON.stringify({ team: 1 }) });
        if (e.key === 'p' || e.key === 'P') fetch('https://offense-defense/' + getCallback('switchTeam'), { method: 'POST', body: JSON.stringify({ team: 2 }) });
        if ((e.key === 'r' || e.key === 'R') && state.game !== 'rb') fetch('https://offense-defense/' + getCallback('switchRole'), { method: 'POST', body: JSON.stringify({ role: 'runner' }) });
        if ((e.key === 'b' || e.key === 'B') && state.game !== 'rb') fetch('https://offense-defense/' + getCallback('switchRole'), { method: 'POST', body: JSON.stringify({ role: 'blocker' }) });
    }
    if (state.mode === 'editor' && e.key === 'Escape') {
        fetch('https://offense-defense/editorExit', { method: 'POST' });
    }
});

function showFinalCheckpoint() {
    let el = document.getElementById('final-checkpoint');
    if (!el) {
        el = document.createElement('div');
        el.id = 'final-checkpoint';
        el.className = 'final-checkpoint';
        el.innerHTML = '<div class="final-checkpoint-text">FINAL CHECKPOINT</div>';
        document.body.appendChild(el);
    }
    el.classList.remove('hidden');
    el.classList.add('show');

    setTimeout(() => {
        el.classList.remove('show');
        el.classList.add('hidden');
    }, 3000);
}

function showCarHud() {
    document.getElementById('car-hud').classList.remove('hidden');
}

function hideCarHud() {
    document.getElementById('car-hud').classList.add('hidden');
}

function updateCarHud(data) {
    document.getElementById('car-name').textContent = data.name || 'UNKNOWN';
    document.getElementById('car-speed').textContent = data.speed || 0;
}
