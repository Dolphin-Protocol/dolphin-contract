module monopoly::house_cell {
    use monopoly::{monopoly::{Game, ActionRequest, AdminCap}, utils};
    use std::string::String;
    use sui::{event, transfer::Receiving, vec_map::{Self, VecMap}, vec_set::{Self, VecSet}};

    // === Errors ===

    const ENoParameterBody: u64 = 103;
    const EPlayerNotHouseOwner: u64 = 104;
    const EHouseNotRegistered: u64 = 105;
    const EHousePluginNotAllowed: u64 = 106;
    const ENameAlreadyRecorded: u64 = 107;

    // === Constants ===

    const VERSION: u64 = 1;
    const BASE_BPS: u64 = 10_000;

    // === Structs ===

    public struct HousePlugin has copy, drop, store {}

    public struct HousePluginInfo has store {
        player_assets: VecMap<address, VecSet<u8>>,
        name_to_position: VecMap<String, u8>,
    }

    public struct HouseRegistry has key {
        id: UID,
        versions: VecSet<u64>,
        // house object with its name
        houses: VecMap<String, House>,
    }

    public struct House has copy, store {
        // TODO: maybe walrus img_url stored in url?
        // each level starts from 1
        buy_prices: VecMap<u8, u64>,
        sell_prices: VecMap<u8, u64>,
        tolls: VecMap<u8, u64>,
    }

    public struct HouseCell has key, store {
        id: UID,
        owner: Option<address>,
        level: u8,
        name: String,
        house: House,
    }

    // -- Arguments for settling response
    public struct BuyArgument has copy, drop, store {
        player_balance: u64,
        house_price: u64,
        level: u8,
        eligible: bool,
        purchased: bool,
    }

    // === Events ===

    /// Emit when server resolve buy or upgrade events
    public struct BuyOrUpgradeHouseEvent has copy, drop {
        game: ID,
        action_request: ID,
        player: address,
        pos_index: u64,
        house_name: String,
        level: u8,
        purchased: bool,
    }

    public struct PayHousePollEvent has copy, drop {
        game: ID,
        action_request: ID,
        player: address,
        pos_index: u64,
        house_name: String,
        level: u8,
        payee: address,
    }

    // === Method Aliases ===

    // === Init Function ===

    fun init(ctx: &mut TxContext) {
        let registry = HouseRegistry {
            id: object::new(ctx),
            versions: vec_set::singleton(VERSION),
            houses: vec_map::empty<String, House>(),
        };

        transfer::share_object(registry);
    }

    // === Mutable Functions ===

    fun borrow_house_plugin_info_mut(game: &mut Game): &mut HousePluginInfo {
        game.borrow_state_mut(new_house_plugin())
    }

    fun borrow_player_assets_mut(
        house_plugin: &mut HousePluginInfo,
    ): &mut VecMap<address, VecSet<u8>> {
        &mut house_plugin.player_assets
    }

    fun borrow_name_to_positon_mut(
        house_plugin_info: &mut HousePluginInfo,
    ): &mut VecMap<String, u8> {
        &mut house_plugin_info.name_to_position
    }

    // === View Functions ===

    public fun borrow_house_plugin_info(game: &Game): &HousePluginInfo {
        game.borrow_state(new_house_plugin())
    }

    public fun borrow_player_assets(house_plugin: &HousePluginInfo): &VecMap<address, VecSet<u8>> {
        &house_plugin.player_assets
    }

    public fun borrow_name_to_positon(house_plugin_info: &HousePluginInfo): &VecMap<String, u8> {
        &house_plugin_info.name_to_position
    }

    // Get house info from house cell
    public fun house(house_cell: &HouseCell): (VecMap<u8, u64>, VecMap<u8, u64>, VecMap<u8, u64>) {
        (house_cell.house.buy_prices, house_cell.house.sell_prices, house_cell.house.tolls)
    }

    // Get level from house cell
    public fun level(self: &HouseCell): u8 {
        self.level
    }

    // Get owner from house cell
    public fun owner(self: &HouseCell): Option<address> {
        self.owner
    }

    // Get name from house cell
    public fun name(self: &HouseCell): String {
        self.name
    }

    public fun buy_argument_info(buy_argument: &BuyArgument): (u64, u64, u8, bool) {
        (
            buy_argument.player_balance,
            buy_argument.house_price,
            buy_argument.level,
            buy_argument.purchased,
        )
    }

    public fun house_cell_info(
        self: &HouseCell,
    ): (Option<address>, u8, String, Option<u64>, Option<u64>, u64) {
        (
            self.owner,
            self.level,
            self.name,
            self.house_cell_current_buy_price(),
            self.house_cell_current_sell_price(),
            self.house_cell_current_poll(),
        )
    }

    public fun buy_prices(self: &HouseCell): &VecMap<u8, u64> {
        &self.house.buy_prices
    }

    public fun sell_prices(self: &HouseCell): &VecMap<u8, u64> {
        &self.house.sell_prices
    }

    public fun tolls(self: &HouseCell): &VecMap<u8, u64> {
        &self.house.tolls
    }

    // return None if attain max_level
    public fun house_cell_current_buy_price(self: &HouseCell): Option<u64> {
        if (self.level == self.max_level()) option::none()
        else option::some(self.house.buy_prices[&(self.level + 1)])
    }

    public fun house_cell_current_sell_price(self: &HouseCell): Option<u64> {
        if (self.level == 0) option::none() else option::some(self.house.tolls[&(self.level)])
    }

    public fun house_cell_current_poll(self: &HouseCell): u64 {
        if (self.level == 0) 0 else self.house.tolls[&(self.level)]
    }

    public fun max_level(self: &HouseCell): u8 {
        utils::max_of_u8(self.house.buy_prices.keys())
    }

    public fun buy_argument_player_balance(buy_argument: &BuyArgument): u64 {
        buy_argument.player_balance
    }

    public fun buy_argument_house_price(buy_argument: &BuyArgument): u64 {
        buy_argument.house_price
    }

    public fun buy_argument_amount(buy_argument: &BuyArgument): bool {
        buy_argument.purchased
    }

    public fun house_cell_owner(house_cell: &HouseCell): Option<address> {
        house_cell.owner
    }

    public fun house_cell_house(house_cell: &HouseCell): &House {
        &house_cell.house
    }

    public fun borrow_house_cell_from_game(game: &Game, pos_index: u64): &HouseCell {
        game.borrow_cell(pos_index)
    }

    public fun contains_name(registry: &HouseRegistry, name: String): bool {
        registry.houses.contains(&name)
    }

    public fun sell_price_for_level(self: &HouseCell, level: u8): u64 {
        *self.house.sell_prices.get(&level)
    }

    public fun buy_price_for_level(self: &HouseCell, level: u8): u64 {
        *self.house.buy_prices.get(&level)
    }

    public fun toll_for_level(self: &HouseCell, level: u8): u64 {
        *self.house.tolls.get(&level)
    }

    public fun house_position_of(game: &Game, name: String): u8 {
        let house_plugin_info = borrow_house_plugin_info(game);
        let name_to_position = house_plugin_info.name_to_position;
        *name_to_position.get(&name)
    }

    public fun player_asset_of(game: &Game, player: address): VecSet<u8> {
        assert!(!game.is_plugin_exists<HousePlugin>(), EHousePluginNotAllowed);

        let house_plugin_info = borrow_house_plugin_info(game);
        if (house_plugin_info.player_assets.contains(&player)) {
            let copy_asset = *house_plugin_info.player_assets.get(&player);
            copy_asset
        } else {
            vec_set::empty<u8>()
        }
    }

    // === Admin Functions ===
    /// use AdminCap to check if game object is in creating process
    public fun initialize_states(game: &mut Game, cap: &AdminCap) {
        game.add_and_init_plugin(
            cap,
            HousePlugin {},
            HousePluginInfo {
                player_assets: vec_map::empty<address, VecSet<u8>>(),
                name_to_position: vec_map::empty<String, u8>(),
            },
        );
    }

    /// remove the HousePluginInfo fro game state and drop it
    public fun remove_states(game: &mut Game) {
        let HousePluginInfo {
            player_assets: _,
            name_to_position: _,
        } = game.remove_plugin(HousePlugin {});
    }

    public(package) fun remove_player_asset(game: &mut Game, player: address) {
        assert!(!game.is_plugin_exists<HousePlugin>(), EHousePluginNotAllowed);

        let house_plugin_info = borrow_house_plugin_info_mut(game);
        let player_assets = house_plugin_info.borrow_player_assets_mut();

        let (_, player_asset) = player_assets.remove(&player);
        player_asset.into_keys().pop_back();

        player_assets.insert(player, player_asset);
    }

    // create a new house cell
    public fun new_house_cell(
        registry: &HouseRegistry,
        name: String,
        ctx: &mut TxContext,
    ): HouseCell {
        let house = registry.copy_house(name);

        HouseCell {
            id: object::new(ctx),
            owner: option::none(),
            name,
            level: 0,
            house,
        }
    }

    public fun drop_house_cell(self: HouseCell) {
        let HouseCell {
            id,
            owner: _,
            name: _,
            level: _,
            house,
        } = self;

        object::delete(id);

        let House {
            buy_prices: _,
            sell_prices: _,
            tolls: _,
        } = house;
    }

    public fun add_name_to_position(game: &mut Game, name: String, pos_index: u8) {
        assert!(game.is_plugin_exists<HousePlugin>(), EHousePluginNotAllowed);

        let name_to_position = borrow_house_plugin_info_mut(game).borrow_name_to_positon_mut();

        assert!(!name_to_position.contains(&name), ENameAlreadyRecorded);

        name_to_position.insert(name, pos_index);
    }

    // add house to registry
    public fun add_house_to_registry(
        registry: &mut HouseRegistry,
        _cap: &AdminCap,
        name: String,
        levels: vector<u8>,
        buy_prices: vector<u64>,
        sell_prices: vector<u64>,
        tolls: vector<u64>,
    ) {
        let house = House {
            buy_prices: vec_map::from_keys_values(levels, buy_prices),
            sell_prices: vec_map::from_keys_values(levels, sell_prices),
            tolls: vec_map::from_keys_values(levels, tolls),
        };

        registry.houses.insert(name, house);
    }

    // update specific house in registry
    public fun update_house_in_registry(
        registry: &mut HouseRegistry,
        _cap: &AdminCap,
        name: String,
        new_levels: vector<u8>,
        new_buy_prices: vector<u64>,
        new_sell_prices: vector<u64>,
        new_tolls: vector<u64>,
    ) {
        // set house info field
        let house = registry.houses.get_mut(&name);

        let new_buy_prices_map = vec_map::from_keys_values(new_levels, new_buy_prices);
        let new_sell_prices_map = vec_map::from_keys_values(new_levels, new_sell_prices);
        let new_tolls_map = vec_map::from_keys_values(new_levels, new_tolls);

        house.buy_prices = new_buy_prices_map;
        house.sell_prices = new_sell_prices_map;
        house.tolls = new_tolls_map;
    }

    // remove house in registry
    public fun remove_house_in_registry(
        registry: &mut HouseRegistry,
        _cap: &AdminCap,
        name: String,
    ) {
        let (_, house) = registry.houses.remove(&name);
        let House {
            buy_prices: _,
            sell_prices: _,
            tolls: _,
        } = house;
    }

    // === Package Functions ===

    // called after 'monopoly::request_player_move' to config the parameters
    public fun initialize_buy_params(
        action_request: &mut ActionRequest<BuyArgument>,
        game: &mut Game,
    ) {
        // Retrieve related objects and values in a single block
        let house_cell: &HouseCell = game.borrow_cell_with_request(action_request);
        let (owner, level, house_name, mut house_price, _, poll) = house_cell.house_cell_info();

        // Verify balance type and get player info
        let player = action_request.action_request_player();
        let player_balance = game.player_balance(player).value();

        // Create parameters object
        let mut parameters = BuyArgument {
            player_balance,
            house_price: 0,
            level,
            eligible: false,
            purchased: false,
        };

        if (owner.is_none()) {
            // house_price should be some
            let house_price = house_price.extract();
            // buy action
            if (player_balance >= house_price) {
                parameters.eligible = true;
                parameters.house_price = house_price;
                game.config_parameter(action_request, parameters);
            } else {
                // insufficient balance
                action_request.settle_action_request();
            };
        } else {
            let owner = *owner.borrow();

            if (owner == player) {
                // upgrade
                if (house_price.is_some()) {
                    parameters.eligible = true;
                    parameters.house_price = house_price.extract();
                    game.config_parameter(action_request, parameters);
                } else {
                    // attain max_level
                    action_request.settle_action_request();
                };
            } else {
                // pay the poll
                game
                    .balance_mut()
                    .saturating_transfer(
                        player,
                        owner,
                        poll,
                    );
                let (game_id, player, pos_index) = action_request.action_request_info();
                action_request.settle_action_request();

                event::emit(PayHousePollEvent {
                    game: game_id,
                    action_request: object::id(action_request),
                    player,
                    pos_index,
                    house_name,
                    level,
                    payee: owner,
                })
            };
        };
    }

    public fun empty_house_plugin(): HousePluginInfo {
        HousePluginInfo {
            player_assets: vec_map::empty<address, VecSet<u8>>(),
            name_to_position: vec_map::empty<String, u8>(),
        }
    }

    // user execute buy or upgrade the house
    public fun execute_buy(
        mut request: ActionRequest<BuyArgument>,
        purchased: bool,
        ctx: &TxContext,
    ) {
        // validate balance
        assert!(request.action_request_parameters().is_some(), ENoParameterBody);

        let parameters = request.action_request_parameters_mut().borrow_mut();

        // fill the required parameters
        parameters.purchased = purchased;

        // mark settled in action_request to promise the action is ready to be sent
        request.settle_action_request();

        // transfer action to game object
        request.finish_action_by_player(ctx);
    }

    /// executed by server to settle the game state
    public fun settle_buy(
        received_request: Receiving<ActionRequest<BuyArgument>>,
        game: &mut Game,
        ctx: &mut TxContext,
    ) {
        let request = game.receive_action_request(received_request);
        settle_buy_(request, game, ctx);
    }

    // test_only as we can't acquire Receiving object in test
    #[test_only]
    public fun settle_buy_for_testing(
        request: ActionRequest<BuyArgument>,
        game: &mut Game,
        ctx: &mut TxContext,
    ) {
        settle_buy_(request, game, ctx);
    }

    fun settle_buy_(mut request: ActionRequest<BuyArgument>, game: &mut Game, ctx: &mut TxContext) {
        let BuyArgument {
            player_balance: _,
            house_price,
            level,
            eligible,
            purchased,
        } = request.action_request_remove_parameters(game);

        let (game_id, player, pos_index) = request.action_request_info();
        // validate price
        if (purchased && eligible) {
            // update player's balance
            let balance_manager = game.balance_mut();
            balance_manager.sub_balance(
                player,
                house_price,
            );

            // update house owner & state
            let house_cell: &mut HouseCell = game.borrow_cell_mut_with_request(&request, pos_index);
            house_cell.level = std::u8::min(level + 1, house_cell.max_level());

            if (house_cell.owner.is_none()) {
                house_cell.owner.fill(player);
            } else {
                // this shuoldn't happen
                assert!(house_cell.owner.borrow() == player, EPlayerNotHouseOwner);
            };
        };

        let action_request_id = object::id(&request);

        let house_cell = game.borrow_cell<HouseCell>(pos_index);
        event::emit(BuyOrUpgradeHouseEvent {
            game: game_id,
            action_request: action_request_id,
            player,
            pos_index,
            house_name: house_cell.name,
            level: house_cell.level,
            purchased,
        });

        // consume ActionRequest and transfer new TurnCap to next player
        game.drop_action_request(request, ctx);
    }

    public(package) fun update_toll_by_chance(self: &mut HouseCell, bps: u64) {
        let keys = self.house.tolls.keys();
        keys.do!(|key| {
            let toll = self.house.tolls.get_mut(&key);
            *toll = utils::u256_mul_div(*toll as u256, bps as u256, BASE_BPS as u256) as u64;
        });
    }

    public(package) fun level_up_by_chance(self: &mut HouseCell) {
        let max_level = (self.house.tolls.keys().length() -1) as u8;
        if (self.level < max_level) {
            self.level = self.level + 1;
        };
    }

    public(package) fun level_down_by_chance(self: &mut HouseCell) {
        if (self.level > 0) {
            self.level = self.level - 1;
        };
    }

    public(package) fun level_to_zero(self: &mut HouseCell) {
        self.level = 0;
    }

    public(package) fun new_house_plugin(): HousePlugin {
        HousePlugin {}
    }

    public(package) fun assert_if_not_in_registry(registry: &HouseRegistry, name: String) {
        assert!(registry.contains_name(name), EHouseNotRegistered);
    }

    // === Private Functions ===
    fun copy_house(self: &HouseRegistry, name: String): House {
        House {
            buy_prices: self.houses.get(&name).buy_prices,
            sell_prices: self.houses.get(&name).sell_prices,
            tolls: self.houses.get(&name).tolls,
        }
    }

    // === Test Functions ===
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
