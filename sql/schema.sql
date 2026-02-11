CREATE TABLE users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(30) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    empire_name VARCHAR(60) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at DATETIME NULL,
    is_admin TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE alliances (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    tag VARCHAR(10) NOT NULL UNIQUE,
    leader_user_id INT UNSIGNED NOT NULL,
    description TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alliance_leader FOREIGN KEY (leader_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE alliance_members (
    alliance_id INT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NOT NULL,
    role ENUM('leader','officer','member') NOT NULL DEFAULT 'member',
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (alliance_id, user_id),
    INDEX idx_alliance_members_user (user_id),
    CONSTRAINT fk_alliance_member_alliance FOREIGN KEY (alliance_id) REFERENCES alliances(id) ON DELETE CASCADE,
    CONSTRAINT fk_alliance_member_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE world_tiles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    x_coord INT NOT NULL,
    y_coord INT NOT NULL,
    tile_type ENUM('empty','player_city','resource_node','npc_camp') NOT NULL DEFAULT 'empty',
    owner_user_id INT UNSIGNED NULL,
    resource_type ENUM('food','wood','stone','gold') NULL,
    resource_amount INT UNSIGNED NOT NULL DEFAULT 0,
    npc_strength INT UNSIGNED NOT NULL DEFAULT 0,
    UNIQUE KEY uniq_tile_coord (x_coord, y_coord),
    INDEX idx_tile_owner (owner_user_id),
    INDEX idx_tile_type (tile_type),
    CONSTRAINT fk_tile_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE cities (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL UNIQUE,
    tile_id BIGINT UNSIGNED NOT NULL UNIQUE,
    city_name VARCHAR(80) NOT NULL,
    population INT UNSIGNED NOT NULL DEFAULT 100,
    morale TINYINT UNSIGNED NOT NULL DEFAULT 100,
    food BIGINT UNSIGNED NOT NULL DEFAULT 500,
    wood BIGINT UNSIGNED NOT NULL DEFAULT 500,
    stone BIGINT UNSIGNED NOT NULL DEFAULT 500,
    gold BIGINT UNSIGNED NOT NULL DEFAULT 500,
    food_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    wood_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    stone_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    gold_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    last_resource_update DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_city_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_city_tile FOREIGN KEY (tile_id) REFERENCES world_tiles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE building_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(40) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    base_food INT UNSIGNED NOT NULL DEFAULT 0,
    base_wood INT UNSIGNED NOT NULL DEFAULT 0,
    base_stone INT UNSIGNED NOT NULL DEFAULT 0,
    base_gold INT UNSIGNED NOT NULL DEFAULT 0,
    base_duration_seconds INT UNSIGNED NOT NULL,
    required_town_hall_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
    max_level TINYINT UNSIGNED NOT NULL DEFAULT 30,
    effects_json JSON NOT NULL
) ENGINE=InnoDB;

CREATE TABLE city_buildings (
    city_id INT UNSIGNED NOT NULL,
    building_id INT UNSIGNED NOT NULL,
    level INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (city_id, building_id),
    CONSTRAINT fk_city_building_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_city_building_definition FOREIGN KEY (building_id) REFERENCES building_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE build_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id INT UNSIGNED NOT NULL,
    building_id INT UNSIGNED NOT NULL,
    target_level INT UNSIGNED NOT NULL,
    starts_at DATETIME NOT NULL,
    finishes_at DATETIME NOT NULL,
    status ENUM('queued','complete') NOT NULL DEFAULT 'queued',
    INDEX idx_build_queue_city_status (city_id, status, finishes_at),
    CONSTRAINT fk_build_queue_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_build_queue_building FOREIGN KEY (building_id) REFERENCES building_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE research_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    branch_key VARCHAR(40) NOT NULL,
    description TEXT NOT NULL,
    max_level TINYINT UNSIGNED NOT NULL DEFAULT 10,
    prerequisite_research_id INT UNSIGNED NULL,
    prerequisite_level TINYINT UNSIGNED NOT NULL DEFAULT 0,
    cost_food INT UNSIGNED NOT NULL,
    cost_wood INT UNSIGNED NOT NULL,
    cost_stone INT UNSIGNED NOT NULL,
    cost_gold INT UNSIGNED NOT NULL,
    duration_seconds INT UNSIGNED NOT NULL,
    effect_json JSON NOT NULL,
    CONSTRAINT fk_research_prereq FOREIGN KEY (prerequisite_research_id) REFERENCES research_definitions(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE player_research (
    user_id INT UNSIGNED NOT NULL,
    research_id INT UNSIGNED NOT NULL,
    level INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, research_id),
    CONSTRAINT fk_player_research_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_player_research_definition FOREIGN KEY (research_id) REFERENCES research_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE research_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    research_id INT UNSIGNED NOT NULL,
    target_level INT UNSIGNED NOT NULL,
    starts_at DATETIME NOT NULL,
    finishes_at DATETIME NOT NULL,
    status ENUM('queued','complete') NOT NULL DEFAULT 'queued',
    INDEX idx_research_user_status (user_id, status, finishes_at),
    CONSTRAINT fk_research_queue_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_research_queue_definition FOREIGN KEY (research_id) REFERENCES research_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE unit_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(40) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    tier TINYINT UNSIGNED NOT NULL,
    attack INT UNSIGNED NOT NULL,
    defense INT UNSIGNED NOT NULL,
    speed DECIMAL(6,2) NOT NULL,
    upkeep_food INT UNSIGNED NOT NULL,
    training_time_seconds INT UNSIGNED NOT NULL,
    cost_food INT UNSIGNED NOT NULL,
    cost_wood INT UNSIGNED NOT NULL,
    cost_stone INT UNSIGNED NOT NULL,
    cost_gold INT UNSIGNED NOT NULL,
    required_tech_id INT UNSIGNED NULL,
    CONSTRAINT fk_unit_required_tech FOREIGN KEY (required_tech_id) REFERENCES research_definitions(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE city_units (
    city_id INT UNSIGNED NOT NULL,
    unit_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (city_id, unit_id),
    CONSTRAINT fk_city_units_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_city_units_unit FOREIGN KEY (unit_id) REFERENCES unit_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE commander_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(40) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    rarity ENUM('common','rare','epic','legendary') NOT NULL DEFAULT 'common',
    attack_buff_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
    defense_buff_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
    speed_buff_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
    upkeep_reduction_pct TINYINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE player_commanders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    commander_definition_id INT UNSIGNED NOT NULL,
    level TINYINT UNSIGNED NOT NULL DEFAULT 1,
    experience INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('available','on_mission','injured') NOT NULL DEFAULT 'available',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_player_commander_user_status (user_id, status),
    CONSTRAINT fk_player_commander_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_player_commander_definition FOREIGN KEY (commander_definition_id) REFERENCES commander_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE training_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id INT UNSIGNED NOT NULL,
    unit_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    starts_at DATETIME NOT NULL,
    finishes_at DATETIME NOT NULL,
    status ENUM('queued','complete') NOT NULL DEFAULT 'queued',
    INDEX idx_training_city_status (city_id, status, finishes_at),
    CONSTRAINT fk_training_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_training_unit FOREIGN KEY (unit_id) REFERENCES unit_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE army_movements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    owner_user_id INT UNSIGNED NOT NULL,
    source_city_id INT UNSIGNED NOT NULL,
    target_tile_id BIGINT UNSIGNED NOT NULL,
    commander_id BIGINT UNSIGNED NULL,
    mission_type ENUM('attack','scout','reinforce','gather') NOT NULL,
    units_json JSON NOT NULL,
    departs_at DATETIME NOT NULL,
    arrives_at DATETIME NOT NULL,
    status ENUM('moving','resolved') NOT NULL DEFAULT 'moving',
    INDEX idx_army_arrival (status, arrives_at),
    INDEX idx_army_owner (owner_user_id),
    CONSTRAINT fk_army_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_army_source_city FOREIGN KEY (source_city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_army_target_tile FOREIGN KEY (target_tile_id) REFERENCES world_tiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_army_commander FOREIGN KEY (commander_id) REFERENCES player_commanders(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE combat_reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attacker_user_id INT UNSIGNED NOT NULL,
    defender_user_id INT UNSIGNED NULL,
    target_tile_id BIGINT UNSIGNED NOT NULL,
    summary VARCHAR(255) NOT NULL,
    battle_data JSON NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_combat_attacker (attacker_user_id, created_at),
    INDEX idx_combat_defender (defender_user_id, created_at),
    CONSTRAINT fk_combat_attacker FOREIGN KEY (attacker_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_combat_defender FOREIGN KEY (defender_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_combat_tile FOREIGN KEY (target_tile_id) REFERENCES world_tiles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sender_user_id INT UNSIGNED NOT NULL,
    recipient_user_id INT UNSIGNED NULL,
    alliance_id INT UNSIGNED NULL,
    channel ENUM('global','alliance','private') NOT NULL DEFAULT 'global',
    body VARCHAR(500) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_messages_channel_time (channel, created_at),
    INDEX idx_messages_alliance_time (alliance_id, created_at),
    CONSTRAINT fk_message_sender FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_message_recipient FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_message_alliance FOREIGN KEY (alliance_id) REFERENCES alliances(id) ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT INTO building_definitions (key_name, display_name, base_food, base_wood, base_stone, base_gold, base_duration_seconds, required_town_hall_level, max_level, effects_json) VALUES
('town_hall', 'Town Hall', 100, 150, 150, 100, 120, 1, 25, JSON_OBJECT('unlocks', JSON_ARRAY('all'))),
('farm', 'Farm', 60, 60, 40, 20, 90, 1, 30, JSON_OBJECT('food_per_minute', 25)),
('lumber_mill', 'Lumber Mill', 50, 80, 40, 20, 90, 1, 30, JSON_OBJECT('wood_per_minute', 25)),
('quarry', 'Quarry', 50, 60, 80, 20, 90, 2, 30, JSON_OBJECT('stone_per_minute', 22)),
('gold_mine', 'Gold Mine', 80, 80, 80, 50, 120, 3, 30, JSON_OBJECT('gold_per_minute', 15)),
('warehouse', 'Warehouse', 100, 100, 100, 50, 150, 2, 25, JSON_OBJECT('storage_per_level', 2000)),
('barracks', 'Barracks', 120, 160, 120, 80, 180, 2, 25, JSON_OBJECT('unit_train_speed_pct', 2)),
('academy', 'Academy', 120, 120, 100, 100, 180, 4, 25, JSON_OBJECT('research_speed_pct', 2)),
('walls', 'Walls', 80, 100, 220, 50, 240, 3, 25, JSON_OBJECT('city_defense_pct', 5));

INSERT INTO research_definitions (id, key_name, display_name, branch_key, description, max_level, prerequisite_research_id, prerequisite_level, cost_food, cost_wood, cost_stone, cost_gold, duration_seconds, effect_json) VALUES
(1, 'agriculture', 'Agriculture', 'economy', 'Increases food production by 5% per level.', 15, NULL, 0, 120, 100, 80, 50, 180, JSON_OBJECT('food_prod_pct', 5)),
(2, 'logging', 'Logging', 'economy', 'Increases wood production by 5% per level.', 15, NULL, 0, 100, 120, 80, 50, 180, JSON_OBJECT('wood_prod_pct', 5)),
(3, 'masonry', 'Masonry', 'economy', 'Increases stone production by 5% per level.', 15, NULL, 0, 100, 100, 120, 50, 180, JSON_OBJECT('stone_prod_pct', 5)),
(4, 'coinage', 'Coinage', 'economy', 'Increases gold production by 5% per level.', 15, 1, 3, 120, 120, 120, 120, 240, JSON_OBJECT('gold_prod_pct', 5)),
(5, 'military_drill', 'Military Drill', 'warfare', 'Increases unit attack by 3% per level.', 15, NULL, 0, 150, 120, 120, 100, 300, JSON_OBJECT('attack_pct', 3)),
(6, 'shield_wall', 'Shield Wall', 'warfare', 'Increases unit defense by 3% per level.', 15, 5, 2, 150, 100, 140, 110, 300, JSON_OBJECT('defense_pct', 3)),
(7, 'horse_breeding', 'Horse Breeding', 'warfare', 'Increases cavalry speed by 4% per level.', 10, 5, 3, 180, 120, 100, 140, 360, JSON_OBJECT('cavalry_speed_pct', 4)),
(8, 'engineering', 'Engineering', 'infrastructure', 'Improves build speed by 2% per level.', 12, 3, 2, 120, 120, 180, 90, 260, JSON_OBJECT('build_speed_pct', 2)),
(9, 'siegecraft', 'Siegecraft', 'warfare', 'Increases siege attack by 5% per level.', 10, 8, 2, 200, 160, 160, 160, 420, JSON_OBJECT('siege_attack_pct', 5)),
(10, 'logistics', 'Logistics', 'infrastructure', 'Reduces unit upkeep by 2% per level.', 12, 8, 1, 160, 160, 140, 120, 280, JSON_OBJECT('upkeep_reduction_pct', 2));

INSERT INTO unit_definitions (key_name, display_name, tier, attack, defense, speed, upkeep_food, training_time_seconds, cost_food, cost_wood, cost_stone, cost_gold, required_tech_id) VALUES
('militia', 'Militia', 1, 8, 7, 0.90, 1, 35, 12, 8, 6, 3, NULL),
('infantry', 'Infantry', 2, 14, 12, 1.00, 1, 50, 24, 12, 12, 8, 5),
('archer', 'Archer', 2, 18, 10, 1.10, 1, 60, 20, 28, 10, 10, 5),
('cavalry', 'Cavalry', 3, 28, 18, 1.85, 2, 130, 56, 40, 24, 28, 7),
('pikeman', 'Pikeman', 3, 22, 24, 0.95, 2, 120, 42, 18, 28, 20, 6),
('siege', 'Siege Engine', 4, 46, 14, 0.70, 3, 190, 70, 50, 70, 34, 9),
('royal_guard', 'Royal Guard', 5, 60, 44, 1.20, 3, 260, 120, 80, 80, 90, 10);

INSERT INTO commander_definitions (key_name, display_name, rarity, attack_buff_pct, defense_buff_pct, speed_buff_pct, upkeep_reduction_pct) VALUES
('captain_arden', 'Captain Arden', 'common', 8, 4, 2, 0),
('marshal_lyra', 'Marshal Lyra', 'rare', 12, 8, 4, 2),
('strategos_vorn', 'Strategos Vorn', 'epic', 16, 10, 5, 4),
('empress_guardian', 'Empress Guardian', 'legendary', 22, 16, 8, 6);
