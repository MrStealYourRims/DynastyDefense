<?php
require_once __DIR__ . '/bootstrap.php';
$payload = post_json();
$buildingId = scalar_int($payload['building_id'] ?? 0, 1);

$stmt = db()->prepare('SELECT bd.*, COALESCE(cb.level, 0) AS level FROM building_definitions bd LEFT JOIN city_buildings cb ON cb.building_id = bd.id AND cb.city_id = ? WHERE bd.id = ?');
$stmt->execute([$city['id'], $buildingId]);
$building = $stmt->fetch();
if (!$building) {
    json_response(['error' => 'Building not found'], 404);
}

$townHallStmt = db()->prepare('SELECT COALESCE(cb.level, 0) AS level FROM city_buildings cb JOIN building_definitions bd ON bd.id = cb.building_id WHERE cb.city_id = ? AND bd.key_name = "town_hall" LIMIT 1');
$townHallStmt->execute([$city['id']]);
$townHallLevel = (int) (($townHallStmt->fetch()['level'] ?? 0));
if ($townHallLevel < (int) $building['required_town_hall_level']) {
    json_response(['error' => 'Town Hall level too low for this building'], 400);
}

$builderStmt = db()->prepare('SELECT * FROM city_builders WHERE city_id = ? AND is_unlocked = 1 AND status = "idle" ORDER BY slot_index ASC LIMIT 1');
$builderStmt->execute([$city['id']]);
$builder = $builderStmt->fetch();
if (!$builder) {
    json_response(['error' => 'No idle builder available. Unlock or wait for a builder.'], 400);
}

$targetLevel = (int) $building['level'] + 1;
if ($targetLevel > (int) $building['max_level']) {
    json_response(['error' => 'Building max level reached'], 400);
}

$costMultiplier = pow(1.22, $targetLevel - 1);
$costs = [
    'food' => (int) floor($building['base_food'] * $costMultiplier),
    'wood' => (int) floor($building['base_wood'] * $costMultiplier),
    'stone' => (int) floor($building['base_stone'] * $costMultiplier),
    'gold' => (int) floor($building['base_gold'] * $costMultiplier),
];
if (!city_has_resources($city, $costs)) {
    json_response(['error' => 'Insufficient resources'], 400);
}

$duration = (int) floor($building['base_duration_seconds'] * $costMultiplier);
$researchBonus = get_research_bonus_map($userId);
if (isset($researchBonus['build_speed_pct'])) {
    $duration = (int) max(20, floor($duration * (1 - ($researchBonus['build_speed_pct'] / 100))));
}

$starts = game_now();
$finishes = $starts->modify('+' . $duration . ' seconds');

$pdo = db();
$pdo->beginTransaction();
try {
    spend_city_resources((int) $city['id'], $costs);
    $queue = $pdo->prepare('INSERT INTO build_queue (city_id, building_id, target_level, starts_at, finishes_at, builder_id) VALUES (?, ?, ?, ?, ?, ?)');
    $queue->execute([$city['id'], $buildingId, $targetLevel, $starts->format('Y-m-d H:i:s'), $finishes->format('Y-m-d H:i:s'), $builder['id']]);
    $pdo->prepare('UPDATE city_builders SET status = "building" WHERE id = ?')->execute([$builder['id']]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    json_response(['error' => 'Could not queue build'], 500);
}

json_response(['ok' => true, 'message' => 'Building upgrade queued']);
