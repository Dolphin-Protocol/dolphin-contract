module monopoly::monopoly;
use std::string::{Self, String};
use std::type_name::{Self, TypeName};

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
// === Structs ===

public struct AdminCap has key {
    id: UID,
}

public struct Game has key, store {
    id: UID,
    versions: VecSet<u64>,
    supported_assets: VecSet<TypeName>,
    // TODO: mapping "${address}-${assets}"
    player_assets: Bag,
    /// players' positions and the order of player's turn
    player_position: VecMap<address, u64>,
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
    ///f valid time window to allow user do the action
    expired_at: u64
}

public struct ActionRequest has key {
    id: UID,
    pos_index: u64,
    action: Action,
    settled: bool
}

// TODO: test
public fun drop_action_request(action_request: ActionRequest){
    let ActionRequest{
        id,
        pos_index: _,
        action: _,
        settled: _
    } = action_request;

    object::delete(id);
}

// === Events ===

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
// -- Cells
fun borrow_cell<Cell: key + store>(self: &Game, pos_index: u64): &Cell {
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
// -- ActionRequest
public fun action_request_pos_index(req: &ActionRequest): u64{
    req.pos_index
}
public fun action_request_action(req: &ActionRequest): Action{
    req.action
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

// === Admin Functions ===
fun init(ctx: &mut TxContext){
    let cap = AdminCap { id: object::new(ctx) };

    transfer::transfer(cap, ctx.sender());
}

entry fun add_cell<Cell: key + store>(
    self: &mut Game,
    _cap: &AdminCap,
    pos_index: u64,
    cell: Cell
){
    self.cells.add(pos_index, cell);
}

// === Package Functions ===

// fun player_move(
//     turn_cap: TurnCap
// ){
//     todo!()
// }

// === Private Functions ===
fun new(
    players: vector<address>,
    ctx: &mut TxContext
):Game {
    let num_of_players = players.length();

    let mut values = vector<u64>[];
    let last_player = players[num_of_players - 1];
    std::u64::do!<()>(num_of_players, |_|values.push_back(0));
    
    Game{
        id: object::new(ctx),
        versions: vec_set::singleton(MODULE_VERSION),
        supported_assets: vec_set::empty(),
        player_assets: bag::new(ctx),
        player_position: vec_map::from_keys_values(players, values),
        cells: object_bag::new(ctx),
        last_player,
        last_action_time: 0,
        plays: 0,
    }
}

fun drop(self: Game){
    let Game{
        id,
        versions: _,
        supported_assets: _,
        player_assets,
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

    let mut game = new(vector[player_a, player_b, player_c], &mut ctx);

    std::u64::do!<()>(5, |_| game.roll_game());

    assert!(game.current_round() == 1);

    game.drop();
}

