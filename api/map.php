<?php
require_once __DIR__ . '/bootstrap.php';
$range = scalar_int($_GET['range'] ?? 8, 3, 15);

$tileStmt = db()->prepare('SELECT wt.*, u.empire_name FROM world_tiles wt LEFT JOIN users u ON u.id = wt.owner_user_id WHERE wt.x_coord BETWEEN ? AND ? AND wt.y_coord BETWEEN ? AND ? ORDER BY wt.y_coord, wt.x_coord');

$cityTile = db()->prepare('SELECT wt.x_coord, wt.y_coord FROM world_tiles wt JOIN cities c ON c.tile_id = wt.id WHERE c.id = ?');
$cityTile->execute([$city['id']]);
$origin = $cityTile->fetch();
$x1 = $origin['x_coord'] - $range;
$x2 = $origin['x_coord'] + $range;
$y1 = $origin['y_coord'] - $range;
$y2 = $origin['y_coord'] + $range;

$tileStmt->execute([$x1, $x2, $y1, $y2]);
$tiles = $tileStmt->fetchAll();
json_response(['origin' => $origin, 'tiles' => $tiles, 'bounds' => compact('x1', 'x2', 'y1', 'y2')]);
