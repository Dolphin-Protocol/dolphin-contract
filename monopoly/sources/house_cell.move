module monopoly::house_cell {
    use monopoly::{monopoly::{Game, ActionRequest, AdminCap}, utils};
    use std::{string::String, type_name::{Self, TypeName}};
    use sui::{event, transfer::Receiving, vec_map::{Self, VecMap}, vec_set::{Self, VecSet}};

    // === Errors ===

    const EUnMatchedCoinType: u64 = 101;
    const ENoParameterBody: u64 = 103;
    const EPlayerNotHouseOwner: u64 = 104;

    // === Constants ===

    const VERSION: u64 = 1;

    // === Structs ===

    public struct HouseRegistry has key {
        id: UID,
        versions: VecSet<u64>,
        // house object with its name
        houses: VecMap<String, House>,
    }

    public struct House has copy, store {
        // TODO: maybe walrus img_url stored in url?
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
    public struct BuyArgument<phantom T> has copy, drop, store {
        type_name: TypeName,
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

    // === View Functions ===
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

    public fun buy_argument_info<T>(buy_argument: &BuyArgument<T>): (TypeName, u64, u64, u8, bool) {
        (
            buy_argument.type_name,
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

    public fun buy_argument_type_name<T>(buy_argument: &BuyArgument<T>): TypeName {
        buy_argument.type_name
    }

    public fun buy_argument_player_balance<T>(buy_argument: &BuyArgument<T>): u64 {
        buy_argument.player_balance
    }

    public fun buy_argument_house_price<T>(buy_argument: &BuyArgument<T>): u64 {
        buy_argument.house_price
    }

    public fun buy_argument_amount<T>(buy_argument: &BuyArgument<T>): bool {
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

    // === Admin Functions ===

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
    public fun initialize_buy_params<T>(
        action_request: &mut ActionRequest<BuyArgument<T>>,
        game: &mut Game,
    ) {
        // Retrieve related objects and values in a single block
        let house_cell: &HouseCell = game.borrow_cell_with_request(action_request);
        let (owner, level, house_name, mut house_price, _, poll) = house_cell.house_cell_info();

        // Verify balance type and get player info
        assert!(game.balance_type_contains<T>(), EUnMatchedCoinType);
        let player = action_request.action_request_player();
        let player_balance = game.player_balance<T>(player).value();

        // Create parameters object
        let mut parameters = BuyArgument<T> {
            type_name: type_name::get<T>(),
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
                    .balance_mut<T>()
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

    // user execute buy or upgrade the house
    public fun execute_buy<T>(
        mut request: ActionRequest<BuyArgument<T>>,
        purchased: bool,
        ctx: &TxContext,
    ) {
        // validate balance
        let type_name = type_name::get<T>();

        assert!(request.action_request_parameters().is_some(), ENoParameterBody);

        let parameters = request.action_request_parameters_mut().borrow_mut();

        assert!(parameters.type_name == type_name, EUnMatchedCoinType);

        // fill the required parameters
        parameters.purchased = purchased;

        // mark settled in action_request to promise the action is ready to be sent
        request.settle_action_request();

        // transfer action to game object
        request.finish_action_by_player(ctx);
    }

    /// executed by server to settle the game state
    public fun settle_buy<T>(
        received_request: Receiving<ActionRequest<BuyArgument<T>>>,
        game: &mut Game,
        ctx: &mut TxContext,
    ) {
        let request = game.receive_action_request(received_request);
        settle_buy_(request, game, ctx);
    }

    // test_only as we can't acquire Receiving object in test
    #[test_only]
    public fun settle_buy_for_testing<T>(
        request: ActionRequest<BuyArgument<T>>,
        game: &mut Game,
        ctx: &mut TxContext,
    ) {
        settle_buy_(request, game, ctx);
    }

    fun settle_buy_<T>(
        mut request: ActionRequest<BuyArgument<T>>,
        game: &mut Game,
        ctx: &mut TxContext,
    ) {
        let player = request.action_request_player();

        let BuyArgument<T> {
            type_name,
            player_balance: _,
            house_price,
            level,
            eligible,
            purchased,
        } = request.action_request_remove_parameters(game);

        assert!(type_name::get<T>() == type_name, EUnMatchedCoinType);

        // validate price
        if (purchased && eligible) {
            // update player's balance
            let balance_manager = game.balance_mut<T>();
            balance_manager.sub_balance(
                request.action_request_player(),
                house_price,
            );

            // update house owner & state
            let house_cell: &mut HouseCell = game.borrow_cell_mut_with_request(&request);
            house_cell.level = std::u8::min(level + 1, house_cell.max_level());

            if (house_cell.owner.is_none()) {
                house_cell.owner.fill(player);
            } else {
                // this shuoldn't happen
                assert!(house_cell.owner.borrow() == player, EPlayerNotHouseOwner);
            };
        };

        let (game_id, player, pos_index) = request.action_request_info();
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
