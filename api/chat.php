<?php
require_once __DIR__ . '/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $channel = in_array($_GET['channel'] ?? 'global', ['global', 'alliance'], true) ? $_GET['channel'] : 'global';
    if ($channel === 'alliance') {
        $allianceIdStmt = db()->prepare('SELECT alliance_id FROM alliance_members WHERE user_id = ? LIMIT 1');
        $allianceIdStmt->execute([$userId]);
        $allianceId = $allianceIdStmt->fetch()['alliance_id'] ?? null;
        if (!$allianceId) {
            json_response(['messages' => []]);
        }
        $stmt = db()->prepare('SELECT m.body, m.created_at, u.username FROM messages m JOIN users u ON u.id = m.sender_user_id WHERE m.channel = "alliance" AND m.alliance_id = ? ORDER BY m.id DESC LIMIT 30');
        $stmt->execute([$allianceId]);
    } else {
        $stmt = db()->query('SELECT m.body, m.created_at, u.username FROM messages m JOIN users u ON u.id = m.sender_user_id WHERE m.channel = "global" ORDER BY m.id DESC LIMIT 30');
    }
    json_response(['messages' => array_reverse($stmt->fetchAll())]);
}

$payload = post_json();
$body = trim($payload['body'] ?? '');
if ($body === '') {
    json_response(['error' => 'Empty message'], 400);
}
$channel = in_array($payload['channel'] ?? 'global', ['global', 'alliance'], true) ? $payload['channel'] : 'global';
$allianceId = null;
if ($channel === 'alliance') {
    $allianceIdStmt = db()->prepare('SELECT alliance_id FROM alliance_members WHERE user_id = ? LIMIT 1');
    $allianceIdStmt->execute([$userId]);
    $allianceId = $allianceIdStmt->fetch()['alliance_id'] ?? null;
    if (!$allianceId) {
        json_response(['error' => 'Join alliance first'], 400);
    }
}
$stmt = db()->prepare('INSERT INTO messages (sender_user_id, alliance_id, channel, body) VALUES (?, ?, ?, ?)');
$stmt->execute([$userId, $allianceId, $channel, mb_substr($body, 0, 500)]);
json_response(['ok' => true]);
