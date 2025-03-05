module monopoly::monopoly;
use std::string::{Self, String};
use std::type_name::{Self, TypeName};

use sui::event;
use sui::transfer::Receiving;
use sui::random::{ Self, Random };
use sui::balance::{Self, Balance};
use sui::bag::{Self, Bag};
use sui::object_bag::{Self, ObjectBag};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use sui::dynamic_field as df;

use monopoly::action::Action;

// === Imports ===

// === Errors ===

// === Constants ===
const MODULE_VERSION: u64 = 1;

const ENotExistPlayer: u64 = 101;
const EActionRequestNotSettled: u64 = 102;
// === Structs ===

public struct AdminCap has key {
    id: UID,
}

public struct Game has key{
    id: UID,
    versions: VecSet<u64>,
    supported_assets: VecSet<TypeName>,
    // TODO: mapping "${address}-${assets}"
    player_assets: Bag,
    /// players' positions and the order of player's turn
    player_position: VecMap<address, u64>,
    // cell_action; to check which action should player execute
    cell_action: VecMap<u64, Action>,
    /// positions of cells in the map
    /// Mapping<u64, T>
    cells: ObjectBag,
    last_player: address,
    last_action_time: u64,
    // times of each player do the actions
    plays: u64
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
    expired_at: u64
}

public struct ActionRequest has key {
    id: UID,
    game: ID,
    player: address,
    pos_index: u64,
    action: Action,
    settled: bool
}

/// Consume the action_request and transfer TurnCap
public fun drop_action_request(
    self: &mut Game,
    action_request: ActionRequest,
    ctx: &mut TxContext
){
    let ActionRequest{
        id,
        game,
        player,
        pos_index: _,
        action: _,
        settled: _
    } = action_request;

    object::delete(id);

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
public struct PlayerMoveEvent has copy, drop{
    game: ID,
    player: address,
    moved_steps: u8,
    turn_cap_id: ID
}

// === Method Aliases ===

// === Public Functions ===
public fun supported_assets(self: &Game): VecSet<TypeName> {
    self.supported_assets
}
fun player_asset_key(asset_type: TypeName, owner: address): String{
    let mut type_str = string::from_ascii(asset_type.into_string());
    let address_str = owner.to_string();

    type_str.append_utf8(b"-");
    type_str.append(address_str);

    type_str
}
public fun player_asset<T>(self: &Game, owner: address): &Balance<T>{
    let asset_key = player_asset_key(type_name::get<T>(), owner);
    &self.player_assets[asset_key]
}
fun player_asset_mut<T>(self: &mut Game, owner: address): &mut Balance<T>{
    let asset_key = player_asset_key(type_name::get<T>(), owner);
    &mut self.player_assets[asset_key]
}
public fun player_asset_mut_with_request<T>(
    self: &mut Game,
    request: &ActionRequest,
): &mut Balance<T>{
    self.player_asset_mut(request.player)
}
fun game_fund_mut<T>(self: &mut Game): &mut Balance<T> {
    let game_address = object::id_address(self);
    let asset_key = player_asset_key(type_name::get<T>(), game_address);

    &mut self.player_assets[asset_key]
}

public fun deposit_fund<T>(
    self: &mut Game,
    fund: Balance<T>
): u64{
    self.game_fund_mut().join(fund)
}
// -- player_positions
fun position_of(self: &Game, player: address): u64 {
    self.player_position[&player]
}

fun player_move_position(
    self: &mut Game,
    player: address,
    moved_steps: u8
): u64 {
    let current_position = self.player_position[&player];
    let new_position = current_position + (moved_steps as u64);
    let last_position_index = self.num_of_cells() - 1;

    if(new_position > last_position_index){
        new_position - last_position_index - 1
    }else{
        new_position
    }
}

// -- Cells
public fun cell_action_of(self: &Game, pos_idx: u64): Action{
    self.cell_action[&pos_idx]
}
public fun borrow_cell<Cell: key + store>(self: &Game, pos_index: u64): &Cell {
    self.cells.borrow(pos_index)
}
fun borrow_cell_mut<Cell: key + store>(self: &mut Game, pos_index: u64): &mut Cell {
    self.cells.borrow_mut(pos_index)
}
public fun borrow_cell_mut_with_request<Cell: key + store>(
    self: &mut Game,
    request: &ActionRequest
): &mut Cell {
    self.borrow_cell_mut(request.pos_index)
}
public fun num_of_cells(self: &Game): u64{
    self.cells.length()
}
// -- ActionRequest
public fun action_request_info(req: &ActionRequest): (address, u64, Action) {
    (
        req.player,
        req.pos_index,
        req.action,
    )
}
public fun action_request_pos_index(req: &ActionRequest): u64{
    req.pos_index
}
public fun action_request_action(req: &ActionRequest): Action{
    req.action
}
public fun action_request_game(req: &ActionRequest): ID{
    req.game
}
public fun action_request_add_state<K: copy + drop + store, V: store>(
    req: &mut ActionRequest,
    state_key: K,
    state: V
){
    df::add(&mut req.id, state_key, state);
}
public fun action_request_remove_state<K: copy + drop + store, V: store>(
    req: &mut ActionRequest,
    state_key: K,
):V{
    df::remove(&mut req.id, state_key)
}

public fun settle_action_request(request: &mut ActionRequest){
    request.settled = true;
}

// === View Functions ===
public fun players(self: &Game): vector<address>{
    self.player_position.keys()
}
public fun num_of_players(self: &Game): u64{
    self.players().length()
}
public fun current_round(self: &Game): u64{
    self.plays / self.num_of_players()
}
public fun next_player_of(self: &Game, player: address): address{
    let players = self.players();
    let mut idx_opt = self.players().find_index!(|player_| player_ == &player);

    assert!(idx_opt.is_some(), ENotExistPlayer);
    let idx = idx_opt.extract();
    let last_index = players.length() - 1;

    if(idx == last_index) players[0] else players[idx + 1]
}

// === Admin Functions ===
fun init(ctx: &mut TxContext){
    let cap = AdminCap { id: object::new(ctx) };

    transfer::transfer(cap, ctx.sender());
}
#[test_only]
public fun init_for_testing(ctx: &mut TxContext){
    init(ctx);
}

public fun add_cell<Cell: key + store>(
    self: &mut Game,
    _cap: &AdminCap,
    pos_index: u64,
    cell: Cell,
    // TODO: should not hardcoded
    action: Action
){
    self.cells.add(pos_index, cell);
    self.cell_action.insert(pos_index, action);
}

// === Package Functions ===
public fun new(
    _cap: &AdminCap,
    players: vector<address>,
    ctx: &mut TxContext
): Game {
    new_(players, ctx)
}

entry fun player_move(
    mut turn_cap: TurnCap,
    random: &Random,
    ctx: &mut TxContext
){
    let mut generator = random::new_generator(random, ctx);
    let moved_steps = random::generate_u8_in_range(&mut generator, 1, 12);
    
    turn_cap.moved_steps = moved_steps;

    // emit the new position event
    event::emit(
        PlayerMoveEvent {
            game: turn_cap.game,
            player: turn_cap.player,
            moved_steps,
            turn_cap_id: object::id(&turn_cap),
        }
    );
    // transfer to game object
    let game_address = turn_cap.game.to_address();
    transfer::transfer(turn_cap, game_address);
}

// executed by server
public fun settle_player_move(
    self: &mut Game,
    receiving_turn_cap: Receiving<TurnCap>,
    ctx: &mut TxContext
){
    let turn_cap = transfer::receive(&mut self.id, receiving_turn_cap);
    let TurnCap{
        id,
        game,
        player,
        moved_steps,
        // TODO: check expired time window
        expired_at
    } = turn_cap;
    object::delete(id);

    let player_new_pos = self.player_move_position(player, moved_steps);

    let action_request = ActionRequest {
        id: object::new(ctx),
        game,
        player,
        pos_index: player_new_pos,
        action: self.cell_action_of(player_new_pos),
        settled: false,
    };

    transfer::transfer(action_request, player);
}

public fun finish_action(
    request: ActionRequest
){
    assert!(request.settled, EActionRequestNotSettled);

    let game_address = request.game.to_address();
    transfer::transfer(request, game_address);
}

public fun receive_action_request(
    self: &mut Game,
    received_request: Receiving<ActionRequest>,
):ActionRequest{
    transfer::receive(&mut self.id, received_request)
}

// === Private Functions ===
fun new_(
    players: vector<address>,
    ctx: &mut TxContext
): Game {
    let num_of_players = players.length();

    let mut values = vector<u64>[];
    let last_player = players[num_of_players - 1];
    std::u64::do!<()>(num_of_players, |_|values.push_back(0));
    
    Game{
        id: object::new(ctx),
        versions: vec_set::singleton(MODULE_VERSION),
        supported_assets: vec_set::empty(),
        player_assets: bag::new(ctx),
        cell_action: vec_map::empty(),
        player_position: vec_map::from_keys_values(players, values),
        cells: object_bag::new(ctx),
        last_player,
        last_action_time: 0,
        plays: 0,
    }
}

public fun settle_game_creation(
    game: Game,
    _cap: &AdminCap,
    recipient: address
){
    transfer::transfer(game, recipient);
}


fun drop(self: Game){
    let Game{
        id,
        versions: _,
        supported_assets: _,
        player_assets,
        cell_action: _,
        cells,
        player_position: _,
        last_player: _,
        last_action_time: _,
        plays: _
    } = self;

    player_assets.destroy_empty();
    cells.destroy_empty();

    object::delete(id);
}

fun roll_game(self: &mut Game){
    self.plays = self.plays + 1;
}

// === Test Functions ===


#[test]
fun test_basic_game(){
    let mut ctx = tx_context::dummy();
    let player_a = @0xA;
    let player_b = @0xB;
    let player_c = @0xC;

    let mut game = new_(vector[player_a, player_b, player_c], &mut ctx);

    std::u64::do!<()>(5, |_| game.roll_game());

    assert!(game.current_round() == 1);

    game.drop();
}

