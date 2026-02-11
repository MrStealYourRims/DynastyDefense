<?php
require_once __DIR__ . '/bootstrap.php';
$payload = post_json();
$unitId = scalar_int($payload['unit_id'] ?? 0, 1);
$qty = scalar_int($payload['quantity'] ?? 0, 1, 50000);

$unitStmt = db()->prepare('SELECT * FROM unit_definitions WHERE id = ?');
$unitStmt->execute([$unitId]);
$unit = $unitStmt->fetch();
if (!$unit) {
    json_response(['error' => 'Unit not found'], 404);
}

if (!empty($unit['required_tech_id'])) {
    $techStmt = db()->prepare('SELECT level FROM player_research WHERE user_id = ? AND research_id = ?');
    $techStmt->execute([$userId, $unit['required_tech_id']]);
    $techLevel = (int) (($techStmt->fetch()['level'] ?? 0));
    if ($techLevel < 1) {
        json_response(['error' => 'Required research not completed for this troop tier'], 400);
    }
}

if (!empty($unit['required_building_key'])) {
    $bStmt = db()->prepare('SELECT COALESCE(cb.level, 0) AS level FROM city_buildings cb JOIN building_definitions bd ON bd.id = cb.building_id WHERE cb.city_id = ? AND bd.key_name = ? LIMIT 1');
    $bStmt->execute([$city['id'], $unit['required_building_key']]);
    $buildingLevel = (int) (($bStmt->fetch()['level'] ?? 0));
    if ($buildingLevel < (int) $unit['required_building_level']) {
        json_response(['error' => sprintf('Requires %s level %d', $unit['required_building_key'], (int) $unit['required_building_level'])], 400);
        json_response(['error' => 'Required research not completed for this unit tier'], 400);
    }
}

$costs = [
    'food' => (int) $unit['cost_food'] * $qty,
    'wood' => (int) $unit['cost_wood'] * $qty,
    'stone' => (int) $unit['cost_stone'] * $qty,
    'gold' => (int) $unit['cost_gold'] * $qty,
];
if (!city_has_resources($city, $costs)) {
    json_response(['error' => 'Insufficient resources'], 400);
}
spend_city_resources((int) $city['id'], $costs);

$starts = game_now();
$barracksLevelStmt = db()->prepare('SELECT cb.level FROM city_buildings cb JOIN building_definitions bd ON bd.id = cb.building_id WHERE cb.city_id = ? AND bd.key_name = "barracks"');
$barracksLevelStmt->execute([$city['id']]);
$barracksLevel = (int) (($barracksLevelStmt->fetch()['level'] ?? 0));
$modifier = max(0.4, 1 - ($barracksLevel * 0.02));
$duration = (int) ceil($unit['training_time_seconds'] * $qty * $modifier);
$finishes = $starts->modify('+' . $duration . ' seconds');

$qStmt = db()->prepare('INSERT INTO training_queue (city_id, unit_id, quantity, starts_at, finishes_at) VALUES (?, ?, ?, ?, ?)');
$qStmt->execute([$city['id'], $unitId, $qty, $starts->format('Y-m-d H:i:s'), $finishes->format('Y-m-d H:i:s')]);
json_response(['ok' => true, 'message' => 'Training started']);
