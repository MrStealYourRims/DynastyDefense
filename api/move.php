<?php
require_once __DIR__ . '/bootstrap.php';
$payload = post_json();

$targetX = scalar_int($payload['target_x'] ?? 0, 0, 10000);
$targetY = scalar_int($payload['target_y'] ?? 0, 0, 10000);
$mission = in_array(($payload['mission_type'] ?? ''), ['attack', 'scout', 'reinforce', 'gather'], true) ? $payload['mission_type'] : 'attack';
$commanderId = isset($payload['commander_id']) ? scalar_int($payload['commander_id'], 0, PHP_INT_MAX) : 0;

$activeMarchStmt = db()->prepare('SELECT COUNT(*) AS c FROM army_movements WHERE owner_user_id = ? AND status = "moving"');
$activeMarchStmt->execute([$userId]);
$activeMarches = (int) $activeMarchStmt->fetch()['c'];
if ($activeMarches >= (int) $city['march_queue_limit']) {
    json_response(['error' => 'All march queues are currently in use'], 400);
}

$targetStmt = db()->prepare('SELECT * FROM world_tiles WHERE x_coord = ? AND y_coord = ?');
$targetStmt->execute([$targetX, $targetY]);
$target = $targetStmt->fetch();
if (!$target) {
    json_response(['error' => 'Target tile not found'], 404);
}

$commanderSpeedBuff = 0;
if ($commanderId > 0) {
    $commanderStmt = db()->prepare('SELECT pc.id, pc.status, cd.speed_buff_pct FROM player_commanders pc JOIN commander_definitions cd ON cd.id = pc.commander_definition_id WHERE pc.id = ? AND pc.user_id = ?');
    $commanderStmt->execute([$commanderId, $userId]);
    $commander = $commanderStmt->fetch();
    if (!$commander || $commander['status'] !== 'available') {
        json_response(['error' => 'Commander unavailable'], 400);
    }
    $commanderSpeedBuff = (float) $commander['speed_buff_pct'];
}

$unitDefs = db()->query('SELECT id, key_name, speed, march_capacity FROM unit_definitions')->fetchAll();
$unitDefs = db()->query('SELECT id, key_name, speed FROM unit_definitions')->fetchAll();
$availableStmt = db()->prepare('SELECT cu.unit_id, cu.quantity FROM city_units cu WHERE city_id = ?');
$availableStmt->execute([$city['id']]);
$available = [];
foreach ($availableStmt->fetchAll() as $row) {
    $available[(int) $row['unit_id']] = (int) $row['quantity'];
}

$selected = [];
$minSpeed = null;
$totalCapacity = 0;
foreach ($unitDefs as $def) {
    $qty = scalar_int($payload[$def['key_name']] ?? 0, 0, 500000);
    if ($qty <= 0) {
        continue;
    }
    if (($available[(int) $def['id']] ?? 0) < $qty) {
        json_response(['error' => 'Not enough ' . $def['key_name']], 400);
    }
    $selected[(int) $def['id']] = $qty;
    $minSpeed = $minSpeed === null ? (float) $def['speed'] : min($minSpeed, (float) $def['speed']);
    $totalCapacity += ((int) $def['march_capacity'] * $qty);
}
if (!$selected) {
    json_response(['error' => 'Select at least one unit'], 400);
}

$sourceTileStmt = db()->prepare('SELECT wt.x_coord, wt.y_coord FROM world_tiles wt JOIN cities c ON c.tile_id = wt.id WHERE c.id = ?');
$sourceTileStmt->execute([$city['id']]);
$source = $sourceTileStmt->fetch();
$distance = sqrt((($source['x_coord'] - $targetX) ** 2) + (($source['y_coord'] - $targetY) ** 2));
$effectiveSpeed = $minSpeed * (1 + ($commanderSpeedBuff / 100));
$travelSeconds = (int) max(30, (config()['game']['base_travel_seconds'] * $distance) / max(0.2, $effectiveSpeed));
$depart = game_now();
$arrive = $depart->modify('+' . $travelSeconds . ' seconds');

$pdo = db();
$pdo->beginTransaction();
try {
    foreach ($selected as $unitId => $qty) {
        $pdo->prepare('UPDATE city_units SET quantity = quantity - ? WHERE city_id = ? AND unit_id = ?')->execute([$qty, $city['id'], $unitId]);
    }

    $stmt = $pdo->prepare('INSERT INTO army_movements (owner_user_id, source_city_id, target_tile_id, commander_id, mission_type, units_json, departs_at, arrives_at, total_march_capacity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([$userId, $city['id'], $target['id'], $commanderId ?: null, $mission, json_encode($selected), $depart->format('Y-m-d H:i:s'), $arrive->format('Y-m-d H:i:s'), $totalCapacity]);
    $stmt = $pdo->prepare('INSERT INTO army_movements (owner_user_id, source_city_id, target_tile_id, commander_id, mission_type, units_json, departs_at, arrives_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([$userId, $city['id'], $target['id'], $commanderId ?: null, $mission, json_encode($selected), $depart->format('Y-m-d H:i:s'), $arrive->format('Y-m-d H:i:s')]);

    if ($commanderId > 0) {
        $pdo->prepare('UPDATE player_commanders SET status = "on_mission" WHERE id = ?')->execute([$commanderId]);
    }
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    json_response(['error' => 'Unable to dispatch army'], 500);
}

json_response(['ok' => true, 'arrives_at' => $arrive->format(DateTimeInterface::ATOM), 'march_capacity' => $totalCapacity]);
json_response(['ok' => true, 'arrives_at' => $arrive->format(DateTimeInterface::ATOM)]);
