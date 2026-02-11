<?php
require_once __DIR__ . '/bootstrap.php';
$buildings = get_building_levels((int) $city['id']);
$research = get_research_levels($userId);
$commanders = get_player_commanders($userId);

$unitsStmt = db()->prepare('SELECT ud.id, ud.key_name, ud.display_name, ud.tier, cu.quantity, ud.attack, ud.defense, ud.speed FROM unit_definitions ud LEFT JOIN city_units cu ON cu.unit_id = ud.id AND cu.city_id = ? ORDER BY ud.tier, ud.id');
$unitsStmt->execute([$city['id']]);
$units = $unitsStmt->fetchAll();

$queue = [
    'build' => (function () use ($city) {
        $stmt = db()->prepare('SELECT * FROM build_queue WHERE city_id = ? AND status = "queued" ORDER BY finishes_at LIMIT 20');
        $stmt->execute([$city['id']]);
        return $stmt->fetchAll();
    })(),
    'training' => (function () use ($city) {
        $stmt = db()->prepare('SELECT * FROM training_queue WHERE city_id = ? AND status = "queued" ORDER BY finishes_at LIMIT 20');
        $stmt->execute([$city['id']]);
        return $stmt->fetchAll();
    })(),
    'research' => (function () use ($userId) {
        $stmt = db()->prepare('SELECT * FROM research_queue WHERE user_id = ? AND status = "queued" ORDER BY finishes_at LIMIT 20');
        $stmt->execute([$userId]);
        return $stmt->fetchAll();
    })(),
];

json_response([
    'city' => $city,
    'buildings' => $buildings,
    'research' => $research,
    'units' => $units,
    'commanders' => $commanders,
    'queue' => $queue,
]);
