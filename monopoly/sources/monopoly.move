module monopoly::monopoly {
    use monopoly::{balance_manager::{Self, BalanceManager}, event::emit_action_request};
    use std::type_name::{Self, TypeName};
    use sui::{
        bag::{Self, Bag},
        balance::{Balance, Supply},
        clock::Clock,
        dynamic_field as df,
        event,
        object_bag::{Self, ObjectBag},
        random::{Self, Random},
        transfer::Receiving,
        vec_map::{Self, VecMap},
        vec_set::{Self, VecSet}
    };

    // === Imports ===

    // === Errors ===

    // === Constants ===
    const MODULE_VERSION: u64 = 1;

    const ENotExistPlayer: u64 = 101;
    const EActionRequestNotSettled: u64 = 102;
    const EActionRequestAlreadySettled: u64 = 103;
    const EGameShouldSupportAtLeastOneBalance: u64 = 104;
    const EPlayerNotSetup: u64 = 105;
    const EBalanceAlreadySetup: u64 = 106;
    const EActionRequestParametersdNotConfig: u64 = 109;
    const EActionRequestAlreadyConfig: u64 = 110;

    // === Structs ===

    public struct AdminCap has key {
        id: UID,
    }

    public struct Game has key {
        id: UID,
        versions: VecSet<u64>,
        // asset type records
        assets: VecSet<TypeName>,
        balances: Bag,
        /// players' positions and the order of player's turn
        player_position: VecMap<address, u64>,
        /// positions of cells in the map
        /// Mapping<u64, T>
        cells: ObjectBag,
        current_player: address,
        last_action_time: u64,
        // times of each player do the actions
        plays: u64,
    }

    public struct CellAccess has key, store {
        id: UID,
    }

    public struct TurnCap has key {
        id: UID,
        game: ID,
        player: address,
        moved_steps: u8,
        ///f valid time window to allow user do the action
        /// TODO
        expired_at: u64,
    }

    public struct ActionRequest<P: copy + drop + store> has key {
        id: UID,
        game: ID,
        player: address,
        pos_index: u64,
        parameters: Option<P>,
        settled: bool,
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

        // TODO: (By Paul): Check if the game has finished.
        // TODO: (By Jarek): Check if the player is eligible for next round; otherwise skip

        let next_player = self.next_player_of(player);

        let turn_cap = TurnCap {
            id: object::new(ctx),
            game,
            player: next_player,
            moved_steps: 0,
            expired_at: 0,
        };

        transfer::transfer(turn_cap, next_player);
    }

    // === Events ===
    public struct PlayerMoveEvent has copy, drop {
        game: ID,
        player: address,
        moved_steps: u8,
        turn_cap_id: ID,
    }

    public struct ActionRequestEvent has copy, drop {
        game: ID,
        player: address,
        new_pos_idx: u64,
    }

    // === Method Aliases ===
    public use fun monopoly::house_cell::initialize_buy_params as
        ActionRequest.initialize_buy_params;
    public use fun monopoly::house_cell::execute_buy as ActionRequest.execute_buy_action;

    // === View Functions ===
    public fun balance<T>(self: &Game): &BalanceManager<T> {
        &self.balances[type_name::get<T>()]
    }

    public fun balance_type_contains<T>(self: &Game): bool {
        self.balances.contains(type_name::get<T>())
    }

    public fun player_balance<T>(self: &Game, player: address): &Balance<T> {
        self.balance().balance_of(player)
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

    public fun player_position_of(self: &Game, player: address):u64{
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

    public fun num_of_cells(self: &Game): u64 {
        self.cells.length()
    }

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

    // === Mutable Functions ===

    public fun balance_mut<T>(self: &mut Game): &mut BalanceManager<T> {
        &mut self.balances[type_name::get<T>()]
    }

    fun player_balance_mut<T>(self: &mut Game, player: address): &mut Balance<T> {
        self.balance_mut().balance_of_mut(player)
    }

    public fun player_balance_mut_with_request<T, P: copy + drop + store>(
        self: &mut Game,
        request: &ActionRequest<P>,
    ): &mut Balance<T> {
        self.player_balance_mut(request.player)
    }

    fun update_player_position(self: &mut Game, mut player: address, new_pos_idx: u64){
        *&mut self.player_position[&mut player] = new_pos_idx;
    }

    fun borrow_cell_mut<Cell: key + store>(self: &mut Game, pos_index: u64): &mut Cell {
        self.cells.borrow_mut(pos_index)
    }

    public fun borrow_cell_mut_with_request<Cell: key + store, P: copy + drop + store>(
        self: &mut Game,
        request: &ActionRequest<P>,
    ): &mut Cell {
        self.borrow_cell_mut(request.pos_index)
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
    public fun new(_cap: &AdminCap, players: vector<address>, ctx: &mut TxContext): Game {
        new_(players, ctx)
    }

    public fun settle_game_creation(
        mut self: Game,
        _cap: &AdminCap,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // validate balances setup
        assert!(!self.balances.is_empty(), EGameShouldSupportAtLeastOneBalance);

        // transfer TurnCap to first player
        let player = self.current_player;
        let turn_cap = TurnCap {
            id: object::new(ctx),
            game: object::id(&self),
            player,
            moved_steps: 0,
            expired_at: 0,
        };
        transfer::transfer(turn_cap, player);

        self.last_action_time = clock.timestamp_ms();

        transfer::transfer(self, recipient);
    }

    /// add BalanceManager to balances and topup all the player's balances
    public fun setup_balance<T>(
        self: &mut Game,
        _cap: &AdminCap,
        supply: Supply<T>,
        initial_funds: u64,
        ctx: &mut TxContext,
    ) {
        assert!(!self.player_position.is_empty(), EPlayerNotSetup);
        assert!(!self.balances.contains(type_name::get<T>()), EBalanceAlreadySetup);

        self.balances.add(type_name::get<T>(), balance_manager::new(supply, ctx));

        self.player_position.keys().do!(|player| {
            self.balance_mut<T>().add_balance(player, initial_funds);
        });
    }

    public fun add_cell<CellType: key + store>(
        self: &mut Game,
        _cap: &AdminCap,
        pos_index: u64,
        cell: CellType,
    ) {
        self.cells.add(pos_index, cell);
    }

    // === Package Functions ===

    /// transfer TurnCap to game instance to determine the random number
    entry fun player_move(mut turn_cap: TurnCap, random: &Random, ctx: &mut TxContext): u8 {
        let mut generator = random::new_generator(random, ctx);
        let moved_steps = random::generate_u8_in_range(&mut generator, 1, 12);

        turn_cap.moved_steps = moved_steps;

        // emit the new position event
        event::emit(PlayerMoveEvent {
            game: turn_cap.game,
            player: turn_cap.player,
            moved_steps,
            turn_cap_id: object::id(&turn_cap),
        });
        // transfer to game object
        let game_address = turn_cap.game.to_address();
        transfer::transfer(turn_cap, game_address);

        moved_steps
    }

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
            // TODO: check expired time window
            expired_at: _,
        } = turn_cap;
        object::delete(id);

        let player_new_pos = self.player_move_position(player, moved_steps);
        self.update_player_position(player, player_new_pos);

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

    public fun finish_action_by_player<P: copy + drop + store>(request: ActionRequest<P>) {
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

    // === Private Functions ===\
    fun new_(players: vector<address>, ctx: &mut TxContext): Game {
        let num_of_players = players.length();

        let mut values = vector<u64>[];
        let current_player = players[0];
        std::u64::do!<()>(num_of_players, |_| values.push_back(0));

        Game {
            id: object::new(ctx),
            versions: vec_set::singleton(MODULE_VERSION),
            assets: vec_set::empty(),
            balances: bag::new(ctx),
            player_position: vec_map::from_keys_values(players, values),
            cells: object_bag::new(ctx),
            current_player,
            last_action_time: 0,
            plays: 0,
        }
    }

    fun drop(self: Game) {
        let Game {
            id,
            versions: _,
            assets: _,
            balances,
            cells,
            player_position: _,
            current_player: _,
            last_action_time: _,
            plays: _,
        } = self;

        balances.destroy_empty();
        cells.destroy_empty();

        object::delete(id);
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

        let mut game = new_(vector[player_a, player_b, player_c], &mut ctx);

        std::u64::do!<()>(5, |_| game.roll_game());

        assert!(game.current_round() == 1);

        game.drop();
    }
}
