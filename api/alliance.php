<?php
require_once __DIR__ . '/bootstrap.php';
$pdo = db();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->prepare('SELECT a.*, am.role FROM alliance_members am JOIN alliances a ON a.id = am.alliance_id WHERE am.user_id = ? LIMIT 1');
    $stmt->execute([$userId]);
    json_response(['alliance' => $stmt->fetch() ?: null]);
}

$payload = post_json();
$action = $payload['action'] ?? '';

if ($action === 'create') {
    $name = trim($payload['name'] ?? '');
    $tag = strtoupper(trim($payload['tag'] ?? ''));
    if (strlen($name) < 3 || strlen($tag) < 2) {
        json_response(['error' => 'Invalid alliance name/tag'], 400);
    }

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare('INSERT INTO alliances (name, tag, leader_user_id, description) VALUES (?, ?, ?, ?)');
        $stmt->execute([$name, $tag, $userId, trim($payload['description'] ?? '')]);
        $aid = (int) $pdo->lastInsertId();
        $pdo->prepare('INSERT INTO alliance_members (alliance_id, user_id, role) VALUES (?, ?, "leader")')->execute([$aid, $userId]);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        json_response(['error' => 'Unable to create alliance'], 400);
    }
    json_response(['ok' => true]);
}

if ($action === 'join') {
    $tag = strtoupper(trim($payload['tag'] ?? ''));
    $stmt = $pdo->prepare('SELECT id FROM alliances WHERE tag = ?');
    $stmt->execute([$tag]);
    $alliance = $stmt->fetch();
    if (!$alliance) {
        json_response(['error' => 'Alliance not found'], 404);
    }
    $pdo->prepare('INSERT IGNORE INTO alliance_members (alliance_id, user_id, role) VALUES (?, ?, "member")')->execute([$alliance['id'], $userId]);
    json_response(['ok' => true]);
}

json_response(['error' => 'Unknown action'], 400);
