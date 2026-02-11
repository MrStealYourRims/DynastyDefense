<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/game_logic.php';

$userId = require_login();
$city = get_city_by_user($userId);
if (!$city) {
    die('No city found.');
}
complete_due_queues((int) $city['id'], $userId);
$city = apply_resource_tick((int) $city['id']);
$csrf = csrf_token();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Dynasty Defense - Empire</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
<header class="topbar">
    <h1>Dynasty Defense</h1>
    <div>
        <span><?= htmlspecialchars($city['empire_name']) ?> (<?= htmlspecialchars($city['username']) ?>)</span>
        <a href="logout.php">Logout</a>
    </div>
</header>

<main class="layout" id="gameApp" data-csrf="<?= htmlspecialchars($csrf) ?>">
    <aside class="panel" id="resourcesPanel">
        <h2>Resources</h2>
        <ul>
            <li>Food: <strong id="res-food"><?= (int) $city['food'] ?></strong></li>
            <li>Wood: <strong id="res-wood"><?= (int) $city['wood'] ?></strong></li>
            <li>Stone: <strong id="res-stone"><?= (int) $city['stone'] ?></strong></li>
            <li>Gold: <strong id="res-gold"><?= (int) $city['gold'] ?></strong></li>
        </ul>
    </aside>

    <section class="panel">
        <h2>City Management</h2>
        <div id="buildings"></div>
        <div id="research"></div>
        <div id="units"></div>
    </section>

    <section class="panel">
        <h2>World Map</h2>
        <div id="mapGrid" class="map-grid"></div>
        <div id="tileInfo" class="tile-info">Select a tile to inspect it.</div>
        <form id="sendArmyForm">
            <h3>Send Army</h3>
            <label>Target X <input type="number" name="target_x" required></label>
            <label>Target Y <input type="number" name="target_y" required></label>
            <label>Mission
                <select name="mission_type">
                    <option value="attack">Attack</option>
                    <option value="scout">Scout</option>
                </select>
            </label>
            <label>Commander
                <select name="commander_id" id="commanderSelect">
                    <option value="0">None</option>
                </select>
            </label>
            <label>Infantry <input type="number" name="infantry" value="0" min="0"></label>
            <label>Archers <input type="number" name="archer" value="0" min="0"></label>
            <label>Cavalry <input type="number" name="cavalry" value="0" min="0"></label>
            <label>Siege <input type="number" name="siege" value="0" min="0"></label>
            <button type="submit">Dispatch Army</button>
        </form>
    </section>

    <section class="panel">
        <h2>Chat & Alliance</h2>
        <div id="chatMessages" class="chat-box"></div>
        <form id="chatForm">
            <input type="text" name="message" placeholder="Type message..." maxlength="500" required>
            <button type="submit">Send</button>
        </form>
        <div id="alliancePanel"></div>
    </section>
</main>

<script src="assets/js/game.js"></script>
</body>
</html>
