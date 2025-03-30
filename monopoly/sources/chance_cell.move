module monopoly::chance_cell {
    use monopoly::{
        house_cell::{Self, HouseRegistry, HouseCell},
        monopoly::{AdminCap, Game, ActionRequest}
    };
    use std::string::String;
    use sui::{event, random::Random, vec_set::{Self, VecSet}};

    public struct ChanceArgument has copy, drop, store {}

    // === Structs ===

    public struct BalanceChance has copy, drop, store {
        description: String,
        is_increase: bool,
        amount: u64,
    }

    public struct TollChance has copy, drop, store {
        description: String,
        name: String, // House's name
        bps: u64, // base: 10_000
    }

    public struct JailChance has copy, drop, store {
        description: String,
        round: u8,
    }

    public struct HouseChance has copy, drop, store {
        description: String,
        is_level_up: bool,
        name: String, // House's name
    }

    public struct ChanceCell has key, store {
        id: UID,
        name: String,
        balance_chances_len: u8,
        toll_chances_len: u8,
        jail_chances_len: u8,
        house_chances_len: u8,
    }

    public struct ChanceRegistry has key {
        id: UID,
        versions: VecSet<u64>,
        // chances, description -> Arguments
        balance_chances: VecSet<BalanceChance>,
        toll_chances: VecSet<TollChance>,
        jail_chances: VecSet<JailChance>,
        house_chances: VecSet<HouseChance>,
    }

    // === Events ===
    public struct BalanceChancePicked has copy, drop {
        game: ID,
        player: address,
        description: String,
        is_increase: bool,
        amount: u64,
    }

    public struct TollChancePicked has copy, drop {
        game: ID,
        player: address,
        description: String,
        house_name: String,
        bps: u64,
    }

    public struct JailChancePicked has copy, drop {
        game: ID,
        player: address,
        description: String,
        round: u8,
    }

    public struct HouseChancePicked has copy, drop {
        game: ID,
        player: address,
        description: String,
        house_name: String,
        is_level_up: bool,
        level: u8,
    }

    // === Errors ===
    const EChanceTypeUndefined: u64 = 0;

    // === Constants ===
    const VERSION: u64 = 1;
    const MAX_ROUND: u8 = 12;

    // === Alias ===

    // === Init Function ===
    fun init(ctx: &mut TxContext) {
        let registry = ChanceRegistry {
            id: object::new(ctx),
            versions: vec_set::singleton(VERSION),
            balance_chances: vec_set::empty(),
            toll_chances: vec_set::empty(),
            jail_chances: vec_set::empty(),
            house_chances: vec_set::empty(),
        };
        transfer::share_object(registry);
    }

    // === Mutable Functions ===

    // === View Functions ===

    public fun name(self: &ChanceCell): String { self.name }

    public fun balance_chance_info(balance_chance: &BalanceChance): (String, bool, u64) {
        (balance_chance.description, balance_chance.is_increase, balance_chance.amount)
    }

    public fun toll_chance_info(toll_chance: &TollChance): (String, String, u64) {
        (toll_chance.description, toll_chance.name, toll_chance.bps)
    }

    public fun jail_chance_info(jail_chance: &JailChance): (String, u8) {
        (jail_chance.description, jail_chance.round)
    }

    public fun house_chance_info(house_chance: &HouseChance): (String, bool, String) {
        (house_chance.description, house_chance.is_level_up, house_chance.name)
    }

    public fun balance_chances(registry: &ChanceRegistry): &VecSet<BalanceChance> {
        &registry.balance_chances
    }

    public fun jail_chances(registry: &ChanceRegistry): &VecSet<JailChance> {
        &registry.jail_chances
    }

    public fun house_chances(registry: &ChanceRegistry): &VecSet<HouseChance> {
        &registry.house_chances
    }

    public fun toll_chances(registry: &ChanceRegistry): &VecSet<TollChance> {
        &registry.toll_chances
    }

    public fun balance_chance_amt(registry: &ChanceRegistry): u8 {
        registry.balance_chances.size() as u8
    }

    public fun toll_chance_amt(registry: &ChanceRegistry): u8 {
        registry.toll_chances.size() as u8
    }

    public fun jail_chance_amt(registry: &ChanceRegistry): u8 {
        registry.jail_chances.size() as u8
    }

    public fun house_chance_amt(registry: &ChanceRegistry): u8 {
        registry.house_chances.size() as u8
    }

    public fun total_chance_amt(self: &ChanceCell): u8 {
        self.balance_chances_len + self.toll_chances_len + self.jail_chances_len + self.house_chances_len
    }

    public fun toll_chance_name(toll_chance: &TollChance): String { toll_chance.name }

    // === Admin Functions ===

    #[allow(lint(public_random))]
    public fun initialize_chance_argument(
        request: ActionRequest<ChanceArgument>,
        game: &mut Game,
        registry: &ChanceRegistry,
        random: &Random,
        ctx: &mut TxContext,
    ) {
        let total_amt =
            registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt() + registry.house_chance_amt();
        let mut generator = random.new_generator(ctx);
        let idx = generator.generate_u8_in_range(0, total_amt);

        initialize_chance_argument_(request, game, registry, ctx, idx);
    }

    #[test_only]
    public fun initialize_chance_argument_for_testing(
        request: ActionRequest<ChanceArgument>,
        game: &mut Game,
        registry: &ChanceRegistry,
        idx: u8,
        ctx: &mut TxContext,
    ) {
        initialize_chance_argument_(request, game, registry, ctx, idx);
    }

    fun initialize_chance_argument_(
        mut request: ActionRequest<ChanceArgument>,
        game: &mut Game,
        registry: &ChanceRegistry,
        ctx: &mut TxContext,
        idx: u8,
    ) {
        if (idx < registry.balance_chance_amt()) {
            // balance chance
            request.initialize_balance_chance(game, registry, idx);
        } else if (idx < registry.balance_chance_amt() + registry.toll_chance_amt()) {
            // toll chance
            request.initialize_toll_chance(game, registry, idx);
        } else if (idx < registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt()) {
            // jail chance
            request.initialize_jail_chance(game, registry, idx);
        } else if (idx < registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt() + registry.house_chance_amt()) {
            // house chance
            request.initialize_house_chance(game, registry, idx);
        } else {
            abort EChanceTypeUndefined
        };

        game.drop_action_request(request, ctx);
    }

    public fun add_balance_chance_to_registry(
        registry: &mut ChanceRegistry,
        _: &AdminCap,
        description: String,
        is_increase: bool,
        amount: u64,
    ) {
        let balance_chance = new_balance_chance(description, is_increase, amount);
        registry.balance_chances.insert(balance_chance);
    }

    public fun add_toll_chance_to_registry(
        registry: &mut ChanceRegistry,
        _: &AdminCap,
        house_registry: &HouseRegistry,
        description: String,
        name: String,
        bps: u64,
    ) {
        house_registry.assert_if_not_in_registry(name);
        let toll_chance = new_toll_chance(description, name, bps);
        registry.toll_chances.insert(toll_chance);
    }

    public fun add_jail_chance_to_registry(
        registry: &mut ChanceRegistry,
        _: &AdminCap,
        description: String,
        round: u8,
    ) {
        let jail_chance = new_jail_chance(description, round);
        registry.jail_chances.insert(jail_chance);
    }

    public fun add_house_chance_to_registry(
        registry: &mut ChanceRegistry,
        _: &AdminCap,
        house_registry: &HouseRegistry,
        description: String,
        is_level_up: bool,
        name: String,
    ) {
        house_registry.assert_if_not_in_registry(name);
        let house_chance = new_house_chance(description, is_level_up, name);
        registry.house_chances.insert(house_chance);
    }

    public fun new_chance_cell(
        registry: &ChanceRegistry,
        _: &AdminCap,
        name: String,
        ctx: &mut TxContext,
    ): ChanceCell {
        ChanceCell {
            id: object::new(ctx),
            name,
            balance_chances_len: registry.balance_chances().size() as u8,
            toll_chances_len: registry.toll_chances().size() as u8,
            jail_chances_len: registry.jail_chances().size() as u8,
            house_chances_len: registry.house_chances().size() as u8,
        }
    }

    // handle balance chance to update user balance
    public fun initialize_balance_chance(
        request: &mut ActionRequest<ChanceArgument>,
        game: &mut Game,
        registry: &ChanceRegistry,
        rand_num: u8,
    ) {
        let chance = burn_receipt_and_get_balance_chance_info(registry, rand_num);
        let player = request.action_request_player();
        let (_, is_increase, amount) = chance.balance_chance_info();

        if (is_increase) {
            let balance_manager = game.balance_mut();
            let _ = balance_manager.add_balance(player, amount);
        } else {
            let player_value = game.player_balance(player).value();
            // check if the player has enough value
            if (player_value >= chance.amount) {
                let balance_manager = game.balance_mut();
                let _ = balance_manager.sub_balance(player, amount);
            } else {
                let player_asset_value = calculate_total_asset_value_of(game, player);
                let player_total_value = player_value + player_asset_value;
                // calculate the player's total va
                if (player_total_value < chance.amount) {
                    // the player is bankrupt
                    let balance_manager = game.balance_mut();
                    balance_manager.saturating_sub_balance(player, chance.amount);

                    if (house_cell::player_asset_of(game, player).size() > 0) {
                        //remove  all assets
                        house_cell::player_asset_of(game, player).size().do!<u64>(|_| {
                            house_cell::remove_player_asset(game, player);
                        });
                    };

                    // skip the player util the game is over
                    game.add_to_skips(player, MAX_ROUND);
                } else {
                    // Sell the player's assets to make a payment
                    let mut asset_value = 0;
                    while (true) {
                        let house_position =
                            house_cell::player_asset_of(game, player).keys().length() - 1;
                        let house_cell: &mut HouseCell = game.borrow_cell_mut_with_request(
                            request,
                            house_position as u64,
                        );
                        let sell_price = house_cell.sell_price_for_level(house_cell.level());
                        asset_value = asset_value + sell_price;

                        house_cell::remove_player_asset(game, player);

                        let current_value = player_value + asset_value;
                        if (current_value >= chance.amount) {
                            let balance_manager = game.balance_mut();
                            let sub_value = player_value + chance.amount - current_value;
                            balance_manager.sub_balance(player, sub_value);
                            break
                        }
                    }
                };
            };
        };

        request.settle_action_request();

        event::emit(BalanceChancePicked {
            game: object::id(game),
            player: player,
            description: chance.description,
            is_increase: chance.is_increase,
            amount: chance.amount,
        });
    }

    public fun initialize_toll_chance(
        request: &mut ActionRequest<ChanceArgument>,
        game: &mut Game,
        registry: &ChanceRegistry,
        rand_num: u8,
    ) {
        let chance = burn_receipt_and_get_toll_chance_info(registry, rand_num);
        let house_position = house_cell::house_position_of(game, chance.name);
        let house_cell: &mut HouseCell = game.borrow_cell_mut_with_request(
            request,
            house_position as u64,
        );

        house_cell.update_toll_by_chance(chance.bps);

        request.settle_action_request();

        event::emit(TollChancePicked {
            game: object::id(game),
            player: request.action_request_player(),
            description: chance.description,
            house_name: chance.name,
            bps: chance.bps,
        });
    }

    public fun initialize_jail_chance(
        request: &mut ActionRequest<ChanceArgument>,
        game: &mut Game,
        registry: &ChanceRegistry,
        rand_num: u8,
    ) {
        let chance = burn_receipt_and_get_jail_chance_info(registry, rand_num);
        let player = request.action_request_player();
        game.add_to_skips(player, chance.round);
        let player_position = game.borrow_player_position_mut();
        *player_position.get_mut(&player) = 5;

        request.settle_action_request();

        event::emit(JailChancePicked {
            game: object::id(game),
            player: request.action_request_player(),
            description: chance.description,
            round: chance.round,
        });
    }

    public fun initialize_house_chance(
        request: &mut ActionRequest<ChanceArgument>,
        game: &mut Game,
        registry: &ChanceRegistry,
        rand_num: u8,
    ) {
        let chance = burn_receipt_and_get_house_chance_info(registry, rand_num);
        request.settle_action_request();

        let house_position = house_cell::house_position_of(game, chance.name);
        {
            let house_cell: &mut HouseCell = game.borrow_cell_mut_with_request(
                request,
                house_position as u64,
            );

            if (chance.is_level_up) {
                house_cell.level_up_by_chance();
            } else {
                house_cell.level_down_by_chance();
            };
        };

        let house_cell = game.borrow_cell<HouseCell>(house_position as u64);

        event::emit(HouseChancePicked {
            game: object::id(game),
            player: request.action_request_player(),
            description: chance.description,
            house_name: chance.name,
            is_level_up: chance.is_level_up,
            level: house_cell.level(),
        });
    }

    public fun drop_chance_cell(self: ChanceCell) {
        let ChanceCell {
            id,
            name: _,
            balance_chances_len: _,
            toll_chances_len: _,
            jail_chances_len: _,
            house_chances_len: _,
        } = self;

        object::delete(id);
    }

    // === Package Functions ===
    // === Private Functions ===
    // it needs to be called after pick_chance_num function.
    fun burn_receipt_and_get_balance_chance_info(
        registry: &ChanceRegistry,
        rand_num: u8,
    ): BalanceChance {
        if (rand_num < registry.balance_chance_amt()) {
            let keys = *registry.balance_chances.keys();
            let idx = rand_num % registry.balance_chance_amt();
            *keys.borrow(idx as u64)
        } else {
            abort EChanceTypeUndefined
        }
    }

    // it needs to be called after pick_chance_num function.
    fun burn_receipt_and_get_toll_chance_info(registry: &ChanceRegistry, rand_num: u8): TollChance {
        if (rand_num < registry.balance_chance_amt() + registry.toll_chance_amt()) {
            let keys = *registry.toll_chances.keys();
            let idx = (rand_num - registry.balance_chance_amt())% registry.toll_chance_amt();
            *keys.borrow(idx as u64)
        } else {
            abort EChanceTypeUndefined
        }
    }

    // it needs to be called after pick_chance_num function.
    fun burn_receipt_and_get_jail_chance_info(registry: &ChanceRegistry, rand_num: u8): JailChance {
        if (
            rand_num < registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt()
        ) {
            let keys = *registry.jail_chances.keys();
            let idx =
                (rand_num - registry.balance_chance_amt() - registry.toll_chance_amt() )% registry.jail_chance_amt();
            *keys.borrow(idx as u64)
        } else {
            abort EChanceTypeUndefined
        }
    }

    // it needs to be called after pick_chance_num function.
    fun burn_receipt_and_get_house_chance_info(
        registry: &ChanceRegistry,
        rand_num: u8,
    ): HouseChance {
        if (
            rand_num < registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt() + registry.house_chance_amt()
        ) {
            let keys = *registry.house_chances.keys();
            let idx =
                (rand_num - registry.balance_chance_amt() - registry.toll_chance_amt() - registry.jail_chance_amt())% registry.house_chance_amt();
            *keys.borrow(idx as u64)
        } else {
            abort EChanceTypeUndefined
        }
    }

    fun new_balance_chance(description: String, is_increase: bool, amount: u64): BalanceChance {
        BalanceChance {
            description,
            is_increase,
            amount,
        }
    }

    fun new_toll_chance(description: String, name: String, bps: u64): TollChance {
        TollChance {
            description,
            name,
            bps,
        }
    }

    fun new_jail_chance(description: String, round: u8): JailChance {
        JailChance {
            description,
            round,
        }
    }

    fun new_house_chance(description: String, is_level_up: bool, name: String): HouseChance {
        HouseChance {
            description,
            is_level_up,
            name,
        }
    }

    public fun calculate_total_asset_value_of(game: &Game, player: address): u64 {
        let asset_idxs = (house_cell::player_asset_of(game, player)).into_keys();
        let mut player_asset_value = 0;
        asset_idxs.do!(|idx| {
            let house_cell: &HouseCell = game.borrow_cell(idx as u64);
            let level = house_cell.level();
            let (_, sell_prices, _) = house_cell.house();
            let sell_price = *sell_prices.get(&level);
            player_asset_value = player_asset_value + sell_price;
        });

        player_asset_value
    }

    // === Test Functions ===

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
