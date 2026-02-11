<?php
require_once __DIR__ . '/helpers.php';

function get_city_by_user(int $userId): ?array
{
    $stmt = db()->prepare('SELECT c.*, u.username, u.empire_name FROM cities c JOIN users u ON u.id = c.user_id WHERE c.user_id = ?');
    $stmt->execute([$userId]);
    return $stmt->fetch() ?: null;
}

function get_building_levels(int $cityId): array
{
    $stmt = db()->prepare('SELECT bd.id, bd.key_name, bd.display_name, bd.base_food, bd.base_wood, bd.base_stone, bd.base_gold, bd.base_duration_seconds, bd.required_town_hall_level, bd.max_level, cb.level, bd.effects_json FROM building_definitions bd LEFT JOIN city_buildings cb ON cb.building_id = bd.id AND cb.city_id = ? ORDER BY bd.id');
    $stmt->execute([$cityId]);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$row) {
        $row['level'] = (int) ($row['level'] ?? 0);
        $row['required_town_hall_level'] = (int) $row['required_town_hall_level'];
        $row['max_level'] = (int) $row['max_level'];
        $row['effects'] = json_decode($row['effects_json'], true) ?: [];
    }
    return $rows;
}

function get_research_levels(int $userId): array
{
    $stmt = db()->prepare('SELECT rd.id, rd.key_name, rd.display_name, rd.branch_key, rd.description, rd.max_level, rd.prerequisite_research_id, rd.prerequisite_level, rd.effect_json, COALESCE(pr.level, 0) AS level FROM research_definitions rd LEFT JOIN player_research pr ON pr.research_id = rd.id AND pr.user_id = ? ORDER BY rd.branch_key, rd.id');
    $stmt->execute([$userId]);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$row) {
        $row['level'] = (int) $row['level'];
        $row['max_level'] = (int) $row['max_level'];
        $row['prerequisite_research_id'] = $row['prerequisite_research_id'] ? (int) $row['prerequisite_research_id'] : null;
        $row['prerequisite_level'] = (int) $row['prerequisite_level'];
        $row['effects'] = json_decode($row['effect_json'], true) ?: [];
    }
    return $rows;
}

function get_player_commanders(int $userId): array
{
    $stmt = db()->prepare('SELECT pc.id, pc.level, pc.experience, pc.status, cd.display_name, cd.rarity, cd.attack_buff_pct, cd.defense_buff_pct, cd.speed_buff_pct, cd.upkeep_reduction_pct FROM player_commanders pc JOIN commander_definitions cd ON cd.id = pc.commander_definition_id WHERE pc.user_id = ? ORDER BY pc.status, pc.id');
    $stmt->execute([$userId]);
    return $stmt->fetchAll();
}

function get_research_bonus_map(int $userId): array
{
    $bonus = [];
    foreach (get_research_levels($userId) as $research) {
        if ($research['level'] <= 0) {
            continue;
        }
        foreach ($research['effects'] as $effectKey => $effectVal) {
            $bonus[$effectKey] = ($bonus[$effectKey] ?? 0) + ((float) $effectVal * $research['level']);
        }
    }
    return $bonus;
}

function production_rates(int $cityId, int $userId): array
{
    $rates = ['food' => 10.0, 'wood' => 10.0, 'stone' => 10.0, 'gold' => 5.0];
    foreach (get_building_levels($cityId) as $building) {
        if ($building['level'] <= 0) {
            continue;
        }
        foreach (['food', 'wood', 'stone', 'gold'] as $res) {
            $key = $res . '_per_minute';
            if (isset($building['effects'][$key])) {
                $rates[$res] += (float) $building['effects'][$key] * $building['level'];
            }
        }
    }

    $bonus = get_research_bonus_map($userId);
    foreach (['food', 'wood', 'stone', 'gold'] as $res) {
        $key = $res . '_prod_pct';
        if (isset($bonus[$key])) {
            $rates[$res] *= 1 + ($bonus[$key] / 100);
        }
    }
    return $rates;
}

function apply_resource_tick(int $cityId): array
{
    $pdo = db();
    $stmt = $pdo->prepare('SELECT * FROM cities WHERE id = ? FOR UPDATE');
    $pdo->beginTransaction();
    $stmt->execute([$cityId]);
    $city = $stmt->fetch();
    if (!$city) {
        $pdo->rollBack();
        return [];
    }

    $lastUpdate = new DateTimeImmutable($city['last_resource_update'], new DateTimeZone('UTC'));
    $now = game_now();
    $minutes = max(0, ($now->getTimestamp() - $lastUpdate->getTimestamp()) / 60);
    if ($minutes <= 0) {
        $pdo->commit();
        return $city;
    }

    $rates = production_rates((int) $city['id'], (int) $city['user_id']);
    foreach ($rates as $resource => $perMinute) {
        $capacity = (int) $city[$resource . '_capacity'];
        $city[$resource] = min($capacity, (int) $city[$resource] + (int) floor($perMinute * $minutes));
    }
    $city['last_resource_update'] = $now->format('Y-m-d H:i:s');

    $update = $pdo->prepare('UPDATE cities SET food = ?, wood = ?, stone = ?, gold = ?, last_resource_update = ? WHERE id = ?');
    $update->execute([$city['food'], $city['wood'], $city['stone'], $city['gold'], $city['last_resource_update'], $city['id']]);
    $pdo->commit();
    return $city;
}

function complete_due_queues(int $cityId, int $userId): void
{
    $now = game_now()->format('Y-m-d H:i:s');
    $pdo = db();

    $builds = $pdo->prepare('SELECT * FROM build_queue WHERE city_id = ? AND status = "queued" AND finishes_at <= ?');
    $builds->execute([$cityId, $now]);
    foreach ($builds->fetchAll() as $row) {
        $pdo->prepare('INSERT INTO city_buildings (city_id, building_id, level) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE level = VALUES(level)')
            ->execute([$cityId, $row['building_id'], $row['target_level']]);
        $defStmt = $pdo->prepare('SELECT key_name FROM building_definitions WHERE id = ?');
        $defStmt->execute([$row['building_id']]);
        $def = $defStmt->fetch();
        if ($def && $def['key_name'] === 'warehouse') {
            $capacityIncrease = 2000;
            $pdo->prepare('UPDATE cities SET food_capacity = food_capacity + ?, wood_capacity = wood_capacity + ?, stone_capacity = stone_capacity + ?, gold_capacity = gold_capacity + ? WHERE id = ?')
                ->execute([$capacityIncrease, $capacityIncrease, $capacityIncrease, $capacityIncrease, $cityId]);
        }
        $pdo->prepare('UPDATE build_queue SET status = "complete" WHERE id = ?')->execute([$row['id']]);
        if (!empty($row['builder_id'])) {
            $pdo->prepare('UPDATE city_builders SET status = "idle" WHERE id = ?')->execute([$row['builder_id']]);
        }
    }

    $training = $pdo->prepare('SELECT * FROM training_queue WHERE city_id = ? AND status = "queued" AND finishes_at <= ?');
    $training->execute([$cityId, $now]);
    foreach ($training->fetchAll() as $row) {
        $pdo->prepare('INSERT INTO city_units (city_id, unit_id, quantity) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)')
            ->execute([$cityId, $row['unit_id'], $row['quantity']]);
        $pdo->prepare('UPDATE training_queue SET status = "complete" WHERE id = ?')->execute([$row['id']]);
    }

    $research = $pdo->prepare('SELECT * FROM research_queue WHERE user_id = ? AND status = "queued" AND finishes_at <= ?');
    $research->execute([$userId, $now]);
    foreach ($research->fetchAll() as $row) {
        $pdo->prepare('INSERT INTO player_research (user_id, research_id, level) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE level = VALUES(level)')
            ->execute([$userId, $row['research_id'], $row['target_level']]);
        $pdo->prepare('UPDATE research_queue SET status = "complete" WHERE id = ?')->execute([$row['id']]);
    }
}

function city_has_resources(array $city, array $costs): bool
{
    foreach (['food', 'wood', 'stone', 'gold'] as $res) {
        if (($city[$res] ?? 0) < ($costs[$res] ?? 0)) {
            return false;
        }
    }
    return true;
}

function spend_city_resources(int $cityId, array $costs): void
{
    $stmt = db()->prepare('UPDATE cities SET food = food - ?, wood = wood - ?, stone = stone - ?, gold = gold - ? WHERE id = ?');
    $stmt->execute([$costs['food'] ?? 0, $costs['wood'] ?? 0, $costs['stone'] ?? 0, $costs['gold'] ?? 0, $cityId]);
}


function troop_counter_multiplier(string $attackerClass, string $defenderClass): float
{
    if ($attackerClass === 'infantry' && $defenderClass === 'cavalry') {
        return 1.15;
    }
    if ($attackerClass === 'cavalry' && $defenderClass === 'archer') {
        return 1.15;
    }
    if ($attackerClass === 'archer' && $defenderClass === 'infantry') {
        return 1.15;
    }
    if ($attackerClass === 'siege' && $defenderClass === 'defense') {
        return 1.10;
    }
    return 1.0;
}

function resolve_due_movements(): int
{
    $pdo = db();
    $now = game_now()->format('Y-m-d H:i:s');
    $stmt = $pdo->prepare('SELECT am.*, wt.owner_user_id AS target_owner_user_id, pc.level AS commander_level, cd.attack_buff_pct, cd.defense_buff_pct FROM army_movements am JOIN world_tiles wt ON wt.id = am.target_tile_id LEFT JOIN player_commanders pc ON pc.id = am.commander_id LEFT JOIN commander_definitions cd ON cd.id = pc.commander_definition_id WHERE am.status = "moving" AND am.arrives_at <= ?');
    $stmt->execute([$now]);
    $resolved = 0;

    foreach ($stmt->fetchAll() as $movement) {
        $units = json_decode($movement['units_json'], true) ?: [];
        $attackPower = 0;
        foreach ($units as $unitId => $qty) {
            $uStmt = $pdo->prepare('SELECT attack, troop_class FROM unit_definitions WHERE id = ?');
            $uStmt->execute([$unitId]);
            $u = $uStmt->fetch();
            if ($u) {
                $attackPower += ((int) $u['attack'] * (int) $qty);
            }
        }

        $researchBonus = get_research_bonus_map((int) $movement['owner_user_id']);
        if (isset($researchBonus['attack_pct'])) {
            $attackPower *= (1 + ($researchBonus['attack_pct'] / 100));
        }

        if ($movement['commander_id']) {
            $commanderAttackBuff = ((float) ($movement['attack_buff_pct'] ?? 0)) + (((int) ($movement['commander_level'] ?? 1)) - 1);
            $attackPower *= (1 + ($commanderAttackBuff / 100));
        }

        $defenderUserId = $movement['target_owner_user_id'] ? (int) $movement['target_owner_user_id'] : null;
        $defensePower = 0;

        if ($defenderUserId && $defenderUserId !== (int) $movement['owner_user_id']) {
            $cityStmt = $pdo->prepare('SELECT id FROM cities WHERE user_id = ?');
            $cityStmt->execute([$defenderUserId]);
            $defCity = $cityStmt->fetch();
            if ($defCity) {
                $dUnitsStmt = $pdo->prepare('SELECT cu.quantity, ud.defense, ud.troop_class FROM city_units cu JOIN unit_definitions ud ON ud.id = cu.unit_id WHERE cu.city_id = ?');
                $dUnitsStmt->execute([$defCity['id']]);
                $defenders = $dUnitsStmt->fetchAll();
                foreach ($defenders as $du) {
                    $defensePower += ((int) $du['quantity'] * (int) $du['defense']);
                }

                                // Hostinger-compatible fallback counter calc without JSON_TABLE
                $attackerClasses = [];
                foreach ($units as $unitId => $qty) {
                    $clsStmt = $pdo->prepare('SELECT troop_class FROM unit_definitions WHERE id = ?');
                    $clsStmt->execute([$unitId]);
                    $cls = $clsStmt->fetch()['troop_class'] ?? 'infantry';
                    $attackerClasses[] = [$cls, (int) $qty];
                }
                $counterBonus = 0.0;
                foreach ($attackerClasses as [$aclass, $aqty]) {
                    foreach ($defenders as $du) {
                        $counterBonus += troop_counter_multiplier((string) $aclass, (string) $du['troop_class']) * $aqty;
                    }
                }
                $attackPower *= 1 + min(0.25, ($counterBonus / 100000));
                
            }
        }

        $roll = mt_rand(80, 120) / 100;
        $attackerWins = ($attackPower * $roll) >= max(1, $defensePower);
        $summary = $attackerWins ? 'Attacker won the engagement.' : 'Defender held the line.';

        $reportStmt = $pdo->prepare('INSERT INTO combat_reports (attacker_user_id, defender_user_id, target_tile_id, summary, battle_data) VALUES (?, ?, ?, ?, ?)');
        $reportStmt->execute([
            $movement['owner_user_id'],
            $defenderUserId,
            $movement['target_tile_id'],
            $summary,
            json_encode([
                'attack_power' => (int) round($attackPower),
                'defense_power' => (int) round($defensePower),
                'roll' => $roll,
                'units_sent' => $units,
                'commander_id' => $movement['commander_id'],
                'attacker_won' => $attackerWins,
            ]),
        ]);

        $pdo->prepare('UPDATE army_movements SET status = "resolved" WHERE id = ?')->execute([$movement['id']]);
        if ($movement['commander_id']) {
            $pdo->prepare('UPDATE player_commanders SET status = "available", experience = experience + 20 WHERE id = ?')->execute([$movement['commander_id']]);
        }
        $resolved++;
    }

    return $resolved;
}
