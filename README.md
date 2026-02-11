# Dynasty Defense (PHP 4X MMORPG)

Dynasty Defense is a lightweight browser-based 4X MMO prototype designed for PHP + MySQL shared hosting (Hostinger-compatible). It includes account auth, persistent city/resource simulation, map exploration, build/train/research queues, army movement/combat resolution, alliance basics, global/alliance chat, unit tiers (1-5), commander-led armies, and deeper multi-branch research.

## Architecture overview
- **Backend**: PHP 8 scripts with modular includes (`includes/`) and AJAX endpoints (`api/`).
- **Frontend**: HTML5/CSS + vanilla JavaScript polling every 15s.
- **Persistence**: MySQL schema in `sql/schema.sql` with indexed game tables.
- **Real-time model**: turnless, event queues + timestamp-based progression.
- **Ticks**: can run lazily on requests *and* via cron (`cron/tick.php`).

## Project structure
- `index.php`, `register.php`, `login.php`, `logout.php` - authentication pages.
- `game.php` - main game UI.
- `api/*.php` - endpoints for status, map, build, train, move, combat-ready movement resolution trigger, chat, alliance.
- `includes/` - DB/auth/util/game logic modules.
- `assets/css/style.css`, `assets/js/game.js` - frontend.
- `sql/schema.sql` - full MySQL schema + starter data.
- `cron/tick.php` - queue and movement resolver.
- `cron/map_seed.php` - populate world tiles.

## Hostinger deployment
1. **Create DB** in Hostinger hPanel (MySQL Database + user).
2. **Import SQL**:
   - Open phpMyAdmin.
   - Import `sql/schema.sql`.
3. **Upload files**:
   - Upload entire project into `public_html/` (or a subfolder).
4. **Configure DB**:
   - Edit `config/config.php` values (`host`, `dbname`, `user`, `pass`).
5. **Seed map once**:
   - Run `php cron/map_seed.php` via SSH or temporary web runner script.
6. **Cron setup** in Hostinger:
   - Add cron job every 5 minutes:
     - `php /home/USERNAME/public_html/cron/tick.php`
7. **Permissions/Security**:
   - Keep `config/config.php` non-public if using custom folder layout.
   - Enable HTTPS in Hostinger and force SSL.

## Configuration variables
`config/config.php` contains:
- DB connection settings.
- `map_width` / `map_height`.
- `tick_seconds` / `base_travel_seconds`.
- Session/csrf names.

## Notes
- Queries use prepared statements.
- Passwords are hashed with `password_hash`.
- CSRF token checks are enforced for POST API actions.
- Combat formula is intentionally simple and easy to rebalance.


## New progression additions
- **Unit tiers (T1-T5)** with escalating costs/stats and tech requirements.
- **Building level gating** via required Town Hall levels.
- **Research branches** (`economy`, `warfare`, `infrastructure`) with prerequisites and max levels.
- **Commanders** that can be assigned to armies and provide attack/defense/speed buffs.

- UI now surfaces build/research/train cost and duration previews before confirming actions.
- Troop training now enforces both research and building-level prerequisites for tier progression.

## Major feature expansion implemented
- **City Building & Development**: Added many additional structure definitions (Archery Range, Stable, Siege Workshop, Hospital, Tavern, Trading Post, Watchtower, Monument) plus builder-slot management via `city_builders` and queue builder assignment.
- **Civilizations**: Added 14 playable civilizations with unique bonuses, selected at registration, and civilization-specific starter commander targeting.
- **Commanders**: Expanded commander schema with 4 rarity tiers (Advanced/Elite/Epic/Legendary), specializations, 4 base skills + mastery, pairing support, and commander equipment scaffolding.
- **Troops & Combat**: Added troop class metadata, march capacity, multiple march queue constraints, and class-counter influence in combat resolution.
- **Map/Meta/Progression**: Added terrain/fog metadata, kingdoms and KvK season scaffolding, items, quests, and monetization-facing currencies (gems, AP, VIP points) at schema level.

> Note: This commit delivers the database + backend + UI scaffolding for these systems in a shared-hosting-safe architecture. Full content-complete balancing (all live events/KvK loops, 100% commander ability behavior, translation, monetization storefront workflows, etc.) should be iterated in follow-up phases.
