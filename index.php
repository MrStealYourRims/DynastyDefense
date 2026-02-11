<?php
require_once __DIR__ . '/includes/auth.php';
start_secure_session();
if (current_user_id()) {
    header('Location: game.php');
    exit;
}
$csrf = csrf_token();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Dynasty Defense - Login</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body class="auth-page">
<div class="card">
    <h1>Dynasty Defense</h1>
    <p>Persistent 4X MMO in your browser.</p>
    <form method="post" action="login.php">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrf) ?>">
        <label>Username <input type="text" name="username" required></label>
        <label>Password <input type="password" name="password" required></label>
        <button type="submit">Login</button>
    </form>
    <p>New player? <a href="register.php">Create an account</a></p>
</div>
</body>
</html>
