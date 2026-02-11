<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/game_logic.php';

start_secure_session();
$userId = require_login();
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $payload = post_json();
    if (!verify_csrf($payload['csrf_token'] ?? $_POST['csrf_token'] ?? '')) {
        json_response(['error' => 'Invalid CSRF token'], 400);
    }
}
$city = get_city_by_user($userId);
if (!$city) {
    json_response(['error' => 'City not found'], 404);
}
complete_due_queues((int) $city['id'], $userId);
$city = apply_resource_tick((int) $city['id']);
