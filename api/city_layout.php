<?php
require_once __DIR__ . '/bootstrap.php';
$pdo = db();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->prepare('SELECT cls.pos_x, cls.pos_y, bd.id AS building_id, bd.display_name, bd.key_name, COALESCE(cb.level,0) AS level
        FROM city_layout_slots cls
        JOIN building_definitions bd ON bd.id = cls.building_id
        LEFT JOIN city_buildings cb ON cb.city_id = cls.city_id AND cb.building_id = cls.building_id
        WHERE cls.city_id = ?
        ORDER BY cls.pos_y, cls.pos_x');
    $stmt->execute([$city['id']]);
    $slots = $stmt->fetchAll();

    if (!$slots) {
        $seed = $pdo->prepare('SELECT building_id FROM city_buildings WHERE city_id = ? AND level > 0 ORDER BY building_id');
        $seed->execute([$city['id']]);
        $i = 0;
        foreach ($seed->fetchAll() as $row) {
            $x = $i % 8;
            $y = intdiv($i, 8);
            $pdo->prepare('INSERT IGNORE INTO city_layout_slots (city_id, building_id, pos_x, pos_y) VALUES (?, ?, ?, ?)')
                ->execute([$city['id'], $row['building_id'], $x, $y]);
            $i++;
        }
        $stmt->execute([$city['id']]);
        $slots = $stmt->fetchAll();
    }

    json_response(['slots' => $slots, 'grid' => ['width' => 8, 'height' => 8]]);
}

$payload = post_json();
$buildingId = scalar_int($payload['building_id'] ?? 0, 1);
$x = scalar_int($payload['x'] ?? -1, 0, 7);
$y = scalar_int($payload['y'] ?? -1, 0, 7);

$exists = $pdo->prepare('SELECT 1 FROM city_buildings WHERE city_id = ? AND building_id = ? AND level > 0');
$exists->execute([$city['id'], $buildingId]);
if (!$exists->fetchColumn()) {
    json_response(['error' => 'Building not available in city'], 400);
}

$pdo->beginTransaction();
try {
    $clear = $pdo->prepare('DELETE FROM city_layout_slots WHERE city_id = ? AND pos_x = ? AND pos_y = ?');
    $clear->execute([$city['id'], $x, $y]);

    $stmt = $pdo->prepare('INSERT INTO city_layout_slots (city_id, building_id, pos_x, pos_y)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE pos_x = VALUES(pos_x), pos_y = VALUES(pos_y)');
    $stmt->execute([$city['id'], $buildingId, $x, $y]);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    json_response(['error' => 'Could not move building'], 500);
}
json_response(['ok' => true]);
