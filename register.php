<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/helpers.php';

start_secure_session();
$pdo = db();
$error = '';
$civilizations = $pdo->query('SELECT id, display_name, key_name FROM civilizations ORDER BY id')->fetchAll();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!verify_csrf($_POST['csrf_token'] ?? '')) {
        $error = 'Invalid CSRF token.';
    } else {
        $username = trim($_POST['username'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $empireName = trim($_POST['empire_name'] ?? '');
        $password = $_POST['password'] ?? '';
        $civilizationId = scalar_int($_POST['civilization_id'] ?? 0, 1);

        if (!preg_match('/^[A-Za-z0-9_]{3,30}$/', $username)) {
            $error = 'Username must be 3-30 chars and alphanumeric.';
        } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $error = 'Enter a valid email.';
        } elseif (strlen($password) < 8) {
            $error = 'Password must be at least 8 characters.';
        } elseif ($empireName === '') {
            $error = 'Empire name is required.';
        } elseif (!$civilizationId) {
            $error = 'Please choose a civilization.';
        } else {
            try {
                $pdo->beginTransaction();
                $civStmt = $pdo->prepare('SELECT id, starter_commander_key, bonus_json FROM civilizations WHERE id = ?');
                $civStmt->execute([$civilizationId]);
                $civ = $civStmt->fetch();
                if (!$civ) {
                    throw new RuntimeException('Invalid civilization');
                }

                $stmt = $pdo->prepare('INSERT INTO users (username, email, password_hash, empire_name, civilization_id) VALUES (?, ?, ?, ?, ?)');
                $stmt->execute([$username, $email, password_hash($password, PASSWORD_DEFAULT), $empireName, $civilizationId]);
                $userId = (int) $pdo->lastInsertId();

                $config = config()['game'];
                $x = random_int(0, $config['map_width'] - 1);
                $y = random_int(0, $config['map_height'] - 1);

                $tileStmt = $pdo->prepare('INSERT INTO world_tiles (x_coord, y_coord, tile_type, owner_user_id) VALUES (?, ?, "player_city", ?) ON DUPLICATE KEY UPDATE tile_type = VALUES(tile_type), owner_user_id = VALUES(owner_user_id)');
                $tileStmt->execute([$x, $y, $userId]);

                $fetchTile = $pdo->prepare('SELECT id FROM world_tiles WHERE x_coord = ? AND y_coord = ?');
                $fetchTile->execute([$x, $y]);
                $tile = $fetchTile->fetch();

                $cityStmt = $pdo->prepare('INSERT INTO cities (user_id, tile_id, city_name) VALUES (?, ?, ?)');
                $cityStmt->execute([$userId, $tile['id'], $empireName . ' Capital']);
                $cityId = (int) $pdo->lastInsertId();

                $defaults = ['town_hall' => 1, 'farm' => 1, 'lumber_mill' => 1, 'quarry' => 1, 'gold_mine' => 1, 'warehouse' => 1, 'barracks' => 1];
                $defs = $pdo->query('SELECT id, key_name FROM building_definitions')->fetchAll();
                foreach ($defs as $def) {
                    $level = $defaults[$def['key_name']] ?? 0;
                    $pdo->prepare('INSERT INTO city_buildings (city_id, building_id, level) VALUES (?, ?, ?)')->execute([$cityId, $def['id'], $level]);
                }

                $builderStmt = $pdo->prepare('INSERT INTO city_builders (city_id, slot_index, is_unlocked, unlock_cost_gems, status) VALUES (?, ?, ?, ?, ?)');
                $builderStmt->execute([$cityId, 1, 1, 0, 'idle']);
                $builderStmt->execute([$cityId, 2, 0, 1500, 'idle']);

                $starterCommander = null;
                if (!empty($civ['starter_commander_key'])) {
                    $cmdStmt = $pdo->prepare('SELECT id FROM commander_definitions WHERE key_name = ? LIMIT 1');
                    $cmdStmt->execute([$civ['starter_commander_key']]);
                    $starterCommander = $cmdStmt->fetch();
                }
                if (!$starterCommander) {
                    $starterCommander = $pdo->query('SELECT id FROM commander_definitions ORDER BY id LIMIT 1')->fetch();
                }
                if ($starterCommander) {
                    $pdo->prepare('INSERT INTO player_commanders (user_id, commander_definition_id, level) VALUES (?, ?, 1)')
                        ->execute([$userId, $starterCommander['id']]);
                }

                $bonus = json_decode($civ['bonus_json'] ?? '{}', true) ?: [];
                if (!empty($bonus['march_queue_bonus'])) {
                    $pdo->prepare('UPDATE cities SET march_queue_limit = march_queue_limit + ? WHERE id = ?')
                        ->execute([(int) $bonus['march_queue_bonus'], $cityId]);
                }


                $pdo->prepare('INSERT INTO player_items (user_id, item_key, quantity) VALUES (?, "targeted_teleport", 2), (?, "random_teleport", 1), (?, "civilization_change_token", 1)')
                    ->execute([$userId, $userId, $userId]);

                $pdo->commit();
                login_user($userId);
                header('Location: game.php');
                exit;
            } catch (Throwable $e) {
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                $error = 'Registration failed: username/email may already exist.';
            }
        }
    }
}
$csrf = csrf_token();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Register - Dynasty Defense</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body class="auth-page">
<div class="card">
    <h1>Create Account</h1>
    <?php if ($error): ?><p class="error"><?= htmlspecialchars($error) ?></p><?php endif; ?>
    <form method="post">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrf) ?>">
        <label>Username <input type="text" name="username" required></label>
        <label>Email <input type="email" name="email" required></label>
        <label>Empire Name <input type="text" name="empire_name" required></label>
        <label>Civilization
            <select name="civilization_id" required>
                <option value="">Select civilization</option>
                <?php foreach ($civilizations as $civ): ?>
                    <option value="<?= (int) $civ['id'] ?>"><?= htmlspecialchars($civ['display_name']) ?></option>
                <?php endforeach; ?>
            </select>
        </label>
        <label>Password <input type="password" name="password" required></label>
        <button type="submit">Register</button>
    </form>
    <p>Already registered? <a href="index.php">Back to login</a></p>
</div>
</body>
</html>
