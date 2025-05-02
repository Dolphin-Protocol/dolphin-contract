module monopoly::monopoly {
    use monopoly::{
        balance::{Self, Balance, Supply},
        balance_manager::{Self, BalanceManager},
        event::emit_action_request
    };
    use std::type_name::{Self, TypeName};
    use sui::{
        dynamic_field as df,
        event,
        object_bag::{Self, ObjectBag},
        random::{Self, Random},
        transfer::Receiving,
        vec_map::{Self, VecMap},
        vec_set::{Self, VecSet}
    };

    // === Errors ===

    // === Constants ===
    const MODULE_VERSION: u64 = 1;

    const EInvalidGameSetup: u64 = 100;
    const ENotExistPlayer: u64 = 101;
    const EActionRequestNotSettled: u64 = 102;
    const EActionRequestAlreadySettled: u64 = 103;
    const EInvalidNumOfCells: u64 = 104;
    const ENotPlayer: u64 = 107;
    const EStepsMightExceedOneCircuit: u64 = 108;
    const EActionRequestParametersdNotConfig: u64 = 109;
    const EActionRequestAlreadyConfig: u64 = 110;
    const EGameStillOngoing: u64 = 111;
    const EPluginAlreadyExisted: u64 = 112;
    const EPluginExists: u64 = 113;

    // === Structs ===

    // Balance Type
    public struct Monopoly has drop {}

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct Game has key {
        id: UID,
        versions: VecSet<u64>,
        plugins: VecSet<TypeName>,
        max_round: u64,
        max_steps: u8,
        salary: u64,
        // asset type records
        assets: VecSet<TypeName>,
        balance_manager: BalanceManager<Monopoly>,
        /// players' positions and the order of player's turn
        player_position: VecMap<address, u64>,
        /// positions of cells in the map
        /// Mapping<u64, T>
        cells: ObjectBag,
        // times of each player do the actions
        plays: u64,
        // skip player's turn when he is in jail
        skips: VecMap<address, u8>,
    }

    public struct CellAccess has key, store {
        id: UID,
    }

    public struct TurnCap has key {
        id: UID,
        game: ID,
        player: address,
        moved_steps: u8,
        max_steps: u8,
        ///f valid time window to allow user do the action
        /// TODO
        expired_at: u64,
    }

    public struct ActionRequest<P: copy + drop + store> has key {
        id: UID,
        // TODO: assert gameId
        game: ID,
        player: address,
        pos_index: u64,
        parameters: Option<P>,
        settled: bool,
    }

    public struct StateKey<phantom Plugin: drop> has copy, drop, store {}

    // === Events ===
    public struct GameCreatedEvent has copy, drop {
        game: ID,
        players: vector<address>,
    }

    public struct RollDiceEvent has copy, drop {
        game: ID,
        player: address,
        dice_num: u8,
        turn_cap_id: ID,
    }

    public struct GameClosedEvent has copy, drop {
        game: ID,
        winners: vector<address>,
    }

    public struct ChangeTurnEvent has copy, drop {
        game: ID,
        player: address,
        turn_cap: ID,
    }

    // === Method Aliases ===
    // cell
    public use fun monopoly::cell::initialize_do_nothing_params as
        ActionRequest.initialize_do_nothing_params;
    // house_cell
    public use fun monopoly::house_cell::initialize_buy_params as
        ActionRequest.initialize_buy_params;
    public use fun monopoly::house_cell::execute_buy as ActionRequest.execute_buy_action;
    // chance cell
    public use fun monopoly::chance_cell::initialize_balance_chance as
        ActionRequest.initialize_balance_chance;
    public use fun monopoly::chance_cell::initialize_toll_chance as
        ActionRequest.initialize_toll_chance;
    public use fun monopoly::chance_cell::initialize_house_chance as
        ActionRequest.initialize_house_chance;
    public use fun monopoly::chance_cell::initialize_jail_chance as
        ActionRequest.initialize_jail_chance;

    // === View Functions ===
    public fun max_round(self: &Game): u64 {
        self.max_round
    }

    public fun max_steps(self: &Game): u8 {
        self.max_steps
    }

    public fun balance(self: &Game): &BalanceManager<Monopoly> {
        &self.balance_manager
    }

    public fun player_balance(self: &Game, player: address): &Balance<Monopoly> {
        self.balance_manager.balance_of(player)
    }

    public fun players(self: &Game): vector<address> {
        self.player_position.keys()
    }

    public fun num_of_players(self: &Game): u64 {
        self.players().length()
    }

    public fun player_position(self: &Game): &VecMap<address, u64> {
        &self.player_position
    }

    public fun player_position_of(self: &Game, player: address): u64 {
        self.player_position()[&player]
    }

    public fun cell_contains_with_type<Cell: key + store>(self: &Game, pos_index: u64): bool {
        self.cells.contains_with_type<u64, Cell>(pos_index)
    }

    public fun borrow_cell<Cell: key + store>(self: &Game, pos_index: u64): &Cell {
        self.cells.borrow(pos_index)
    }

    public fun borrow_cell_with_request<Cell: key + store, P: copy + drop + store>(
        self: &Game,
        request: &ActionRequest<P>,
    ): &Cell {
        self.borrow_cell(request.pos_index)
    }

    public fun borrow_state<Plugin: drop, State: store>(self: &Game, _: Plugin): &State {
        df::borrow(&self.id, StateKey<Plugin> {})
    }

    public fun num_of_cells(self: &Game): u64 {
        self.cells.length()
    }

    public fun plays(self: &Game): u64 { self.plays }

    public fun action_request_info<P: copy + drop + store>(
        req: &ActionRequest<P>,
    ): (ID, address, u64) {
        (req.game, req.player, req.pos_index)
    }

    public fun action_request_game<P: drop + copy + store>(req: &ActionRequest<P>): ID {
        req.game
    }

    public fun action_request_player<P: drop + copy + store>(req: &ActionRequest<P>): address {
        req.player
    }

    public fun action_request_pos_index<P: drop + copy + store>(req: &ActionRequest<P>): u64 {
        req.pos_index
    }

    public fun action_request_parameters<P: drop + copy + store>(
        req: &ActionRequest<P>,
    ): &Option<P> {
        &req.parameters
    }

    public fun action_request_settled<P: drop + copy + store>(req: &ActionRequest<P>): bool {
        req.settled
    }

    public fun turn_cap_game(turn_cap: &TurnCap): ID {
        turn_cap.game
    }

    public fun turn_cap_player(turn_cap: &TurnCap): address {
        turn_cap.player
    }

    public fun turn_cap_moved_steps(turn_cap: &TurnCap): u8 {
        turn_cap.moved_steps
    }

    // zero-based; first round will be 0
    public fun current_round(self: &Game): u64 {
        self.plays / self.num_of_players()
    }

    public fun next_player_of(self: &Game, player: address): address {
        let players = self.players();
        let mut idx_opt = self.players().find_index!(|player_| player_ == &player);

        assert!(idx_opt.is_some(), ENotExistPlayer);
        let idx = idx_opt.extract();
        let last_index = players.length() - 1;

        if (idx == last_index) players[0] else players[idx + 1]
    }

    public fun is_gaming_ongoing(self: &Game): bool {
        self.current_round() < self.max_round
    }

    public fun skips(self: &Game): &VecMap<address, u8> {
        &self.skips
    }

    public fun is_plugin_exists<Plugin: drop>(self: &Game): bool {
        self.plugins.contains(&type_name::get<Plugin>())
    }

    public fun winner(results: VecMap<address, u64>): vector<address> {
        let size = results.size();
        // Return empty vector if the map is empty
        if (size == 0) {
            return vector::empty<address>()
        };

        // Initialize max value to minimum possible u64 value
        let mut max_value = 0u64;
        let mut winners = vector::empty<address>();

        size.do!<()>(|i| {
            let (addr, value) = vec_map::get_entry_by_idx(&results, i);

            if (*value > max_value) {
                // Found a new maximum, clear previous winners and add this one
                max_value = *value;
                winners = vector::singleton<address>(*addr);
            } else if (value == max_value) {
                // Found another address with the same maximum value
                vector::push_back(&mut winners, *addr);
            };
        });

        winners
    }

    // === Mutable Functions ===

    public fun balance_mut(self: &mut Game): &mut BalanceManager<Monopoly> {
        &mut self.balance_manager
    }

    fun player_balance_mut(self: &mut Game, player: address): &mut Balance<Monopoly> {
        self.balance_mut().balance_of_mut(player)
    }

    public fun player_balance_mut_with_request<P: copy + drop + store>(
        self: &mut Game,
        request: &ActionRequest<P>,
    ): &mut Balance<Monopoly> {
        self.player_balance_mut(request.player)
    }

    fun update_player_position(self: &mut Game, player: address, new_pos_idx: u64) {
        *&mut self.player_position[&player] = new_pos_idx;
    }

    public fun borrow_cell_mut_with_request<Cell: key + store, P: copy + drop + store>(
        self: &mut Game,
        _request: &ActionRequest<P>,
        pos_index: u64,
    ): &mut Cell {
        self.borrow_cell_mut(pos_index)
    }

    fun borrow_cell_mut<Cell: key + store>(self: &mut Game, pos_index: u64): &mut Cell {
        self.cells.borrow_mut(pos_index)
    }

    public fun action_request_parameters_mut<P: drop + copy + store>(
        req: &mut ActionRequest<P>,
    ): &mut Option<P> {
        &mut req.parameters
    }

    public fun action_request_remove_parameters<P: drop + copy + store>(
        req: &mut ActionRequest<P>,
        _self: &Game,
    ): P {
        req.parameters.extract()
    }

    public fun action_request_add_state<P: copy + drop + store, K: copy + drop + store, V: store>(
        req: &mut ActionRequest<P>,
        state_key: K,
        state: V,
    ) {
        df::add(&mut req.id, state_key, state);
    }

    public fun borrow_state_mut<Plugin: drop, State: store>(
        self: &mut Game,
        _: Plugin,
    ): &mut State {
        df::borrow_mut(&mut self.id, StateKey<Plugin> {})
    }

    public fun go_to_jail(self: &mut Game, player: address, round: u8) {
        self.add_to_skips(player, round);
        let jail_index = self.cells.length() / 4;
        *self.player_position.get_mut(&player) = jail_index;
    }

    public fun action_request_remove_state<
        P: drop + copy + store,
        K: copy + drop + store,
        V: store,
    >(
        req: &mut ActionRequest<P>,
        state_key: K,
    ): V {
        df::remove(&mut req.id, state_key)
    }

    /// This function should be called at the end of each action
    public fun settle_action_request<P: drop + copy + store>(request: &mut ActionRequest<P>) {
        assert!(!request.settled, EActionRequestAlreadySettled);
        request.settled = true;
    }

    public fun add_to_skips(self: &mut Game, player: address, round: u8) {
        self.skips.insert(player, round);
    }

    // === Init Function ===
    fun init(ctx: &mut TxContext) {
        let cap = AdminCap { id: object::new(ctx) };

        transfer::transfer(cap, ctx.sender());
    }
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    // === Admin Functions ===

    /// create game instance
    /// steps to start each game round
    /// 1) determined the players and their order then acquire game instance
    /// 2) config supported assets by calling 'add_balance' with game object
    /// 3) add cell and corresponding action
    /// 4) call 'settle_game_creation' when all the configs are setup, then transfer game object to admin and TurnCap to first player
    public fun new(
        _cap: &AdminCap,
        players: vector<address>,
        max_round: u64,
        max_steps: u8,
        salary: u64,
        initial_funds: u64,
        ctx: &mut TxContext,
    ): Game {
        let supply = balance::create_supply(Monopoly {});
        new_(players, max_round, max_steps, salary, initial_funds, supply, ctx)
    }

    public fun new_supply(_cap: &AdminCap): Supply<Monopoly> {
        balance::create_supply(Monopoly {})
    }

    public fun settle_game_creation(
        self: Game,
        _cap: &AdminCap,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        assert!(self.max_steps != 0 && self.num_of_cells() != 0, EInvalidGameSetup);
        assert!((self.max_steps as u64) < self.num_of_cells(), EStepsMightExceedOneCircuit);
        assert!(!self.cells.is_empty() && self.cells.length() % 4 == 0, EInvalidNumOfCells);

        let player = self.players()[0];
        // transfer TurnCap to first player
        let turn_cap = TurnCap {
            id: object::new(ctx),
            game: object::id(&self),
            player,
            moved_steps: 0,
            max_steps: self.max_steps,
            expired_at: 0,
        };

        let game = object::id(&self);
        event::emit(ChangeTurnEvent {
            game,
            player,
            turn_cap: object::id(&turn_cap),
        });

        event::emit(GameCreatedEvent { game, players: self.players() });
        transfer::transfer(turn_cap, player);
        transfer::transfer(self, recipient);
    }

    public fun add_cell<CellType: key + store>(
        self: &mut Game,
        _cap: &AdminCap,
        pos_index: u64,
        cell: CellType,
    ) {
        self.cells.add(pos_index, cell);
    }

    public fun remove_cell<CellType: key + store>(self: &mut Game, pos_index: u64): CellType {
        assert!(!self.is_gaming_ongoing(), EGameStillOngoing);
        self.cells.remove(pos_index)
    }

    public fun add_and_init_plugin<Plugin: drop, V: store>(
        self: &mut Game,
        _: &AdminCap,
        _plugin: Plugin,
        value: V,
    ) {
        assert!(!self.plugins.contains(&type_name::get<Plugin>()), EPluginAlreadyExisted);

        self.plugins.insert(type_name::get<Plugin>());
        df::add(&mut self.id, StateKey<Plugin> {}, value);
    }

    public fun remove_plugin<Plugin: drop, V: store>(self: &mut Game, _plugin: Plugin): V {
        assert!(!self.is_gaming_ongoing(), EGameStillOngoing);

        self.plugins.remove(&type_name::get<Plugin>());
        df::remove(&mut self.id, StateKey<Plugin> {})
    }

    // === Public Functions ===

    /// transfer TurnCap to game instance to determine the random number
    entry fun player_move(mut turn_cap: TurnCap, random: &Random, ctx: &mut TxContext): u8 {
        let mut generator = random::new_generator(random, ctx);
        let dice_num = random::generate_u8_in_range(&mut generator, 1, turn_cap.max_steps);

        turn_cap.moved_steps = dice_num;

        // emit the new position event
        event::emit(RollDiceEvent {
            game: turn_cap.game,
            player: turn_cap.player,
            dice_num,
            turn_cap_id: object::id(&turn_cap),
        });
        // transfer to game object
        let game_address = turn_cap.game.to_address();
        transfer::transfer(turn_cap, game_address);

        dice_num
    }

    #[test_only]
    entry fun player_move_for_testing(mut turn_cap: TurnCap, moved_steps: u8): u8 {
        turn_cap.moved_steps = moved_steps;

        // transfer to game object
        let game_address = turn_cap.game.to_address();
        transfer::transfer(turn_cap, game_address);

        moved_steps
    }

    // TODO: rename to execute, request should be used when sender is player
    // should called by external module to config the required parameters
    public fun request_player_move<P: drop + copy + store>(
        self: &mut Game,
        receiving_turn_cap: Receiving<TurnCap>,
        ctx: &mut TxContext,
    ): ActionRequest<P> {
        let turn_cap = transfer::receive(&mut self.id, receiving_turn_cap);

        request_player_move_<P>(self, turn_cap, ctx)
    }

    // since testing doesn't allow acquire Receiving object, we create additional interface for testing
    #[test_only]
    public fun request_player_move_for_testing<P: copy + drop + store>(
        self: &mut Game,
        turn_cap: TurnCap,
        ctx: &mut TxContext,
    ): ActionRequest<P> {
        request_player_move_<P>(self, turn_cap, ctx)
    }

    // TODO: how can we handle multiple assets?
    fun request_player_move_<P: copy + drop + store>(
        self: &mut Game,
        turn_cap: TurnCap,
        ctx: &mut TxContext,
    ): ActionRequest<P> {
        let TurnCap {
            id,
            game,
            player,
            moved_steps,
            max_steps: _,
            // TODO: check expired time window
            expired_at: _,
        } = turn_cap;
        object::delete(id);

        let prev_pos_idx = self.player_position_of(player);

        let player_new_pos = self.player_move_position(player, moved_steps);
        self.update_player_position(player, player_new_pos);

        // salary rewards
        if (
            prev_pos_idx != 0
            && player_new_pos != 0
            && player_new_pos < prev_pos_idx
        ) {
            let salary = self.salary;
            self.balance_mut().add_balance(player, salary);
        };

        ActionRequest {
            id: object::new(ctx),
            game,
            player,
            pos_index: player_new_pos,
            parameters: option::none(),
            settled: false,
        }
    }

    public fun config_parameter<P: copy + drop + store>(
        _self: &Game,
        action_request: &mut ActionRequest<P>,
        parameters: P,
    ) {
        assert!(action_request.parameters.is_none(), EActionRequestAlreadyConfig);
        assert!(!action_request.settled, EActionRequestAlreadySettled);

        action_request.parameters.fill(parameters);
    }

    // transfer configed ActionRequest to current_player to allow the POST method
    public fun request_player_action<P: copy + drop + store>(
        _self: &Game,
        action_request: ActionRequest<P>,
    ) {
        assert!(!action_request.settled, EActionRequestAlreadySettled);
        assert!(action_request.parameters.is_some(), EActionRequestParametersdNotConfig);

        let (game, player, new_pos_idx) = action_request.action_request_info();

        // emit the event with request body
        emit_action_request<P>(game, player, new_pos_idx, *action_request.parameters.borrow());

        transfer::transfer(action_request, player);
    }

    public fun finish_action_by_player<P: copy + drop + store>(
        request: ActionRequest<P>,
        ctx: &TxContext,
    ) {
        assert!(request.player == ctx.sender(), ENotPlayer);
        assert!(request.settled, EActionRequestNotSettled);

        let game_address = request.game.to_address();
        transfer::transfer(request, game_address);
    }

    public fun receive_action_request<P: copy + drop + store>(
        self: &mut Game,
        received_request: Receiving<ActionRequest<P>>,
    ): ActionRequest<P> {
        transfer::receive(&mut self.id, received_request)
    }

    /// Consume the completed action_request and transfer TurnCap
    public fun drop_action_request<P: copy + drop + store>(
        self: &mut Game,
        action_request: ActionRequest<P>,
        ctx: &mut TxContext,
    ) {
        assert!(action_request.settled, EActionRequestNotSettled);

        let ActionRequest {
            id,
            game,
            player,
            pos_index: _,
            settled: _,
            parameters: _,
        } = action_request;

        object::delete(id);
        // increase plays count by 1
        self.roll_game();

        let next_player = self.next_player_of(player);

        // check if next_player is in skip list
        if (self.skips.contains(&next_player)) {
            // skips should always larger than 1
            *&mut self.skips[&next_player] = self.skips[&next_player] - 1;
            self.roll_game();

            if (self.skips[&next_player] == 0) {
                self.skips.remove(&next_player);
            };
        };

        if (self.is_gaming_ongoing()) {
            // next rounds
            let turn_cap = TurnCap {
                id: object::new(ctx),
                game,
                player: next_player,
                moved_steps: 0,
                max_steps: self.max_steps,
                expired_at: 0,
            };

            event::emit(ChangeTurnEvent {
                game,
                player: next_player,
                turn_cap: object::id(&turn_cap),
            });

            transfer::transfer(turn_cap, next_player);
        };
    }

    // === Private Functions ===\
    fun new_(
        players: vector<address>,
        max_round: u64,
        max_steps: u8,
        salary: u64,
        initial_funds: u64,
        supply: Supply<Monopoly>,
        ctx: &mut TxContext,
    ): Game {
        let num_of_players = players.length();

        let mut values = vector<u64>[];
        std::u64::do!<()>(num_of_players, |_| values.push_back(0));

        let mut balance_manager = balance_manager::new<Monopoly>(supply, ctx);
        players.do!(|player| {
            balance_manager.add_balance(player, initial_funds);
        });

        Game {
            id: object::new(ctx),
            versions: vec_set::singleton(MODULE_VERSION),
            plugins: vec_set::empty(),
            balance_manager,
            max_round,
            max_steps,
            salary,
            assets: vec_set::empty(),
            player_position: vec_map::from_keys_values(players, values),
            cells: object_bag::new(ctx),
            plays: 0,
            skips: vec_map::empty(),
        }
    }

    // TODO: should return object wrapping game result to handle rewards distributions & game record
    public fun drop(self: Game): vector<address> {
        let Game {
            id,
            versions: _,
            plugins,
            max_round: _,
            max_steps: _,
            salary: _,
            assets: _,
            balance_manager,
            cells,
            player_position: _,
            plays: _,
            skips: _,
        } = self;

        assert!(plugins.is_empty(), EPluginExists);

        let (supply, results) = balance_manager.drop();
        supply.destroy_supply();
        cells.destroy_empty();

        let game_id = id.to_inner();
        object::delete(id);

        let winners = winner(results);

        event::emit(GameClosedEvent { game: game_id, winners });

        winners
    }

    fun roll_game(self: &mut Game) {
        self.plays = self.plays + 1;
    }

    fun player_move_position(self: &Game, player: address, moved_steps: u8): u64 {
        let current_position = self.player_position[&player];
        let new_position = current_position + (moved_steps as u64);
        let last_position_index = self.num_of_cells() - 1;

        if (new_position > last_position_index) {
            new_position - last_position_index - 1
        } else {
            new_position
        }
    }

    // === Test Functions ===

    #[test]
    fun test_roll_game() {
        let mut ctx = tx_context::dummy();
        let player_a = @0xA;
        let player_b = @0xB;
        let player_c = @0xC;

        let mut game = new_(
            vector[player_a, player_b, player_c],
            12,
            12,
            100,
            2000,
            balance::create_supply(Monopoly {}),
            &mut ctx,
        );

        std::u64::do!<()>(5, |_| game.roll_game());

        assert!(game.current_round() == 1);

        game.drop();
    }
}
