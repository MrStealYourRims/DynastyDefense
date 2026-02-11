<?php
require_once __DIR__ . '/../includes/db.php';
$config = config()['game'];
$pdo = db();

for ($y = 0; $y < $config['map_height']; $y++) {
    for ($x = 0; $x < $config['map_width']; $x++) {
        $typeRoll = random_int(1, 100);
        $tileType = 'empty';
        $resourceType = null;
        $resourceAmount = 0;
        $npcStrength = 0;

        if ($typeRoll <= 8) {
            $tileType = 'npc_camp';
            $npcStrength = random_int(20, 120);
        } elseif ($typeRoll <= 20) {
            $tileType = 'resource_node';
            $resourceTypes = ['food', 'wood', 'stone', 'gold'];
            $resourceType = $resourceTypes[array_rand($resourceTypes)];
            $resourceAmount = random_int(1000, 6000);
        }

        $stmt = $pdo->prepare('INSERT IGNORE INTO world_tiles (x_coord, y_coord, tile_type, resource_type, resource_amount, npc_strength) VALUES (?, ?, ?, ?, ?, ?)');
        $stmt->execute([$x, $y, $tileType, $resourceType, $resourceAmount, $npcStrength]);
    }
}
echo "Map seeding complete\n";
