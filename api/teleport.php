<?php
require_once __DIR__ . '/bootstrap.php';
$payload = post_json();
$targetX = scalar_int($payload['target_x'] ?? -1, 0, config()['game']['map_width'] - 1);
$targetY = scalar_int($payload['target_y'] ?? -1, 0, config()['game']['map_height'] - 1);

$pdo = db();
$itemStmt = $pdo->prepare('SELECT quantity FROM player_items WHERE user_id = ? AND item_key = "targeted_teleport"');
$itemStmt->execute([$userId]);
$teleports = (int) (($itemStmt->fetch()['quantity'] ?? 0));
if ($teleports < 1) {
    json_response(['error' => 'No targeted teleport item available'], 400);
}

$targetStmt = $pdo->prepare('SELECT id, tile_type FROM world_tiles WHERE x_coord = ? AND y_coord = ?');
$targetStmt->execute([$targetX, $targetY]);
$tile = $targetStmt->fetch();
if (!$tile) {
    json_response(['error' => 'Target tile does not exist'], 404);
}
if ($tile['tile_type'] !== 'empty') {
    json_response(['error' => 'Target tile is occupied'], 400);
}

$currentTileStmt = $pdo->prepare('SELECT tile_id FROM cities WHERE id = ?');
$currentTileStmt->execute([$city['id']]);
$currentTileId = (int) $currentTileStmt->fetch()['tile_id'];

$pdo->beginTransaction();
try {
    $pdo->prepare('UPDATE world_tiles SET tile_type = "empty", owner_user_id = NULL WHERE id = ?')->execute([$currentTileId]);
    $pdo->prepare('UPDATE world_tiles SET tile_type = "player_city", owner_user_id = ? WHERE id = ?')->execute([$userId, $tile['id']]);
    $pdo->prepare('UPDATE cities SET tile_id = ? WHERE id = ?')->execute([$tile['id'], $city['id']]);
    $pdo->prepare('UPDATE player_items SET quantity = quantity - 1 WHERE user_id = ? AND item_key = "targeted_teleport"')->execute([$userId]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    json_response(['error' => 'Teleport failed'], 500);
}
json_response(['ok' => true, 'target' => ['x' => $targetX, 'y' => $targetY]]);
