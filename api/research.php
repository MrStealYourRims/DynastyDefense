<?php
require_once __DIR__ . '/bootstrap.php';
$payload = post_json();
$researchId = scalar_int($payload['research_id'] ?? 0, 1);

$stmt = db()->prepare('SELECT rd.*, COALESCE(pr.level, 0) AS level FROM research_definitions rd LEFT JOIN player_research pr ON pr.research_id = rd.id AND pr.user_id = ? WHERE rd.id = ?');
$stmt->execute([$userId, $researchId]);
$research = $stmt->fetch();
if (!$research) {
    json_response(['error' => 'Research not found'], 404);
}

$currentLevel = (int) $research['level'];
if ($currentLevel >= (int) $research['max_level']) {
    json_response(['error' => 'Research max level reached'], 400);
}

if ($research['prerequisite_research_id']) {
    $preStmt = db()->prepare('SELECT COALESCE(level, 0) AS level FROM player_research WHERE user_id = ? AND research_id = ?');
    $preStmt->execute([$userId, $research['prerequisite_research_id']]);
    $prereqLevel = (int) (($preStmt->fetch()['level'] ?? 0));
    if ($prereqLevel < (int) $research['prerequisite_level']) {
        json_response(['error' => 'Research prerequisite not met'], 400);
    }
}

$costMultiplier = pow(1.25, $currentLevel);
$costs = [
    'food' => (int) floor($research['cost_food'] * $costMultiplier),
    'wood' => (int) floor($research['cost_wood'] * $costMultiplier),
    'stone' => (int) floor($research['cost_stone'] * $costMultiplier),
    'gold' => (int) floor($research['cost_gold'] * $costMultiplier),
];
if (!city_has_resources($city, $costs)) {
    json_response(['error' => 'Insufficient resources'], 400);
}
spend_city_resources((int) $city['id'], $costs);

$academyLevelStmt = db()->prepare('SELECT cb.level FROM city_buildings cb JOIN building_definitions bd ON bd.id = cb.building_id WHERE cb.city_id = ? AND bd.key_name = "academy"');
$academyLevelStmt->execute([$city['id']]);
$academyLevel = (int) (($academyLevelStmt->fetch()['level'] ?? 0));
$modifier = max(0.5, 1 - ($academyLevel * 0.02));
$duration = (int) ceil($research['duration_seconds'] * $costMultiplier * $modifier);
$starts = game_now();
$finishes = $starts->modify('+' . $duration . ' seconds');

$stmt = db()->prepare('INSERT INTO research_queue (user_id, research_id, target_level, starts_at, finishes_at) VALUES (?, ?, ?, ?, ?)');
$stmt->execute([$userId, $researchId, $currentLevel + 1, $starts->format('Y-m-d H:i:s'), $finishes->format('Y-m-d H:i:s')]);
json_response(['ok' => true, 'message' => 'Research queued']);
