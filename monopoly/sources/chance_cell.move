module monopoly::chance_cell;

// === imports ===
use monopoly::{
    monopoly::{AdminCap, Game, ActionRequest, },
    house_cell::{
        HouseRegistry,
        HouseCell
    },
    supply::{Monopoly}
    // mt::{MT},
};

use sui::{
    vec_set::{Self, VecSet},
    random::{ Random},
    event::{Self,}
};

use std::{
    string::{String},
};


// === Structs ===
public struct IndexReceipt{
    idx: u8,
}

public struct BalanceChance has store, drop, copy {
    description: String,
    is_increase: bool,    
    amount: u64,
}

public struct TollChance has store, drop, copy{
    description: String,
    name: String, // House's name
    bps: u64, // base: 10_000
}

public struct JailChance has store, drop, copy{
    description: String,
    round: u8,
}

public struct HouseChance has store, drop, copy{
    description: String,
    is_level_up: bool,
    name: String, // House's name
}

public struct ChanceCell has key, store{
    id: UID,
    name: String,
    balance_chances_len: u8,
    toll_chances_len: u8,
    jail_chances_len: u8,
    house_chances_len: u8,
}

public struct ChanceRegistry has key{
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
    round: u8
}

public struct HouseChancePicked has copy, drop{
    game: ID,
    player: address,
    description: String,
    house_name: String,
    is_level_up: bool,
    level: u8,
}

// === Errors ===
const EChanceTypenOTdefined: u64 = 0;

// === Constants ===
const VERSION: u64 = 1;
const MAX_ROUND: u8 = 12;

// === Alias ===

// === Init Function ===
fun init (ctx: &mut TxContext){
    let registry = ChanceRegistry{
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

public fun name(self: &ChanceCell,): String{ self.name }

public fun balance_chance_info(
    balance_chance: &BalanceChance,
): (String, bool, u64){
    (
        balance_chance.description,
        balance_chance.is_increase,
        balance_chance.amount
    )
}

public fun toll_chance_info(
    toll_chance: &TollChance,
): (String, String, u64){
    (
        toll_chance.description,
        toll_chance.name,
        toll_chance.bps
    )
}

public fun jail_chance_info(
    jail_chance: &JailChance,
): (String, u8){
    (
        jail_chance.description,
        jail_chance.round
    )
}

public fun house_chance_info(
    house_chance: &HouseChance,
): (String, bool, String){
    (
        house_chance.description,
        house_chance.is_level_up,
        house_chance.name
    )
}

public fun balance_chances(
    registry: &ChanceRegistry,
): &VecSet<BalanceChance>{
    &registry.balance_chances
}

public fun jail_chances(
    registry: &ChanceRegistry,
): &VecSet<JailChance>{
    &registry.jail_chances
}

public fun house_chances(
    registry: &ChanceRegistry,
): &VecSet<HouseChance>{
    &registry.house_chances
}

public fun toll_chances(
    registry: &ChanceRegistry,
): &VecSet<TollChance>{
    &registry.toll_chances
}

public fun balance_chance_amt(
    registry: &ChanceRegistry,
): u8{
    registry.balance_chances.size() as u8
}

public fun toll_chance_amt(
    registry: &ChanceRegistry,
): u8{
     registry.toll_chances.size() as u8
}

public fun jail_chance_amt(
    registry: &ChanceRegistry,
): u8{
    registry.jail_chances.size() as u8
}

public fun house_chance_amt(
    registry: &ChanceRegistry,
): u8{
    registry.house_chances.size() as u8
}

public fun total_chance_amt(
    self: &ChanceCell,
): u8{
    self.balance_chances_len + self.toll_chances_len + self.jail_chances_len + self.house_chances_len
}

public fun index(
    receipt: &IndexReceipt
): u8{
    receipt.idx
}

public fun toll_chance_name(toll_chance: &TollChance): String{ toll_chance.name }


// === Admin Functions ===
public fun add_balance_chance_to_registry(
    registry: &mut ChanceRegistry,
    _: &AdminCap,
    description: String,
    is_increase: bool,
    amount: u64,
){
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
){
    house_registry.assert_if_not_in_registry(name);
    let toll_chance = new_toll_chance(description, name, bps);
    registry.toll_chances.insert(toll_chance);
}

public fun add_jail_chance_to_registry(
    registry: &mut ChanceRegistry,
    _: &AdminCap,
    description: String,
    round: u8,
){
    let jail_chance = new_jail_chance(description, round);
    registry.jail_chances.insert( jail_chance);
}

public fun add_house_chance_to_registry(
    registry: &mut ChanceRegistry,
    _: &AdminCap,
    house_registry: &HouseRegistry,
    description: String,
    is_level_up: bool,
    name: String, 
){
    house_registry.assert_if_not_in_registry(name);
    let house_chance = new_house_chance(description, is_level_up, name);
    registry.house_chances.insert(house_chance);
}

public fun new_chance_cell(
    registry: &ChanceRegistry,
    _: &AdminCap,
    name: String,
    ctx: &mut TxContext
): ChanceCell{
    ChanceCell{
        id: object::new(ctx),
        name,
        balance_chances_len: registry.balance_chances().size() as u8,
        toll_chances_len: registry.toll_chances().size() as u8,
        jail_chances_len: registry.jail_chances().size() as u8,
        house_chances_len: registry.house_chances().size() as u8,
    }
}

// pick a index to map chance registry
#[allow(lint(public_random))]
public fun pick_chance_num(
    registry: &ChanceRegistry,
    _: &Game,
    rand: &Random,
    ctx: &mut TxContext,
): IndexReceipt{
    let total_amt = registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt() + registry.house_chance_amt();
    let mut generator = rand.new_generator(ctx);
    let pick_idx = generator.generate_u8_in_range(0, total_amt);
    IndexReceipt{
        idx: pick_idx,
    }
}

// it needs to be called after pick_chance_num function.
public fun burn_receipt_and_get_balance_chance_info(
    registry: &ChanceRegistry,
    receipt: IndexReceipt,
): BalanceChance{

    let IndexReceipt{
        idx: chance_idx,
    } = receipt;

    if (chance_idx < registry.balance_chance_amt()
    ){ 
        let keys = *registry.balance_chances.keys();
        let idx = chance_idx % registry.balance_chance_amt();
        *keys.borrow(idx as u64)
    }else{
        abort EChanceTypenOTdefined
    }
}

// it needs to be called after pick_chance_num function.
public fun burn_receipt_and_get_toll_chance_info(
    registry: &ChanceRegistry,
    receipt: IndexReceipt,
): TollChance{

    let IndexReceipt{
        idx: chance_idx,
    } = receipt;

    if (chance_idx < registry.balance_chance_amt() + registry.toll_chance_amt()
    ){ 
        let keys = *registry.toll_chances.keys();
        let idx = (chance_idx - registry.balance_chance_amt())% registry.toll_chance_amt();
        *keys.borrow(idx as u64)
    }else{
        abort EChanceTypenOTdefined
    }
}

// it needs to be called after pick_chance_num function.
public fun burn_receipt_and_get_jail_chance_info(
    registry: &ChanceRegistry,
    receipt: IndexReceipt,
): JailChance{

    let IndexReceipt{
        idx: chance_idx,
    } = receipt;

    if (chance_idx < registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt()
    ){ 
        let keys = *registry.jail_chances.keys();
        let idx = (chance_idx - registry.balance_chance_amt() - registry.toll_chance_amt() )% registry.jail_chance_amt();
        *keys.borrow(idx as u64)
    }else{
        abort EChanceTypenOTdefined
    }
}

// it needs to be called after pick_chance_num function.
public fun burn_receipt_and_get_house_chance_info(
    registry: &ChanceRegistry,
    receipt: IndexReceipt,
): HouseChance{

    let IndexReceipt{
        idx: chance_idx,
    } = receipt;

    if (chance_idx < registry.balance_chance_amt() + registry.toll_chance_amt() + registry.jail_chance_amt() + registry.house_chance_amt()
    ){ 
        let keys = *registry.house_chances.keys();
        let idx = (chance_idx - registry.balance_chance_amt() - registry.toll_chance_amt() - registry.jail_chance_amt())% registry.house_chance_amt();
        *keys.borrow(idx as u64)
    }else{
        abort EChanceTypenOTdefined
    }
}

// handle balance chance to update user balance
public fun initialize_balance_chance(
    request: &mut ActionRequest<BalanceChance>,
    game: &mut Game,
    chance: BalanceChance,
){
    let player = request.action_request_player();
    let (_, is_increase, amount) = chance.balance_chance_info();

    if (is_increase){
        let balance_manager = game.balance_mut<Monopoly>();
        let _ = balance_manager.add_balance(player, amount);
    }else{
        let player_value = game.player_balance<Monopoly>(player).value();
        // check if the player has enough value
        if (player_value >= chance.amount){
            let balance_manager = game.balance_mut<Monopoly>();
            let _ = balance_manager.sub_balance( player, amount);
        }else{
            let player_asset_value = calculate_total_asset_value_of(game, player);
            let player_total_value = player_value + player_asset_value;
            // calculate the player's total va         
            if (player_total_value < chance.amount){ // the player is bankrupt
                let balance_manager = game.balance_mut<Monopoly>();
                balance_manager.saturating_sub_balance(player, chance.amount);

                if (game.player_asset_of(player).size() > 0){
                    //remove  all assets
                    game.player_asset_of(player).size().do!<u64>(|_| {
                        game.remove_player_asset(player);
                    });
                };  

                // skip the player util the game is over
                game.add_to_skips(player, MAX_ROUND );

            }else{ 
                // Sell the player's assets to make a payment   
                let mut asset_value = 0;
                while(true){
                    let house_position = game.player_asset_of(player).keys().length() - 1;
                    let house_cell = game.borrow_cell_mut<HouseCell>(house_position as u64);
                    let sell_price = house_cell.sell_price_for_level(house_cell.level());
                    asset_value = asset_value + sell_price;
                    
                    game.remove_player_asset(player);
                    
                    let current_value = player_value + asset_value;
                    if (current_value >= chance.amount){
                        let balance_manager = game.balance_mut<Monopoly>();
                        let sub_value = player_value + chance.amount - current_value;
                        balance_manager.sub_balance(player, sub_value);
                        break
                    }
                    
                }                      
            };
        };

        
    };

    game.config_parameter(request, chance);
    request.settle_action_request();

    event::emit(BalanceChancePicked{
        game: object::id(game),
        player: player,
        description: chance.description,
        is_increase: chance.is_increase,
        amount: chance.amount
    });
}

public fun initialize_toll_chance(
    request: &mut ActionRequest<TollChance>,
    game: &mut Game,
    chance: TollChance,
){
    let house_position = game.house_position_of(chance.name);
    let house_cell = game.borrow_cell_mut<HouseCell>(house_position as u64);

    house_cell.update_toll_by_chance(chance.bps);
    
    game.config_parameter(request, chance);
    request.settle_action_request();

    event::emit(TollChancePicked{
        game: object::id(game),
        player: request.action_request_player(),
        description: chance.description,
        house_name: chance.name,
        bps: chance.bps,
    });
}

public fun initialize_jail_chance(
    request: &mut ActionRequest<JailChance>,
    game: &mut Game,
    chance: JailChance,
){
    let player = request.action_request_player();
    game.add_to_skips(player, chance.round);
    
    game.config_parameter(request, chance);
    request.settle_action_request();

    event::emit(JailChancePicked{
        game: object::id(game),
        player: request.action_request_player(),
        description: chance.description,
        round: chance.round,
    });

}

public fun initialize_house_chance(
    request: &mut ActionRequest<HouseChance>,
    game: &mut Game,
    chance: HouseChance
){  
    game.config_parameter(request, chance);
    request.settle_action_request();

    let house_position = game.house_position_of(chance.name);
    {
        let house_cell = game.borrow_cell_mut<HouseCell>(house_position as u64);

        if (chance.is_level_up){ 
            house_cell.level_up_by_chance();
        }else{
            house_cell.level_down_by_chance();
        };
    };

    
    let house_cell = game.borrow_cell<HouseCell>(house_position as u64);

    event::emit(HouseChancePicked{
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
fun new_balance_chance(
    description: String,
    is_increase: bool,
    amount: u64,
): BalanceChance{
    BalanceChance{
        description,
        is_increase,
        amount
    }
}

fun new_toll_chance(
    description: String,
    name: String,
    bps: u64,
): TollChance{
    TollChance{
        description,
        name,
        bps
    }
}

fun new_jail_chance(
    description: String,
    round: u8,
): JailChance{
    JailChance{
        description,
        round
    }
}

fun new_house_chance(
    description: String,
    is_level_up: bool,
    name: String,
): HouseChance{
    HouseChance{
        description,
        is_level_up,
        name,
    }
}

fun calculate_total_asset_value_of (
    game: &Game,
    player: address
): u64{
    let asset_idxs = (game.player_asset_of(player)).into_keys();
        let mut player_asset_value = 0;
        asset_idxs.do!(|idx| {
            let level = game.borrow_cell<HouseCell>(idx as u64 ).level();
            let (_, sell_prices, _) = game.borrow_cell<HouseCell>(idx as u64 ).house();
            let sell_price = *sell_prices.get(&level);
            player_asset_value = player_asset_value + sell_price;
        } );

        player_asset_value
}


// === Test Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun pick_chance_num_testing(
    idx: u8,
): IndexReceipt{
    IndexReceipt{
        idx,
    }
}

