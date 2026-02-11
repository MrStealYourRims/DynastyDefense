<?php
require_once __DIR__ . '/db.php';

function start_secure_session(): void
{
    $securityCfg = config()['security'];
    if (session_status() === PHP_SESSION_NONE) {
        session_name($securityCfg['session_name']);
        session_set_cookie_params([
            'httponly' => true,
            'secure' => isset($_SERVER['HTTPS']),
            'samesite' => 'Lax',
        ]);
        session_start();
    }
}

function csrf_token(): string
{
    start_secure_session();
    $tokenName = config()['security']['csrf_token_name'];
    if (!isset($_SESSION[$tokenName])) {
        $_SESSION[$tokenName] = bin2hex(random_bytes(32));
    }
    return $_SESSION[$tokenName];
}

function verify_csrf(string $token): bool
{
    $tokenName = config()['security']['csrf_token_name'];
    return hash_equals($_SESSION[$tokenName] ?? '', $token);
}

function current_user_id(): ?int
{
    start_secure_session();
    return isset($_SESSION['user_id']) ? (int) $_SESSION['user_id'] : null;
}

function require_login(): int
{
    $userId = current_user_id();
    if (!$userId) {
        http_response_code(401);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'Authentication required']);
        exit;
    }
    return $userId;
}

function login_user(int $userId): void
{
    start_secure_session();
    session_regenerate_id(true);
    $_SESSION['user_id'] = $userId;
}

function logout_user(): void
{
    start_secure_session();
    $_SESSION = [];
    session_destroy();
}
