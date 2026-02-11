<?php
require_once __DIR__ . '/../includes/game_logic.php';

$pdo = db();
$cities = $pdo->query('SELECT id, user_id FROM cities')->fetchAll();
foreach ($cities as $city) {
    complete_due_queues((int) $city['id'], (int) $city['user_id']);
    apply_resource_tick((int) $city['id']);
}
$resolved = resolve_due_movements();
echo sprintf("Tick complete. Cities processed: %d, movements resolved: %d\n", count($cities), $resolved);
